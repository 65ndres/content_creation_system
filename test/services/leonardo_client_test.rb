require "test_helper"
require "minitest/mock"

class LeonardoClientTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

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
