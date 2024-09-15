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
    return if scene.merged_audio_video_url.present?
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
      CheckMergedAudioVideoGenerationStatusJob.set(wait: (3 + rand()).round(2).minutes).perform_later(scene)
    end
  end

  def self.create_story_video(story)
    return if story.video_url.present?
    payload             = {}
    story_type          = story.story_type
  
    payload["id"]       = "story-#{story.id}-all-scenes"
    payload["fps"]      = 25
    payload["cache"]    = payload["draft"] = false
    payload["width"]    = story_type.output_width
    payload["height"]   = story_type.output_height
    payload["scenes"]   = create_story_video_payload(story)
    payload["elements"] = [story_video_captions_payload]
    project             = create_video(payload)
    story.video_gen_id  = project

    if story.save
      CheckStoryVideoGenerationStatusJob.set(wait: 5.minutes).perform_later(story)
    end
  end

  def self.create_story_video_payload(story)
    result = []
    story_type = story.story_type
    story.scenes.each do |scene|

      element_obj                  = {}
      element_obj["elements"]      = []
      element_obj_value            = {}

      element_obj_value["src"]      = scene.merged_audio_video_url
      element_obj_value["type"]     = "video"
      element_obj_value["zoom"]     = 0
      element_obj_value["width"]    = story_type.output_width
      element_obj_value["height"]   = story_type.output_height
      element_obj_value["duration"] = -1
      element_obj_value["position"] = "center-center"
      element_obj["elements"] << element_obj_value
      result << element_obj
    end
    result
  end

  def self.create_scene_video_payload(scene, story_type)
    result = []
    scene.images_data.each do |image|
      element_obj                  = {}
      element_obj["elements"]      = []
      element_obj_value            = {}

      element_obj_value["src"]      = image["url"]
      element_obj_value["type"]     = "image"
      element_obj_value["zoom"]     = 2
      element_obj_value["width"]    = story_type.output_width
      element_obj_value["height"]   = story_type.output_height
      element_obj_value["duration"] = 5
      element_obj_value["position"] = "center-center"
      element_obj["elements"] << element_obj_value
      result << element_obj
    end
    result
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

  def self.story_video_captions_payload
    {
      "id": "qzbft9yb",
      "type": "subtitles",
      "settings": {
        "position": "mid-bottom-center",
        "font-family": "Luckiest Guy",
        "font-size": 75,
        "outline-width": 5
      }
    }
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

  def self.video_generation_status(id)
    response = `curl --location --request GET 'https://api.json2video.com/v2/movies?id=#{id}' \
    --header 'X-api-key: #{ENV["JSON2VIDEO_KEY"]}' \
    --header 'Content-Type: application/json'`
    data     = JSON.parse(response)
    data
  end

  def self.create_video(payload)
    response = `curl --location --request POST 'https://api.json2video.com/v2/movies' \
    --header "x-api-key: #{ENV['JSON2VIDEO_KEY']}" \
    --header "Content-Type: application/json" \
    --data-raw '#{payload.to_json}'`
    data     = JSON.parse(response)
    data["project"]
  end


end
