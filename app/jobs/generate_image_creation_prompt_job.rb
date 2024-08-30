class GenerateImageCreationPromptJob < ApplicationJob
  queue_as :default

  def perform(*args)
    story = args.first
    story.generate_image_creation_prompts
  end
end
