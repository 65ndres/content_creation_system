class CreateSceneAudioJob < ApplicationJob
  queue_as :default

  def perform(*args)
    scene = args.first
    story = scene.story
    Rails.logger.info("CreateSceneAudioJob scene=#{scene.id}")
    ElevenlabsClient.create_audio_file(scene)
    
  end
end
