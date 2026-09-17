class StoryType < ApplicationRecord
  DEFAULT_VOICE_ID = "HIGUfNOdjuWQwwapnTRW"

  before_validation :assign_default_voice_id

  validates :voice_id, presence: true

  private

  def assign_default_voice_id
    self.voice_id = voice_id.to_s.strip
    self.voice_id = DEFAULT_VOICE_ID if voice_id.blank?
  end
end
