class CheckSceneVideoGenerationStatusJob < ApplicationJob
  queue_as :default

  def perform(*args)
    scene = args.first
    Rails.logger.info("CheckSceneVideoGenerationStatusJob scene=#{scene.id}")
    VideoEditorClient.is_scene_video_ready(scene)

    if scene.video_url.present? && scene.audio.attached?
      MergeAudioVideoJob.set(wait: 1.minutes).perform_later(scene)
    end
  end
end
