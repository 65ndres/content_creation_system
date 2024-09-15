class MergeAudioVideoJob < ApplicationJob
    queue_as :default
  
    def perform(*args)
      scene = args.first
      puts "######## CreateStoryVideoJob #{scene} ########"
      Json2videoClient.merge_audio_video(scene)
    end
  end