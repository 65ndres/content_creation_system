class CreateStoryVideoJob < ApplicationJob
  queue_as :default

  def perform(*args)
    story = args.first
    Json2videoClient.create_story_video(story)
  end
end