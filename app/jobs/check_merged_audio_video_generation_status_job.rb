class CheckMergedAudioVideoGenerationStatusJob < ApplicationJob
  queue_as :default

  def perform(*args)
    scene = args.first
    Rails.logger.info("CheckMergedAudioVideoGenerationStatusJob scene=#{scene.id}")
    VideoEditorClient.is_merged_audio_video_ready(scene)
  end
end
