class Story < ApplicationRecord
  belongs_to :source
  belongs_to :story_type
  has_many   :scenes

  before_create :create_text_and_scenes
  
  def create_text_and_scenes
    CreateStoryTextJob.perform_now(self)
    CreateStoryScenesJob.perform_now(self)
  end

  def create_text
    self.text = ChatGPTClient.generate_story_text(self)
    self.save
  end

  def create_scenes
    data = ChatGPTClient.generate_scene_images_prompts(self)
    JSON.parse(data)["pairs"].each do |obj|
      scene                 = Scene.new
      scene.story_id        = self.id
      scene.text            = obj["original"]
      scene.ai_image_prompt = obj["aiImagePrompts"]
      scene.images_total    = obj["aiImagePrompts"].count
      scene.save
    end
  end

  def scenes_video_generation_completed?
    self.scenes.reduce(true) do |is_completed, scene| 
      is_completed && scene.video_url.present?
    end
  end

  def scenes_audio_video_merge_completed?
    self.scenes.reduce(true) do |is_completed, scene|
      is_completed && scene.merged_audio_video_url.present?
    end
  end

  def scenes_audio_files_completed?
    self.scenes.reduce(true) do |is_completed, scene|
      is_completed && scene.audio.blob.present?
    end
  end
 
end
