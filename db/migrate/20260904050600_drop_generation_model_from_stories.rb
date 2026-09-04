class DropGenerationModelFromStories < ActiveRecord::Migration[7.2]
  def up
    if !column_exists?(:story_types, :image_width)
      add_column :story_types, :image_width, :integer
      add_column :story_types, :image_height, :integer
      add_column :story_types, :output_width, :integer
      add_column :story_types, :output_height, :integer

      execute(<<~SQL.squish)
        UPDATE story_types
        SET image_width = 1024, image_height = 576,
            output_width = 1920, output_height = 1080
        WHERE image_width IS NULL
      SQL

      change_column_null :story_types, :image_width, false
      change_column_null :story_types, :image_height, false
      change_column_null :story_types, :output_width, false
      change_column_null :story_types, :output_height, false
    end

    if column_exists?(:stories, :generation_model_id)
      remove_reference :stories, :generation_model, foreign_key: true
    end

    drop_table :generation_models if table_exists?(:generation_models)
  end

  def down
    raise ActiveRecord::IrreversibleMigration
  end
end
