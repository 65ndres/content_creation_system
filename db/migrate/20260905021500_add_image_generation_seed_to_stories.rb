class AddImageGenerationSeedToStories < ActiveRecord::Migration[7.2]
  def change
    add_column :stories, :image_generation_seed, :string
  end
end
