class CreateSources < ActiveRecord::Migration[7.2]
  def change
    create_table :sources do |t|
      t.text :text
      t.references :user, null: false, foreign_key: true

      t.timestamps
    end
  end
end
