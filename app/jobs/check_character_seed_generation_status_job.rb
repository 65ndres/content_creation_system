class CheckCharacterSeedGenerationStatusJob < ApplicationJob
  queue_as :default

  def perform(*args)
    story = args.first
    generation_id = args.second
    Rails.logger.info("CheckCharacterSeedGenerationStatusJob story=#{story.id} generation_id=#{generation_id}")
    LeonardoClient.check_character_seed_generation_status(story, generation_id)
  end
end
