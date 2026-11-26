require "test_helper"
require "minitest/mock"

class VideoEditorClientTest < ActiveSupport::TestCase
  test "story video payload sends the story type's outro video" do
    outro = OutroVideo.new(name: "Gospel closing")
    outro.video.attach(io: file_fixture("outro.mp4").open, filename: "outro.mp4", content_type: "video/mp4")
    outro.save!
    story = stories(:one)
    story.story_type.update!(outro_video: outro)

    seen = nil
    fake_url = lambda do |attachment|
      seen = attachment
      "https://files.example/outro.mp4"
    end
    payload = VideoEditorClient.stub(:attached_download_url, fake_url) do
      VideoEditorClient.create_story_video_payload(story)
    end

    assert_equal story.id, payload["story_id"]
    assert_equal "https://files.example/outro.mp4", payload["outro_video_url"]
    assert_equal outro.video.blob, seen.blob
  end

  test "story video payload leaves out the outro when the story type has none" do
    story = stories(:one)
    story.story_type.update!(outro_video: nil)

    payload = VideoEditorClient.create_story_video_payload(story)

    assert_equal({ "story_id" => story.id }, payload)
  end

  test "story type render settings ride along on the merge and story payloads" do
    story = stories(:one)
    story.story_type.update!(output_width: 1080, output_height: 1920, outro_video: nil,
                             render_settings: { "fill_output" => true, "caption_center_y" => 1325, "caption_margin_right" => 140 })
    expected = { "fill_output" => true, "caption_center_y" => 1325, "caption_margin_right" => 140,
                 "output_width" => 1080, "output_height" => 1920 }

    scene = Scene.create!(story: story, text: "Some babies drift off anywhere.")
    merge = VideoEditorClient.send(:merge_audio_video_payload, scene, audio_path: "/tmp/a.mp3")

    assert_equal expected, merge.slice(*expected.keys)
    assert_equal expected.merge("story_id" => story.id), VideoEditorClient.create_story_video_payload(story)
  end

  test "story types without render settings send none" do
    story = stories(:one)
    story.story_type.update!(render_settings: {})
    scene = Scene.create!(story: story, text: "Some babies drift off anywhere.")

    merge = VideoEditorClient.send(:merge_audio_video_payload, scene, audio_path: "/tmp/a.mp3")

    assert_not merge.key?("fill_output")
    assert_not merge.key?("output_width")
  end
end
