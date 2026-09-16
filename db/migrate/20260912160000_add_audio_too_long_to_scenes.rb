class AddAudioTooLongToScenes < ActiveRecord::Migration[7.2]
  def change
    add_column :scenes, :audio_too_long, :boolean, null: false, default: false
  end
end
