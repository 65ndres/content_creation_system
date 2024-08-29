class CreateScenes < ActiveRecord::Migration[7.2]
  def change
    create_table :scenes do |t|
      t.text :scene
      t.text :ai_image_prompt

      t.timestamps
    end
  end
end
