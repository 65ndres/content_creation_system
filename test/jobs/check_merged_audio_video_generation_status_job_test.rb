require "test_helper"
require "minitest/mock"

class CheckMergedAudioVideoGenerationStatusJobTest < ActiveJob::TestCase
  test "does not automatically create the story video when all scenes are merged" do
    scene = scenes(:one)
    scene.update_columns(merged_audio_video_url: "https://example.com/merged.mp4")

    VideoEditorClient.stub(:is_merged_audio_video_ready, true) do
      CreateStoryVideoJob.stub(:perform_now, ->(*) { flunk "should not auto-create the story video" }) do
        CreateStoryVideoJob.stub(:perform_later, ->(*) { flunk "should not auto-create the story video" }) do
          CheckMergedAudioVideoGenerationStatusJob.perform_now(scene)
        end
      end
    end
  end
end
