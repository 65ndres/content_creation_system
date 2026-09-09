require "base64"
require "httparty"

class VideoEditorClient

  VIDEO_ENDPOINT = "http://localhost:3003/reel_generator/videos"

  def self.generate_scene_video(scene)
    if scene.video_url.present?
      Rails.logger.warn("generate_scene_video skipped scene=#{scene.id}: video_url already present")
      return
    end

    unless scene.audio.attached?
      Rails.logger.warn("generate_scene_video skipped scene=#{scene.id}: audio not attached, retrying")
      GenerateSceneVideoJob.set(wait: 1.minute).perform_later(scene)
      return
    end

    payload = generate_scene_video_payload(scene)
    if payload["images_urls"].blank?
      Rails.logger.warn("generate_scene_video skipped scene=#{scene.id}: no static_url images")
      return
    end

    if scene.video_gen_id.present?
      CheckSceneVideoGenerationStatusJob.perform_later(scene)
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
      GenerateSceneVideoJob.set(wait: 1.minute).perform_later(scene)
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
    if scene.merged_audio_video_url.present?
      Rails.logger.warn("merge_audio_video skipped scene=#{scene.id}: already merged")
      return
    end

    scene.update!(merged_audio_video_gen_id: nil) if scene.merged_audio_video_gen_id.present?

    unless scene.video_url.present?
      Rails.logger.warn("merge_audio_video skipped scene=#{scene.id}: missing leonardo_video_url")
      return
    end

    unless scene.audio.attached?
      Rails.logger.warn("merge_audio_video skipped scene=#{scene.id}: audio not attached")
      return
    end

    persisted = persist_scene_media(scene, persist_audio: true)
    unless persisted["audio_path"].present?
      Rails.logger.warn("merge_audio_video deferred scene=#{scene.id}: local audio not ready")
      MergeAudioVideoJob.set(wait: 1.minute).perform_later(scene)
      return
    end

    payload = merge_audio_video_payload(scene, audio_path: persisted["audio_path"])

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

  def self.persist_scene_media(scene, persist_audio: false, persist_video: false, audio_bytes: nil)
    payload = {
      "scene_id" => scene.id,
      "story_id" => scene.story_id
    }
    if persist_audio
      bytes = binary_data(audio_bytes) || attached_audio_bytes(scene)
      payload["audio_base64"] = Base64.strict_encode64(bytes) if bytes
    end
    if persist_video
      payload["video_url"] = scene.leonardo_video_url.presence || scene.video_url
    end

    unless persist_audio || persist_video
      Rails.logger.warn("persist_scene_media skipped scene=#{scene.id}: nothing to persist")
      return {}
    end

    headers                  = {}
    options                  = {}
    headers[:"Content-Type"] = "application/json"
    options[:headers]        = headers
    options[:body]           = payload.to_json

    response = HTTParty.post(VIDEO_ENDPOINT + "/persist_scene_media", options)
    body     = response_body(response) || {}

    unless response.success?
      Rails.logger.error(
        "persist_scene_media failed scene=#{scene.id} status=#{response.code} body=#{response.body}"
      )
      return {}
    end

    if persist_video && body["video_path"].present?
      scene.update!(video_url: body["video_path"])
    end

    body
  end

  def self.generate_scene_video_payload(scene)
    payload                = {}
    payload["scene_id"]    = scene.id
    payload["story_id"]    = scene.story_id
    payload["images_urls"] = scene.images_data.filter_map { |image_data| image_data["static_url"] }
    payload["audio_url"]   = attached_download_url(scene.audio)
    payload
  end
  private_class_method :generate_scene_video_payload

  def self.merge_audio_video_payload(scene, audio_path:)
    payload                = {}
    payload["video_url"]  = scene.video_url
    payload["audio_url"]  = audio_path
    payload["scene_id"]   = scene.id
    payload["story_id"]   = scene.story_id
    payload
  end

  def self.attached_audio_bytes(scene)
    return unless scene.audio.attached?

    blob = scene.audio.blob
    if blob.service.respond_to?(:bucket)
      object = s3_object_for(blob)
      unless object.exists?
        Rails.logger.error("attached_audio_bytes scene=#{scene.id}: S3 object missing key=#{blob.key}")
        return
      end

      return binary_data(object.get.body.read)
    end

    buffer = +"".b
    blob.download { |chunk| buffer << chunk.b }
    binary_data(buffer)
  rescue => e
    Rails.logger.error("attached_audio_bytes failed scene=#{scene.id}: #{e.class}: #{e.message}")
    nil
  end
  private_class_method :attached_audio_bytes

  def self.binary_data(value)
    return if value.nil?

    data = value.to_s.b
    data if data.bytesize.positive?
  end
  private_class_method :binary_data

  def self.s3_object_for(blob)
    blob.service.send(:object_for, blob.key)
  rescue NoMethodError
    blob.service.bucket.object(blob.key)
  end
  private_class_method :s3_object_for

  def self.attached_download_url(attachment)
    return unless attachment&.attached?

    blob = attachment.blob
    if blob.service.respond_to?(:bucket)
      return s3_object_for(blob).presigned_url(:get, expires_in: 2.hours.to_i)
    end

    url = blob.url(expires_in: 2.hours).to_s
    return url if url.match?(/\Ahttps?:\/\//i)

    host = ENV["CONTENT_CREATION_PUBLIC_URL"].presence || "http://localhost:3000"
    "#{host.to_s.chomp('/')}#{url.start_with?('/') ? url : "/#{url}"}"
  end
  private_class_method :attached_download_url

  def self.is_scene_video_ready(scene)
    gen_id = scene.video_gen_id
    if gen_id.blank?
      Rails.logger.warn("is_scene_video_ready skipped scene=#{scene.id}: missing video_gen_id")
      return
    end

    data = generation_status(gen_id)
    Rails.logger.info("is_scene_video_ready scene=#{scene.id} data=#{data.inspect}")

    if data["completed"] == true || data["completed"] == "true"
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
