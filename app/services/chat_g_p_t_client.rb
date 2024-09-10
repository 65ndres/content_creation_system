require 'chatgpt/client'

class ChatGPTClient

  def self.generate_story_text(story)
    client   = ChatGPT::Client.new(ENV['CHATGPT_KEY'])
    messages = [
      {
        role:    "user",
        content: story.source.text + story.story_type.story_prompt_text 
      }
    ]

    response  = client.chat(messages)
    response["choices"][0]["message"]["content"]
  end

  def self.generate_scene_images_prompts(story)
    client   = ChatGPT::Client.new(ENV['CHATGPT_KEY'])
    messages = [
      {
        role:    "user",
        content: story.story_type.scenes_json_prompts + ' ' + story.text
      }
    ]

    response = client.chat(messages)
    puts "response, this is the response #{response}"
    data = response["choices"][0]["message"]["content"]
    data
  end
end