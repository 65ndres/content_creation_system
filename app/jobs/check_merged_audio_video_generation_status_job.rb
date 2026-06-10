class CheckMergedAudioVideoGenerationStatusJob < ApplicationJob
  queue_as :default

  def perform(*args)
    scene = args.first
    story = scene.story
    Rails.logger.info("CheckMergedAudioVideoGenerationStatusJob scene=#{scene.id}")
    VideoEditorClient.is_merged_audio_video_ready(scene)
    if story.scenes_audio_video_merge_completed?
      CreateStoryVideoJob.perform_now(story)
    end
  end
end
