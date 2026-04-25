require 'json'
require 'open3'

class ChatGPTClient
  RESPONSES_URL = 'https://api.openai.com/v1/responses'.freeze
  CHAT_MODEL      = ENV.fetch('OPENAI_CHAT_MODEL', 'gpt-5.5').freeze

  def self.generate_story_text(story)
    input = story.source.text.to_s + story.story_type.story_prompt_text.to_s
    responses_request(input)
  end

  def self.generate_scene_images_prompts(story)
    input = story.story_type.scenes_json_prompts.to_s + ' ' + story.text.to_s
    text  = responses_request(input)
    puts "response, this is the response #{text}"
    text
  end

  def self.responses_request(input)
    api_key = ENV['OPENAI_API_KEY'].presence || ENV['CHATGPT_KEY']
    raise KeyError, 'Set OPENAI_API_KEY or CHATGPT_KEY' if api_key.blank?

    body = { 'model' => CHAT_MODEL, 'input' => input }
    cmd  = [
      'curl', '-sS', '-f',
      RESPONSES_URL,
      '-H', 'Content-Type: application/json',
      '-H', "Authorization: Bearer #{api_key}",
      '-d', body.to_json
    ]

    stdout, stderr, status = Open3.capture3(*cmd)
    unless status.success?
      puts "ChatGPTClient curl failed: #{stderr}"
      raise "OpenAI request failed: #{stderr.presence || stdout}"
    end

    parsed = JSON.parse(stdout)
    if parsed['error'].present?
      puts "ChatGPTClient API error: #{parsed['error']}"
      raise parsed['error'].to_json
    end

    text = extract_responses_output_text(parsed)
    raise 'Empty model output' if text.blank?

    text
  rescue JSON::ParserError => e
    puts "ChatGPTClient invalid JSON: #{e.message} body=#{stdout&.slice(0, 500)}"
    raise
  end

  def self.extract_responses_output_text(parsed)
    return unless parsed.is_a?(Hash)

    if parsed['output_text'].is_a?(String) && parsed['output_text'].present?
      return parsed['output_text']
    end

    output = parsed['output']
    return unless output.is_a?(Array)

    texts = []
    output.each do |item|
      next unless item.is_a?(Hash) && item['type'] == 'message'

      Array(item['content']).each do |part|
        next unless part.is_a?(Hash)

        if part['type'] == 'output_text' && part['text'].present?
          texts << part['text']
        elsif part['text'].present?
          texts << part['text']
        end
      end
    end

    texts.join
  end
  private_class_method :extract_responses_output_text
end

