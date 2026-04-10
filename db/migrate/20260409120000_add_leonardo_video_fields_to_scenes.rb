class AddLeonardoVideoFieldsToScenes < ActiveRecord::Migration[7.2]
  def change
    add_column :scenes, :leonardo_video_gen_id, :string
    add_column :scenes, :leonardo_scene_video_url, :string
  end
end
