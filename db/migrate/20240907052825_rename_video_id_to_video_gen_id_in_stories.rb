class RenameVideoIdToVideoGenIdInStories < ActiveRecord::Migration[7.2]
  def change
    rename_column :stories, :video_id, :video_gen_id
  end
end
