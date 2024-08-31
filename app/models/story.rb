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
      scene.scene           = obj["original"]
      scene.ai_image_prompt = obj["aiImagePrompts"]
      scene.save
    end
  end
end
