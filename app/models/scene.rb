class Scene < ApplicationRecord
  belongs_to :story

  after_create :create_images

  def create_images
    CreateSceneImagesJob.perform_now(self)
  end

  def create_video
    CreateSceneVideoJob.perform_now()
  end

  def images_generation_completed?
    self.images_total == self.images_data.count
  end
end
