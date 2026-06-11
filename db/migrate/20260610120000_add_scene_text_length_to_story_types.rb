class AddSceneTextLengthToStoryTypes < ActiveRecord::Migration[7.2]
  def change
    add_column :story_types, :scene_text_min_chars, :integer, null: false, default: 100
    add_column :story_types, :scene_text_max_chars, :integer, null: false, default: 140
  end
end
