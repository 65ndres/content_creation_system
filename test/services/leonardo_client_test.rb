require "test_helper"
require "minitest/mock"

class LeonardoClientTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  test "check_character_seed_generation_status stores seed number and image url" do
    story = stories(:one)
    story.update_columns(image_generation_seed: nil, character_seed_image_url: nil)

    payload = {
      "generations_by_pk" => {
        "status" => "COMPLETE",
        "seed" => 4242,
        "generated_images" => [
          { "url" => "https://cdn.leonardo.ai/seed.jpg" }
        ]
      }
    }

    LeonardoClient.stub(:check_asset_generation_status, payload) do
      assert_enqueued_with(job: CreateStoryScenesJob, args: [ story ]) do
        LeonardoClient.check_character_seed_generation_status(story, "gen-seed")
      end
    end

    story.reload
    assert_equal "4242", story.image_generation_seed
    assert_equal "https://cdn.leonardo.ai/seed.jpg", story.character_seed_image_url
  end

  test "character seed prompt is a shoulders-up portrait" do
    prompt = LeonardoClient.send(
      :build_character_seed_prompt,
      [ { "name" => "Ada", "physical_description" => "short dark hair" } ],
      story_types(:one)
    )

    assert_match(/shoulders up/i, prompt)
    assert_match(/focus on faces/i, prompt)
    assert_no_match(/full body/i, prompt)
    assert_includes prompt, "Ada"
  end

  test "character seed prompt uses the story type visual style" do
    story_type = story_types(:one)
    story_type.update_columns(visual_style: "Retro 1980s anime-style screen-print illustration, thin black ink linework")

    prompt = LeonardoClient.send(
      :build_character_seed_prompt,
      [ { "name" => "Ada", "physical_description" => "short dark hair" } ],
      story_type
    )

    assert prompt.start_with?("Visual style")
    assert_includes prompt, "Retro 1980s anime-style screen-print illustration, thin black ink linework."
  end

  def direct_video_scene(text:, seed_id: "seed-img-1", brand_assets: {})
    story = stories(:one)
    story.update_columns(video_generation_model: "wan-2.6", image_generation_seed: "777", character_seed_image_id: seed_id, characters: [])
    story.story_type.update_columns(brand_assets: brand_assets)
    scene = scenes(:one)
    scene.update_columns(
      story_id: story.id, text: text, ai_image_prompt: [ "Mom rocks in a paper chair." ],
      leonardo_video_gen_id: nil, leonardo_video_url: nil, video_url: nil,
      start_frame_gen_id: nil, start_frame_image_id: nil, start_frame_image_type: nil
    )
    scene.reload
  end

  test "running out of credits leaves the prompts alone" do
    scene = direct_video_scene(text: "It's 3 AM.")
    scene.update_columns(start_frame_image_id: "frame", start_frame_image_type: "GENERATED", image_prompt_rewrite_count: 0)
    broke = [ { "extensions" => { "code" => "HttpException", "statusCode" => 402 }, "message" => "Insufficient tokens" } ]

    LeonardoClient.stub(:generate_video, broke) do
      ChatGPTClient.stub(:soften_image_prompts, ->(*) { flunk "prompts softened for a billing error" }) do
        LeonardoClient.generate_scene_video(scene)
      end
    end

    scene.reload
    assert_equal 0, scene.image_prompt_rewrite_count
    assert_equal [ "Mom rocks in a paper chair." ], StoryJsonNormalizer.normalize_ai_image_prompts(scene.ai_image_prompt)
    assert_nil scene.leonardo_video_gen_id
  end

  test "long narration gets a 10 second Wan clip" do
    short = direct_video_scene(text: "Less guessing. More rest. For both of you.")
    assert_equal 5, LeonardoClient.send(:wan_video_payload, short).dig("parameters", "duration")

    long = direct_video_scene(text: "So give your dragon a very dark room, steady white noise, and the same calm routine every night.")
    assert_equal 10, LeonardoClient.send(:wan_video_payload, long).dig("parameters", "duration")
  end

  test "an image flagged nsfw that still has a url is kept, not regenerated" do
    scene = scenes(:one)
    scene.update_columns(images_data: [ { "leonardo_image_gen_id" => "img-gen", "api" => "v2" } ], images_total: 1,
                         image_prompt_rewrite_count: 0, ai_image_prompt: [ "Baby asleep in a stroller." ])
    payload = { "generations_by_pk" => {
      "status" => "COMPLETE",
      "generated_images" => [ { "id" => "img-1", "url" => "https://cdn.leonardo.ai/baby.jpg", "nsfw" => true } ],
      "prompt_moderations" => [ { "moderationClassification" => [ "NSFW", "CHILD" ] } ]
    } }

    LeonardoClient.stub(:check_asset_generation_status, payload) do
      ChatGPTClient.stub(:soften_image_prompts, ->(*) { flunk "a usable image was regenerated" }) do
        LeonardoClient.check_scene_images_generation_status(scene)
      end
    end

    scene.reload
    assert_equal "https://cdn.leonardo.ai/baby.jpg", scene.images_data.first["static_url"]
    assert_equal 0, scene.image_prompt_rewrite_count
  end

  test "a moderation tag on a running video is not treated as blocked" do
    scene = direct_video_scene(text: "It's 3 AM.")
    scene.update_columns(leonardo_video_gen_id: "vid-gen", image_prompt_rewrite_count: 0)
    payload = { "generations_by_pk" => {
      "status" => "PENDING", "generated_images" => [],
      "prompt_moderations" => [ { "moderationClassification" => [ "CHILD" ] } ]
    } }

    LeonardoClient.stub(:check_asset_generation_status, payload) do
      ChatGPTClient.stub(:soften_image_prompts, ->(*) { flunk "prompts softened while the video was still generating" }) do
        assert_enqueued_with(job: CheckLeonardoSceneVideoGenerationStatusJob) do
          LeonardoClient.check_leonardo_scene_video_generation_status(scene)
        end
      end
    end

    assert_equal "vid-gen", scene.reload.leonardo_video_gen_id
  end

  test "character seed status stores the seed image id" do
    story = stories(:one)
    story.update_columns(character_seed_image_id: nil)
    payload = { "generations_by_pk" => { "status" => "COMPLETE", "seed" => 1, "generated_images" => [ { "id" => "img-42", "url" => "https://x/seed.jpg" } ] } }

    LeonardoClient.stub(:check_asset_generation_status, payload) do
      LeonardoClient.check_character_seed_generation_status(story, "gen")
    end

    assert_equal "img-42", story.reload.character_seed_image_id
  end

  test "direct video scenes first request a Nano Banana 2 frame that references the character seed" do
    scene = direct_video_scene(text: "It's 3 AM.")
    sent = nil

    LeonardoClient.stub(:generate_asset, ->(payload, _endpoint) { sent = payload; { "generate" => { "generationId" => "frame-gen" } } }) do
      LeonardoClient.stub(:generate_video, ->(_) { flunk "video requested before its first frame" }) do
        assert_enqueued_with(job: CheckSceneStartFrameStatusJob) do
          LeonardoClient.generate_scene_video(scene)
        end
      end
    end

    assert_equal "nano-banana-2", sent["model"]
    assert_equal 777, sent.dig("parameters", "seed")
    assert_equal [ { "image" => { "id" => "seed-img-1", "type" => "GENERATED" }, "strength" => "HIGH" } ],
                 sent.dig("parameters", "guidances", "image_reference")
    assert_equal "frame-gen", scene.reload.start_frame_gen_id
  end

  test "brand scenes add the app art as references" do
    assets = { "keywords" => [ "Tiny Rest" ], "references" => [ { "label" => "unicorn", "id" => "up-unicorn" } ] }
    scene = direct_video_scene(text: "Tiny Rest keeps track for you.", brand_assets: assets)
    scene.story.scenes.create!(text: "A later scene.", ai_image_prompt: [ "p" ]) # so this one is not the end card
    sent = nil

    LeonardoClient.stub(:generate_asset, ->(payload, _endpoint) { sent = payload; { "generate" => { "generationId" => "g" } } }) do
      LeonardoClient.send(:prepare_scene_start_frame, scene)
    end

    ids = sent.dig("parameters", "guidances", "image_reference").map { |ref| [ ref.dig("image", "id"), ref.dig("image", "type") ] }
    assert_equal [ [ "seed-img-1", "GENERATED" ], [ "up-unicorn", "UPLOADED" ] ], ids
  end

  test "the last brand scene opens on the uploaded end card" do
    assets = { "keywords" => [ "Tiny Rest" ], "end_card_id" => "up-end-card" }
    scene = direct_video_scene(text: "Tiny Rest. Calmer days start with better rest.", brand_assets: assets)
    sent = nil

    LeonardoClient.stub(:generate_asset, ->(*) { flunk "end card should not be generated" }) do
      LeonardoClient.stub(:generate_video, ->(payload) { sent = payload; { "generate" => { "generationId" => "vid" } } }) do
        LeonardoClient.generate_scene_video(scene)
      end
    end

    assert_equal [ { "image" => { "id" => "up-end-card", "type" => "UPLOADED" } } ], sent.dig("parameters", "guidances", "start_frame")
    assert_equal 777, sent.dig("parameters", "seed")
  end

  test "a finished first frame is sent to Wan as its start frame" do
    scene = direct_video_scene(text: "It's 3 AM.")
    scene.update_columns(start_frame_gen_id: "frame-gen")
    payload = { "generations_by_pk" => { "status" => "COMPLETE", "generated_images" => [ { "id" => "frame-img", "url" => "https://x/f.jpg" } ] } }

    LeonardoClient.stub(:check_asset_generation_status, payload) do
      assert_enqueued_with(job: LeonardoCreateSceneVideoJob) do
        LeonardoClient.check_scene_start_frame_status(scene)
      end
    end

    sent = nil
    LeonardoClient.stub(:generate_video, ->(body) { sent = body; { "generate" => { "generationId" => "vid" } } }) do
      LeonardoClient.generate_scene_video(scene.reload)
    end
    assert_equal [ { "image" => { "id" => "frame-img", "type" => "GENERATED" } } ], sent.dig("parameters", "guidances", "start_frame")
  end

  test "direct video prompts carry the descriptions of characters in the scene" do
    story = stories(:one)
    story.update_columns(
      video_generation_model: "wan-2.6",
      characters: [
        { "name" => "Mom", "physical_description" => "long dark wavy hair in a messy bun, oversized lavender sweater" },
        { "name" => "Dad", "physical_description" => "short dark hair and a short beard, navy t-shirt" }
      ]
    )
    scene = scenes(:one)
    scene.update_columns(story_id: story.id, text: "It's 3 AM.", ai_image_prompt: [ "Mom rocks in a paper chair." ])

    prompt = LeonardoClient.send(:build_scene_video_prompt, scene.reload)

    assert prompt.start_with?("Mom rocks in a paper chair.")
    assert_includes prompt, "- Mom: long dark wavy hair in a messy bun, oversized lavender sweater"
    assert_not_includes prompt, "Dad"
  end

  test "direct video prompts trim the scene, not the characters, to fit the limit" do
    story = stories(:one)
    story.update_columns(
      video_generation_model: "wan-2.6",
      characters: [ { "name" => "Mom", "physical_description" => "oversized lavender sweater and soft gray joggers" } ]
    )
    scene = scenes(:one)
    scene.update_columns(story_id: story.id, ai_image_prompt: [ "Mom sits by the window. " + ("Paper stars drift. " * 120) ])

    prompt = LeonardoClient.send(:build_scene_video_prompt, scene.reload)

    assert_operator prompt.length, :<=, LeonardoClient::MAX_HAILUO_PROMPT_LENGTH
    assert_includes prompt, "- Mom: oversized lavender sweater and soft gray joggers"
    assert prompt.end_with?("matches their physical description above.")
  end

  test "generate_scene_video retries later when Leonardo is rate limited" do
    scene = scenes(:one)
    scene.update_columns(video_url: nil, leonardo_video_url: nil, leonardo_video_gen_id: nil)

    rate_limit = [ {
      "extensions" => { "code" => "RATE_LIMIT_EXCEEDED" },
      "message" => "Too many pending generations. Please wait for some to complete before submitting more."
    } ]

    LeonardoClient.stub(:generate_video, rate_limit) do
      assert_enqueued_with(job: LeonardoCreateSceneVideoJob) do
        LeonardoClient.generate_scene_video(scene)
      end
    end

    assert_nil scene.reload.leonardo_video_gen_id
  end

  test "rewrite_blocked_scene_prompts requeues video for direct video stories" do
    story = stories(:one)
    story.update_column(:video_generation_model, "wan-2.6")
    scene = scenes(:one)
    scene.update_columns(ai_image_prompt: [ "blood everywhere" ], story_id: story.id)

    ChatGPTClient.stub(:soften_image_prompts, [ "no blood" ]) do
      assert_enqueued_with(job: LeonardoCreateSceneVideoJob) do
        assert LeonardoClient.rewrite_blocked_scene_prompts(
          scene,
          instruction: "make this scene less violent, and remove blood"
        )
      end
    end

    scene.reload
    assert_equal [ "no blood" ], StoryJsonNormalizer.normalize_ai_image_prompts(scene.ai_image_prompt)
  end

  test "check_leonardo_scene_video_generation_status keeps a completed nsfw video" do
    scene = scenes(:one)
    gen_id = "1f1acc95-4005-6d30-ad58-82bd349a4a31"
    scene.update_columns(
      leonardo_video_gen_id: gen_id,
      leonardo_video_url: nil,
      video_url: nil,
      image_prompt_rewrite_count: 4
    )

    payload = {
      "generations_by_pk" => {
        "status" => "COMPLETE",
        "generated_images" => [
          {
            "nsfw" => true,
            "motionMP4URL" => "https://cdn.leonardo.ai/scene.mp4",
            "url" => "https://cdn.leonardo.ai/frame.jpg"
          }
        ]
      }
    }

    LeonardoClient.stub(:check_asset_generation_status, payload) do
      LeonardoClient.check_leonardo_scene_video_generation_status(scene)
    end

    scene.reload
    assert_equal gen_id, scene.leonardo_video_gen_id
    assert_equal "https://cdn.leonardo.ai/scene.mp4", scene.leonardo_video_url
    assert_equal "https://cdn.leonardo.ai/scene.mp4", scene.video_url
  end

  test "check_leonardo_scene_video_generation_status does not clear gen id when rewrite limit is reached" do
    scene = scenes(:one)
    gen_id = "aaaaaaaa-bbbb-cccc-dddd-eeeeeeeeeeee"
    scene.update_columns(
      leonardo_video_gen_id: gen_id,
      leonardo_video_url: nil,
      video_url: nil,
      ai_image_prompt: [ "prompt" ],
      image_prompt_rewrite_count: 4
    )

    payload = { "generations_by_pk" => { "status" => "FAILED", "generated_images" => [] } }

    LeonardoClient.stub(:check_asset_generation_status, payload) do
      LeonardoClient.check_leonardo_scene_video_generation_status(scene)
    end

    assert_equal gen_id, scene.reload.leonardo_video_gen_id
  end
end
