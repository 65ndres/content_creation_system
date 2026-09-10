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
end
