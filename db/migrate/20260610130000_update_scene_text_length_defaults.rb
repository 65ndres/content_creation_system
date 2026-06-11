class UpdateSceneTextLengthDefaults < ActiveRecord::Migration[7.2]
  def up
    change_column_default :story_types, :scene_text_min_chars, from: 100, to: 70
    change_column_default :story_types, :scene_text_max_chars, from: 140, to: 100

    execute <<~SQL.squish
      UPDATE story_types
      SET scene_text_min_chars = 70, scene_text_max_chars = 100
      WHERE scene_text_min_chars = 100 AND scene_text_max_chars = 140
    SQL
  end

  def down
    change_column_default :story_types, :scene_text_min_chars, from: 70, to: 100
    change_column_default :story_types, :scene_text_max_chars, from: 100, to: 140

    execute <<~SQL.squish
      UPDATE story_types
      SET scene_text_min_chars = 100, scene_text_max_chars = 140
      WHERE scene_text_min_chars = 70 AND scene_text_max_chars = 100
    SQL
  end
end
