require "test_helper"
require "minitest/mock"

class ScenesControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper

  test "rewrite prompt updates the scene and retries generation" do
    scene = scenes(:one)
    scene.update_column(:ai_image_prompt, [ "a violent bloody fight" ])

    ChatGPTClient.stub(:soften_image_prompts, [ "a tense standoff with no blood" ]) do
      assert_enqueued_with(job: CreateSceneImagesJob) do
        post rewrite_story_scene_url(scene.story, scene), params: {
          instruction: "make this scene less violent, and remove blood"
        }
      end
    end

    scene.reload
    assert_redirected_to story_url(scene.story)
    assert_equal [ "a tense standoff with no blood" ], StoryJsonNormalizer.normalize_ai_image_prompts(scene.ai_image_prompt)
    assert_equal 1, scene.image_prompt_rewrite_count
  end

  test "generate video enqueues stills for slideshow stories" do
    scene = scenes(:one)
    scene.update_columns(video_url: nil, leonardo_video_url: nil, leonardo_video_gen_id: nil, images_data: [])

    assert_enqueued_with(job: CreateSceneImagesJob) do
      post generate_story_scene_video_url(scene.story, scene)
    end

    assert_redirected_to story_url(scene.story)
  end

  test "generate video enqueues wan job for direct video stories" do
    story = stories(:one)
    story.update_column(:video_generation_model, "wan-2.6")
    scene = scenes(:one)
    scene.reload
    scene.update_columns(video_url: nil, leonardo_video_url: nil, leonardo_video_gen_id: nil)

    assert_enqueued_with(job: LeonardoCreateSceneVideoJob) do
      post generate_story_scene_video_url(story, scene)
    end

    assert_redirected_to story_url(story)
  end

  test "generate video skips scenes that already have video" do
    scene = scenes(:one)
    scene.update_columns(video_url: "https://example.com/scene.mp4", leonardo_video_url: nil, leonardo_video_gen_id: nil)

    assert_no_enqueued_jobs only: [ CreateSceneImagesJob, LeonardoCreateSceneVideoJob ] do
      post generate_story_scene_video_url(scene.story, scene)
    end

    assert_redirected_to story_url(scene.story)
  end

  test "generate video skips scenes with an in-flight leonardo generation" do
    story = stories(:one)
    story.update_column(:video_generation_model, "wan-2.6")
    scene = scenes(:one)
    scene.reload
    scene.update_columns(video_url: nil, leonardo_video_url: nil, leonardo_video_gen_id: "gen-in-flight")

    assert_no_enqueued_jobs only: [ CreateSceneImagesJob, LeonardoCreateSceneVideoJob ] do
      post generate_story_scene_video_url(story, scene)
    end

    assert_redirected_to story_url(story)
  end

  test "regenerate video updates the prompt and requeues generation" do
    scene = scenes(:one)
    scene.update_columns(
      ai_image_prompt: [ "old prompt" ],
      video_url: "https://example.com/old.mp4",
      leonardo_video_url: "https://example.com/old-leo.mp4",
      leonardo_video_gen_id: "old-gen",
      merged_audio_video_url: "https://example.com/merged.mp4",
      merged_audio_video_gen_id: "old-merge"
    )
    scene.story.update_columns(video_url: "https://example.com/story.mp4", video_gen_id: "story-gen")

    assert_enqueued_with(job: CreateSceneImagesJob) do
      post regenerate_story_scene_video_url(scene.story, scene), params: {
        prompt: "a calmer street at dusk"
      }
    end

    scene.reload
    assert_redirected_to story_url(scene.story)
    assert_equal [ "a calmer street at dusk" ], StoryJsonNormalizer.normalize_ai_image_prompts(scene.ai_image_prompt)
    assert_nil scene.video_url
    assert_nil scene.leonardo_video_url
    assert_nil scene.leonardo_video_gen_id
    assert_nil scene.merged_audio_video_url
    assert_nil scene.story.reload.video_url
  end

  test "regenerate audio updates narration and requeues audio" do
    scene = scenes(:one)
    scene.update_columns(
      text: "old narration",
      video_url: "https://example.com/scene.mp4",
      merged_audio_video_url: "https://example.com/merged.mp4",
      merged_audio_video_gen_id: "old-merge"
    )
    scene.story.update_columns(video_url: "https://example.com/story.mp4", video_gen_id: "story-gen")

    assert_enqueued_with(job: CreateSceneAudioJob, args: [ scene ]) do
      post regenerate_story_scene_audio_url(scene.story, scene), params: {
        text: "the island was quiet at dusk"
      }
    end

    scene.reload
    assert_redirected_to story_url(scene.story)
    assert_equal "the island was quiet at dusk", scene.text
    assert_equal "https://example.com/scene.mp4", scene.video_url
    assert_nil scene.merged_audio_video_url
    assert_nil scene.merged_audio_video_gen_id
    assert_nil scene.story.reload.video_url
  end
end
