class Scene < ApplicationRecord
  has_one_attached :audio
  belongs_to :story

  after_create_commit :create_audio

  def create_audio
    CreateSceneAudioJob.perform_now(self)
  end

  def create_video_and_audio
    create_audio
  end

  def merged?
    merged_audio_video_url.present?
  end

  def video_ready?
    leonardo_video_url.present? || video_url.present?
  end

  def leonardo_generation_in_flight?
    if story.leonardo_direct_video?
      leonardo_video_gen_id.present? && !video_ready?
    else
      Array(images_data).any? { |image_data| image_data["leonardo_image_gen_id"].present? } && !video_ready?
    end
  end

  def apply_prompt_text!(text)
    stripped = text.to_s.strip
    return if stripped.blank?

    prompts = if story.leonardo_direct_video?
      [ stripped ]
    else
      StoryJsonNormalizer.normalize_ai_image_prompts(
        stripped.split(/\n\s*\n/).map(&:strip).reject(&:blank?)
      )
    end
    return if prompts.blank?

    self.ai_image_prompt = prompts
    self.images_total = prompts.size
  end

  def reset_visual_generation!
    self.leonardo_video_url = nil
    self.leonardo_video_gen_id = nil
    self.video_url = nil
    self.video_gen_id = nil
    self.images_data = []
    self.merged_audio_video_url = nil
    self.merged_audio_video_gen_id = nil
  end

  def regenerate_leonardo_generation!(prompt: nil)
    apply_prompt_text!(prompt)
    reset_visual_generation!
    save!
    clear_story_video!
    enqueue_leonardo_generation!
  end

  def regenerate_audio!(text: nil)
    self.text = text.to_s.strip unless text.nil?
    return false if self.text.blank?

    audio.purge if audio.attached?
    self.merged_audio_video_url = nil
    self.merged_audio_video_gen_id = nil
    save!
    clear_story_video!
    CreateSceneAudioJob.perform_later(self)
    true
  end

  def enqueue_leonardo_generation!(wait: 0)
    return false if video_ready? || leonardo_generation_in_flight?

    job = story.leonardo_direct_video? ? LeonardoCreateSceneVideoJob : CreateSceneImagesJob
    if wait.to_f.positive?
      job.set(wait: wait).perform_later(self)
    else
      job.perform_later(self)
    end
    true
  end

  def generation_status_label
    return "Complete" if merged?
    return "Generating" if leonardo_generation_in_flight? || video_ready?
    "Waiting"
  end

  def leonardo_scene_video_generation_completed?
    story.scenes.reduce(true) do |is_completed, scene|
      is_completed && scene.leonardo_video_url.present?
    end
  end

  def images_generation_completed?
    return false if images_data.blank?

    images_data.all? { |image_data| image_data["static_url"].present? }
  end

  def has_generated_stills?
    images_data.any? { |image_data| image_data["static_url"].present? }
  end

  private

  def clear_story_video!
    return unless story.video_url.present? || story.video_gen_id.present?

    story.update_columns(video_url: nil, video_gen_id: nil)
  end
end
