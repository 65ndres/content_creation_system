class MergeAudioVideoJob < ApplicationJob
  queue_as :default

  def perform(*args)
    scene = args.first
    Rails.logger.info("MergeAudioVideoJob scene=#{scene.id}")
    VideoEditorClient.merge_audio_video(scene)
  end
end
