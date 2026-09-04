class AddImageGenerationModelToStories < ActiveRecord::Migration[7.2]
  def change
    add_column :stories, :image_generation_model, :string, null: false, default: "lucid"
  end
end
