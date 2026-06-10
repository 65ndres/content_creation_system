class CreateStoryScenesJob < ApplicationJob
  queue_as :default

  def perform(*args)
    story = args.first
    Rails.logger.info("CreateStoryScenesJob story=#{story.id}")
    story.create_scenes
  end
end
