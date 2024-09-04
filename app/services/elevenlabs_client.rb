class ElevenlabsClient

  ELELVEN_LABS = "https://api.elevenlabs.io/v1/text-to-speech/TX3LPaxmHKxFdv7VOQHJ/stream"
  MODEL_ID     = "eleven_monolingual_v1"

  def self.create_audio_file(scene)

    headers                 = {}
    headers["Accept"]       = "audio/mpeg"
    headers["Content-Type"] = "application/json"
    headers["xi-api-key"]   = ENV["ELEVENLABS_KEY"]

    data             = {}
    data["text"]     = scene.text
    data["model_id"] = MODEL_ID

    options            = {}
    options["headers"] = headers
    options["body"]    = data

    puts "This are the option #{options}"

    res = HTTParty.post(ELELVEN_LABS, options)

    # puts "This is the response #{res}"
#     headers = {
#   "Accept": "audio/mpeg",
#   "Content-Type": "application/json",
#   "xi-api-key": "sk_c58cc1629dde118a09307290b5c90b2f4994fb0c25308fae"
# }

# data = {
#   "text": "Born and raised in the charming south, 
#   I can add a touch of sweet southern hospitality 
#   to your audiobooks and podcasts",
#   "model_id": "eleven_monolingual_v1",
#   "voice_settings": {
#     "stability": 0.5,
#     "similarity_boost": 0.5
#   }
# }.to_json

# options = {
#     headers: headers,
#     body: data
# }


# puts "This is the response #{res}"

    file_name = "#{scene.text[0...30].gsub(" ", "").gsub(",", "").gsub(".", "") + rand(1..10).to_s}.mp3"

    File.open(file_name, "wb") do |f|
      f.write(res)
    end

    data = scene.audio.attach(
        io:           File.open("/app/#{file_name}"), 
        filename:     file_name, 
        content_type: "audio/mpeg"
    )

    # puts data

  end

  # def create_audio_file(scene)
  # end
end


# --------------------------------------------------------------


# url = "https://api.elevenlabs.io/v1/text-to-speech/TX3LPaxmHKxFdv7VOQHJ/stream"

# headers = {
#   "Accept": "audio/mpeg",
#   "Content-Type": "application/json",
#   "xi-api-key": "sk_c58cc1629dde118a09307290b5c90b2f4994fb0c25308fae"
# }

# data = {
#   "text": "Born and raised in the charming south, 
#   I can add a touch of sweet southern hospitality 
#   to your audiobooks and podcasts",
#   "model_id": "eleven_monolingual_v1",
#   "voice_settings": {
#     "stability": 0.5,
#     "similarity_boost": 0.5
#   }
# }.to_json

# options = {
#     headers: headers,
#     body: data
# }

# res = HTTParty.post(url, options)

# File.open("output.mp3", "wb") do |f|
#     f.write(f)
# end




# Scene.last.audio.attach(
#     io:           File.open("app/output.mp3"), 
#     filename:     "output.mp3", 
#     content_type: "audio/mpeg"
# )



# aws_client = Aws::S3::Client.new(
#   region:               'us-east-1',
#   access_key_id:        ENV['AWS_ACCESS'],
#   secret_access_key:    ENV['AWS_ACCESS_SECRET']
# )


# s3       = Aws::S3::Resource.new(client: aws_client)
# bucket   = s3.bucket('rails-app-reel-generator')
# obj      = bucket.object("output-#{SecureRandom.uuid}")
# url      = obj.presigned_url(:put)



# File.open("output.mp3","w’") do |f|
#   f.write(res)
#   end