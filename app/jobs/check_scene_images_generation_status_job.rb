class CheckSceneImagesGenerationStatusJob < ApplicationJob
  queue_as :default

  def perform(*args)
    scene = args.first
    Rails.logger.info("CheckSceneImagesGenerationStatusJob scene=#{scene.id}")
    LeonardoClient.check_scene_images_generation_status(scene)
  end
end
