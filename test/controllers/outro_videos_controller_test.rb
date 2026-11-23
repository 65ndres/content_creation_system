require "test_helper"

class OutroVideosControllerTest < ActionDispatch::IntegrationTest
  test "index renders the upload form and the empty state" do
    get outro_videos_url

    assert_response :success
    assert_select "input[type=file][name='outro_video[video]']"
    assert_select ".empty", text: /No outro videos yet/
  end

  test "create uploads an outro video" do
    assert_difference("OutroVideo.count", 1) do
      post outro_videos_url, params: {
        outro_video: { name: "Gospel closing (EN)", video: fixture_file_upload("outro.mp4", "video/mp4") }
      }
    end

    assert_redirected_to outro_videos_url
    outro = OutroVideo.order(:id).last
    assert_equal "Gospel closing (EN)", outro.name
    assert outro.video.attached?

    follow_redirect!
    assert_select ".outro-card strong", text: "Gospel closing (EN)"
  end

  test "create shows errors and saves nothing without a file" do
    assert_no_difference("OutroVideo.count") do
      post outro_videos_url, params: { outro_video: { name: "No file" } }
    end

    assert_response :unprocessable_entity
    assert_select ".is-error", text: /Video must be attached/
  end
end
