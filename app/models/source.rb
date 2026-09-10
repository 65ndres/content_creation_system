class Source < ApplicationRecord
  belongs_to :user

  def dashboard_label
    snippet = text.to_s.gsub(/\s+/, " ").strip.truncate(72)
    "##{id} · #{snippet.presence || "empty"}"
  end
end
