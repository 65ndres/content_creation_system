require 'chatgpt/client'

class ChatGPTClient
  attr_accessor :client

  def initialize
    client = ChatGPT::Client.new(ENV['CHATGPT_KEY'])
  end

  def generate_story_text(story)
    client   ||= new
    messages = [
      {
        role:    "user",
        content: story.source.text + story.story_type.story_prompt_text 
      }
    ]

    response  = client.chat(messages)
    response["choices"][0]["message"]["content"]
  end

  def generate_scene_images_prompts(story)
    client   ||= ChatGPT::Client.new(ENV['CHATGPT_KEY'])
    messages = [
      {
        role:    "user",
        content: story.story_type.scenes_json_prompts + story.text
      }
    ]

    response = client.chat(messages)
    response["choices"][0]["message"]["content"]
  end
end