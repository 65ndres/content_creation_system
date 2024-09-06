class AddMoreColumnsForVideosToScenes < ActiveRecord::Migration[7.2]
  def change
    add_column :scenes, :merged_audio_video_url, :string
    add_column :scenes, :merged_audio_video_gen_id, :string
    rename_column :scenes, :video_id, :video_gen_id
    # add_column :scenes, :mere
  end
end
