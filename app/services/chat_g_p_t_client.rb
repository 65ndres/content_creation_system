require 'json'
require 'open3'

class ChatGPTClient
  RESPONSES_URL = 'https://api.openai.com/v1/responses'.freeze
  CHAT_MODEL      = ENV.fetch('OPENAI_CHAT_MODEL', 'gpt-5.5').freeze

  def self.generate_story_text(story)
    input = story.source.text.to_s + story.story_type.story_prompt_text.to_s
    responses_request(input)
  end

  CHARACTERS_EXTRACTION_PROMPT = <<~PROMPT.squish
    Based on the story below, list every character (named or clearly recurring unnamed roles).
    For each character, provide a very detailed, fixed physical description suitable for consistent
    AI image and video generation. Include age or age range, build, face, hair, skin tone where
    relevant, typical clothing, and distinguishing features.
    Return ONLY valid JSON with no markdown fences or commentary. Use this structure:
    { "characters": [ { "name": "Character Name", "physical_description": "Very detailed description..." } ] }
    Story:
  PROMPT

  def self.generate_story_characters(story)
    input = CHARACTERS_EXTRACTION_PROMPT + ' ' + story.text.to_s
    responses_request(input)
  end

  def self.generate_scene_images_prompts(story)
    input = story.story_type.scenes_json_prompts.to_s + ' ' + story.text.to_s
    input += character_reference_block(story) if story.characters.present?
    text  = responses_request(input)
    puts "response, this is the response #{text}"
    text
  end

  def self.character_reference_block(story)
    lines = story.characters.map do |character|
      name = character['name'] || character[:name]
      description = character['physical_description'] || character[:physical_description]
      "- #{name}: #{description}"
    end

    "\n\nCharacter reference (use these exact physical descriptions whenever a character appears in a prompt):\n" +
      lines.join("\n")
  end
  private_class_method :character_reference_block

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

