class CreateSceneAudioJob < ApplicationJob
  queue_as :default

  def perform(*args)
    scene = args.first
    puts "######## CreateSceneAudioJob #{scene} ########"
    ElevenlabsClient.create_audio_file(scene)

    if scene.story.scenes_audio_files_completed?
      story.scenes.each do |scene|
        Json2videoClient.merge_audio_video(scene)
      end
    end
    
  end
end
