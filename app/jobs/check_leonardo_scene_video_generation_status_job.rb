class CheckLeonardoSceneVideoGenerationStatusJob < ApplicationJob
  queue_as :default

  def perform(*args)
    scene = args.first
    puts "######## CheckLeonardoSceneVideoGenerationStatusJob #{scene} ########"
    LeonardoClient.check_leonardo_scene_video_generation_status(scene)
    if scene.leonardo_scene_video_generation_completed?
      MergeAudioVideoJob.set(wait: 1.minutes).perform_later(scene)
    end
  end
end
