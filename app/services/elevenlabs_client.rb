require "stringio"
require "tempfile"

class ElevenlabsClient
  MODEL_ID     = "eleven_multilingual_v2"
  MAX_DURATION_SECONDS = 5.0
  MAX_LENGTH_ATTEMPTS = 3

  def self.create_audio_file(scene)
    if scene.text.blank?
      Rails.logger.error("ElevenlabsClient create_audio_file skipped scene=#{scene.id}: blank text")
      return
    end

    last_bytes = nil
    MAX_LENGTH_ATTEMPTS.times do |attempt|
      bytes = generate_audio_bytes(scene)
      break if bytes.blank?

      last_bytes = bytes
      duration = audio_duration_seconds(bytes)
      Rails.logger.info(
        "ElevenlabsClient audio duration=#{duration} attempt=#{attempt + 1} scene=#{scene.id}"
      )

      if duration <= 0 || duration < MAX_DURATION_SECONDS
        attach_audio(scene, bytes)
        assign_audio_too_long!(scene, false)
        return bytes
      end

      break if attempt == MAX_LENGTH_ATTEMPTS - 1

      summarized = ChatGPTClient.summarize_narration(scene.text)
      if summarized.blank? || summarized == scene.text
        Rails.logger.warn("ElevenlabsClient cannot summarize narration further scene=#{scene.id}")
        break
      end

      scene.update!(text: summarized)
    end

    return if last_bytes.blank?

    attach_audio(scene, last_bytes)
    assign_audio_too_long!(scene, true)
    Rails.logger.warn("ElevenlabsClient audio still over #{MAX_DURATION_SECONDS}s scene=#{scene.id}")
    last_bytes
  end

  def self.generate_audio_bytes(scene)
    headers                  = {}
    headers[:"Accept"]       = "audio/mpeg"
    headers[:"Content-Type"] = "application/json"
    headers[:"xi-api-key"]   = ENV["ELEVENLABS_KEY"]

    data             = {}
    data[:text]      = scene.text
    data[:model_id]  = MODEL_ID

    options           = {}
    options[:headers] = headers
    options[:body]    = data.to_json

    res  = HTTParty.post(tts_endpoint(voice_id_for(scene)), options)
    body = res.body.to_s

    unless res.success? && mpeg_audio?(body)
      Rails.logger.error(
        "ElevenlabsClient create_audio_file failed scene=#{scene.id} status=#{res.code} body=#{body.slice(0, 500)}"
      )
      return
    end

    body.b
  end
  private_class_method :generate_audio_bytes

  def self.assign_audio_too_long!(scene, value)
    Scene.refresh_audio_too_long_column!
    return unless Scene.column_names.include?("audio_too_long")

    Scene.where(id: scene.id).update_all(audio_too_long: value, updated_at: Time.current)
  end
  private_class_method :assign_audio_too_long!

  def self.attach_audio(scene, body)
    file_name = "story-#{scene.story_id}-scene-#{scene.id}-#{rand(10)}.mp3"
    io        = StringIO.new(body)
    io.set_encoding(Encoding::BINARY)
    io.rewind

    scene.audio.attach(
      io:           io,
      filename:     file_name,
      content_type: "audio/mpeg",
      identify:     false
    )
  end
  private_class_method :attach_audio

  def self.voice_id_for(scene)
    scene.story&.story_type&.voice_id.presence || StoryType::DEFAULT_VOICE_ID
  end
  private_class_method :voice_id_for

  def self.tts_endpoint(voice_id)
    "https://api.elevenlabs.io/v1/text-to-speech/#{voice_id}?output_format=mp3_44100_128"
  end
  private_class_method :tts_endpoint

  def self.audio_duration_seconds(bytes)
    return 0 if bytes.blank?

    Tempfile.create([ "scene-audio", ".mp3" ]) do |file|
      file.binmode
      file.write(bytes)
      file.flush
      raw = IO.popen(
        [ "ffprobe", "-v", "error", "-show_entries", "format=duration", "-of", "csv=p=0", file.path ],
        err: File::NULL,
        &:read
      )
      raw.to_f
    end
  rescue Errno::ENOENT => e
    Rails.logger.error("ElevenlabsClient audio_duration_seconds missing ffprobe: #{e.message}")
    0
  end
  private_class_method :audio_duration_seconds

  def self.mpeg_audio?(body)
    return false if body.blank?

    header = body.byteslice(0, 3).to_s
    return true if header.start_with?("ID3")
    return false if header.bytesize < 2

    bytes = header.bytes
    bytes[0] == 0xFF && (bytes[1] & 0xE0) == 0xE0
  end
  private_class_method :mpeg_audio?
end
