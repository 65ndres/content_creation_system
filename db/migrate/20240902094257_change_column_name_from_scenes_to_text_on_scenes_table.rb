class ChangeColumnNameFromScenesToTextOnScenesTable < ActiveRecord::Migration[7.2]
  def change
    rename_column :scenes, :scene, :text
  end
end
