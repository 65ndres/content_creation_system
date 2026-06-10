class CheckStoryVideoGenerationStatusJob < ApplicationJob
    queue_as :default
  
    def perform(*args)
      story = args.first
      Rails.logger.info("CheckStoryVideoGenerationStatusJob story=#{story.id}")
      VideoEditorClient.is_story_video_ready(story)
      if story.video_completed?
        Rails.logger.info("Story video completed story=#{story.id}")
      end
    end
  end