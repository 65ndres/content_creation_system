class CheckSceneVideoGenerationStatusJob < ApplicationJob
    queue_as :default
  
    def perform(*args)
      scene = args.first
      story = scene.story
      Json2videoClient.check_video_generation_status(scene)
      if story.scenes_video_generation_completed?
        puts "WOHOO all the scene videos have been created"
        # call job for next task
        # Job to generate audio files ( one per scene is my guess)
      end

    end
  end
  