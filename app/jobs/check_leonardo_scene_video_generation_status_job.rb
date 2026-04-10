class CheckLeonardoSceneVideoGenerationStatusJob < ApplicationJob
  queue_as :default

  def perform(*args)
    scene = args.first
    puts "######## CheckLeonardoSceneVideoGenerationStatusJob #{scene} ########"
    LeonardoClient.check_leonardo_scene_video_generation_status(scene)
  end
end
