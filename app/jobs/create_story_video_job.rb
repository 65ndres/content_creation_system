class CreateStoryVideoJob < ApplicationJob
  queue_as :default

  def perform(*args)
    story = args.first
    VideoEditorClient.create_story_video(story)
  end
end