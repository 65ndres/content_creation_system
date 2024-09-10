class CreateStoryScenesJob < ApplicationJob
  queue_as :default

  def perform(*args)
    story = args.first
    puts "######## Create Story Scene job #{story} ########"
    story.create_scenes
  end
end
