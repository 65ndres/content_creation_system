# A clip appended to the end of a story type's videos (e.g. "The Gospel of the Lord" + app CTA).
# The file itself lives in Active Storage.
class OutroVideo < ApplicationRecord
  MAX_FILE_SIZE = 200.megabytes

  has_one_attached :video
  has_many :story_types, dependent: :nullify

  validates :name, presence: true
  validate :video_must_be_a_video_file

  private

  def video_must_be_a_video_file
    unless video.attached?
      errors.add(:video, "must be attached")
      return
    end

    errors.add(:video, "must be a video file") unless video.blob.content_type.to_s.start_with?("video/")
    errors.add(:video, "must be smaller than #{MAX_FILE_SIZE / 1.megabyte} MB") if video.blob.byte_size > MAX_FILE_SIZE
  end
end
