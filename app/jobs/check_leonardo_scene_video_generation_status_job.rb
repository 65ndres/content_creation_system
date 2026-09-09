class CheckLeonardoSceneVideoGenerationStatusJob < ApplicationJob
  queue_as :default

  def perform(*args)
    scene = args.first
    Rails.logger.info("CheckLeonardoSceneVideoGenerationStatusJob scene=#{scene.id}")
    LeonardoClient.check_leonardo_scene_video_generation_status(scene)
    scene.reload
    if scene.leonardo_video_url.present? && scene.video_url.to_s.match?(/\Ahttps?:\/\//i)
      VideoEditorClient.persist_scene_media(scene, persist_video: true)
      scene.reload
    end

    local_video = scene.video_url.present? && !scene.video_url.to_s.match?(/\Ahttps?:\/\//i)
    if local_video && scene.audio.attached?
      MergeAudioVideoJob.set(wait: ([1,2,3].sample + rand()).round(2).minutes + rand(1...10.seconds)).perform_later(scene)
    elsif scene.leonardo_video_url.present? && !local_video
      Rails.logger.warn("CheckLeonardoSceneVideoGenerationStatusJob scene=#{scene.id}: persist video failed, retrying")
      self.class.set(wait: 1.minute).perform_later(scene)
    end
  end
end
