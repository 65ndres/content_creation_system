require "test_helper"
require "minitest/mock"

class CreateSceneAudioJobTest < ActiveJob::TestCase
  test "persists audio and enqueues merge when video is ready" do
    scene = scenes(:one)
    scene.update_columns(video_url: "/tmp/scene.mp4", merged_audio_video_url: nil)

    ElevenlabsClient.stub(:create_audio_file, ->(s) {
      s.audio.attach(io: StringIO.new("ID3"), filename: "n.mp3", content_type: "audio/mpeg")
      "ID3"
    }) do
      VideoEditorClient.stub(:persist_scene_media, { "audio_path" => "/tmp/audio.mp3" }) do
        assert_enqueued_with(job: MergeAudioVideoJob) do
          CreateSceneAudioJob.perform_now(scene)
        end
      end
    end
  end

  test "does not enqueue merge when video is missing" do
    scene = scenes(:one)
    scene.update_columns(video_url: nil, leonardo_video_url: nil)

    ElevenlabsClient.stub(:create_audio_file, ->(s) {
      s.audio.attach(io: StringIO.new("ID3"), filename: "n.mp3", content_type: "audio/mpeg")
      "ID3"
    }) do
      VideoEditorClient.stub(:persist_scene_media, { "audio_path" => "/tmp/audio.mp3" }) do
        assert_no_enqueued_jobs only: MergeAudioVideoJob do
          CreateSceneAudioJob.perform_now(scene)
        end
      end
    end
  end
end
