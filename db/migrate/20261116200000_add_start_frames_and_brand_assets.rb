class AddStartFramesAndBrandAssets < ActiveRecord::Migration[7.2]
  def change
    # Direct-video scenes can open on a Leonardo image (Wan 2.6 start_frame).
    add_column :scenes, :start_frame_gen_id, :string
    add_column :scenes, :start_frame_image_id, :string
    add_column :scenes, :start_frame_image_type, :string

    # Leonardo ids of brand images: { "references" => [{ "id", "label" }], "keywords" => [...], "end_card_id" => id }
    add_column :story_types, :brand_assets, :jsonb, default: {}, null: false
  end
end
