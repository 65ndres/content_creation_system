require 'httparty'

class Json2videoClient

  MOVIES_ENDPOINT = "https://api.json2video.com/v2/movies"

  def self.create_scene_video(scene)
    return if scene.video_url.present?
    payload            = {}
    story              = scene.story
    story_type         = story.story_type
    payload["id"]      = "story-#{scene.story_id}-scene-#{scene.id}"
    payload["fps"]     = 25
    payload["cache"]   = payload["draft"] = false
    payload["width"]   = story_type.output_width
    payload["height"]  = story_type.output_height
    payload["scenes"]  = create_scene_video_payload(scene, story_type)
    project            = create_video(payload)
    scene.video_gen_id = project
    if scene.save
      CheckSceneVideoGenerationStatusJob.set(wait: 5.minutes).perform_later(scene)
    end
  end

  def self.merge_audio_video(scene)
    payload           = {}
    story             = scene.story
    story_type        = story.story_type
  
    payload["id"]     = "story-#{scene.story_id}-scene-#{scene.id}-audio-#{scene.id}"
    payload["fps"]    = 25
    payload["cache"]  = payload["draft"] = false
    payload["width"]  = story_type.output_width
    payload["height"] = story_type.output_height
    payload["scenes"] = merge_audio_video_payload(scene)
    project           = create_video(payload)

    scene.merged_audio_video_gen_id  = project

    if scene.save
      CheckMergedAudioVideoGenerationStatusJob.set(wait: 5.minutes).perform_later(scene)
    end
  end

  def self.create_story_video(story)
    payload            = {}
    story_type         = story.story_type
  
    payload["id"]      = "story-#{scene.story_id}-all-scenes"
    payload["fps"]     = 25
    payload["cache"]   = payload["draft"] = false
    payload["width"]   = story_type.output_width
    payload["height"]  = story_type.output_height
    payload["scenes"]  = create_story_video_payload(story)
    project            = create_video(payload)
    story.video_gen_id = project

    if story.save
      CheckStoryVideoGenerationStatusJob.set(wait: 5.minutes).perform_later(scene)
    end
  end

  def self.create_story_video_payload(story)
    result     = []
    story_type = story.story_type
    story.scenes.each do |scene|
      result_obj              = element_obj = {}
      result_obj["elements"]  = []
      element_obj["src"]      = scene.merged_audio_video_url
      element_obj["type"]     = "video"
      element_obj["zoom"]     = 0
      element_obj["width"]    = story_type.output_width
      element_obj["height"]   = story_type.output_height
      element_obj["duration"] = -1
      element_obj["position"] = "center-center"
      result_obj["elements"]  << element_obj
      result << result_obj
    end
    result
  end

  def self.create_scene_video_payload(scene, story_type)
    result = []
    scene.images_data.each do |image|
      result_obj              = element_obj = {}
      result_obj["elements"]  = []
      element_obj["src"]      = image["url"]
      element_obj["type"]     = "image"
      element_obj["zoom"]     = 2
      element_obj["width"]    = story_type.output_width
      element_obj["height"]   = story_type.output_height
      element_obj["duration"] = 5
      element_obj["position"] = "center-center"
      result_obj["elements"]  << element_obj
      result << result_obj
    end
    result
  end

  def self.video_generation_status(id)
    response = `curl --location --request GET '#{MOVIES_ENDPOINT}?id=#{id}' \
    --header 'X-api-key: #{ENV["JSON2VIDEO_KEY"]}' \
    --header 'Content-Type: application/json'`
    data     = JSON.parse(response)
    data
  end

  def self.create_video(payload)
    response = `curl --location --request POST '#{MOVIES_ENDPOINT}' \
    --header 'x-api-key: #{ENV["JSON2VIDEO_KEY"]}' \
    --header 'Content-Type: application/json' \
    --data-raw '#{payload.to_json}'`
    data     = JSON.parse(response)
    data["project"]
  end

  def self.merge_audio_video_payload(scene)
    result_obj              = {}
    result_obj["elements"]  = []

    video_element_obj             = {}
    video_element_obj["src"]      = scene.video_url
    video_element_obj["type"]     = "video"
    video_element_obj["duration"] = -2
    result_obj["elements"]        << video_element_obj

    audio_element_obj             = {}
    audio_element_obj["src"]      = scene.audio.blob.url
    audio_element_obj["type"]     = "audio"
    audio_element_obj["duration"] = -1
    result_obj["elements"]        << audio_element_obj
    [result_obj]
  end

  def self.is_scene_video_ready(scene)
    id   = scene.video_gen_id
    data = video_generation_status(id)

    if data["success"] == true
      if data["movie"]["status"] = "done"
        scene.video_url = data["movie"]["url"]
        scene.save
      else
        CheckSceneVideoGenerationStatusJob.set(wait: 5.minutes).perform_later(scene)
      end
    else
      puts "Soemthing when wrong with the call, Fix me for a real logger pls"
    end
  end

  def self.is_merged_audio_video_ready(scene)
    id   = scene.merged_audio_video_gen_id
    data = video_generation_status(id)

    if data["success"] == true
      if data["movie"]["status"] = "done"
        scene.merged_audio_video_url = data["movie"]["url"]
        scene.save
      else
        CheckStoryVideoGenerationStatusJob.set(wait: 5.minutes).perform_later(scene)
      end
    else
      puts "Soemthing when wrong with the call, Fix me for a real logger pls"
    end
  end

  def self.is_story_video_ready(story)
    id   = story.video_gen_id
    data = video_generation_status(id)

    if data["success"] == true
      if data["movie"]["status"] = "done"
        story.video_url = data["movie"]["url"]
        story.save
      else
        CheckSceneVideoGenerationStatusJob.set(wait: 5.minutes).perform_later(story)
      end
    else
      puts "Soemthing when wrong with the call, Fix me for a real logger pls"
    end
  end
end

