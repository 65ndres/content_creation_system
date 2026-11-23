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

  test "create links the chosen outro video" do
    outro = OutroVideo.new(name: "Gospel closing")
    outro.video.attach(io: file_fixture("outro.mp4").open, filename: "outro.mp4", content_type: "video/mp4")
    outro.save!

    post story_types_url, params: {
      name: "Gospel With Outro",
      story_prompt_text: "Write the narration.",
      scenes_json_prompts: "Return pairs JSON.",
      image_width: 1024,
      image_height: 576,
      output_width: 1920,
      output_height: 1080,
      outro_video_id: outro.id
    }, as: :json

    assert_response :success
    assert_equal outro, StoryType.order(:id).last.outro_video
  end

  test "create saves a story type without an outro video" do
    post story_types_url, params: {
      name: "No Outro",
      story_prompt_text: "Write the narration.",
      scenes_json_prompts: "Return pairs JSON.",
      image_width: 1024,
      image_height: 576,
      output_width: 1920,
      output_height: 1080,
      outro_video_id: ""
    }, as: :json

    assert_response :success
    assert_nil StoryType.order(:id).last.outro_video_id
  end

  def uploaded_outro(name = "Gospel closing")
    outro = OutroVideo.new(name: name)
    outro.video.attach(io: file_fixture("outro.mp4").open, filename: "outro.mp4", content_type: "video/mp4")
    outro.save!
    outro
  end

  test "index lists story types with their outro" do
    outro = uploaded_outro
    story_types(:one).update!(name: "Gospel Stories", outro_video: outro)
    story_types(:two).update!(name: "Night Report", outro_video: nil)

    get story_types_url

    assert_response :success
    assert_select "a.tab.is-active", text: "Story types"
    assert_select "a.story-row[href=?]", story_type_path(story_types(:one)) do
      assert_select "strong", text: "Gospel Stories"
      assert_select ".pill", text: "Outro: Gospel closing"
    end
    assert_select "a.story-row[href=?] .pill", story_type_path(story_types(:two)), text: "No outro"
  end

  test "show offers every uploaded outro with the current one selected" do
    outro = uploaded_outro
    uploaded_outro("Other outro")
    story_types(:one).update!(outro_video: outro)

    get story_type_url(story_types(:one))

    assert_response :success
    assert_select "video[src]"
    assert_select "select[name=outro_video_id] option", count: 3
    assert_select "select[name=outro_video_id] option[selected][value=?]", outro.id.to_s
    assert_select "form button", text: "Remove outro"
  end

  test "update_outro attaches an outro" do
    outro = uploaded_outro

    post story_type_outro_url(story_types(:one)), params: { outro_video_id: outro.id }

    assert_redirected_to story_type_url(story_types(:one))
    assert_equal outro, story_types(:one).reload.outro_video
    follow_redirect!
    assert_select ".is-success", text: "Outro set to “Gospel closing”."
  end

  test "update_outro removes the outro when none is chosen" do
    story_types(:one).update!(outro_video: uploaded_outro)

    post story_type_outro_url(story_types(:one)), params: { outro_video_id: "" }

    assert_redirected_to story_type_url(story_types(:one))
    assert_nil story_types(:one).reload.outro_video_id
  end

  test "update_outro rejects an outro that does not exist" do
    post story_type_outro_url(story_types(:one)), params: { outro_video_id: 999_999 }

    assert_response :unprocessable_entity
    assert_select ".is-error", text: "That outro video no longer exists."
    assert_nil story_types(:one).reload.outro_video_id
  end
end
