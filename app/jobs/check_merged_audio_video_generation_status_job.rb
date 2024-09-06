class CheckMergedAudioVideoGenerationStatusJob < ApplicationJob
    queue_as :default

    def perform(*args)
        scene = args.first
        Json2videoClient.is_merged_audio_video_ready(scene)
        # if 
        # once done ask if al other scenes have it and fo
        # Schedule the nex item
        # add all video together and add captions
    end
end