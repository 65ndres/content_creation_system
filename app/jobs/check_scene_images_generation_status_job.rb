class CheckSceneImagesGenerationStatusJob < ApplicationJob
  queue_as :default

  def perform(*args)
    scene = args.first
    LeonardoClient.check_scene_images_generation_status(scene)
    if scene.images_generation_completed?
      CreateSceneVideoJob.perform_now(scene)
    end
  end
end
