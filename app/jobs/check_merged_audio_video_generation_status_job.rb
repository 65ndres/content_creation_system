class CheckMergedAudioVideoGenerationStatusJob < ApplicationJob
  queue_as :default

  def perform(*args)
    scene = args.first
    story = scene.story
    Json2videoClient.is_merged_audio_video_ready(scene)
    if story.scenes_audio_video_merge_completed?
      CreateStoryVideojob.perform_now(story) 
    end
  end
end