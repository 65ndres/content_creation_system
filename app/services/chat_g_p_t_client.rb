require 'json'
require 'open3'

class ChatGPTClient
  RESPONSES_URL = 'https://api.openai.com/v1/responses'.freeze
  CHAT_MODEL      = ENV.fetch('OPENAI_CHAT_MODEL', 'gpt-5.5').freeze

  def self.generate_source_text(prompt)
    responses_request(prompt.to_s)
  end

  STORY_TYPE_GENERATION_PROMPT = <<~PROMPT.squish
    Create a reusable story type for a short-form video pipeline.
    Return ONLY valid JSON with no markdown fences or commentary. Use this structure:
    {
      "name": "short display name",
      "story_prompt_text": "instructions that take a source article and write voice-over narration",
      "scenes_json_prompts": "instructions that take that narration and return JSON image prompts"
    }
    scenes_json_prompts must tell the model to return JSON with a key "pairs", an array of objects.
    Each object must have "original" (a narration sentence) and "aiImagePrompts" (an array of exactly one prompt string).
    Those prompt strings must stay under 1500 characters and describe action, setting, and mood only — no character physical descriptions.
    User request:
  PROMPT

  def self.generate_story_type_draft(prompt)
    raw = ""
    raw = responses_request("#{STORY_TYPE_GENERATION_PROMPT}\n#{prompt}")
    data = JSON.parse(raw.to_s.gsub("```json", "").gsub("```", "").strip)
    data = {} unless data.is_a?(Hash)
    {
      "name" => data["name"].to_s,
      "story_prompt_text" => data["story_prompt_text"].to_s,
      "scenes_json_prompts" => data["scenes_json_prompts"].to_s
    }
  rescue JSON::ParserError
    {
      "name" => "",
      "story_prompt_text" => raw.to_s,
      "scenes_json_prompts" => ""
    }
  end

  def self.generate_story_text(story)
    input = story.source.text.to_s + story.story_type.story_prompt_text.to_s
    responses_request(input)
  end

  CHARACTERS_EXTRACTION_PROMPT = <<~PROMPT.squish
    Based on the story below, list every character (named or clearly recurring unnamed roles).
    For each character, provide a very detailed, fixed physical description suitable for consistent
    AI image and video generation. alwys include age or age range, build, face, hair type, hair color, skin tone where
    relevant, typical clothing, and distinguishing features.
    Do not add special characters, keep it simple and clean.
    
    Return ONLY valid JSON with no markdown fences or commentary. Use this structure:
    { "characters": [ { "name": "Character Name", "physical_description": "Very detailed description..." } ] }
    Story:
  PROMPT

  def self.generate_story_characters(story)
    input = CHARACTERS_EXTRACTION_PROMPT + ' ' + story.text.to_s
    responses_request(input)
  end

  SOFTEN_IMAGE_PROMPTS = <<~PROMPT.squish
    Rewrite each AI image and video generation prompt using the instruction below.
    Keep the same characters, setting, narrative, and visual style.
    Do not add commentary or markdown.
    Return ONLY valid JSON with this structure:
    { "prompts": ["rewritten prompt 1", "rewritten prompt 2"] }
    Use the same number of prompts, in the same order.
  PROMPT

  DEFAULT_PROMPT_REWRITE_INSTRUCTION = "make this scene less violent, and remove blood"

  def self.soften_image_prompts(prompts, instruction: nil)
    prompts = StoryJsonNormalizer.normalize_ai_image_prompts(prompts)
    return [] if prompts.blank?

    instruction = instruction.to_s.strip.presence || DEFAULT_PROMPT_REWRITE_INSTRUCTION
    numbered = prompts.each_with_index.map { |prompt, i| "#{i + 1}. #{prompt}" }.join("\n\n")
    response = responses_request(
      "#{SOFTEN_IMAGE_PROMPTS}\n\nInstruction: #{instruction}\n\nPrompts:\n#{numbered}"
    )
    data     = JSON.parse(response.gsub("```json", "").gsub("```", "").strip)
    rewritten = StoryJsonNormalizer.normalize_ai_image_prompts(data["prompts"] || data)
    Rails.logger.info("ChatGPTClient soften_image_prompts count=#{rewritten.size} instruction=#{instruction}")
    rewritten
  rescue JSON::ParserError, StandardError => e
    Rails.logger.error("ChatGPTClient soften_image_prompts failed: #{e.message}")
    []
  end

  def self.generate_scene_images_prompts(story)
    story_type = story.story_type
    input = story_type.scenes_json_prompts.to_s + ' ' + story.text.to_s
    if story.characters.present? && !story.leonardo_direct_video?
      input += character_reference_block(story)
    end
    input += scene_text_length_block(story_type)
    input += leonardo_video_prompt_block if story.leonardo_direct_video?
    text  = responses_request(input)
    Rails.logger.info("ChatGPTClient scene prompts response story=#{story.id} body=#{text&.slice(0, 500)}")
    text
  end

  def self.character_reference_block(story)
    lines = StoryJsonNormalizer.normalize_characters(story.characters).map do |character|
      "- #{character['name']}: #{character['physical_description']}"
    end

    "\n\nCharacter reference (use these exact physical descriptions whenever a character appears in a prompt):\n" +
      lines.join("\n")
  end
  private_class_method :character_reference_block

  def self.leonardo_video_prompt_block
    "\n\nLeonardo video prompt rules: Each `aiImagePrompts` string must be at most " \
      "#{LeonardoClient::MAX_HAILUO_PROMPT_LENGTH} characters. Name characters only if needed. " \
      "Do not include physical descriptions, clothing, age, face, hair, or body details. " \
      "Describe only the action, setting, mood, and visual style."
  end
  private_class_method :leonardo_video_prompt_block

  def self.scene_text_length_block(story_type)
    min_chars = story_type.scene_text_min_chars
    max_chars = story_type.scene_text_max_chars

    "\n\nScene text length rules: Each `original` string must be between #{min_chars} and #{max_chars} " \
      "characters (inclusive). Split or combine story sentences as needed so every `original` fits this range. " \
      "Do not output pairs outside this range."
  end
  private_class_method :scene_text_length_block

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
      Rails.logger.error("ChatGPTClient curl failed: #{stderr}")
      raise "OpenAI request failed: #{stderr.presence || stdout}"
    end

    parsed = JSON.parse(stdout)
    if parsed['error'].present?
      Rails.logger.error("ChatGPTClient API error: #{parsed['error']}")
      raise parsed['error'].to_json
    end

    text = extract_responses_output_text(parsed)
    raise 'Empty model output' if text.blank?

    text
  rescue JSON::ParserError => e
    Rails.logger.error("ChatGPTClient invalid JSON: #{e.message} body=#{stdout&.slice(0, 500)}")
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

