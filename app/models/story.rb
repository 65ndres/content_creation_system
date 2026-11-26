class Story < ApplicationRecord
  belongs_to :source
  belongs_to :story_type
  has_many   :scenes

  # queued → running → done / failed. Cancelled stories leave the queue without running.
  # See StoryQueue: only STORY_QUEUE_CONCURRENCY stories (default 1) run at a time.
  QUEUE_STATES = %w[queued running done failed cancelled].freeze

  attr_accessor :defer_pipeline

  enum :queue_state, QUEUE_STATES.index_with(&:itself), prefix: :queue, validate: true

  scope :queue_running, -> { where(queue_state: "running") }
  scope :queue_waiting, -> { where(queue_state: "queued").order(:queued_at, :id) }

  before_validation :normalize_image_generation_model, :normalize_video_generation_model
  before_create { self.queued_at ||= Time.current }
  # New stories wait their turn; defer_pipeline is for callers that drive the steps themselves.
  after_create_commit :join_queue, unless: :defer_pipeline

  def self.start(story_type, source, model: LeonardoClient::DEFAULT_IMAGE_MODEL, video_model: nil)
    create!(
      story_type: story_type,
      source: source,
      image_generation_model: model,
      video_generation_model: video_model
    )
  end

  def leonardo_direct_video?
    LeonardoClient.normalize_video_model(video_generation_model).present?
  end

  def create_text_and_scenes
    CreateStoryTextJob.perform_now(self)
  end

  def join_queue
    StoryQueue.advance!
  end

  # The final video exists (or a review-only story has its scenes): free the slot.
  def finish_in_queue!
    return if queue_done? || queue_cancelled?

    leave_queue!("done")
  end

  # Something stopped the pipeline. Only a running story is marked; a failed manual regenerate on a
  # finished story does not reopen it.
  def fail_in_queue!(reason)
    Rails.logger.error("Story #{id} failed in queue: #{reason}")
    return unless queue_running?

    leave_queue!("failed", error: reason.to_s.truncate(500))
  end

  # A queued story leaves the line; a running one frees the slot (jobs already sent keep going).
  def cancel_in_queue!
    return false unless queue_queued? || queue_running?

    leave_queue!("cancelled")
    true
  end

  # A failed or cancelled story goes to the back of the line and resumes where it stopped.
  def retry_in_queue!
    return false unless queue_failed? || queue_cancelled?

    now = Time.current
    update_columns(queue_state: "queued", queued_at: now, finished_at: nil, last_error: nil, updated_at: now)
    StoryQueue.advance!
    true
  end

  # Restart the unfinished steps of a story that already has scenes.
  def resume_pipeline!
    return finish_in_queue! unless auto_produce?

    if scenes_audio_video_merge_completed?
      return finish_in_queue! if video_url.present?

      update_columns(video_gen_id: nil)
      return create_final_video_if_ready!
    end

    queued = 0
    scenes.order(:id).each do |scene|
      scene.create_audio unless scene.audio.attached?
      next if scene.merged?

      if scene.video_ready?
        MergeAudioVideoJob.perform_later(scene) if scene.audio.attached?
      else
        # Whatever was in flight when the story stopped will not report back.
        scene.reset_visual_generation!
        scene.save!
        queued += 1 if scene.enqueue_leonardo_generation!(wait: queued * 30.seconds)
      end
    end
  end

  # The newest change to the story or any of its scenes; the watchdog uses it to spot a stall.
  def last_activity_at
    [ started_at, updated_at, scenes.maximum(:updated_at) ].compact.max
  end

  def create_text
    self.text = ChatGPTClient.generate_story_text(self)
    self.save
  end

  # A fixed cast keeps its exact descriptions (and order) for the characters this
  # story mentions. Without extend_cast that is the whole list; with it, ChatGPT
  # adds the story's other characters after them.
  def create_characters
    cast  = StoryJsonNormalizer.normalize_characters(story_type.cast)
    fixed = StoryJsonNormalizer.filter_characters_in_text(cast, text.to_s)
    if cast.present? && !story_type.extend_cast?
      self.characters = fixed
      return save
    end

    response  = ChatGPTClient.generate_story_characters(self, fixed_cast: cast)
    data      = JSON.parse(response.gsub("```json", "").gsub("```", "").strip)
    generated = StoryJsonNormalizer.normalize_characters(data.fetch("characters", []))
    self.characters = merge_cast(fixed, cast, generated)
    self.save
  rescue JSON::ParserError, StandardError => e
    Rails.logger.error("Error extracting characters for story #{id}: #{e.message}")
    self.characters = Array(fixed)
    self.save
  end

  def create_scenes
    Rails.logger.info("Creating scenes for story #{id}")
    response = ChatGPTClient.generate_scene_images_prompts(self)
    data     = JSON.parse(response.gsub("```json", "").gsub("```", "").strip)
    existing_texts = scenes.reload.pluck(:text).map { |text| normalize_scene_text(text) }

    pairs = StoryJsonNormalizer.merge_mid_phrase_pairs(StoryJsonNormalizer.normalize_pairs(data))
    pairs.each do |obj|
      text = obj["original"].to_s
      if scene_text_already_present?(text, existing_texts)
        Rails.logger.info("Skipping existing scene text for story #{id}")
        next
      end

      prompts               = StoryJsonNormalizer.normalize_ai_image_prompts(obj["aiImagePrompts"])
      scene                 = Scene.new
      scene.story_id        = self.id
      scene.text            = text
      scene.ai_image_prompt = prompts
      scene.images_total    = prompts.size
      scene.save!
      existing_texts << normalize_scene_text(text)
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotSaved => e
      Rails.logger.error("Error creating scene for story #{id}: #{e.message}")
    end

    scenes.reload.order(:id).each do |scene|
      scene.create_audio unless scene.audio.attached?
    end

    if scenes.none?
      fail_in_queue!("No scenes were created")
    elsif auto_produce?
      enqueue_scene_generations!
    else
      # Without auto-produce the story waits for review, so it gives up its turn.
      finish_in_queue!
    end
  rescue JSON::ParserError, StandardError => e
    Rails.logger.error("Error creating scenes for story #{id}: #{e.message}")
    fail_in_queue!("Creating scenes failed: #{e.message}")
  end

  # Leonardo's plan allows one pending generation at a time, so space out
  # every scene (images and direct video alike).
  def enqueue_scene_generations!
    queued = 0
    scenes.order(:id).each do |scene|
      queued += 1 if scene.enqueue_leonardo_generation!(wait: queued * 30.seconds)
    end
    queued
  end

  # Called whenever a scene finishes merging. With auto_produce on, the last
  # merge kicks off the final story video. The row lock keeps two scenes that
  # finish together from both requesting it.
  def create_final_video_if_ready!
    return false unless auto_produce?

    started = false
    with_lock do
      if video_url.blank? && video_gen_id.blank? && scenes_audio_video_merge_completed?
        Rails.logger.info("Auto-producing final video story=#{id}")
        VideoEditorClient.create_story_video(self)
        started = true
      end
    end
    started
  end

  def scenes_video_generation_completed?
    self.scenes.reduce(true) do |is_completed, scene|
      is_completed && scene.video_url.present?
    end
  end

  def scenes_audio_video_merge_completed?
    scenes.any? && scenes.all? { |scene| scene.merged_audio_video_url.present? }
  end

  def scenes_audio_files_completed?
    self.scenes.reduce(true) do |is_completed, scene|
      is_completed && scene.audio.blob.present?
    end
  end

  def video_completed?
    self.video_url.present?
  end

  private

  def leave_queue!(state, error: nil)
    now = Time.current
    update_columns(queue_state: state, finished_at: now, last_error: error, updated_at: now)
    StoryQueue.advance!
  end

  # A generated character that shares a cast name takes the cast description.
  def merge_cast(fixed, cast, generated)
    generated.each_with_object(fixed.dup) do |character, merged|
      entry = cast.find { |c| c["name"].casecmp?(character["name"].to_s) } || character
      merged << entry unless merged.any? { |c| c["name"].casecmp?(entry["name"]) }
    end
  end

  def normalize_scene_text(text)
    text.to_s.downcase.gsub(/[^a-z0-9\s]/, " ").squeeze(" ").strip
  end

  def scene_text_already_present?(text, existing_texts)
    normalized = normalize_scene_text(text)
    return true if existing_texts.include?(normalized)

    words = normalized.split
    return false if words.size < 5

    existing_texts.any? do |existing|
      other = existing.split
      next false if other.size < 4

      shorter, longer = [ words, other ].sort_by(&:size)
      shared = (shorter & longer).size
      shared >= 5 && shared >= (shorter.size * 0.7)
    end
  end

  def normalize_image_generation_model
    self.image_generation_model = LeonardoClient.normalize_image_model(image_generation_model)
  end

  def normalize_video_generation_model
    self.video_generation_model = LeonardoClient.normalize_video_model(video_generation_model)
  end
end
