require 'uri'
require 'net/http'

class LeonardoClient

  GENERATION_ENDPOINT       = "https://cloud.leonardo.ai/api/rest/v1/generations"
  MOTION_ENDPOINT           = "https://cloud.leonardo.ai/api/rest/v1/generations-motion-svd"
  V2_GENERATION_ENDPOINT    = "https://cloud.leonardo.ai/api/rest/v2/generations"
  VIDEO_GENERATION_ENDPOINT = V2_GENERATION_ENDPOINT
  # See https://docs.leonardo.ai/docs/hailuo-23 — model slug, mode, duration, and width/height are strict.
  HAILUO_VIDEO_MODEL      = "hailuo-2_3"
  DEFAULT_HAILUO_DURATION = 6 # 1080p allows 6s only; 768p allows 6 or 10
  MAX_HAILUO_PROMPT_LENGTH = 1500
  MAX_NANO_BANANA_PROMPT_LENGTH = 9999
  # See https://docs.leonardo.ai/docs/wan-26 — text-to-video, duration 5/10/15, 9:16 720x1280.
  WAN_VIDEO_MODEL         = "wan-2.6"
  DEFAULT_WAN_DURATION    = 5
  WAN_WIDTH               = 720
  WAN_HEIGHT              = 1280
  # Lucid Origin — current getting-started default. See https://docs.leonardo.ai/docs/getting-started
  LUCID_ORIGIN_MODEL_ID   = "7b592283-e8a7-4c5a-9ba6-d18c31f258b9"
  DYNAMIC_STYLE_UUID      = "111dc692-d470-4eec-b791-3475abac4c46"
  DEFAULT_IMAGE_MODEL     = "lucid"
  NANO_BANANA_2_MODEL     = "nano-banana-2"
  NANO_BANANA_2_WIDTH     = 848
  NANO_BANANA_2_HEIGHT    = 1264
  IMAGE_MODEL_ALIASES     = {
    "lucid"          => DEFAULT_IMAGE_MODEL,
    "lucid-origin"   => DEFAULT_IMAGE_MODEL,
    "nano-banana-2"  => NANO_BANANA_2_MODEL
  }.freeze
  VIDEO_MODEL_ALIASES     = {
    "wan-2.6" => WAN_VIDEO_MODEL,
    "wan-26"  => WAN_VIDEO_MODEL
  }.freeze

  def self.normalize_image_model(model)
    return DEFAULT_IMAGE_MODEL if model.blank?

    key = model.to_s.strip.downcase.tr("_", "-")
    IMAGE_MODEL_ALIASES.fetch(key) do
      raise ArgumentError, "Unknown image generation model #{model.inspect}. Expected lucid or nano-banana-2."
    end
  end

  def self.normalize_video_model(model)
    return if model.blank?

    key = model.to_s.strip.downcase.tr("_", "-")
    VIDEO_MODEL_ALIASES.fetch(key) do
      raise ArgumentError, "Unknown video generation model #{model.inspect}. Expected wan-2.6."
    end
  end

  def self.generate_scene_images(scene)
    story      = scene.story
    story_type = story.story_type
    model      = normalize_image_model(story.image_generation_model)
    api        = image_model_api(model)
    endpoint   = image_generation_endpoint(model)

    StoryJsonNormalizer.normalize_ai_image_prompts(scene.ai_image_prompt).each do |prompt|
      begin
        payload  = image_generation_payload(model, prompt, story_type, seed: story.image_generation_seed)
        response = generate_asset(payload, endpoint)
        Rails.logger.info("Leonardo generate_scene_images scene=#{scene.id} model=#{model} response=#{response.inspect&.slice(0, 500)}")

        generation_id = extract_generation_id(response)
        if generation_id.present?
          scene.images_data_will_change!
          scene.images_data << { "leonardo_image_gen_id" => generation_id, "api" => api }
        else
          Rails.logger.error("Leonardo generate_scene_images scene=#{scene.id}: missing generationId #{response.inspect&.slice(0, 500)}")
        end
      rescue => e
        Rails.logger.error("Leonardo generate_scene_images scene=#{scene.id}: #{e.message}")
        scene.save
        Rails.logger.error("ERROR generation images from Leonardo scene=#{scene.id}")
      end
    end

    scene.save
    if scene.images_data.any? { |image_data| image_data["leonardo_image_gen_id"].present? }
      CheckSceneImagesGenerationStatusJob.set(wait: (2 + rand()).round(2).minutes).perform_later(scene)
    else
      Rails.logger.error("Leonardo generate_scene_images scene=#{scene.id}: no generation ids stored")
    end
  end

  def self.generate_character_seed_image(story)
    characters = StoryJsonNormalizer.seed_characters(story.characters, story.text)
    if characters.blank?
      Rails.logger.info("Leonardo generate_character_seed_image story=#{story.id}: no characters, skipping")
      CreateStoryScenesJob.perform_later(story)
      return
    end

    Rails.logger.info("Leonardo generate_character_seed_image story=#{story.id} characters=#{characters.map { |c| c['name'] }.join(', ')}")
    model    = normalize_image_model(story.image_generation_model)
    endpoint = image_generation_endpoint(model)
    payload  = image_generation_payload(model, build_character_seed_prompt(characters, story.story_type), story.story_type)
    response = generate_asset(payload, endpoint)
    Rails.logger.info("Leonardo generate_character_seed_image story=#{story.id} model=#{model} response=#{response.inspect&.slice(0, 500)}")

    generation_id = extract_generation_id(response)
    if generation_id.present?
      CheckCharacterSeedGenerationStatusJob.set(wait: (2 + rand()).round(2).minutes).perform_later(story, generation_id)
    else
      Rails.logger.error("Leonardo generate_character_seed_image story=#{story.id}: missing generationId #{response.inspect&.slice(0, 500)}")
      CreateStoryScenesJob.perform_later(story)
    end
  rescue => e
    Rails.logger.error("Leonardo generate_character_seed_image story=#{story.id}: #{e.message}")
    CreateStoryScenesJob.perform_later(story)
  end

  def self.check_character_seed_generation_status(story, generation_id)
    data    = check_asset_generation_status(generation_id)
    payload = generation_status_payload(data)
    status  = generation_status_value(payload)
    Rails.logger.info("Leonardo character seed status story=#{story.id} gen_id=#{generation_id} status=#{status} seed=#{payload['seed'].inspect}")

    if status == "FAILED"
      Rails.logger.error("Leonardo character seed generation failed for story #{story.id} gen_id=#{generation_id}")
      CreateStoryScenesJob.perform_later(story)
      return
    end

    if status == "COMPLETE"
      seed = payload["seed"]
      if seed.present?
        story.update!(image_generation_seed: seed.to_s)
        Rails.logger.info("Leonardo character seed stored story=#{story.id} seed=#{story.image_generation_seed}")
      else
        Rails.logger.error("Leonardo character seed missing for story #{story.id} gen_id=#{generation_id}")
      end
      CreateStoryScenesJob.perform_later(story)
      return
    end

    CheckCharacterSeedGenerationStatusJob.set(wait: (1 + rand()).round(2).minutes).perform_later(story, generation_id)
  end

  def self.check_asset_generation_status(gen_id, api: "v1")
    # Create can be v1 or v2; status is only exposed on GET /v1/generations/{id}.
    endpoint = "#{GENERATION_ENDPOINT}/#{gen_id}"
    headers = { "authorization" => "Bearer #{ENV['LEONARDO_KEY']}", "Accept" => "application/json" }
    response = HTTParty.get(endpoint, headers: headers)
    log_http_call("GET", endpoint, response: response)
    response
  end

  def self.check_scene_images_generation_status(scene)
    pending = false

    scene.images_data.each do |image_data|
      next if image_data["static_url"].present?

      gen_id      = image_data["leonardo_image_gen_id"]
      data        = check_asset_generation_status(gen_id)
      payload     = generation_status_payload(data)
      status      = generation_status_value(payload)
      first_image = generation_first_image(payload)

      if generation_blocked?(status, payload, first_image)
        if rewrite_blocked_scene_prompts(scene)
          return
        end

        if status == "FAILED"
          Rails.logger.error("Leonardo image generation failed for scene #{scene.id} gen_id=#{gen_id}")
          next
        end
      end

      if status == "COMPLETE" && first_image.present?
        scene.images_data_will_change!
        image_data.merge!(
          "static_url"  => first_image["url"] || first_image["src"],
          "prompt"      => payload["prompt"],
          "leonardo_id" => first_image["id"]
        )
      else
        pending = true
        CheckSceneImagesGenerationStatusJob.set(wait: (1 + rand()).round(2).minutes).perform_later(scene)
        break
      end
    end

    scene.save
    return if pending

    if scene.has_generated_stills? && scene.video_url.blank? && scene.video_gen_id.blank?
      GenerateSceneVideoJob.perform_later(scene)
    elsif scene.video_url.blank? && scene.video_gen_id.blank?
      Rails.logger.error("Leonardo check_scene_images_generation_status scene=#{scene.id}: no stills to build video")
    end
  end

  # def self.check_scene_motion_images_generation_status(scene)
  #   scene.images_data.each do |image_data|
  #     gen_id = image_data["leonardo_motion_image_gen_id"]
  #     data   = check_asset_generation_status(gen_id)

  #     Rails.logger.info("Leonardo check_scene_motion_images scene=#{scene.id} response=#{data.inspect&.slice(0, 500)}")

  #     if data["generations_by_pk"].present? && data["generations_by_pk"]["status"] == "COMPLETE"
  #       image_data.merge!({"motion_url": data["generations_by_pk"]["generated_images"][0]["motionMP4URL"]})
  #     else   
  #       CheckSceneMotionImagesGenerationStatusJob.set(wait: (2 + rand()).round(2).minutes).perform_later(scene)
  #     end
  #   end
  #   scene.save
  # end

  def self.check_leonardo_scene_video_generation_status(scene)
    gen_id = scene.leonardo_video_gen_id
    return if gen_id.blank?

    data    = check_asset_generation_status(gen_id)
    payload = generation_status_payload(data)
    status  = generation_status_value(payload)
    Rails.logger.info("Leonardo scene video status scene=#{scene.id} gen_id=#{gen_id} status=#{status}")

    if status == "FAILED"
      Rails.logger.error("Leonardo video generation failed for scene #{scene.id} gen_id=#{gen_id}")
      return
    end

    if status != "COMPLETE"
      CheckLeonardoSceneVideoGenerationStatusJob.set(wait: (1 + rand()).round(2).minutes).perform_later(scene)
      return
    end

    video_url = generation_video_url(payload)
    if video_url.blank?
      Rails.logger.error("Leonardo video generation complete but missing URL scene=#{scene.id} gen_id=#{gen_id}")
      return
    end

    scene.leonardo_video_url = video_url
    if scene.video_url.blank? || scene.video_url.to_s.match?(/\Ahttps?:\/\//i)
      scene.video_url = video_url
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
      log_http_call("POST", endpoint, body: payload, response: response)
      response
    rescue => e
      Rails.logger.error("Leonardo POST #{endpoint} body=#{payload.to_json} error=#{e.message}")
    end
  end

  def self.generate_video(body_hash)
    begin
      headers                  = {}
      headers["Accept"]        = "application/json"
      headers["Content-Type"]  = "application/json"
      headers["authorization"] = "Bearer #{ENV['LEONARDO_KEY']}"

      options             = {}
      options[:"headers"] = headers
      options[:"body"]   = body_hash.to_json

      response = HTTParty.post(VIDEO_GENERATION_ENDPOINT, options)
      log_http_call("POST", VIDEO_GENERATION_ENDPOINT, body: body_hash, response: response)
      response
    rescue => e
      Rails.logger.error("Leonardo POST #{VIDEO_GENERATION_ENDPOINT} body=#{body_hash.to_json} error=#{e.message}")
    end
  end

  def self.generate_scene_video(scene)
    if scene.leonardo_video_url.present? || scene.video_url.present?
      Rails.logger.warn("generate_scene_video skipped scene=#{scene.id}: video already present")
      return
    end

    if scene.leonardo_video_gen_id.present?
      CheckLeonardoSceneVideoGenerationStatusJob.perform_later(scene)
      return
    end

    payload  = wan_video_payload(scene)
    response = generate_video(payload)
    generation_id = extract_generation_id(response)
    if generation_id.present?
      scene.leonardo_video_gen_id = generation_id
      scene.save
      CheckLeonardoSceneVideoGenerationStatusJob.set(wait: (1 + rand()).round(2).minutes).perform_later(scene)
    else
      Rails.logger.error("Leonardo generate_scene_video scene=#{scene.id}: missing generationId #{response.inspect&.slice(0, 500)}")
    end
  end

  def self.build_scene_video_prompt(scene)
    base_prompt = StoryJsonNormalizer.normalize_ai_image_prompts(scene.ai_image_prompt).first.to_s
    characters  = StoryJsonNormalizer.filter_characters_in_text(
      scene.story.characters,
      base_prompt,
      scene.text
    )
    characters = characters.reject { |character| description_embedded_in_prompt?(base_prompt, character["physical_description"]) }

    prompt = if characters.blank?
      base_prompt
    else
      character_lines = characters.map do |character|
        "- #{character['name']}: #{character['physical_description']}"
      end

      <<~PROMPT.strip
        #{base_prompt}

        Character reference — use these exact physical descriptions for any character visible in this scene:
        #{character_lines.join("\n")}

        Ensure each character in the video matches their physical description above.
      PROMPT
    end

    truncate_hailuo_prompt(prompt)
  end
  private_class_method :build_scene_video_prompt

  def self.description_embedded_in_prompt?(base_prompt, description)
    snippet = description.to_s.strip.slice(0, 80)
    return false if snippet.length < 40

    base_prompt.downcase.include?(snippet.downcase)
  end
  private_class_method :description_embedded_in_prompt?

  def self.truncate_hailuo_prompt(prompt)
    truncate_prompt(prompt, MAX_HAILUO_PROMPT_LENGTH)
  end
  private_class_method :truncate_hailuo_prompt

  def self.log_http_call(method, endpoint, body: nil, response: nil)
    parts = ["Leonardo #{method} #{endpoint}"]
    parts << "body=#{body.to_json}" if body
    if response
      status = response.respond_to?(:code) ? response.code : nil
      parsed = response.respond_to?(:parsed_response) ? response.parsed_response : response
      parts << "status=#{status}"
      parts << "response=#{parsed.inspect}"
    end
    Rails.logger.info(parts.join(" "))
  end
  private_class_method :log_http_call

  def self.truncate_prompt(prompt, max_length)
    return prompt if prompt.length <= max_length

    Rails.logger.warn("Leonardo prompt truncated from #{prompt.length} to #{max_length} characters")
    truncated = prompt.slice(0, max_length)
    truncated.sub(/\s+\S*\z/, "").strip
  end
  private_class_method :truncate_prompt

  def self.image_model_api(model)
    normalize_image_model(model) == NANO_BANANA_2_MODEL ? "v2" : "v1"
  end
  private_class_method :image_model_api

  def self.image_generation_endpoint(model)
    image_model_api(model) == "v2" ? V2_GENERATION_ENDPOINT : GENERATION_ENDPOINT
  end
  private_class_method :image_generation_endpoint

  def self.image_generation_payload(model, prompt, story_type, seed: nil)
    model = normalize_image_model(model)
    seed_value = integer_seed(seed)
    if model == NANO_BANANA_2_MODEL
      parameters = {
        "width"          => NANO_BANANA_2_WIDTH,
        "height"         => NANO_BANANA_2_HEIGHT,
        "prompt"         => truncate_prompt(prompt.to_s, MAX_NANO_BANANA_PROMPT_LENGTH),
        "quantity"       => 1,
        "style_ids"      => [DYNAMIC_STYLE_UUID],
        "prompt_enhance" => "OFF"
      }
      parameters["seed"] = seed_value if seed_value
      {
        "model"      => NANO_BANANA_2_MODEL,
        "parameters" => parameters,
        "public"     => false
      }
    else
      payload = {
        "prompt"     => truncate_hailuo_prompt(prompt.to_s),
        "modelId"    => LUCID_ORIGIN_MODEL_ID,
        "width"      => story_type.image_width,
        "height"     => story_type.image_height,
        "num_images" => 1,
        "contrast"   => 3.5,
        "alchemy"    => false,
        "styleUUID"  => DYNAMIC_STYLE_UUID,
        "public"     => false
      }
      payload["seed"] = seed_value if seed_value
      payload
    end
  end
  private_class_method :image_generation_payload

  def self.wan_video_payload(scene)
    parameters = {
      "prompt"   => build_scene_video_prompt(scene),
      "duration" => DEFAULT_WAN_DURATION,
      "width"    => WAN_WIDTH,
      "height"   => WAN_HEIGHT
    }
    seed_value = integer_seed(scene.story.image_generation_seed)
    parameters["seed"] = seed_value if seed_value

    {
      "model"      => WAN_VIDEO_MODEL,
      "public"     => false,
      "parameters" => parameters
    }
  end
  private_class_method :wan_video_payload

  def self.integer_seed(seed)
    return if seed.blank?

    Integer(seed)
  rescue ArgumentError, TypeError
    Rails.logger.error("Leonardo invalid image generation seed #{seed.inspect}")
    nil
  end
  private_class_method :integer_seed

  def self.build_character_seed_prompt(characters, story_type)
    lines = characters.map do |character|
      "- #{character['name']}: #{character['physical_description']}"
    end
    style = story_type&.name.to_s.strip
    style_prefix = style.present? ? "#{style}. " : ""

    <<~PROMPT.strip
      #{style_prefix}Character reference sheet. Full body portraits of only these characters standing together, consistent cinematic style, clear faces and clothing.
      Generate only the main character and the two most mentioned supporting characters. Do not include anyone else.

      #{lines.join("\n")}
    PROMPT
  end
  private_class_method :build_character_seed_prompt

  def self.extract_generation_id(response)
    return if response.blank?

    response.dig("sdGenerationJob", "generationId") ||
      response["generationId"] ||
      response.dig("generate", "generationId")
  end
  private_class_method :extract_generation_id

  def self.generation_status_payload(data)
    return {} if data.blank?

    hash = data.respond_to?(:parsed_response) ? data.parsed_response : data
    return {} unless hash.is_a?(Hash)

    hash = hash.stringify_keys
    pk   = hash["generations_by_pk"]
    pk.is_a?(Hash) ? pk.stringify_keys : hash
  end
  private_class_method :generation_status_payload

  def self.generation_status_value(payload)
    (payload["status"] || payload["job_status"]).to_s.upcase.presence
  end
  private_class_method :generation_status_value

  def self.generation_first_image(payload)
    images = payload["generated_images"] || payload["images"] || []
    image  = Array(images).first
    image.respond_to?(:stringify_keys) ? image.stringify_keys : image
  end
  private_class_method :generation_first_image

  def self.generation_video_url(payload)
    candidates = []
    first_image = generation_first_image(payload)
    if first_image.present?
      candidates.concat(
        [
          first_image["motionMP4URL"],
          first_image["motion_mp4_url"],
          first_image["url"],
          first_image["src"]
        ]
      )
    end

    videos = payload["generated_videos"] || payload["videos"] || []
    Array(videos).each do |video|
      video = video.respond_to?(:stringify_keys) ? video.stringify_keys : video
      next unless video.is_a?(Hash)

      candidates.concat([video["url"], video["src"], video["motionMP4URL"], video["motion_mp4_url"]])
    end

    urls = candidates.map(&:presence).compact
    urls.find { |url| url.to_s.match?(/\.mp4(\?|$)/i) } || urls.first
  end
  private_class_method :generation_video_url

  def self.generation_blocked?(status, payload, first_image)
    status == "FAILED" || image_nsfw?(first_image) || prompt_moderated?(payload)
  end
  private_class_method :generation_blocked?

  def self.image_nsfw?(image)
    return false if image.blank?

    ActiveModel::Type::Boolean.new.cast(image["nsfw"])
  end
  private_class_method :image_nsfw?

  def self.prompt_moderated?(payload)
    mods = payload["prompt_moderations"] || payload["promptModerations"]
    Array(mods).any? do |mod|
      next false unless mod.is_a?(Hash)

      classifications = mod["moderationClassification"] || mod["moderation_classification"]
      Array(classifications).any?(&:present?)
    end
  end
  private_class_method :prompt_moderated?

  def self.rewrite_blocked_scene_prompts(scene)
    if scene.image_prompt_rewrite_count.to_i >= 1
      Rails.logger.info("Leonardo scene=#{scene.id}: prompt already rewritten, not retrying")
      return false
    end

    original = StoryJsonNormalizer.normalize_ai_image_prompts(scene.ai_image_prompt)
    if original.blank?
      Rails.logger.error("Leonardo scene=#{scene.id}: no prompts to soften")
      return false
    end

    softened = ChatGPTClient.soften_image_prompts(original)
    if softened.blank? || softened.size != original.size
      Rails.logger.error("Leonardo scene=#{scene.id}: soften_image_prompts returned unexpected prompts")
      return false
    end

    scene.ai_image_prompt = softened
    scene.images_data = []
    scene.image_prompt_rewrite_count = scene.image_prompt_rewrite_count.to_i + 1
    scene.save
    Rails.logger.info("Leonardo scene=#{scene.id}: softened prompts and requeued image generation")
    CreateSceneImagesJob.perform_later(scene)
    true
  rescue => e
    Rails.logger.error("Leonardo scene=#{scene.id}: failed to soften prompts #{e.message}")
    false
  end
  private_class_method :rewrite_blocked_scene_prompts

  # Hailuo 2.3 text-to-video uses fixed presets per resolution (see dimension tables in docs).
  # Returns [width, height, mode] where mode is RESOLUTION_1080 or RESOLUTION_768.
  def self.hailuo_video_dimensions(image_width, image_height)
    w = image_width.to_i
    h = image_height.to_i
    return [1920, 1080, "RESOLUTION_1080"] if w <= 0 || h <= 0

    ratio = w.to_f / h
    if ratio >= 1.34
      [1920, 1080, "RESOLUTION_1080"]      # 16:9
    elsif ratio <= 0.75
      [1080, 1920, "RESOLUTION_1080"]      # 9:16
    else
      [1080, 1080, "RESOLUTION_1080"]      # 1:1
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
        Rails.logger.info("Leonardo create_scene_motion_images scene=#{scene.id} response=#{response.inspect&.slice(0, 500)}")
        image_data.merge!({ "leonardo_motion_image_gen_id": response["motionSvdGenerationJob"]["generationId"]})
      rescue => e
        Rails.logger.error("Leonardo create_scene_motion_images scene=#{scene.id}: #{e.message}")
        scene.save
        Rails.logger.error("ERROR generation motion images from Leonardo scene=#{scene.id}")
      end
    end

    scene.save
    if scene.images_data.count == scene.ai_image_prompt.count
      # wee nee to schedule not at the same time
      CheckSceneMotionImagesGenerationStatusJob.set(wait: (2 + rand()).round(2).minutes).perform_later(scene)
    else
      Rails.logger.error("Error: scene.leonardo_gen_ids != scene.ai_image_prompt.count scene=#{scene.id}")
    end

  end

end
