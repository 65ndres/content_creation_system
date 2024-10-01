class CheckSceneMotionImagesGenerationStatusJob < ApplicationJob
  queue_as :default

  def perform(*args)
    scene = args.first
    LeonardoClient.check_scene_motion_images_generation_status(scene)
    if scene.motion_images_generation_completed?
      puts "YESSSS"
      CreateSceneVideoJob.perform_now(scene)
    end
  end
end