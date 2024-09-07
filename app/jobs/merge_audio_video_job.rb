class MergeAudioVideoJob < ApplicationJob
    queue_as :default
  
    def perform(*args)
      scene = args.first
      Json2videoClient.merge_audio_video(story)
    end
  end