class AddCharactersToStories < ActiveRecord::Migration[7.2]
  def change
    add_column :stories, :characters, :jsonb, default: [], null: false
  end
end
