class CheckStoryVideoGenerationStatusJob < ApplicationJob
    queue_as :default
  
    def perform(*args)
      story = args.first
      puts "######## CheckStoryVideoGenerationStatusJob #{story} ########"
      Json2videoClient.is_story_video_ready(story)
      if story.video_completed?
        puts "Yay, the video is completed!!!!  WE made it"
      end
    end
  end