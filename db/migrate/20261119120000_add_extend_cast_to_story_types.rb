class AddExtendCastToStoryTypes < ActiveRecord::Migration[7.2]
  def change
    # When true, the fixed cast keeps its exact descriptions and ChatGPT still adds
    # each story's other characters (a Bible passage brings new people every time).
    add_column :story_types, :extend_cast, :boolean, default: false, null: false
  end
end
