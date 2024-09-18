require 'httparty'

class VideoEditorClient

  VIDEO_ENDPOINT = "http://172.20.0.5:3001/reel_generator/videos"

  def self.create_scene_video(scene)
    payload = create_scene_video_payload(scene)
  
    headers                  = {}
    options                  = {}
    headers[:"Content-Type"] = "application/json"
    options[:headers]        = headers
    options[:body]           = payload.to_json

    response = HTTParty.post(VIDEO_ENDPOINT + "/generate_scene_video", options)

    scene.video_gen_id = response["gen_id"]

    if scene.save
      CheckSceneVideoGenerationStatusJob.set(wait: 1.minutes).perform_later(scene)
    end

  end

  def self.merge_audio_video(scene)
    payload = merge_audio_video_payload(scene)

    headers                  = {}
    options                  = {}
    headers[:"Content-Type"] = "application/json"
    options[:headers]        = headers
    options[:body]           = payload.to_json

    response = HTTParty.post(VIDEO_ENDPOINT + "/merge_audio_video", options)

    scene.merged_audio_video_gen_id = response["gen_id"]

    if scene.save
      CheckMergedAudioVideoGenerationStatusJob.set(wait: (3 + rand()).round(2).minutes).perform_later(scene)
    end
  end


  def self.create_story_video(story)
    payload = create_story_video_payload(scene)

    headers                  = {}
    options                  = {}
    headers[:"Content-Type"] = "application/json"
    options[:headers]        = headers
    options[:body]           = payload.to_json

    response = HTTParty.post(VIDEO_ENDPOINT + "/merge_audio_video", options)

    story.video_gen_id  = response["gen_id"]

    if story.save
      CheckStoryVideoGenerationStatusJob.set(wait: 5.minutes).perform_later(story)
    end
  end

  def self.create_story_video_payload(story)
  end

  def self.merge_audio_video_payload(scene)
    payload                = {}
    payload["video_path"]  = scene.video_url
    payload["scene_id"]    = scene.id
    payload["story_id"]    = scene.story_id
    payload
  end

  def self.create_scene_video_payload(scene)
    payload                = {}
    payload["images_urls"] = []
    payload["audio_url"]   = scene.audio.blob.url(expires_in: 5000) 
    payload["scene_id"]    = scene.id
    payload["story_id"]    = scene.story.id
    scene.images_data.each do |id|
      payload["images_urls"] << id["url"]
    end
    payload
  end

  def self.is_scene_video_ready(scene)
    gen_id = scene.video_gen_id
    data   = generation_status(gen_id)

    if data["completed"] == true
      scene.video_url = data["file_path"]
      scene.save
    else
      CheckSceneVideoGenerationStatusJob.set(wait: 5.minutes).perform_later(scene)
    end
  end

  def self.is_merged_audio_video_ready(scene)
    gen_id   = scene.merged_audio_video_gen_id
    data     = generation_status(gen_id)

    if data["completed"] == true
      scene.merged_audio_video_url = data["file_path"]
      scene.save
    else
      CheckStoryVideoGenerationStatusJob.set(wait: 5.minutes).perform_later(scene)
    end
  end

  def self.is_story_video_ready(story)
    gen_id = story.video_gen_id
    data   = video_generation_status(gen_id)

    if data["completed"] == true
      story.video_url = data["file_path"]
      story.save
    else
      CheckSceneVideoGenerationStatusJob.set(wait: 5.minutes).perform_later(story)
    end
  end

  def self.generation_status(gen_id)
    response = HTTParty.get(VIDEO_ENDPOINT + "/generation_status" + "/#{gen_id}")
    response["body"]
  end


end