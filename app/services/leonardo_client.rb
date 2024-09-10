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

        scene.leonardo_gen_ids << response["sdGenerationJob"]["generationId"]
      rescue => e
        puts e
        scene.save
        puts "ERROR generation images from Leonardo. Fix me for a real logger pls"
      end
    end


    scene.save
    if scene.leonardo_gen_ids.count == scene.ai_image_prompt.count
      # wee nee to schedule not at the same time
      CheckSceneImagesGenerationStatusJob.set(wait: (3 + rand()).round(2).minutes).perform_later(scene)
    else
      puts "Error: scene.leonardo_gen_ids != scene.ai_image_prompt.count"
    end
  end

  def self.check_scene_images_generation_status(scene)

    headers = { 'authorization' => "Bearer #{ENV['LEONARDO_KEY']}" }
    scene.leonardo_gen_ids.each do |gen_id|
      data = HTTParty.get("https://cloud.leonardo.ai/api/rest/v1/generations/#{gen_id}", headers: headers)

      if data["generations_by_pk"].present?
        url    = data["generations_by_pk"]["generated_images"][0]["url"]
        prompt = data["generations_by_pk"]["prompt"]
        scene.images_data << { url: url, prompt: prompt }
      else   
        CheckSceneImagesGenerationStatusJob.set(wait: (3 + rand()).round(2).minutes).perform_later(scene)
        break
      end
      scene.save
    end
  end
    
  def self.generate_image(payload)
    headers                   = {}
    headers["Accept"]        = "application/json"
    headers["Content-Type"]  = "application/json"
    headers["authorization"] = "Bearer #{ENV['LEONARDO_KEY']}"

    options             = {}
    options[:"headers"] = headers
    options[:"body"]    = payload.to_json

    response = HTTParty.post(GENERATION_ENDPOINT, options)
    response
  end

end


# CheckSceneImagesGenerationStatusJob
# CreateSceneVideoJob