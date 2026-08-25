require 'httparty'

class VideoEditorClient

  VIDEO_ENDPOINT = "http://localhost:3003/reel_generator/videos"

  def self.generate_scene_video(scene)
    # if scene.video_url.present? || scene.video_gen_id.present?
    #   Rails.logger.warn("generate_scene_video skipped scene=#{scene.id}: video already queued or complete")
    #   return
    # end

    unless scene.audio.attached?
      Rails.logger.warn("generate_scene_video skipped scene=#{scene.id}: audio not attached")
      return
    end

    payload = generate_scene_video_payload(scene)
    if payload["images_urls"].blank?
      Rails.logger.warn("generate_scene_video skipped scene=#{scene.id}: no static_url images")
      return
    end

    headers                  = {}
    options                  = {}
    headers[:"Content-Type"] = "application/json"
    options[:headers]        = headers
    options[:body]           = payload.to_json

    response = HTTParty.post(VIDEO_ENDPOINT + "/generate_scene_video", options)
    gen_id   = response_body(response)&.dig("gen_id")

    unless response.success? && gen_id.present?
      Rails.logger.error(
        "generate_scene_video failed scene=#{scene.id} status=#{response.code} body=#{response.body}"
      )
      return
    end

    scene.video_gen_id = gen_id

    if scene.save
      CheckSceneVideoGenerationStatusJob.set(wait: (3 + rand()).round(2).minutes).perform_later(scene)
    end
  end

  def self.create_scene_video(scene)
    generate_scene_video(scene)
  end

  def self.merge_audio_video(scene)
    unless scene.leonardo_video_url.present?
      Rails.logger.warn("merge_audio_video skipped scene=#{scene.id}: missing leonardo_video_url")
      return
    end

    unless scene.audio.attached?
      Rails.logger.warn("merge_audio_video skipped scene=#{scene.id}: audio not attached")
      return
    end

    payload = merge_audio_video_payload(scene)

    headers                  = {}
    options                  = {}
    headers[:"Content-Type"] = "application/json"
    options[:headers]        = headers
    options[:body]           = payload.to_json

    response = HTTParty.post(VIDEO_ENDPOINT + "/merge_audio_video", options)
    gen_id   = response_body(response)&.dig("gen_id")

    unless response.success? && gen_id.present?
      Rails.logger.error(
        "merge_audio_video failed scene=#{scene.id} status=#{response.code} body=#{response.body}"
      )
      return
    end

    scene.merged_audio_video_gen_id = gen_id

    if scene.save
      CheckMergedAudioVideoGenerationStatusJob.set(wait: (3 + rand()).round(2).minutes).perform_later(scene)
    end
  end

  def self.create_story_video(story)
    payload = create_story_video_payload(story)

    headers                  = {}
    options                  = {}
    headers[:"Content-Type"] = "application/json"
    options[:headers]        = headers
    options[:body]           = payload.to_json

    response = HTTParty.post(VIDEO_ENDPOINT + "/create_story_video", options)

    story.video_gen_id  = response["body"]["gen_id"]

    if story.save
      CheckStoryVideoGenerationStatusJob.set(wait: 2.minutes).perform_later(story)
    end
  end

  def self.create_story_video_payload(story)
    payload                = {}
    payload["story_id"]    = story.id
    payload
  end

  def self.generate_scene_video_payload(scene)
    payload                = {}
    payload["scene_id"]    = scene.id
    payload["story_id"]    = scene.story_id
    payload["images_urls"] = scene.images_data.filter_map { |image_data| image_data["static_url"] }
    payload["audio_url"]   = scene.audio.url
    payload["scene_text"]  = scene.text
    payload
  end
  private_class_method :generate_scene_video_payload

  def self.merge_audio_video_payload(scene)
    payload                = {}
    payload["video_url"]  = scene.leonardo_video_url
    payload["audio_url"]  = scene.audio.url
    payload["scene_id"]   = scene.id
    payload["story_id"]   = scene.story_id
    payload
  end

  def self.is_scene_video_ready(scene)
    gen_id = scene.video_gen_id
    data   = generation_status(gen_id)
    if data["completed"] == true
      scene.video_url = data["file_path"]
      scene.save
    else
      CheckSceneVideoGenerationStatusJob.set(wait: 3.minutes).perform_later(scene)
    end
  end

  def self.is_merged_audio_video_ready(scene)
    gen_id = scene.merged_audio_video_gen_id
    if gen_id.blank?
      Rails.logger.warn("is_merged_audio_video_ready skipped scene=#{scene.id}: missing merged_audio_video_gen_id")
      return
    end

    data = generation_status(gen_id)
    Rails.logger.info("is_merged_audio_video_ready scene=#{scene.id} data=#{data.inspect}")

    if data["completed"] == true
      scene.merged_audio_video_url = data["file_path"]
      scene.save
    else
      CheckMergedAudioVideoGenerationStatusJob.set(wait: 3.minutes).perform_later(scene)
    end
  end

  def self.is_story_video_ready(story)
    gen_id = story.video_gen_id
    data   = generation_status(gen_id)

    if data["completed"] == true
      story.video_url = data["file_path"]
      story.save
    else
      CheckStoryVideoGenerationStatusJob.set(wait: 3.minutes).perform_later(story)
    end
  end

  def self.generation_status(gen_id)
    return {} if gen_id.blank?

    response = HTTParty.get("http://localhost:3003/videos/generation_status/#{gen_id}")
    response_body(response) || {}
  end

  def self.response_body(response)
    parsed = response.parsed_response
    return parsed["body"] if parsed.is_a?(Hash) && parsed.key?("body")
    return parsed[:body] if parsed.is_a?(Hash) && parsed.key?(:body)

    response["body"]
  end
  private_class_method :response_body

end
