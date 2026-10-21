require "test_helper"
require "minitest/mock"

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

  test "seed visual style is extracted from the scenes prompt once and stored" do
    story_type = story_types(:one)
    story_type.update_columns(visual_style: nil)
    calls = 0
    extractor = ->(_prompt) { calls += 1; "Dark comic book illustration" }

    ChatGPTClient.stub(:extract_visual_style, extractor) do
      assert_equal "Dark comic book illustration", story_type.seed_visual_style
      assert_equal "Dark comic book illustration", story_type.reload.seed_visual_style
    end
    assert_equal 1, calls
  end

  test "changing the scenes prompt clears an extracted visual style" do
    story_type = story_types(:one)
    story_type.update_columns(visual_style: "Old style")

    story_type.update!(scenes_json_prompts: "Photorealistic stills.")
    assert_nil story_type.reload.visual_style

    story_type.update!(scenes_json_prompts: "Watercolor.", visual_style: "Soft watercolor")
    assert_equal "Soft watercolor", story_type.reload.visual_style

    story_type.update!(scenes_json_prompts: "Watercolor, edited.", visual_style: "Soft watercolor")
    assert_equal "Soft watercolor", story_type.reload.visual_style
  end
end
