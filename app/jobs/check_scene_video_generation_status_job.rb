class CheckSceneVideoGenerationStatusJob < ApplicationJob
    queue_as :default
  
    def perform(*args)
      scene = args.first
      story = scene.story
      Json2videoClient.is_scene_video_ready(scene)

      if story.scenes_video_generation_completed?
        story.scenes.each_with_index do |scene, i|
          CreateSceneAudioJob.set(wait: (1 + i).minutes).perform_later(scene)
        end
      end

    end
  end
  