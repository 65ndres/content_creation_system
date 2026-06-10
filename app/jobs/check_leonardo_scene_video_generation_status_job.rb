class CheckLeonardoSceneVideoGenerationStatusJob < ApplicationJob
  queue_as :default

  def perform(*args)
    scene = args.first
    Rails.logger.info("CheckLeonardoSceneVideoGenerationStatusJob scene=#{scene.id}")
    LeonardoClient.check_leonardo_scene_video_generation_status(scene)
    if scene.leonardo_video_url.present? && scene.audio.attached?
      MergeAudioVideoJob.set(wait: 1.minutes).perform_later(scene)
    end
  end
end
