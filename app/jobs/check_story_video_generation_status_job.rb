class CheckStoryVideoGenerationStatusJob < ApplicationJob
    queue_as :default
  
    def perform(*args)
      story = args.first  
      Json2videoClient.is_story_video_ready(story)
      if story.video_completed?
        puts "Yay, the video is completed"
      end
    end
  end