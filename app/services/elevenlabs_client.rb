class ElevenlabsClient

  ELELVEN_LABS = "https://api.elevenlabs.io/v1/text-to-speech/TX3LPaxmHKxFdv7VOQHJ/stream"
  MODEL_ID     = "eleven_monolingual_v1"

  def self.create_audio_file(scene)
    return if scene.audio.blob.present?
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

    res       = HTTParty.post(ELELVEN_LABS, options)
    file_name = "story-#{scene.story_id}-scene-#{scene.id}-#{rand(10)}.mp3"

    File.open(file_name, "wb") do |f|
      f.write(res)
    end

    data = scene.audio.attach(
        io:           File.open("/app/#{file_name}"), 
        filename:     file_name, 
        content_type: "audio/mpeg"
    )

  end
end
