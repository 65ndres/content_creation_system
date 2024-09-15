class CreateSceneAudioJob < ApplicationJob
  queue_as :default

  def perform(*args)
    scene = args.first
    story = scene.story
    puts "######## CreateSceneAudioJob #{scene} ########"
    ElevenlabsClient.create_audio_file(scene)
    
  end
end
