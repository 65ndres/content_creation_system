class AddImagesDataAndImagesTotalToScenes < ActiveRecord::Migration[7.2]
  def change
    add_column :scenes, :images_data, :jsonb, default: []
    add_column :scenes, :images_total, :integer, default: 0
  end
end
