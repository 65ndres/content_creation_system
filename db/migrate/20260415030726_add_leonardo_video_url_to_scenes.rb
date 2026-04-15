class AddLeonardoVideoUrlToScenes < ActiveRecord::Migration[7.2]
  def change
    add_column :scenes, :leonardo_video_url, :string
  end
end
