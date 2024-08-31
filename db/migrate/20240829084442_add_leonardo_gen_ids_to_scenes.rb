class AddLeonardoGenIdsToScenes < ActiveRecord::Migration[7.2]
  def change
    add_column :scenes, :leonardo_gen_ids, :jsonb, default: []
  end
end
