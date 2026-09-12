class AddCharacterSeedImageUrlToStories < ActiveRecord::Migration[7.2]
  def change
    add_column :stories, :character_seed_image_url, :string
  end
end
