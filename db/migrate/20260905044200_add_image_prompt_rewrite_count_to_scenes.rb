class AddImagePromptRewriteCountToScenes < ActiveRecord::Migration[7.2]
  def change
    add_column :scenes, :image_prompt_rewrite_count, :integer, null: false, default: 0
  end
end
