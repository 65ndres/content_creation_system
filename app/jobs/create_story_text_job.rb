class CreateStoryTextJob < ApplicationJob
  queue_as :default

  def perform(*args)
    story = args.first
    puts "######## Create Story Text Job here #{story} ########"
    story.create_text
  end
end
