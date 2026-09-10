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

  test "story show lists scene media" do
    get story_url(stories(:one))
    assert_response :success
    assert_select "h1", /Story ##{stories(:one).id}/
    assert_select "figcaption", text: "Video"
    assert_select "figcaption", text: "Audio"
    assert_select "figcaption", text: "Merged audio + video"
    assert_select "input[name=instruction]"
  end
end
