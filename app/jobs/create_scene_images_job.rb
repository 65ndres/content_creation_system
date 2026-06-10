class CreateSceneImagesJob < ApplicationJob
  queue_as :default

  def perform(*args)
    scene = args.first
    Rails.logger.info("CreateSceneImagesJob scene=#{scene.id}")
    LeonardoClient.generate_scene_images(scene)
  end
end
