class AddRenderSettingsToStoryTypes < ActiveRecord::Migration[7.2]
  def change
    # Opt-in final-render rules sent to the video editor, e.g.
    # { "fill_output" => true, "caption_center_y" => 1325, "caption_margin_right" => 140 }.
    # Empty keeps the legacy render (clip's own size, bottom captions).
    add_column :story_types, :render_settings, :jsonb, default: {}, null: false
  end
end
