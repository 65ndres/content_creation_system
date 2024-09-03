class AddVideoIdToScenes < ActiveRecord::Migration[7.2]
  def change
    add_column :scenes, :video_id, :string
    add_column :scenes, :video_url, :string
    add_column :stories, :video_id, :string
    add_column :stories, :video_url, :string
  end
end
