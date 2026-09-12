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
    StoryJsonNormalizer.normalize_pairs(data).each do |obj|
      prompts               = StoryJsonNormalizer.normalize_ai_image_prompts(obj["aiImagePrompts"])
      scene                 = Scene.new
      scene.story_id        = self.id
      scene.text            = obj["original"]
      scene.ai_image_prompt = prompts
      scene.images_total    = prompts.size
      scene.save
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

  def normalize_image_generation_model
    self.image_generation_model = LeonardoClient.normalize_image_model(image_generation_model)
  end

  def normalize_video_generation_model
    self.video_generation_model = LeonardoClient.normalize_video_model(video_generation_model)
  end
end
