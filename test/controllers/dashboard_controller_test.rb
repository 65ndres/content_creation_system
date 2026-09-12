require "test_helper"

class DashboardControllerTest < ActionDispatch::IntegrationTest
  include ActiveJob::TestHelper
  test "stories index" do
    get stories_url
    assert_response :success
    assert_select "h1", "Stories"
  end

  test "new story screen has type source and model selects" do
    get new_story_url
    assert_response :success
    assert_select "select#story_story_type_id"
    assert_select "select#story_source_id"
    assert_select "select#story_image_generation_model"
    assert_select "select#story_video_generation_model"
    assert_select "textarea#source-prompt", count: 0
  end

  test "new source screen has an empty prompt box" do
    get new_source_url
    assert_response :success
    assert_select "textarea#source-prompt"
    assert_select "[data-generate]"
  end

  test "new story type screen has an empty prompt box" do
    get new_story_type_url
    assert_response :success
    assert_select "textarea#story-type-prompt"
    assert_select "[data-generate]"
  end

  test "create story enqueues generation" do
    assert_enqueued_with(job: CreateStoryTextJob) do
      post create_story_url, params: {
        story: {
          story_type_id: story_types(:one).id,
          source_id: sources(:one).id,
          image_generation_model: "lucid",
          video_generation_model: "wan-2.6"
        }
      }
    end

    story = Story.order(:id).last
    assert_redirected_to story_url(story)
    assert_equal "lucid", story.image_generation_model
    assert_equal "wan-2.6", story.video_generation_model
    assert_equal story_types(:one).id, story.story_type_id
    assert_equal sources(:one).id, story.source_id
  end

  test "story show lists the character seed image" do
    stories(:one).update_columns(character_seed_image_url: "https://cdn.leonardo.ai/seed.jpg")

    get story_url(stories(:one))
    assert_response :success
    assert_select "figcaption", text: "Seed image"
    assert_select "img.seed-image[src=?]", "https://cdn.leonardo.ai/seed.jpg"
  end

  test "story show lists scene media" do
    get story_url(stories(:one))
    assert_response :success
    assert_select "h1", /Story ##{stories(:one).id}/
    assert_select ".pill", text: /0 \/ 1 scenes complete/
    assert_select "details[open]"
    assert_select "summary", /Waiting/
    assert_select "form[action=?]", generate_story_videos_path(stories(:one))
    assert_select "form[action=?]", generate_story_scene_video_path(stories(:one), scenes(:one))
    assert_select "form[action=?] button[disabled]", create_story_video_path(stories(:one))
    assert_select "figcaption", text: "Video"
    assert_select "figcaption", text: "Audio"
    assert_select "figcaption", text: "Merged audio + video"
    assert_select "input[name=instruction]"
  end

  test "story show lists narration regenerate form" do
    get story_url(stories(:one))
    assert_response :success
    assert_select "form[action=?]", regenerate_story_scene_audio_path(stories(:one), scenes(:one))
    assert_select "textarea[name=text]", text: scenes(:one).text
    assert_select "button", text: "Regenerate audio"
  end

  test "story show collapses merged scenes" do
    scenes(:one).update_columns(merged_audio_video_url: "https://example.com/merged.mp4")

    get story_url(stories(:one))
    assert_response :success
    assert_select ".pill", text: /1 \/ 1 scenes complete/
    assert_select "details:not([open])"
    assert_select "summary", /Complete/
    assert_select "form[action=?]", regenerate_story_scene_video_path(stories(:one), scenes(:one))
    assert_select "textarea[name=prompt]"
    assert_select "form[action=?] button:not([disabled])", create_story_video_path(stories(:one))
  end

  test "create video enqueues concat when every scene is merged" do
    scenes(:one).update_columns(merged_audio_video_url: "https://example.com/merged.mp4")

    assert_enqueued_with(job: CreateStoryVideoJob, args: [ stories(:one) ]) do
      post create_story_video_url(stories(:one))
    end

    assert_redirected_to story_url(stories(:one))
  end

  test "create video skips when scenes are incomplete" do
    scenes(:one).update_columns(merged_audio_video_url: nil)

    assert_no_enqueued_jobs only: CreateStoryVideoJob do
      post create_story_video_url(stories(:one))
    end

    assert_redirected_to story_url(stories(:one))
  end

  test "generate videos enqueues remaining scenes and skips those with video" do
    story = stories(:one)
    story.update_column(:video_generation_model, "wan-2.6")
    pending_scene = scenes(:one)
    pending_scene.update_columns(
      video_url: nil,
      leonardo_video_url: nil,
      leonardo_video_gen_id: nil
    )
    done_scene = scenes(:two)
    done_scene.update_columns(
      story_id: story.id,
      video_url: "https://example.com/done.mp4",
      leonardo_video_url: nil,
      leonardo_video_gen_id: nil
    )

    assert_enqueued_jobs 1, only: LeonardoCreateSceneVideoJob do
      assert_enqueued_with(job: LeonardoCreateSceneVideoJob, args: [ pending_scene ]) do
        post generate_story_videos_url(story)
      end
    end

    assert_redirected_to story_url(story)
  end

  test "generate videos staggers remaining wan jobs" do
    story = stories(:one)
    story.update_column(:video_generation_model, "wan-2.6")
    first = scenes(:one)
    second = scenes(:two)
    [ first, second ].each do |scene|
      scene.update_columns(
        story_id: story.id,
        video_url: nil,
        leonardo_video_url: nil,
        leonardo_video_gen_id: nil
      )
    end

    freeze_time do
      post generate_story_videos_url(story)

      jobs = enqueued_jobs.select { |job| job[:job] == LeonardoCreateSceneVideoJob }
      assert_equal 2, jobs.size
      scheduled = jobs.filter_map { |job| job[:at] }
      assert_equal 1, scheduled.size
      assert_in_delta 30.seconds.from_now.to_f, scheduled.first, 1
    end
  end
end
