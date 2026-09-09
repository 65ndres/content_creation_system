require "stringio"

class ElevenlabsClient

  VOICE_ID     = "TX3LPaxmHKxFdv7VOQHJ"
  TTS_ENDPOINT = "https://api.elevenlabs.io/v1/text-to-speech/#{VOICE_ID}?output_format=mp3_44100_128"
  MODEL_ID     = "eleven_multilingual_v2"

  def self.create_audio_file(scene)
    if scene.text.blank?
      Rails.logger.error("ElevenlabsClient create_audio_file skipped scene=#{scene.id}: blank text")
      return
    end

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

    res  = HTTParty.post(TTS_ENDPOINT, options)
    body = res.body.to_s

    unless res.success? && mpeg_audio?(body)
      Rails.logger.error(
        "ElevenlabsClient create_audio_file failed scene=#{scene.id} status=#{res.code} body=#{body.slice(0, 500)}"
      )
      return
    end

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
    body.b
  end

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
