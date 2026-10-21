class StoryType < ApplicationRecord
  DEFAULT_VOICE_ID = "HIGUfNOdjuWQwwapnTRW"

  before_validation :assign_default_voice_id
  before_save :reset_visual_style, if: :reset_visual_style?

  validates :voice_id, presence: true
  after_save { @visual_style_assigned = false }

  def visual_style=(value)
    @visual_style_assigned = true
    super
  end

  # The art style every image of this story type must share (character seed
  # included). Extracted once from scenes_json_prompts when it was never set.
  def seed_visual_style
    return visual_style if visual_style.present?

    extracted = ChatGPTClient.extract_visual_style(scenes_json_prompts)
    if extracted.present?
      update_column(:visual_style, extracted) if persisted?
      self[:visual_style] = extracted
    end
    visual_style.presence || name.to_s.strip
  end

  private

  def assign_default_voice_id
    self.voice_id = voice_id.to_s.strip
    self.voice_id = DEFAULT_VOICE_ID if voice_id.blank?
  end

  # A new scenes prompt can describe a new style, so the extracted one is stale.
  # A style passed in the same save is kept, even when it is unchanged.
  def reset_visual_style?
    persisted? && scenes_json_prompts_changed? && !@visual_style_assigned
  end

  def reset_visual_style
    self.visual_style = nil
  end
end
