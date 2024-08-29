class ChangeAiImagePromptTypeToJsonb < ActiveRecord::Migration[7.2]
  def change
    change_column(:scenes, :ai_image_prompt, :jsonb, using: "ai_image_prompt::jsonb")
  end
end
