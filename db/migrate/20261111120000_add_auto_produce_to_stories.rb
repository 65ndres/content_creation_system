class AddAutoProduceToStories < ActiveRecord::Migration[7.2]
  def change
    add_column :stories, :auto_produce, :boolean, default: true, null: false
  end
end
