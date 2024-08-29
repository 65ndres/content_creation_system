class CreateStories < ActiveRecord::Migration[7.2]
  def change
    create_table :stories do |t|
      t.text :text
      t.references :source, null: false, foreign_key: true
      t.references :story_type, null: false, foreign_key: true
      t.timestamps
    end
  end
end
