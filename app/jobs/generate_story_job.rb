class GenerateStoryJob < ApplicationJob
  queue_as :default

  def perform(*args)
    story = args.first
    story.generate_story
  end
end
