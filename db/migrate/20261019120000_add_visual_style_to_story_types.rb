class AddVisualStyleToStoryTypes < ActiveRecord::Migration[7.2]
  def change
    add_column :story_types, :visual_style, :text
  end
end
