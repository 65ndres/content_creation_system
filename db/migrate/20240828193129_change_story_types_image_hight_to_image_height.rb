class ChangeStoryTypesImageHightToImageHeight < ActiveRecord::Migration[7.2]
  def change
    rename_column :story_types, :image_hight, :image_height
    rename_column :story_types, :output_hight, :output_height
  end
end
