class CreateStoryScenesJob < ApplicationJob
  queue_as :default

  def perform(*args)
    story = args.first
    story.create_scenes
  end
end
