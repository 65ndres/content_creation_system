class Story < ApplicationRecord
  belongs_to :source
  belongs_to :story_type
  has_many   :scenes

  after_create :create_text_and_scenes
  
  def create_text_and_scenes
    CreateStoryTextJob.perform_now(self)
    CreateStoryScenesJob.set(wait: 1.minute).perform_later(self)
  end

  def create_text
    self.text = ChatGPTClient.generate_story_text(self)
    self.save
    create_characters
  end

  def create_characters
    response = ChatGPTClient.generate_story_characters(self)
    data     = JSON.parse(response.gsub("```json", "").gsub("```", "").strip)
    self.characters = data.fetch("characters", [])
    self.save
  rescue JSON::ParserError, StandardError => e
    puts "Error extracting characters for story #{id}: #{e.message}"
    self.characters = []
    self.save
  end

  def create_scenes
    puts "Creating scenes for story #{self.id}"
    response = ChatGPTClient.generate_scene_images_prompts(self)
    data     = JSON.parse(response.gsub("```json", "").gsub("```", ""))

    data["pairs"].each do |obj|
      scene                 = Scene.new
      scene.story_id        = self.id
      scene.text            = obj["original"]
      scene.ai_image_prompt = obj["aiImagePrompts"]
      scene.images_total    = obj["aiImagePrompts"].count
      scene.save
    end
    # scene.text += "Dont forget to like and subscribe to see more videos like this one."
    # scene.save
    # maybe here add the recomnedation to the last scene
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

  def video_completed?
    self.video_url.present?
  end
 
end
