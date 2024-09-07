# DONT README


1. Create Story
2. Create Scenes
3. Create images for Scenes
3. Create Video from images for Scenes
4. Create Audio File per scene
5. Merge Audio File and Video
6. Merge all the merged audio and video files, plus add subtitles




1. Story is created
    1.1 ChatGPT for story text
    1.2 ChatGPT for Scene description and therefore Scene creation
2. Scenes are created
    2.1 Call Leonardo to create images
        2.1.1 Leonardo will return a generation id for per image (leonardo_gen_ids)
        2.1.2 A Job will be scheduled to check for the images generation status (images_data)
    2.2 Create Scene video from images
        2.2.1 Scenes images are sent to JSON2VIDEO
        2.2.2 JSON2VIDEO will return a gen_id which will trigger a polling job
        2.2.3 Polling job will keep checking and save the data in :video_gen_id
            2.2.3.1 Each time the job is completed it will check whether all the other scenes
                    had their video generation completed to trigger the audio generation.
    2.3 Create audio file 
        2.3.1 Scene text is sent to ElevenLabs
        2.3.2 File is generated intantly store locally and right after upload it the S3
        2.3.3 Each time the job is completed it will check whether all the other scenes
              had their audio generation completed to trigger video and audio merge
    2.4 Merge video and audio
        2.4.1 Video and Audio file are sent to JSON2Video
        2.4.2 JSON2VIDEO will return a gen_id which will trigger a polling job
        2.4.3 Polling job will keep checking and save the data in :merged_audio_video_gen_id
            2.4.3.1 Each time the job is completed it will check whether all the other scenes had their audio and video merge completed to trigger the story video creation.
    2.5 Create Story video file
        2.5.1 Collection of all merged audio and video files will be send to JSON2VIDEO
              along withe the caption settings
        2.4.2 JSON2VIDEO will return a gen_id which will trigger a polling job
        2.4.3 Polling job will keep checking and save the data in :video_url

