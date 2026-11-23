# Tiny Rest paper-cut diorama videos.
#
#   bin/rails tiny_rest:setup                 # create/refresh both story types and the "3 AM" source
#   bin/rails tiny_rest:start_3am             # start the "3 AM" story (Sidekiq must run)
#   bin/rails "tiny_rest:start_3am[lucid,wan-2.6]"   # override the seed image model / video model
#
# Story types (each carries its fixed cast, so stories started from the dashboard use it too):
#   "Tiny Rest Paper-Cut Nursery"            Mom, Baby, Dad, and the Unicorn / Dragon creatures
#   "Tiny Rest Dragon & Unicorn Babies"      dragon baby / unicorn baby: real babies nicknamed by how they sleep,
#                                            with Mom, Dad and the Dragon / Unicorn Toddler versions
#   "Tiny Rest Dragon & Unicorn Reels"       same series and cast; 100-120 word scripts that open on a hook
#                                            and pay it off with a reveal about two thirds in,
#                                            exact 1080x1920 render with Reels-safe captions (y 1325)
#
# Defaults: Nano Banana 2 draws the character seed; each scene opens on a Nano Banana 2 frame that uses
# the seed (and, when the narration names Tiny Rest, the app's unicorn and sky art) as references;
# Wan 2.6 animates from that frame. Both story types end with the "Tiny Rest" outro video (logo, App Store
# and like & follow calls to action; see video_editor/outro/render_tinyrest_outro.py), so no scene is an end card.
#
# setup is idempotent; start_3am creates a new Story each run.
module TinyRest
  VOICE_ID = "jqcCZkN6Knx8BJ5TBdYR".freeze # ElevenLabs narrator for Tiny Rest videos

  VISUAL_STYLE = <<~STYLE.squish.freeze
    Handcrafted layered paper-cut diorama, 3D papercraft storybook illustration, visible paper texture with fine
    ridged grooves and swirl patterns, soft depth of field, pastel palette of lavender, dusty pink, lilac and soft
    cream against a midnight navy night sky with tiny paper stars and a paper crescent moon, swirled paper clouds,
    warm golden lamp glow, cozy calm nursery mood, vertical 9:16 composition
  STYLE

  MOM = { "name" => "Mom", "physical_description" => "a young paper-craft mom with long dark wavy hair in a messy bun, oversized lavender sweater, soft gray joggers, warm gentle smile, slightly tired eyes" }.freeze
  DAD = { "name" => "Dad", "physical_description" => "a paper-craft dad with short dark hair and a short beard, wearing a navy t-shirt" }.freeze

  # Names are what the narration and prompts use, so the pipeline can match them. The seed image draws
  # the first character plus the two most mentioned, so the lead goes first.
  NURSERY_CAST = [
    MOM,
    { "name" => "Baby", "physical_description" => "a chubby paper-craft baby with a little tuft of brown hair and rosy cheeks, wearing a pale yellow footed sleeper or a pale yellow sleep sack" },
    { "name" => "Unicorn", "physical_description" => "a tiny white paper unicorn with a lavender and pink swirled mane, a small golden horn and sleepy closed eyes, floating softly and leaving a trail of tiny paper stars" },
    DAD,
    { "name" => "Dragon", "physical_description" => "a tiny round cute paper dragon, soft purple with a pink belly, small wings, big curious eyes, puffing little swirled paper clouds" }
  ].freeze

  DRAGON_UNICORN_CAST = [
    { "name" => "Dragon Baby", "physical_description" => "a chubby paper-craft human baby with rosy cheeks, big curious eyes and a tuft of dark brown hair, with two tiny soft purple dragon wings on its back, two little rounded nub horns on its head and small pointed dragon ears, wearing a soft lilac footed sleeper; sweet, round and baby-like, never scary" },
    { "name" => "Unicorn Baby", "physical_description" => "a chubby paper-craft human baby with rosy cheeks and sleepy eyes, with a soft swirl of pastel pink and lavender hair like a tiny mane, one small golden unicorn horn on the forehead and little soft pony ears, wearing a pale yellow footed sleeper; sweet, round and baby-like" },
    MOM,
    DAD
  ].freeze

  DRAGON_UNICORN_CONCEPT = <<~CONCEPT.freeze
    About this series: "dragon baby" and "unicorn baby" are nicknames for real human babies, given by how they sleep.
    A unicorn baby falls asleep easily, anywhere. A dragon baby is a light, sensitive sleeper who notices every
    light, sound and change and wakes easily; dragons are not bad sleepers, they are sensitive. They are ordinary
    human babies, not creatures: on screen each one just has a few small, cute features (Dragon Baby: tiny wings,
    little nub horns, pointed ears; Unicorn Baby: a tiny golden horn, a pastel mane-like tuft, pony ears).
    When a line talks about dragon babies or "your dragon", show Dragon Baby; for unicorn babies, show Unicorn Baby;
    when it talks about babies in general, show both. Never show a real dragon or unicorn animal.
  CONCEPT

  # The same two babies about a year or two older, so a story can show a child growing out of the baby stage.
  # Each keeps its baby's hair, features and sleeper colour so viewers read them as the same child.
  DRAGON_UNICORN_FAMILY_CAST = [
    *DRAGON_UNICORN_CAST,
    { "name" => "Dragon Toddler", "physical_description" => "the same child as Dragon Baby at about two years old: a small paper-craft human toddler standing or walking on chubby legs, rosy cheeks, big curious eyes, slightly longer tousled dark brown hair, the same two tiny soft purple dragon wings, little rounded nub horns and small pointed dragon ears, wearing a soft lilac two-piece pajama set; sweet and playful, never scary" },
    { "name" => "Unicorn Toddler", "physical_description" => "the same child as Unicorn Baby at about two years old: a small paper-craft human toddler standing or walking on chubby legs, rosy cheeks and sleepy eyes, a longer soft swirl of pastel pink and lavender hair like a little mane, the same small golden unicorn horn and soft pony ears, wearing a pale yellow two-piece pajama set; sweet and calm" }
  ].freeze

  DRAGON_UNICORN_FAMILY_CONCEPT = <<~CONCEPT.freeze
    #{DRAGON_UNICORN_CONCEPT.strip}
    Dragon Toddler and Unicorn Toddler are the same two children about two years old, with the same small features.
    Show them only when a line talks about toddlers, older babies or a child growing up; otherwise show the babies.
    A toddler sleeps in a toddler bed or crib, never in a bassinet. Mom and Dad are both parents in this family.
  CONCEPT

  # Reels / Shorts targets from the last review: 40-48 seconds including the ~7 s outro, which at this
  # narrator's pace (about 2.6 words a second, plus a short pause per scene) is 100-120 spoken words.
  REELS_WORD_BUDGET = (100..120)

  # Final render for Instagram Reels: exactly 1080x1920, no bars, captions centred at y 1325 (inside the
  # 1250-1400 band) and kept out of the top 220 px, bottom 420 px and right 140 px that the app covers.
  REELS_RENDER_SETTINGS = {
    "fill_output" => true,
    "caption_center_y" => 1325,
    "caption_margin_right" => 140
  }.freeze

  def self.word_budget_rule(budget)
    <<~RULE
      Length: the spoken voiceover of the whole video must total #{budget.min}-#{budget.max} words (about 40-48
      seconds with the outro). Count every voiceover line. If the storyboard is longer, shorten lines by cutting
      filler and repeated ideas, keeping each row's meaning, the hook and the last line; drop a row only if
      trimming is not enough. If it is shorter, keep it as written. This length rule overrides "word for word" and the
      rule below against removing voiceover lines.
    RULE
  end

  # Reels lose most viewers in the first two seconds, so every story opens on a hook built from the source
  # and pays it off with one clear reveal late in the video.
  HOOK_REVEAL_RULE = <<~RULE.freeze
    Hook and reveal (this video must keep viewers watching to the end):
    - Before the first storyboard row, add one new voiceover line: the hook. Write it from the storyboard's own
      story, at most 12 words, spoken in under 3 seconds. It opens a question the viewer needs answered: a
      surprising claim, a relatable struggle with a twist, or a promise of a secret ("Your baby isn't a bad
      sleeper. It's something else."). It must never give the answer away, never ask viewers to download, like
      or follow, and never promise something the video does not deliver. If the storyboard already opens with a
      strong hook, sharpen that first line instead of adding another, so the video does not start twice.
    - Hold back the storyboard's key insight (the answer, the turning point or the surprise) until about two
      thirds of the way through, and give it its own voiceover line that lands clearly as the reveal and
      answers the hook directly. You may move that one line later and reword it lightly so it lands; keep
      every other row in order.
    - The hook's scene direction is a striking, intriguing opening shot (a close-up or a dramatic moment of
      the story). The reveal's scene direction shows a visible turn: the light changes, the camera pulls back
      or the characters react.
    - The hook and reveal count toward the word total. For these two lines only, this rule overrides "word for
      word" and the rule below against adding or reordering voiceover lines.
  RULE

  def self.story_prompt(names:, concept: nil, word_budget: nil, hook: false)
    <<~PROMPT


      ---
      The text above is a storyboard for a short vertical Tiny Rest video (a baby sleep app).
      #{concept}
      Turn it into a production script. Output plain text only, no headings, no markdown, no commentary.#{"\n#{word_budget_rule(word_budget).rstrip}" if word_budget}#{"\n#{HOOK_REVEAL_RULE.rstrip}" if hook}

      Titles and headings (the video title, "Scene 1", "Row 2" and similar) are not voiceover: leave them out.

      For every storyboard row or paragraph, in order, write exactly two lines:
      1) The voiceover line, copied word for word from the storyboard (keep its punctuation and ellipses), except
         for calls to action: the Tiny Rest outro already asks viewers to download the app and to like and follow,
         so leave out every sentence that asks viewers to download, install, try or get the app, mentions the
         App Store, or asks them to like, follow, subscribe or share. Keep the rest of that line; if nothing is
         left, skip the row.
      2) A scene direction in square brackets that starts with "[SCENE:" and describes what happens on screen and
         how the camera moves, following the row's scene prompt when it has one.
      Leave one blank line between rows.

      Rules for scene directions:
      - Refer to characters only by these names: #{names.join(', ')}. Include only the ones in that row.
      - If a row is a real screen recording, write a paper-cut stand-in instead: Mom's hand holding the glowing phone
        with the screen facing away from the camera, soft light spilling onto her face.
      - Every video ends with a separate Tiny Rest outro (logo and calls to action), so never write an end card,
        logo or call-to-action scene. The last row, even when it names Tiny Rest, gets a calm closing scene of
        the story's characters resting peacefully at night.
      - Keep the storyboard's staging: if Mom is holding a baby, she stays holding the baby.
      - Only when a baby is set down to sleep, it lies on its back in a bare crib or bassinet with only a fitted sheet,
        with nothing else inside the crib.
      - Never ask for text, letters, logos or a readable phone screen.

      Apart from the calls to action above, do not add, remove, merge or reorder voiceover lines. Do not write anything else.
    PROMPT
  end

  def self.scenes_prompt(names:, concept: nil)
    <<~PROMPT
      I have a short production script for a vertical Tiny Rest video. Each spoken voiceover line is followed by a
      scene direction in square brackets that starts with [SCENE:. I need AI image and video generation prompts as JSON.
      #{concept}
      Return ONLY valid JSON (no markdown fences, no commentary). The root object has a single key "pairs", an array
      with one object per voiceover line, in script order. Each object has:
      - "original": the voiceover line exactly as written. Never include the bracketed scene direction here.
        When lines are combined to reach the length rules below, join them in order with a space and use the first
        line's scene direction.
      - "aiImagePrompts": an array of exactly one string, built from the scene direction that follows that line.

      Each prompt string must:
      1) Start with: "Handcrafted layered paper-cut diorama, 3D papercraft storybook illustration, visible paper texture with fine ridged grooves and swirl patterns, soft depth of field, pastel lavender, dusty pink, lilac and soft cream against a midnight navy night sky with tiny paper stars and a paper crescent moon, warm golden lamp glow, cozy calm nursery mood, vertical 9:16, gentle slow parallax camera movement:"
      2) Describe the action, setting, camera movement and mood from the scene direction. Refer to characters by name
         (#{names.join(', ')}); their looks are added separately.
      3) Keep the staging of the scene direction (a baby held in arms stays in arms). Only a baby lying down to sleep
         is described as lying flat on its back, face up toward the ceiling, fully inside a bare crib or bassinet
         with only a fitted sheet.
      4) Show any phone with its screen turned away from the camera, as a soft glow.
      5) End with: "Smooth slow motion, soft shadows, no text, no letters, no logos." (The logo and calls to action
         come from a separate outro, so no scene shows them.)
      6) Stay under 1500 characters.

      The script is:
    PROMPT
  end

  NURSERY_NAMES = %w[Mom Baby Dad Unicorn Dragon].freeze
  DRAGON_UNICORN_NAMES = [ "Dragon Baby", "Unicorn Baby", "Mom", "Dad" ].freeze
  DRAGON_UNICORN_FAMILY_NAMES = DRAGON_UNICORN_FAMILY_CAST.map { |c| c["name"] }.freeze

  STORY_TYPES = {
    nursery: {
      name: "Tiny Rest Paper-Cut Nursery",
      cast: NURSERY_CAST,
      story_prompt_text: story_prompt(names: NURSERY_NAMES),
      scenes_json_prompts: scenes_prompt(names: NURSERY_NAMES)
    },
    dragon_unicorn: {
      name: "Tiny Rest Dragon & Unicorn Babies",
      cast: DRAGON_UNICORN_FAMILY_CAST,
      story_prompt_text: story_prompt(names: DRAGON_UNICORN_FAMILY_NAMES, concept: DRAGON_UNICORN_FAMILY_CONCEPT),
      scenes_json_prompts: scenes_prompt(names: DRAGON_UNICORN_FAMILY_NAMES, concept: DRAGON_UNICORN_FAMILY_CONCEPT)
    },
    # Same series with the toddlers added, sized and captioned for Reels / Shorts.
    dragon_unicorn_reels: {
      name: "Tiny Rest Dragon & Unicorn Reels",
      cast: DRAGON_UNICORN_FAMILY_CAST,
      story_prompt_text: story_prompt(names: DRAGON_UNICORN_FAMILY_NAMES, concept: DRAGON_UNICORN_FAMILY_CONCEPT,
                                      word_budget: REELS_WORD_BUDGET, hook: true),
      scenes_json_prompts: scenes_prompt(names: DRAGON_UNICORN_FAMILY_NAMES, concept: DRAGON_UNICORN_FAMILY_CONCEPT),
      render_settings: REELS_RENDER_SETTINGS
    }
  }.freeze

  SOURCE_MARKER = "TINY REST VIDEO 1: 3 AM".freeze
  SOURCE_TEXT = <<~SOURCE.freeze
    #{SOURCE_MARKER}
    Story: a tired mom at 3 AM can't keep track of naps and feeds. A tiny paper unicorn floats out of her phone, and the guessing stops. Launch video, about 25 seconds.

    Row 1 (0-4s)
    Voiceover: "It's 3 AM. Baby's finally asleep… but when is the next nap?"
    Scene: Mom sitting in a paper rocking chair in a dark nursery holding sleeping Baby, a paper wall clock, soft glow from a phone on the armrest, a window with paper stars, slow push-in on her tired face.

    Row 2 (4-9s)
    Voiceover: "Wake windows, feeds, naps… it's a lot to keep in your head."
    Scene: a swirl of paper clocks, tiny paper bottles, moons and question-mark shapes circling above Mom's head like a paper mobile, she sighs, the camera slowly rotates.

    Row 3 (9-15s)
    Voiceover: "Tiny Rest keeps track for you, and tells you when baby will be ready to rest again."
    Scene: Mom looks at the glowing phone (screen faces away from camera), Unicorn floats up out of the light, the paper clocks above her calm down and line up neatly, she smiles.

    Row 4 (15-20s)
    Voiceover: "Less guessing. More rest. For both of you."
    Scene: Mom gently lays Baby on its back in a bassinet with a fitted sheet only, Unicorn sprinkles paper stars over the room, Mom climbs into bed, the lamp dims, the camera pulls back to the paper house under a starry sky.
  SOURCE

  def self.story_type!(key = :nursery)
    config = STORY_TYPES.fetch(key)
    type = StoryType.find_or_initialize_by(name: config[:name])
    type.assign_attributes(
      story_prompt_text: config[:story_prompt_text],
      scenes_json_prompts: config[:scenes_json_prompts],
      cast: config[:cast],
      render_settings: config.fetch(:render_settings, {}),
      visual_style: VISUAL_STYLE,
      image_width: 576,
      image_height: 1024,
      output_width: 1080,
      output_height: 1920,
      # The narrator speaks about 16 characters a second: 70-120 characters keeps every scene at 4-7 seconds.
      # Shorter lines are combined with their neighbours by the scene step.
      scene_text_min_chars: 70,
      scene_text_max_chars: 120,
      voice_id: VOICE_ID
    )
    type.save!
    type
  end

  UI_IMAGES = Rails.root.join("..", "tiny-rest-ui", "assets", "images").freeze
  # App art used as Nano Banana 2 references whenever the narration names the brand.
  BRAND_REFERENCES = {
    "unicorn" => "icon.png", # the logo unicorn over the app sky
    "sky"     => "bg.jpg"    # the app's night-sky background
  }.freeze
  BRAND_KEYWORDS = [ "Tiny Rest" ].freeze

  # Uploads the app art to Leonardo (only when a file changed) and returns the ids for a story type.
  def self.brand_assets!(type)
    stored = type.brand_assets.to_h
    known  = Array(stored["references"]).index_by { |asset| asset["label"] }

    references = BRAND_REFERENCES.map do |label, file|
      path   = UI_IMAGES.join(file).to_s
      digest = Digest::SHA256.file(path).hexdigest
      if known[label] && known[label]["digest"] == digest
        known[label]
      else
        { "label" => label, "file" => file, "digest" => digest, "id" => LeonardoClient.upload_init_image(path) }
      end
    end

    # No end_card_id: the logo and calls to action come from the "Tiny Rest" outro video instead.
    type.update!(brand_assets: { "keywords" => BRAND_KEYWORDS, "references" => references })
    type.brand_assets
  end

  # Every Tiny Rest story type shares the same uploaded brand art.
  def self.all_story_types!
    nursery = story_type!(:nursery)
    assets  = brand_assets!(nursery)
    others  = (STORY_TYPES.keys - [ :nursery ]).map { |key| story_type!(key).tap { |t| t.update!(brand_assets: assets) } }
    [ nursery, *others ]
  end

  def self.source!
    user = User.first or abort("No user exists yet. Run bin/rails db:seed first.")
    source = Source.where("text LIKE ?", "#{SOURCE_MARKER}%").first || user.sources.new
    source.update!(text: SOURCE_TEXT)
    source
  end
end

namespace :tiny_rest do
  desc "Create or refresh the Tiny Rest story types and the '3 AM' source"
  task setup: :environment do
    TinyRest.all_story_types!.each do |type|
      puts "Story type ##{type.id}: #{type.name} (cast: #{type.cast.map { |c| c['name'] }.join(', ')})"
    end
    source = TinyRest.source!
    puts "Source ##{source.id}: #{TinyRest::SOURCE_MARKER}"
    puts "Start stories from /stories/new (the cast is locked by the story type), or run bin/rails tiny_rest:start_3am."
  end

  desc "Start the '3 AM' story on the Tiny Rest nursery type (args: image_model, video_model)"
  task :start_3am, [ :image_model, :video_model ] => :environment do |_t, args|
    type   = TinyRest.all_story_types!.first
    source = TinyRest.source!

    story = Story.new(
      story_type: type,
      source: source,
      # The image model draws the character seed; Wan 2.6 animates each scene from a frame built on it.
      image_generation_model: args[:image_model].presence || LeonardoClient::NANO_BANANA_2_MODEL,
      video_generation_model: args[:video_model].presence || LeonardoClient::WAN_VIDEO_MODEL,
      # It runs right away below, so it takes the running slot instead of waiting in the story queue.
      queue_state: "running",
      started_at: Time.current
    )
    story.defer_pipeline = true
    story.save!

    # Same steps as CreateStoryTextJob; create_characters uses the story type's fixed cast.
    story.create_text
    story.create_characters
    LeonardoClient.generate_character_seed_image(story)

    puts "Story ##{story.id} started with cast: #{story.characters.map { |c| c['name'] }.join(', ')}"
    puts "Follow it at /stories/#{story.id} (scenes are created by Sidekiq once the character seed is ready)."
  end
end
