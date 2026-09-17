require "test_helper"

class StoryTypeTest < ActiveSupport::TestCase
  test "assigns the default voice id when none is provided" do
    story_type = StoryType.create!(
      name: "Default Voice",
      story_prompt_text: "Write narration.",
      scenes_json_prompts: "Return pairs JSON.",
      image_width: 1024,
      image_height: 576,
      output_width: 1920,
      output_height: 1080
    )

    assert_equal StoryType::DEFAULT_VOICE_ID, story_type.voice_id
  end

  test "keeps a passed voice id" do
    story_type = StoryType.create!(
      name: "Custom Voice",
      story_prompt_text: "Write narration.",
      scenes_json_prompts: "Return pairs JSON.",
      image_width: 1024,
      image_height: 576,
      output_width: 1920,
      output_height: 1080,
      voice_id: "customVoice123"
    )

    assert_equal "customVoice123", story_type.voice_id
  end
end
