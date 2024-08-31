require 'uri'
require 'net/http'

GENERATION_ENDPOINT = "https://cloud.leonardo.ai/api/rest/v1/generations"

class LeonardoClient

  def generate_scene_images(scene)
    scene.ai_image_prompt.each_with_index do |prompt, i|
      begin
        payload               = {}
        payload["num_images"] = i + 1
        payload["public"]     = false
        payload["prompt"]     = prompt
        payload["width"]      = story_type.image_width
        payload["height"]     = story_type.image_height
        payload["modelId"]    = "aa77f04e-3eec-4034-9c07-d0f619684628"
        response              = generate_image(payload)

        scene.leonardo_gen_ids << response["sdGenerationJob"]["generationId"]
      rescue
        scene.save
        puts "ERROR generation images from Leonardo. Fix me for a real logger pls"
      end
    end
  end

  def check_scene_images_generation_status(scene)

    scene.leonardo_gen_ids.each do |gen_id|

      url          = URI("#{GENERATION_ENDPOINT}/#{gen_id}")
      http         = Net::HTTP.new(url.host, url.port)
      http.use_ssl = true
    
      request                  = Net::HTTP::Get.new(url)
      request["authorization"] = "Bearer #{ENV['LEONARDO_KEY']}"
      request["accept"]        = request["content-type"] = 'application/json'
      response                 = http.request(request)
      data                     = JSON.parse(response.body)

      if !data["generations_by_pk"].nil?
        url = data["generations_by_pk"]["generated_images"][0]["url"]
      else   
        CheckSceneImagesGenerationStatusJob.set(wait: 5.minutes).perform_later(scene)
        break
      end
    end
  end
    
  def generate_image(payload)
    url          = URI(GENERATION_ENDPOINT)
    http         = Net::HTTP.new(url.host, url.port)
    http.use_ssl = true
  
    request                  = Net::HTTP::Post.new(url)
    request["accept"]        = request["content-type"] = 'application/json'
    request["authorization"] = "Bearer #{ENV['LEONARDO_KEY']}"
    request.body             = payload.to_json
    response                 = http.request(request)
  end

end