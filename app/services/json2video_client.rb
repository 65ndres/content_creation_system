require 'httparty'

class Json2videoClient

  MOVIES_ENDPOINT = "https://api.json2video.com/v2/movies"

  def self.create_scene_video(scene)
    return if scene.video_url.present?
    payload           = {}
    story             = scene.story
    story_type        = story.story_type
  
    payload["id"]     = "story-#{scene.story_id}-scene-#{scene.id}"
    payload["fps"]    = 25
    payload["cache"]  = payload["draft"] = false
    payload["width"]  = story_type.output_width
    payload["height"] = story_type.output_height
    payload["scenes"] = create_scene_payload(scene, story_type)
    project           = create_video(payload)
    scene.video_gen_id    = project
    if scene.save
      CheckSceneVideoGenerationStatusJob.set(wait: 5.minutes).perform_later(scene)
    end
  end

  def self.merge_audio_and_video(scene)
    # Scene will need one more column to store the merged_ vifeo 
    # return if scene.video_url.present?
    payload           = {}
    story             = scene.story
    story_type        = story.story_type
  
    payload["id"]     = "story-#{scene.story_id}-scene-#{scene.id}-audio-#{scene.id}"
    payload["fps"]    = 25
    payload["cache"]  = payload["draft"] = false
    payload["width"]  = story_type.output_width
    payload["height"] = story_type.output_height
    payload["scenes"] = merge_audio_and_video_payload(scene, story_type)
    project           = create_video(payload)
    scene.video_and_audio_gen_id  = project

    if scene.save
      CheckMergeVideoAndAudioGenerationStatusJob.set(wait: 5.minutes).perform_later(scene)
    end
  end
  

  def self.create_scene_payload(scene, story_type)
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
  data = video_generation_status(scene)

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
    data = video_generation_status(scene)

    if data["success"] == true
      if data["movie"]["status"] = "done"
        scene.merged_audio_video_url = data["movie"]["url"]
        scene.save
      else
        CheckSceneVideoGenerationStatusJob.set(wait: 5.minutes).perform_later(scene)
      end
    else
      puts "Soemthing when wrong with the call, Fix me for a real logger pls"
    end
  end

end


# [
#     {
#         "json": "{\"id\":\"recQ5gYkgiDJA9J1Z\",\"fps\":25,\"width\":1920,\"height\":1080,\"scenes\":[{\"elements\":[{\"src\":\"https://v5.airtableusercontent.com/v3/u/32/32/1725480000000/Y71PpLWZ2Ds3RvCwnaD7TQ/JvUkOxKx_iV7IoFz7Igropr-6VMBsRJf5VX479asmBPzWXtC899_hV-LHKoT-nyVKnS__oTrIpTs1tr_f4VTpHvP7hYMgMQmnPSXrly2DPy9LvvSXeAItb1I_6Y2h8hUB3EzfILU7B1Wa5pW1OTCEflq73YGa4iV1Z_zSiki0FA/d__yCmelK08T5ncJUxBeQYN49TjbnNkmhGwrqNsX7mQ\",\"type\":\"video\",\"duration\":-2},{\"src\":\"https://v5.airtableusercontent.com/v3/u/32/32/1725480000000/88k9S3xT-0G8Kt1r5jMnDw/8XQ-6iQtKbyKwyI_4Otjx0Q_hGRc3djiqlY_f6e6wdzb0X5ekQK9a2ZC_jDYnM9jmDaWi1nmJlPMYG_DtvxJWIeWTw0xA9wiqA_NbhTDDCMtSqQG5Ur0MigR4Azq7NFbbHDaoWJluaaWM6rjF66GiQ/RoU0M8gtcBPxwnBKX3Om6QVwjS7v2RX-jYKel4NPPjk\",\"type\":\"audio\",\"duration\":-1}]}],\"exports\":[{\"destinations\":[{\"type\":\"webhook\",\"endpoint\":\"https://hooks.airtable.com/workflows/v1/genericWebhook/app17miNPZN6KewDx/wflaiAFEicjPZTIA2/wtrJtrvoi4R4vHL5N\",\"Content-Type\":\"application/json\"}]}],\"quality\":\"high\",\"elements\":[],\"settings\":{},\"resolution\":\"custom\"}"
#     }
# ]

# {"id"=>"recQ5gYkgiDJA9J1Z",
#  "fps"=>25,
#  "width"=>1920,
#  "height"=>1080,
#  "scenes"=>
#   [{"elements"=>
#      [{"src"=>
#         "https://v5.airtableusercontent.com/v3/u/32/32/1725480000000/Y71PpLWZ2Ds3RvCwnaD7TQ/JvUkOxKx_iV7IoFz7Igropr-6VMBsRJf5VX479asmBPzWXtC899_hV-LHKoT-nyVKnS__oTrIpTs1tr_f4VTpHvP7hYMgMQmnPSXrly2DPy9LvvSXeAItb1I_6Y2h8hUB3EzfILU7B1Wa5pW1OTCEflq73YGa4iV1Z_zSiki0FA/d__yCmelK08T5ncJUxBeQYN49TjbnNkmhGwrqNsX7mQ",
#        "type"=>"video",
#        "duration"=>-2},
#       {"src"=>
#         "https://v5.airtableusercontent.com/v3/u/32/32/1725480000000/88k9S3xT-0G8Kt1r5jMnDw/8XQ-6iQtKbyKwyI_4Otjx0Q_hGRc3djiqlY_f6e6wdzb0X5ekQK9a2ZC_jDYnM9jmDaWi1nmJlPMYG_DtvxJWIeWTw0xA9wiqA_NbhTDDCMtSqQG5Ur0MigR4Azq7NFbbHDaoWJluaaWM6rjF66GiQ/RoU0M8gtcBPxwnBKX3Om6QVwjS7v2RX-jYKel4NPPjk",
#        "type"=>"audio",
#        "duration"=>-1}]}],
#  "exports"=>
#   [{"destinations"=>
#      [{"type"=>"webhook",
#        "endpoint"=>
#         "https://hooks.airtable.com/workflows/v1/genericWebhook/app17miNPZN6KewDx/wflaiAFEicjPZTIA2/wtrJtrvoi4R4vHL5N",
#        "Content-Type"=>"application/json"}]}],
#  "quality"=>"high",
#  "elements"=>[],
#  "settings"=>{},
#  "resolution"=>"custom"}