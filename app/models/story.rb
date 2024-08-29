class Story < ApplicationRecord
  belongs_to :source
  belongs_to :story_type
  has_many :scenes

  before_create :generate_story
  require 'chatgpt/client'



  def generate_story

    client = ChatGPT::Client.new(api_key)
    content = self.source.text + self.story_type.story_prompt_text
    messages = [
      {
        role: "user",
        content: content 
      }
    ]

    response = client.chat(messages)
    self.text = response["choices"][0]["message"]["content"]

  end


  def generate_scene_prompts
    client = ChatGPT::Client.new(api_key)
    content = self.story_type.scenes_json_prompts + self.text

    messages = [
      {
        role: "user",
        content: content 
      }
    ]

    response = client.chat(messages)
    response = JSON.parse(response["choices"][0]["message"]["content"])
    #
    response["pairs"].each do |obj|
      scene = Scene.new
      scene.text = obj["original"]
      scene.ai_image_prompt = obj["aiImagePrompts"]
      scene.save
    end

  end

  def generate_scene_from_prompts
    scene = Scene.last
    story_type = scene.story.story_type
    scene.ai_image_prompt.each_with_index do |prompt, i|
      begin
        payload = {}
        payload["height"] = story_type.image_height
        payload["modelId"] = "aa77f04e-3eec-4034-9c07-d0f619684628"
        payload["width"] = story_type.image_width
        payload["prompt"] = prompt
        payload["public"] = false
        payload["num_images"] = i + 1
        # puts payload
        response = send_to_leonardo(payload)
        scene.leonardo_gen_ids << response["sdGenerationJob"]["generationId"]
        scene.save # This feels dirty but It will do for now
      rescue
        puts "ERROR generation images from Leonardo. Fix me for a real logger pls"
      end
    end

    # assuming we checked for possible errors now we create a Job
    # that will use leonardo_gen_ids to check for our generated images

  end

  def send_to_leonardo(payload)
    require 'uri'
    require 'net/http'

    url = URI("https://cloud.leonardo.ai/api/rest/v1/generations")

    http = Net::HTTP.new(url.host, url.port)
    http.use_ssl = true
  
    request = Net::HTTP::Post.new(url)
    request["Authorization"] = "Bearer #{api_key}"
    request["accept"] = 'application/json'
    request["content-type"] = 'application/json'
    request.body = payload.to_json

    response = http.request(request)
    JSON.parse(response.body)
  end
  
  def generate_scene_from_prompts_sample
    #AS per MAKE


    # Parse Json
      # gets:
        #[
          #     {
          #       "json": "{\"aIImagePrompts\": [\"Create a vivid, dynamic comic book illustration of a futuristic cityscape at night, illuminated by neon lights and holograms. Show a chaotic battle taking place between shadowy figures with glowing weapons amidst the towering skyscrapers, casting dramatic shadows on the streets below.\",\"Create a vivid, dynamic comic book illustration of a group of futuristic soldiers, clad in advanced armor, engaging in an intense battle, firing energy beams under the bright neon signs of a bustling city. The atmosphere should be tense, with sparks flying and debris scattered around.\",\"Create a vivid, dynamic comic book illustration capturing the skyline of a sprawling metropolis, with exploding vehicles and flickering neon signs around, as the silhouette of a hero rises against the chaos, ready to join the fray.\"]}"
          #   }
          # ]
      #returns:

          #       [
          #     {
          #         "aIImagePrompts": [
          #             "Create a vivid, dynamic comic book illustration of a futuristic cityscape at night, illuminated by neon lights and holograms. Show a chaotic battle taking place between shadowy figures with glowing weapons amidst the towering skyscrapers, casting dramatic shadows on the streets below.",
          #             "Create a vivid, dynamic comic book illustration of a group of futuristic soldiers, clad in advanced armor, engaging in an intense battle, firing energy beams under the bright neon signs of a bustling city. The atmosphere should be tense, with sparks flying and debris scattered around.",
          #             "Create a vivid, dynamic comic book illustration capturing the skyline of a sprawling metropolis, with exploding vehicles and flickering neon signs around, as the silhouette of a hero rises against the chaos, ready to join the fray."
          #         ]
          #     }
          # ]

    #

    # Iterator

    #GETS:
      #     [
      #     {
      #         "array": [
      #             {
      #                 "value": "Create a vivid, dynamic comic book illustration of a futuristic cityscape at night, illuminated by neon lights and holograms. Show a chaotic battle taking place between shadowy figures with glowing weapons amidst the towering skyscrapers, casting dramatic shadows on the streets below."
      #             },
      #             {
      #                 "value": "Create a vivid, dynamic comic book illustration of a group of futuristic soldiers, clad in advanced armor, engaging in an intense battle, firing energy beams under the bright neon signs of a bustling city. The atmosphere should be tense, with sparks flying and debris scattered around."
      #             },
      #             {
      #                 "value": "Create a vivid, dynamic comic book illustration capturing the skyline of a sprawling metropolis, with exploding vehicles and flickering neon signs around, as the silhouette of a hero rises against the chaos, ready to join the fray."
      #             }
      #         ]
      #     }
      # ]

      # RETURNS:


#       [
#     {
#         "value": "Create a vivid, dynamic comic book illustration of a futuristic cityscape at night, illuminated by neon lights and holograms. Show a chaotic battle taking place between shadowy figures with glowing weapons amidst the towering skyscrapers, casting dramatic shadows on the streets below.",
#         "__IMTINDEX__": 1,
#         "__IMTLENGTH__": 3
#     },
#     {
#         "value": "Create a vivid, dynamic comic book illustration of a group of futuristic soldiers, clad in advanced armor, engaging in an intense battle, firing energy beams under the bright neon signs of a bustling city. The atmosphere should be tense, with sparks flying and debris scattered around.",
#         "__IMTINDEX__": 2,
#         "__IMTLENGTH__": 3
#     },
#     {
#         "value": "Create a vivid, dynamic comic book illustration capturing the skyline of a sprawling metropolis, with exploding vehicles and flickering neon signs around, as the silhouette of a hero rises against the chaos, ready to join the fray.",
#         "__IMTINDEX__": 3,
#         "__IMTLENGTH__": 3
#     }
# ]


# What leonardo receives:

# [
#     {
#         "width": 1024,
#         "height": 576,
#         "prompt": "Create a vivid, dynamic comic book illustration of a futuristic cityscape at night, illuminated by neon lights and holograms. Show a chaotic battle taking place between shadowy figures with glowing weapons amidst the towering skyscrapers, casting dramatic shadows on the streets below.",
#         "public": false,
#         "modelId": "aa77f04e-3eec-4034-9c07-d0f619684628",
#         "num_images": 1,
#         "sd_version": "v2"
#     }
# ]

#example on Leonardo

# require 'uri'
# require 'net/http'

# url = URI("https://cloud.leonardo.ai/api/rest/v1/generations")

# http = Net::HTTP.new(url.host, url.port)
# http.use_ssl = true

# request = Net::HTTP::Post.new(url)
# request["accept"] = 'application/json'
# request["content-type"] = 'application/json'
# request.body = "{\"alchemy\":true,\"height\":768,\"modelId\":\"b24e16ff-06e3-43eb-8d33-4416c2d75876\",\"num_images\":4,\"presetStyle\":\"DYNAMIC\",\"prompt\":\"A majestic cat in the snow\",\"width\":1024}"

# response = http.request(request)
# puts response.read_body

  end


  def generate_scenes
    if generate_scene_prompts && generate_scene_from_prompts
      #create job to check for the status of the image
    end

  end
end
