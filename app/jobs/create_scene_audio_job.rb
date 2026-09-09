class CreateSceneAudioJob < ApplicationJob
  queue_as :default

  def perform(*args)
    scene = args.first
    Rails.logger.info("CreateSceneAudioJob scene=#{scene.id}")
    audio_bytes = ElevenlabsClient.create_audio_file(scene)
    scene.reload
    if audio_bytes.to_s.bytesize.positive? || scene.audio.attached?
      VideoEditorClient.persist_scene_media(scene, persist_audio: true, audio_bytes: audio_bytes)
    end
    if scene.video_url.present? && scene.audio.attached?
      MergeAudioVideoJob.set(wait: 1.minutes).perform_later(scene)
    end
  end
end
