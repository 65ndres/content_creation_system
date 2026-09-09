class AddVideoGenerationModelToStories < ActiveRecord::Migration[7.2]
  def change
    add_column :stories, :video_generation_model, :string
  end
end
