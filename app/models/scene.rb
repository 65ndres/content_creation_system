class Scene < ApplicationRecord
  has_one_attached :audio
  belongs_to :story

  after_create :create_images

  def create_images
    CreateSceneImagesJob.set(wait: rand(5..15).round(2).seconds).perform_later(self)
    CreateSceneAudioJob.perform_now(self)
  end

  def images_generation_completed?
    self.images_data.reduce(true) do |is_completed, image_data|
      is_completed && image_data["static_url"].present?
    end
  end

  def motion_images_generation_completed?
    self.images_data.reduce(true) do |is_completed, image_data|
      is_completed && image_data["motion_url"].present?
    end
  end
end
