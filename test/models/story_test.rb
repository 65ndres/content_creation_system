require "test_helper"
require "minitest/mock"

class StoryTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  test "create_scenes inserts every pair and enqueues audio later" do
    story = stories(:one)
    story.scenes.destroy_all

    payload = {
      "pairs" => [
        { "original" => "First scene text here.", "aiImagePrompts" => [ "prompt one" ] },
        { "original" => "Second scene text here.", "aiImagePrompts" => [ "prompt two" ] }
      ]
    }.to_json

    ChatGPTClient.stub(:generate_scene_images_prompts, payload) do
      assert_enqueued_jobs 2, only: CreateSceneAudioJob do
        story.create_scenes
      end
    end

    assert_equal [ "First scene text here.", "Second scene text here." ], story.scenes.order(:id).pluck(:text)
  end

  test "create_scenes skips texts that already exist" do
    story = stories(:one)
    story.scenes.destroy_all
    story.scenes.create!(text: "First scene text here.", ai_image_prompt: [ "x" ], images_total: 1)

    payload = {
      "pairs" => [
        { "original" => "First scene text here.", "aiImagePrompts" => [ "prompt one" ] },
        { "original" => "Second scene text here.", "aiImagePrompts" => [ "prompt two" ] }
      ]
    }.to_json

    ChatGPTClient.stub(:generate_scene_images_prompts, payload) do
      story.create_scenes
    end

    assert_equal [ "First scene text here.", "Second scene text here." ], story.scenes.order(:id).pluck(:text)
  end

  test "create_scenes skips a pair that was already summarized" do
    story = stories(:one)
    story.scenes.destroy_all
    story.scenes.create!(
      text: "What if a Louvre murder was a centuries-old clue?",
      ai_image_prompt: [ "x" ],
      images_total: 1
    )

    payload = {
      "pairs" => [
        {
          "original" => "What if a murder in the Louvre was not just a crime scene, but a centuries-old clue?",
          "aiImagePrompts" => [ "prompt one" ]
        },
        { "original" => "Langdon follows coded clues through Paris.", "aiImagePrompts" => [ "prompt two" ] }
      ]
    }.to_json

    ChatGPTClient.stub(:generate_scene_images_prompts, payload) do
      story.create_scenes
    end

    assert_equal(
      [ "What if a Louvre murder was a centuries-old clue?", "Langdon follows coded clues through Paris." ],
      story.scenes.order(:id).pluck(:text)
    )
  end
end
