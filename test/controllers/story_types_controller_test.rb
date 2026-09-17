require "test_helper"
require "minitest/mock"

class StoryTypesControllerTest < ActionDispatch::IntegrationTest
  test "generate returns a story type draft" do
    draft = {
      "name" => "Dark Fact",
      "story_prompt_text" => "Write narration.",
      "scenes_json_prompts" => "Return pairs JSON."
    }

    ChatGPTClient.stub(:generate_story_type_draft, draft) do
      post generate_story_type_url, params: { prompt: "make a documentary type" }, as: :json
    end

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal "Dark Fact", body["name"]
    assert_equal "Write narration.", body["story_prompt_text"]
  end

  test "generate rejects a blank prompt" do
    post generate_story_type_url, params: { prompt: "  " }, as: :json

    assert_response :unprocessable_entity
    assert_equal "Type something before sending it to ChatGPT.", JSON.parse(response.body)["error"]
  end

  test "create saves a story type" do
    assert_difference("StoryType.count", 1) do
      post story_types_url, params: {
        name: "Night Report",
        story_prompt_text: "Write the narration.",
        scenes_json_prompts: "Return pairs JSON.",
        image_width: 1024,
        image_height: 576,
        output_width: 1920,
        output_height: 1080
      }, as: :json
    end

    assert_response :success
    story_type = StoryType.order(:id).last
    assert_equal "Night Report", story_type.name
    assert_equal StoryType::DEFAULT_VOICE_ID, story_type.voice_id
    assert_equal "Night Report", JSON.parse(response.body)["name"]
  end

  test "create stores a passed voice id" do
    assert_difference("StoryType.count", 1) do
      post story_types_url, params: {
        name: "Custom Voice Report",
        story_prompt_text: "Write the narration.",
        scenes_json_prompts: "Return pairs JSON.",
        image_width: 1024,
        image_height: 576,
        output_width: 1920,
        output_height: 1080,
        voice_id: "customVoice123"
      }, as: :json
    end

    assert_response :success
    story_type = StoryType.order(:id).last
    assert_equal "customVoice123", story_type.voice_id
  end

  test "create uses the default voice id when a blank voice id is passed" do
    assert_difference("StoryType.count", 1) do
      post story_types_url, params: {
        name: "Blank Voice Report",
        story_prompt_text: "Write the narration.",
        scenes_json_prompts: "Return pairs JSON.",
        image_width: 1024,
        image_height: 576,
        output_width: 1920,
        output_height: 1080,
        voice_id: "   "
      }, as: :json
    end

    assert_response :success
    assert_equal StoryType::DEFAULT_VOICE_ID, StoryType.order(:id).last.voice_id
  end
end
