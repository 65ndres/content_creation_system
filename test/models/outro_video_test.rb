require "test_helper"

class OutroVideoTest < ActiveSupport::TestCase
  def attach(outro, file, content_type)
    outro.video.attach(io: file_fixture(file).open, filename: file, content_type: content_type)
    outro
  end

  test "valid with a name and a video file" do
    assert attach(OutroVideo.new(name: "Gospel closing"), "outro.mp4", "video/mp4").valid?
  end

  test "requires a name" do
    outro = attach(OutroVideo.new, "outro.mp4", "video/mp4")
    assert_not outro.valid?
    assert_includes outro.errors[:name], "can't be blank"
  end

  test "requires a video" do
    outro = OutroVideo.new(name: "Gospel closing")
    assert_not outro.valid?
    assert_includes outro.errors[:video], "must be attached"
  end

  test "rejects files that are not videos" do
    outro = attach(OutroVideo.new(name: "Notes"), "outro.txt", "text/plain")
    assert_not outro.valid?
    assert_includes outro.errors[:video], "must be a video file"
  end

  test "story types keep working when their outro is deleted" do
    outro = attach(OutroVideo.new(name: "Gospel closing"), "outro.mp4", "video/mp4")
    outro.save!
    story_type = story_types(:one)
    story_type.update!(outro_video: outro)

    outro.destroy!

    assert_nil story_type.reload.outro_video_id
  end
end
