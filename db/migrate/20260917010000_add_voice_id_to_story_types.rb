class AddVoiceIdToStoryTypes < ActiveRecord::Migration[7.2]
  def change
    add_column :story_types, :voice_id, :string, null: false, default: "HIGUfNOdjuWQwwapnTRW"
  end
end
