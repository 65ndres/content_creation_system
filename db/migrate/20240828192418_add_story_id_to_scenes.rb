class AddStoryIdToScenes < ActiveRecord::Migration[7.2]
  def change
    add_column :scenes, :story_id, :integer
  end
end
