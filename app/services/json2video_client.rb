require 'httparty'

class Json2videoClient

  MOVIES_ENDPOINT = "https://api.json2video.com/v2/movies"

  def self.create_scene_video(scene)
    payload           = {}
    story             = scene.story
    story_type        = story.story_type
  
    payload["id"]     = "story-#{scene.story_id}-scene-#{scene.id}"
    payload["fps"]    = 25
    payload["cache"]  = payload["draft"] = false
    payload["width"]  = story_type.output_width
    payload["height"] = story_type.output_height
    payload["scenes"] = create_scene_payload(scene, story_type)
    puts "Thi sis where the payload is", payload
    project           = create_video(payload)
    puts "Thi sis where the project", project
    scene.video_id    = project
    # if scene.save
    #   CheckSceneVideoGenerationStatusJob.set(wait: 5.minutes).perform_later(scene)
    # else
    # end
  end

  def self.create_scene_payload(scene, story_type)
    result = []
    scene.images_data.each do |image|
      result_obj              = {}
      element_obj             = {}
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

  def self.check_video_generation_status(obj)
    video_id = obj.video_id
    response = `curl --location --request GET '#{MOVIES_ENDPOINT}?id=#{video_id}' \
    --header 'X-api-key: #{ENV["JSON2VIDEO_KEY"]}' \
    --header 'Content-Type: application/json'`
    data     = JSON.parse(response)

    if data["success"] == true
      if data["movie"]["status"]
        obj.video_url = data["movie"]["url"]
        obj.save
      else
        CheckSceneVideoGenerationStatusJob.set(wait: 5.minutes).perform_later(scene)
      end
    else
      puts "Soemthing when wrong with the call, Fix me for a real logger pls"
    end
  end


  def self.create_video(payload)
    response = `curl --location --request POST '#{MOVIES_ENDPOINT}' \
    --header 'x-api-key: #{ENV["JSON2VIDEO_KEY"]}' \
    --header 'Content-Type: application/json' \
    --data-raw '#{payload.to_json}'`

    response["project"]
  end
end