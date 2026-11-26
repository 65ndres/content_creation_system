# Records the application needs in every environment. Idempotent: safe to run with bin/rails db:seed at any time.

# Story types copied exactly from the local database (see db/seeds/story_types.yml). Each one is created or
# updated by name, so this block is safe to re-run. The outro video is linked by name when it exists; outro
# files live in Active Storage and are not seeded, so upload them first (/outro_videos) and seed again.
YAML.load_file(Rails.root.join("db/seeds/story_types.yml")).each do |attrs|
  outro_name = attrs.delete("outro_video")
  type = StoryType.find_or_initialize_by(name: attrs["name"])
  type.assign_attributes(attrs)
  type.outro_video = OutroVideo.find_by(name: outro_name) if outro_name
  type.save!
  puts "Seeded story type: #{type.name}#{" (outro '#{outro_name}' not found)" if outro_name && type.outro_video.nil?}"
end
