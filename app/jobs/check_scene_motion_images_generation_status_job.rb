class CheckSceneMotionImagesGenerationStatusJob < ApplicationJob
  queue_as :default

  def perform(*args)
    scene = args.first
    LeonardoClient.check_scene_motion_images_generation_status(scene)
    if scene.motion_images_generation_completed?
      Rails.logger.info("Scene motion images completed scene=#{scene.id}")
      CreateSceneVideoJob.perform_now(scene)
    end
  end
end