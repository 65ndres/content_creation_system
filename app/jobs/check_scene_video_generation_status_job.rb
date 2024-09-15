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

      

      # if story.scenes_video_generation_completed?
      #   story.scenes.each_with_index do |scene, i|
      #     CreateSceneAudioJob.set(wait: (1 + i).minutes).perform_later(scene)
      #   end
      # end

    end
  end
  