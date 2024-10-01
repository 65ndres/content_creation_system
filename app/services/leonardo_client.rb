require 'uri'
require 'net/http'

class LeonardoClient

  GENERATION_ENDPOINT = "https://cloud.leonardo.ai/api/rest/v1/generations"
  MOTION_ENDPOINT     = "https://cloud.leonardo.ai/api/rest/v1/generations-motion-svd"

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
        response              = generate_asset(payload)
        puts "THis is the response #{response}"

        # scene.leonardo_gen_ids << response["sdGenerationJob"]["generationId"]
        scene.images_data << { "leonardo_image_gen_id": response["sdGenerationJob"]["generationId"] }
        # we are gonna have to find the properGenId to popullate the rest of the fields

        # it would be idea to have the id as the 
      rescue => e
        puts e
        scene.save
        puts "ERROR generation images from Leonardo. Fix me for a real logger pls"
      end
    end

    scene.save
    if scene.images_data.count == scene.ai_image_prompt.count
      # wee nee to schedule not at the same time
      CheckSceneImagesGenerationStatusJob.set(wait: (2 + rand()).round(2).minutes).perform_later(scene)
    else
      puts "Error: scene.leonardo_gen_ids != scene.ai_image_prompt.count"
    end
  end

  def self.check_asset_generation_status(gen_id)
    headers  = { 'authorization' => "Bearer #{ENV['LEONARDO_KEY']}" }
    response = HTTParty.get("https://cloud.leonardo.ai/api/rest/v1/generations/#{gen_id}", headers: headers)
    response
  end

  def self.check_scene_images_generation_status(scene) 
    scene.images_data.each do |image_data|
      gen_id = image_data["leonardo_image_gen_id"]
      data   = check_asset_generation_status(gen_id)

      if data["generations_by_pk"].present?
        url         = data["generations_by_pk"]["generated_images"][0]["url"]
        prompt      = data["generations_by_pk"]["prompt"]
        leonardo_id = data["generations_by_pk"]["generated_images"][0]["id"]
        image_data.merge!({ static_url: url, prompt: prompt, leonardo_id: leonardo_id })
      else   
        CheckSceneImagesGenerationStatusJob.set(wait: (1 + rand()).round(2).minutes).perform_later(scene)
        break
      end
    end
    scene.save
  end

  def self.check_scene_motion_images_generation_status(scene)
    scene.images_data.each do |image_data|
      gen_id = image_data["leonardo_motion_image_gen_id"]
      data   = check_asset_generation_status(gen_id)

      puts "this is the the response #{data}"

      if data["generations_by_pk"].present? && data["generations_by_pk"]["status"] == "COMPLETE"
        image_data.merge!({"motion_url": data["generations_by_pk"]["generated_images"][0]["motionMP4URL"]})
      else   
        CheckSceneMotionImagesGenerationStatusJob.set(wait: (2 + rand()).round(2).minutes).perform_later(scene)
      end
    end
    scene.save
  end
    
  def self.generate_asset(payload, endpoint=GENERATION_ENDPOINT)
    begin
      headers                   = {}
      headers["Accept"]        = "application/json"
      headers["Content-Type"]  = "application/json"
      headers["authorization"] = "Bearer #{ENV['LEONARDO_KEY']}"

      options             = {}
      options[:"headers"] = headers
      options[:"body"]    = payload.to_json

      response = HTTParty.post(endpoint, options)
      response
    rescue
      puts "Error in gereate_image, response #{response}"
    end
  end

  def self.create_scene_motion_images(scene)
    # Get all the images in the scenes
    scene.images_data.each_with_index do |image_data, i|
      begin
        payload                   = {}
        payload["imageId"]        = image_data["leonardo_id"]
        payload["isPublic"]       = payload["isVariation"] = false
        payload["motionStrength"] = 4
        response                  = generate_asset(payload, MOTION_ENDPOINT)
        puts "This is the response for csmi #{response}"
        image_data.merge!({ "leonardo_motion_image_gen_id": response["motionSvdGenerationJob"]["generationId"]})
      rescue => e
        puts e
        scene.save
        puts "ERROR generation images from Leonardo. Fix me for a real logger pls"
      end
    end

    scene.save
    if scene.images_data.count == scene.ai_image_prompt.count
      # wee nee to schedule not at the same time
      CheckSceneMotionImagesGenerationStatusJob.set(wait: (2 + rand()).round(2).minutes).perform_later(scene)
    else
      puts "Error: scene.leonardo_gen_ids != scene.ai_image_prompt.count"
    end

  end

end
