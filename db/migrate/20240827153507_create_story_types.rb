class CreateStoryTypes < ActiveRecord::Migration[7.2]
  def change
    create_table :story_types do |t|
      t.string :name, null: false
      t.text :story_prompt_text, null: false
      t.text :scenes_json_prompts, null: false
      t.integer :output_width, null: false
      t.integer :output_hight, null: false
      t.integer :image_width, null: false
      t.integer :image_hight, null: false

      t.timestamps
    end
  end
end
