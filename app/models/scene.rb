class Scene < ApplicationRecord
  has_one_attached :audio
  belongs_to :story

  after_create_commit :create_video_and_audio

  def create_video_and_audio
    if story.leonardo_direct_video?
      LeonardoCreateSceneVideoJob.perform_now(self)
    else
      CreateSceneImagesJob.perform_now(self)
    end
    CreateSceneAudioJob.perform_now(self)
  end


  def leonardo_scene_video_generation_completed?
    # self.leonardo_video_gen_id.present?
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

  # def motion_images_generation_completed?
  #   self.images_data.reduce(true) do |is_completed, image_data|
  #     is_completed && image_data["motion_url"].present?
  #   end
  # end
end


# Here is going to create a video and audio for the scene

