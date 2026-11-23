require "test_helper"
require "minitest/mock"

class StoryTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  test "create_characters uses the story type's fixed cast for the characters the story mentions" do
    story = stories(:one)
    story.story_type.update_columns(cast: [
      { "name" => "Dragon Baby", "physical_description" => "tiny purple wings" },
      { "name" => "Unicorn Baby", "physical_description" => "tiny golden horn" },
      { "name" => "Dad", "physical_description" => "short beard" }
    ])
    story.update_columns(text: "Dragon babies hear a leaf fall. [SCENE: Dragon Baby wakes in the crib while Mom tiptoes out.]")

    ChatGPTClient.stub(:generate_story_characters, ->(*) { flunk "should not extract characters" }) do
      story.create_characters
    end

    assert_equal [ "Dragon Baby" ], story.reload.characters.map { |c| c["name"] }
  end

  test "create_characters with extend_cast keeps the fixed cast first and adds the story's other characters" do
    story = stories(:one)
    story.story_type.update_columns(extend_cast: true, cast: [
      { "name" => "Jesus", "physical_description" => "Soft White robe, Dusty Pink mantle" }
    ])
    story.update_columns(text: "Jesus told his disciples a parable. A man called in his servants.")

    seen = nil
    response = {
      "characters" => [
        { "name" => "The Servant", "physical_description" => "Mustard Yellow tunic" },
        { "name" => "jesus", "physical_description" => "a different look" }
      ]
    }.to_json
    ChatGPTClient.stub(:generate_story_characters, ->(_story, fixed_cast:) { seen = fixed_cast; response }) do
      story.create_characters
    end

    assert_equal [ "Jesus" ], seen.map { |c| c["name"] }
    assert_equal [
      { "name" => "Jesus", "physical_description" => "Soft White robe, Dusty Pink mantle" },
      { "name" => "The Servant", "physical_description" => "Mustard Yellow tunic" }
    ], story.reload.characters
  end

  test "create_characters with extend_cast falls back to the fixed cast when ChatGPT fails" do
    story = stories(:one)
    story.story_type.update_columns(extend_cast: true, cast: [ { "name" => "Jesus", "physical_description" => "robe" } ])
    story.update_columns(text: "Jesus went up the mountain.")

    ChatGPTClient.stub(:generate_story_characters, ->(*, **) { "not json" }) do
      story.create_characters
    end

    assert_equal [ "Jesus" ], story.reload.characters.map { |c| c["name"] }
  end

  test "pairs cut mid-phrase are joined with the next pair" do
    pairs = [
      { "original" => "Dragon babies hear a leaf fall two rooms away. You tiptoe out", "aiImagePrompts" => [ "A" ] },
      { "original" => "of the nursery, holding your breath… and those little eyes pop wide open.", "aiImagePrompts" => [ "B" ] },
      { "original" => "They notice everything:", "aiImagePrompts" => [ "C" ] },
      { "original" => "the light, the sounds, every little change.", "aiImagePrompts" => [ "D" ] },
      { "original" => "So give your dragon a very", "aiImagePrompts" => [ "E" ] },
      { "original" => "dark room, steady white noise", "aiImagePrompts" => [ "F" ] },
      { "original" => "and the same calm routine every single night.", "aiImagePrompts" => [ "G" ] }
    ]

    merged = StoryJsonNormalizer.merge_mid_phrase_pairs(pairs)

    assert_equal [
      "Dragon babies hear a leaf fall two rooms away. You tiptoe out of the nursery, holding your breath… and those little eyes pop wide open.",
      "They notice everything:",
      "the light, the sounds, every little change.",
      "So give your dragon a very dark room, steady white noise and the same calm routine every single night."
    ], merged.map { |p| p["original"] }
    assert_equal [ [ "A" ], [ "C" ], [ "D" ], [ "E" ] ], merged.map { |p| p["aiImagePrompts"] }
    assert_equal "You tiptoe out", pairs.first["original"].split(". ").last, "input pairs are not modified"
  end

  test "a shared role word does not match another character" do
    cast = [
      { "name" => "Dragon Baby", "physical_description" => "wings" },
      { "name" => "Unicorn Baby", "physical_description" => "horn" }
    ]

    matched = StoryJsonNormalizer.filter_characters_in_text(cast, "Unicorn Baby naps in the stroller; the baby smiles.")
    assert_equal [ "Unicorn Baby" ], matched.map { |c| c["name"] }
    assert_equal [ "Dragon Baby" ], StoryJsonNormalizer.filter_characters_in_text(cast, "So give your dragon a dark room.").map { |c| c["name"] }
  end

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

  test "create_scenes queues scene generation when auto_produce is on" do
    story = stories(:one)
    story.update!(auto_produce: true)
    story.scenes.destroy_all
    payload = { "pairs" => [ { "original" => "Only scene text.", "aiImagePrompts" => [ "p" ] } ] }.to_json

    ChatGPTClient.stub(:generate_scene_images_prompts, payload) do
      assert_enqueued_jobs 1, only: CreateSceneImagesJob do
        story.create_scenes
      end
    end
  end

  test "create_scenes waits for a click when auto_produce is off" do
    story = stories(:one)
    story.update!(auto_produce: false)
    story.scenes.destroy_all
    payload = { "pairs" => [ { "original" => "Only scene text.", "aiImagePrompts" => [ "p" ] } ] }.to_json

    ChatGPTClient.stub(:generate_scene_images_prompts, payload) do
      assert_no_enqueued_jobs only: CreateSceneImagesJob do
        story.create_scenes
      end
    end
  end

  test "create_final_video_if_ready! starts the final video once every scene is merged" do
    story = stories(:one)
    story.update!(auto_produce: true, video_url: nil, video_gen_id: nil)
    story.scenes.destroy_all
    first = story.scenes.create!(text: "a", merged_audio_video_url: "/tmp/a.mp4")
    second = story.scenes.create!(text: "b")
    calls = 0

    VideoEditorClient.stub(:create_story_video, ->(_s) { calls += 1 }) do
      assert_not story.create_final_video_if_ready!
      second.update!(merged_audio_video_url: "/tmp/b.mp4")
      assert story.reload.create_final_video_if_ready!
    end
    assert_equal 1, calls
    assert first.persisted?
  end

  test "create_final_video_if_ready! does nothing when auto_produce is off" do
    story = stories(:one)
    story.update!(auto_produce: false, video_url: nil, video_gen_id: nil)
    story.scenes.destroy_all
    story.scenes.create!(text: "a", merged_audio_video_url: "/tmp/a.mp4")

    VideoEditorClient.stub(:create_story_video, ->(_s) { flunk "should not run" }) do
      assert_not story.create_final_video_if_ready!
    end
  end
end
