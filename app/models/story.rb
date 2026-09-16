class Story < ApplicationRecord
  belongs_to :source
  belongs_to :story_type
  has_many   :scenes

  attr_accessor :defer_pipeline

  before_validation :normalize_image_generation_model, :normalize_video_generation_model
  after_create :create_text_and_scenes, unless: :defer_pipeline

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

  def create_text
    self.text = ChatGPTClient.generate_story_text(self)
    self.save
  end

  def create_characters
    response = ChatGPTClient.generate_story_characters(self)
    data     = JSON.parse(response.gsub("```json", "").gsub("```", "").strip)
    self.characters = StoryJsonNormalizer.normalize_characters(data.fetch("characters", []))
    self.save
  rescue JSON::ParserError, StandardError => e
    Rails.logger.error("Error extracting characters for story #{id}: #{e.message}")
    self.characters = []
    self.save
  end

  def create_scenes
    Rails.logger.info("Creating scenes for story #{id}")
    response = ChatGPTClient.generate_scene_images_prompts(self)
    data     = JSON.parse(response.gsub("```json", "").gsub("```", "").strip)
    existing_texts = scenes.reload.pluck(:text).map { |text| normalize_scene_text(text) }

    StoryJsonNormalizer.normalize_pairs(data).each do |obj|
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
  rescue JSON::ParserError, StandardError => e
    Rails.logger.error("Error creating scenes for story #{id}: #{e.message}")
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
