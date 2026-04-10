require "httparty"

class XaiClient
  BASE_URL = "https://api.x.ai/v1"
  RESPONSES_PATH = "/responses"
  DEFAULT_MODEL = "grok-4.20-reasoning"
  POLL_INTERVAL = 1.5
  MAX_POLL_ATTEMPTS = 120

  class Error < StandardError; end

  def self.generate_story_text(story)
    input = story.source.text + story.story_type.story_prompt_text
    call_responses(input)
  end

  def self.generate_scene_images_prompts(story)
    input = story.story_type.scenes_json_prompts + " " + story.text
    call_responses(input)
  end

  def self.call_responses(input)
    body = {
      model: model_name,
      input: input
    }
    response = HTTParty.post(
      "#{BASE_URL}#{RESPONSES_PATH}",
      headers: request_headers,
      body: body.to_json
    )
    handle_http_errors(response)
    parsed = normalize_parsed(response)
    ensure_completed_response(parsed)
  end

  class << self
    private

    def model_name
      ENV["XAI_MODEL"].presence || DEFAULT_MODEL
    end

    def request_headers
      {
        "Content-Type" => "application/json",
        "Authorization" => "Bearer #{api_key}"
      }
    end

    def api_key
      key = ENV["XAI_API_KEY"]
      raise Error, "XAI_API_KEY is not set" if key.blank?
      key
    end

    def normalize_parsed(response)
      parsed = response.parsed_response
      return parsed if parsed.is_a?(Hash)
      JSON.parse(response.body)
    end

    def handle_http_errors(response)
      return if response.success?
      raise Error, "xAI API HTTP #{response.code}: #{response.body}"
    end

    def ensure_completed_response(parsed)
      raise_if_error_object(parsed)
      id = parsed["id"]
      status = parsed["status"]

      attempt = 0
      while status == "in_progress" && attempt < MAX_POLL_ATTEMPTS
        sleep POLL_INTERVAL
        attempt += 1
        parsed = fetch_response(id)
        status = parsed["status"]
      end

      raise Error, "xAI response incomplete (status=#{status})" if status == "incomplete"
      raise Error, "xAI response timed out (still in_progress)" if status == "in_progress"
      raise Error, "xAI unexpected status: #{status}" unless status == "completed"

      output_text_from_response(parsed)
    end

    def fetch_response(id)
      get_resp = HTTParty.get(
        "#{BASE_URL}#{RESPONSES_PATH}/#{id}",
        headers: request_headers
      )
      handle_http_errors(get_resp)
      parsed = normalize_parsed(get_resp)
      raise_if_error_object(parsed)
      parsed
    end

    def raise_if_error_object(parsed)
      return unless parsed.is_a?(Hash)
      err = parsed["error"]
      return if err.blank?
      msg = err.is_a?(Hash) ? (err["message"].presence || err.inspect) : err.to_s
      raise Error, "xAI API error: #{msg}"
    end

    def output_text_from_response(parsed)
      output = parsed["output"]
      raise Error, "xAI response missing output" unless output.is_a?(Array)

      parts = []
      output.each do |item|
        next unless item.is_a?(Hash)
        content = item["content"]
        next unless content.is_a?(Array)
        content.each do |block|
          next unless block.is_a?(Hash) && block["type"] == "output_text"
          parts << block["text"].to_s
        end
      end

      text = parts.join
      raise Error, "xAI response contained no output_text" if text.blank?
      text
    end
  end
end
