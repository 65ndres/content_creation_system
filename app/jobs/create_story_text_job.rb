class CreateStoryTextJob < ApplicationJob
  queue_as :default

  def perform(*args)
    story = args.first
    Rails.logger.info("CreateStoryTextJob story=#{story.id}")
    story.create_text
  end
end
