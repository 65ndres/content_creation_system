class CreateStoryTextJob < ApplicationJob
  queue_as :default

  def perform(*args)
    story = args.first
    Rails.logger.info("CreateStoryTextJob story=#{story.id}")
    story.create_text
    story.create_characters

    if StoryJsonNormalizer.normalize_characters(story.characters).blank?
      Rails.logger.info("CreateStoryTextJob story=#{story.id}: no characters, skipping seed image")
      CreateStoryScenesJob.perform_later(story)
      return
    end

    LeonardoClient.generate_character_seed_image(story)
  end
end
