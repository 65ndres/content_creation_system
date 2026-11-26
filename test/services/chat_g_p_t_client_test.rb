require "test_helper"
require "minitest/mock"

class ChatGPTClientTest < ActiveSupport::TestCase
  test "summarize narration returns a shorter rewrite" do
    ChatGPTClient.stub(:responses_request, "The island stayed quiet.") do
      assert_equal "The island stayed quiet.", ChatGPTClient.summarize_narration(
        "The island was quiet tonight under the stars and nobody spoke."
      )
    end
  end

  test "summarize narration rejects a rewrite that is not shorter" do
    ChatGPTClient.stub(:responses_request, "one two three four five") do
      assert_equal "", ChatGPTClient.summarize_narration("one two three four")
    end
  end

  test "character prompt carries the image rules and the names already designed" do
    story = stories(:one)
    story.story_type.update_columns(visual_style: "paper relief", scenes_json_prompts: "Do not depict God as a human figure.")
    story.update_columns(text: "Jesus spoke to John.")

    sent = nil
    ChatGPTClient.stub(:responses_request, ->(input) { sent = input; "{}" }) do
      ChatGPTClient.generate_story_characters(story, fixed_cast: [ { "name" => "Jesus", "physical_description" => "robe" } ])
    end

    assert_includes sent, "visual style: paper relief"
    assert_includes sent, "Image instructions:\nDo not depict God as a human figure."
    assert_includes sent, "already designed, so do not list them, and leave out anyone the image instructions say is drawn as one of them: Jesus."
    assert sent.end_with?("Story: Jesus spoke to John.")
  end
end
