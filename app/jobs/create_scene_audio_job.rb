class CreateSceneAudioJob < ApplicationJob
  queue_as :default

  def perform(*args)
    scene = args.first
    ElevenlabsClient.create_audio_file(scene)
    if scene.story.scenes_audio_files_completed?
      ## we gotta call something here
      Json2videoClient.merge_audio_video(scene)
      ### I hace somethinm to do there
    end
    
  end
end
