class AddCastToStoryTypes < ActiveRecord::Migration[7.2]
  def change
    # Fixed characters ([{ "name", "physical_description" }]) used instead of extracting them per story.
    add_column :story_types, :cast, :jsonb, default: [], null: false
  end
end
