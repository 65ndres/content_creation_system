class Scene < ApplicationRecord
  belongs_to :story

  after_create :create_images

  def create_images
    # the jobs wait for the story
    CreateSceneImagesJob.perform_now()
  end
end
