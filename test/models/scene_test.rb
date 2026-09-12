require "test_helper"

class SceneTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  test "enqueue leonardo generation sends stills for slideshow stories" do
    scene = scenes(:one)
    scene.update_columns(video_url: nil, leonardo_video_url: nil, images_data: [])

    assert_enqueued_with(job: CreateSceneImagesJob) do
      assert scene.enqueue_leonardo_generation!
    end
  end

  test "enqueue leonardo generation skips when video is already present" do
    scene = scenes(:one)
    scene.update_columns(video_url: "https://example.com/scene.mp4")

    assert_no_enqueued_jobs only: [ CreateSceneImagesJob, LeonardoCreateSceneVideoJob ] do
      assert_not scene.enqueue_leonardo_generation!
    end
  end

  test "enqueue leonardo generation skips in-flight wan jobs" do
    story = stories(:one)
    story.update_column(:video_generation_model, "wan-2.6")
    scene = scenes(:one)
    scene.reload
    scene.update_columns(video_url: nil, leonardo_video_url: nil, leonardo_video_gen_id: "abc")

    assert_no_enqueued_jobs only: LeonardoCreateSceneVideoJob do
      assert_not scene.enqueue_leonardo_generation!
    end
  end

  test "regenerate leonardo generation clears video and merge then requeues" do
    scene = scenes(:one)
    scene.update_columns(
      video_url: "https://example.com/old.mp4",
      merged_audio_video_url: "https://example.com/merged.mp4"
    )

    assert_enqueued_with(job: CreateSceneImagesJob) do
      assert scene.regenerate_leonardo_generation!(prompt: "new prompt")
    end

    scene.reload
    assert_equal [ "new prompt" ], StoryJsonNormalizer.normalize_ai_image_prompts(scene.ai_image_prompt)
    assert_nil scene.video_url
    assert_nil scene.merged_audio_video_url
  end

  test "regenerate audio updates text, clears merge, and requeues audio" do
    scene = scenes(:one)
    scene.update_columns(
      text: "old narration",
      video_url: "https://example.com/scene.mp4",
      merged_audio_video_url: "https://example.com/merged.mp4",
      merged_audio_video_gen_id: "old-merge"
    )
    scene.story.update_columns(video_url: "https://example.com/story.mp4", video_gen_id: "story-gen")

    assert_enqueued_with(job: CreateSceneAudioJob, args: [ scene ]) do
      assert scene.regenerate_audio!(text: "new narration")
    end

    scene.reload
    assert_equal "new narration", scene.text
    assert_equal "https://example.com/scene.mp4", scene.video_url
    assert_nil scene.merged_audio_video_url
    assert_nil scene.merged_audio_video_gen_id
    assert_nil scene.story.reload.video_url
  end

  test "regenerate audio skips blank text" do
    scene = scenes(:one)
    scene.update_columns(text: "")

    assert_no_enqueued_jobs only: CreateSceneAudioJob do
      assert_not scene.regenerate_audio!(text: "   ")
    end
  end
end
