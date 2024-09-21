class Scene < ApplicationRecord
  has_one_attached :audio
  belongs_to :story

  after_create :create_images

  def create_images
    CreateSceneImagesJob.set(wait: rand(5..15).round(2).seconds).perform_later(self)
    CreateSceneAudioJob.perform_now(self)
  end


  def images_generation_completed?
    self.images_total == self.images_data.count
  end
end
