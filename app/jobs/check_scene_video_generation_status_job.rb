class CheckSceneVideoGenerationStatusJob < ApplicationJob
    queue_as :default
  
    def perform(*args)
      scene = args.first
      story = scene.story
      puts "######## CheckSceneVideoGenerationStatusJob #{scene} ########"
      Json2videoClient.is_scene_video_ready(scene)

      if scene.video_url.present? && scene.audio.present?
        MergeAudioVideoJob.set(wait: 1.minutes).perform_later(scene)
      end

    end
  end
  