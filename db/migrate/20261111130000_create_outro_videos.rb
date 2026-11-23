class CreateOutroVideos < ActiveRecord::Migration[7.2]
  def change
    create_table :outro_videos do |t|
      t.string :name, null: false
      t.timestamps
    end

    add_reference :story_types, :outro_video, foreign_key: true, null: true
  end
end
