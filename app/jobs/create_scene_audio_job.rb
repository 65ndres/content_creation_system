class CreateSceneAudioJob < ApplicationJob
  queue_as :default

  def perform(*args)
    scene = args.first
    ElevenlabsClient.create_audio_file(scene)
    if scene.story.scenes_audio_files_completed?
      # Merge Audio  and Video
    end
    # Do something later
    
  end
end
