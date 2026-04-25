Ensure redis is running

1. Create a Source and a story type
2. With the source and story type created above I need to create a new instance of a Story
    story = Story.new(source_id: Source.last.id, story_type: StoryType.last)

    1. Story has a call back after_create :create_text_and_scenes
        ChatGPTClient.generate_story_text gets called to generate the summirzed version of the story where
            I get to decide the length of it.
        ChatGPTClient.generate_scene_images_prompts also gets called to create the prompts and the correct format
            that will be sent to Leonardo. This last step creates a Scene which has its own call back.

    2. When a scene gets created from the step above :create_video_and_audio gets call
        LeonardoClient.generate_scene_video(scene) gets called. Leonardo API will give me gen_id that I will use  in a different job to poll until the video is ready. When is ready the video url will be saved on leonardo_video_url.
        ELevenLabs.create_audio_file also gets called to generate the Audio. This is an attachemnt that will be saved in S3.

    3. When the video and the audio per scene have been completed I will call VideoEditorClient.merge_audio_video
    to merge the records. This will also called CheckMergedAudioVideoGenerationStatusJob which by checking
    if story.scenes_audio_video_merge_completed? will merge all the videos together