class CreateStoryTextJob < ApplicationJob
  queue_as :default

  def perform(*args)
    story = args.first
    story.create_text
  end
end
