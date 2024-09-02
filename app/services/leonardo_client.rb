require 'uri'
require 'net/http'

class LeonardoClient

  GENERATION_ENDPOINT = "https://cloud.leonardo.ai/api/rest/v1/generations"

  def self.generate_scene_images(scene)
    story_type = scene.story.story_type
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

        puts "RESponse here #{response}"

        scene.leonardo_gen_ids << response["sdGenerationJob"]["generationId"]
      rescue => e
        puts e
        scene.save
        puts "ERROR generation images from Leonardo. Fix me for a real logger pls"
      end
    end


    scene.save
    # goota check of all worked if so the schedule the 
    if scene.leonardo_gen_ids.count == scene.ai_image_prompt.count
      CheckSceneImagesGenerationStatusJob.set(wait: 5.minutes).perform_later(scene)
    else
      puts "Error: scene.leonardo_gen_ids != scene.ai_image_prompt.count"
      #reschedule a retry of this function call 30 min
    end
  end

  def self.check_scene_images_generation_status(scene)
    scene.leonardo_gen_ids.each do |gen_id|

      url          = URI("#{GENERATION_ENDPOINT}/#{gen_id}")
      http         = Net::HTTP.new(url.host, url.port)
      http.use_ssl = true
    
      request                  = Net::HTTP::Get.new(url)
      request["authorization"] = "Bearer #{ENV['LEONARDO_KEY']}"
      request["accept"]        = request["content-type"] = 'application/json'
      puts " HERE check_scene_images_generation_status request: #{request}"
      response                 = http.request(request)
      data                     = JSON.parse(response.body)
      puts " HERE check_scene_images_generation_status data: #{data}"

      if data["generations_by_pk"].present?
        url    = data["generations_by_pk"]["generated_images"][0]["url"]
        prompt = data["generations_by_pk"]["prompt"]
        scene.images_data << { url: url, prompt: prompt }
      else   
        CheckSceneImagesGenerationStatusJob.set(wait: 5.minutes).perform_later(scene)
        break
      end
      scene.save
    end
  end
    
  def self.generate_image(payload)
    url          = URI(GENERATION_ENDPOINT)
    http         = Net::HTTP.new(url.host, url.port)
    http.use_ssl = true
  
    request                  = Net::HTTP::Post.new(url)
    request["accept"]        = request["content-type"] = 'application/json'
    request["authorization"] = "Bearer #{ENV['LEONARDO_KEY']}"
    request.body             = payload.to_json
    response                 = http.request(request)
    JSON.parse(response.body)
  end

end