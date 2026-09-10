# This file should ensure the existence of records required to run the application in every environment (production,
# development, test). The code here should be idempotent so that it can be executed at any point in every environment.
# The data can then be loaded with the bin/rails db:seed command (or created alongside the database with db:setup).
#
# Example:
#
#   ["Action", "Comedy", "Drama", "Horror"].each do |genre_name|
#     MovieGenre.find_or_create_by!(name: genre_name)
#   end

user = User.new
user.name = "TEST user (me)"
user.email = "andres@gmail.com"
user.save


source = Source.new
source.user_id = user.id
source.text = "The FBI and Los Angeles Police Department are investigating one of the largest cash heists in the city's history after as much as $30 million was stolen from a San Fernando Valley money storage facility, a law enforcement source briefed on the investigation told CNN Thursday.
The burglary happened on the night of Easter Sunday at an unnamed facility in Sylmar, a suburban neighborhood in the San Fernando Valley, where cash from businesses across the region is handled and stored, the source said.
The Los Angeles Times first reported the incident.
The FBI Los Angeles office told CNN Thursday they are investigating 'a large theft' in the San Fernando Valley and are working jointly with the LAPD, but would not share any other details citing an ongoing investigation. The LAPD referred all comment to the FBI.
Burglars gained access to the building and entered the vault without setting off the alarms and investigators believe it is a sophisticated group based on their ability to evade detection, the source said. One area of focus for the investigation is whether the group had inside knowledge of the facility, said the source, who added that the heist was discovered on Monday.
The facility was operated by private security firm GardaWorld, the source said. CNN has reached out to the company for comment on the incident.
According to the Los Angeles Times, previously the largest cash heist in the city happened on September 12, 1997, when $18.9 million was stolen from the former site of the Dunbar Armored Inc. facility on Mateo Street. Those suspects were eventually caught"
source.save

story_type = StoryType.new
story_type.name = "Comic News"
story_type.story_prompt_text = "Read the article above.
You're a tech news reporter. Let's create a 200 word factual review of the article.
I will send that narration to an AI voice generator that will be used on top of images.
First create a 10 word headline.
First create a single sentence intro that will attract tech enthusiasts.
Then take a sentence to explain why this article is important.
Then talk about the facts of the article.
Finalize tell the reader to take action in order to take advantage of the news shared in the article."

story_type.scenes_json_prompts = "I have a story for which I need to generate AI image generation prompts. Each prompt should be designed as a vivid, dynamic comic book illustration of the action and setting only. Do not include character physical descriptions, clothing, age, face, hair, or body details. A visual seed is applied later for consistency.
Please format the results as a JSON object containing an array called 'pairs'. Each object within the array should have two keys: 'original', with the original sentence from the story, and 'aiImagePrompts', which contains an array of exactly one string. That string should be a detailed prompt for generating an image in a comic book style, focusing on the narrative content of the sentence it corresponds to.
Guidelines for the prompts:
1. **Comic Book Style Declaration**: Start each prompt with 'Create a vivid, dynamic comic book illustration of...'
2. **Action Description**: Describe what is happening in the scene. You may use character names, but do not describe how they look.
3. **Setting/Background**: Include details of the environment or background where the action takes place.
4. **Mood and Theme**: Reflect the mood and thematic elements of the sentence in the illustration details.
5. **Visual Elements**: Incorporate specific visual elements that should be highlighted, such as technology, specific emotions, or unique environmental features.
6. **Length**: Each prompt must be at most 1500 characters. Leonardo rejects or truncates longer prompts.
The aim is to receive creative, engaging prompts that will inspire detailed and lively illustrations, encapsulating the essence of the story through the lens of comic book art.
Here's the story I want to use:"

story_type.image_height  = 576
story_type.image_width   = 1024
story_type.output_height = 1080
story_type.output_width  = 1920
story_type.scene_text_min_chars = 70
story_type.scene_text_max_chars = 100
story_type.save

# Real-events / documentary-style pipeline: factual narration + photoreal image prompts with locked character descriptions.
real_events_type = StoryType.find_or_initialize_by(name: "Real Events Documentary")
real_events_type.story_prompt_text = <<~PROMPT.squish
  Read the article or source material above.
  You are writing voice-over narration for a short documentary grounded in real events. Stay faithful to the source:
  do not invent dates, names, quotes, or outcomes that are not supported by the text. If something is unclear, say only what is known.
  Track every named person, organization, and location; use the exact same names and roles in every sentence they appear.
  Do not turn real people into caricatures or merge two people into one.
  Structure the script as follows:
  1) A headline of at most 10 words (factual and clear).
  2) One sentence that hooks the listener and states what happened.
  3) One sentence on why this matters (then, now, or for understanding the event).
  4) The body: walk through the facts in logical order (who, what, when, where, how, and documented consequences or status of the case if the source covers it).
  5) A brief, accurate closing line (no exaggerated claims).
  Keep the total length similar to a tight 500-word segment suitable for AI voice-over. For any quotation marks in narration, use single quotes.
PROMPT

real_events_type.scenes_json_prompts = <<~PROMPT
  I have a factual story based on real events. I need AI image generation prompts as JSON for photorealistic documentary-style stills (not illustration or comic art).

  Character consistency (do this before writing any prompts; do not output this as separate text—only the JSON below):
  For every named real person who appears in the story, decide ONE fixed visual description (age range or era, build, hair, skin tone if relevant and respectful, typical clothing for the period and role). Copy that exact same wording into every aiImagePrompts string where that person appears. Do not change hair length, facial hair, or wardrobe between scenes for the same person unless the story explicitly moves to a different time period; then state the time jump in the prompt.

  Output requirements:
  Return ONLY valid JSON (no markdown fences, no commentary before or after). The root object must have a single key "pairs", an array of objects. Each object must have:
  - "original": the exact sentence from the story this row corresponds to.
  - "aiImagePrompts": an array of exactly one strings, each a detailed image prompt.

  Each prompt string must:
  1) Start with: "Photorealistic documentary film still, natural cinematic lighting, 35mm photograph style:"
  2) Describe the scene, action, and setting consistent with the sentence and with known realism (no fantasy elements unless the source is about fiction).
  3) Whenever a named real person appears, paste their full fixed description into this prompt (same wording every time).
  4) For crowds or unnamed figures, describe generic period-appropriate people without assigning them the face or body of a named real individual.
  5) Avoid text overlays, logos, or readable documents unless the sentence demands it; if included, keep wording generic or illegible to reduce hallucinated names.

  The story text to illustrate is:
PROMPT

real_events_type.image_height  = story_type.image_height
real_events_type.image_width   = story_type.image_width
real_events_type.output_height = story_type.output_height
real_events_type.output_width  = story_type.output_width
real_events_type.scene_text_min_chars = 70
real_events_type.scene_text_max_chars = 100
real_events_type.save!

# generate a 500 word story detailing the Operation Northwoods describe what it was, where it was started, who approved it, how it affected its victims and how it ended, for any quotation marks make sure to use single


# Then talk extensively about the facts and storyline of the story



# generate a 2000 word story detailing the CIA mk ultra experiments, describe what it is, where it was started, who approved it, how it affected its victims and how it ended



conspiracy_story_type = StoryType.new
conspiracy_story_type.name = "Government Outreach"
conspiracy_story_type.story_prompt_text = "Read the article above.

You're a mystery story teller.

Let's create a 200 word factual review of the article.

I will send that narration to an AI voice generator that will be used on top of images.

First create a 10 word headline

First create a single sentence intro that will attract conspiracy enthusiasts.

Then take a sentence to explain why this story is important.

Then talk about the facts of the article.

Finalize asking the reader if their view of our government is still the same."


conspiracy_story_type.scenes_json_prompts = "I have a story for which I need to generate AI image generation prompts. Each prompt should be designed as a dark, obscure comic book illustration.The prompts must include an overall description, character actions, character appearances, and the setting/background, tailored to each sentence in the story, the prompts must never be too graphic or generate realistic images.
Format the results as a JSON object containing an array called 'pairs'. Each object within the array should have two keys: 'original', with the original sentence from the story, and 'aiImagePrompts', which contains an array of exactly one string. That string should be a detailed prompt for generating an image in a comic book style, focusing on the narrative content of the sentence it corresponds to.
Guidelines for the prompts:
1. **Comic Book Style Declaration**: Start each prompt with 'Create a dark, obscure comic book illustration of...'
2. **Character and Action Description**: Clearly describe the characters and their actions as depicted in the scene.
3. **Setting/Background**: Include details of the environment or background where the action takes place.
4. **Mood and Theme**: Reflect the mood and thematic elements of the sentence in the illustration details.
5. **Visual Elements**: Incorporate specific visual elements that should be highlighted, such as darkness, specific emotions, or unique environmental features.
The aim is to receive creative, engaging prompts that will inspire detailed and lively illustrations, encapsulating the essence of the story through the lens of comic book art.
Here's the story I want to use:"

conspiracy_story_type.image_height  = 1024
conspiracy_story_type.image_width   = 576
conspiracy_story_type.output_height = 1920
conspiracy_story_type.output_width  = 1080 

conspiracy_story_type.save

dark_fact_story_type = StoryType.new
dark_fact_story_type.name = "Dark Fact"
dark_fact_story_type.story_prompt_text = "Read the story above.
You're a mystery story teller. Let's create a 500 word factual review of the story where you will
explain with detail the timeline of the story, you will explain the what, when and where.
Ensure the explain in detail how the story how it ends."

dark_fact_story_type.scenes_json_prompts = "I have a story for which I need to generate AI image generation prompts. Each prompt should be designed as a dark, obscure comic book illustration. The prompts must include an overall description, character actions, character appearances, and the setting/background, tailored to each sentence in the story.
Format the results as a JSON object containing an array called 'pairs'. Each object within the array should have two keys: 'original', with the original sentence from the story, and 'aiImagePrompts', which contains an array of exactly one string. That string should be a detailed prompt for generating an image in a comic book style, focusing on the narrative content of the sentence it corresponds to.
Guidelines for the prompts:
1. **Comic Book Style Declaration**: Start each prompt with 'Create a dark, obscure comic book illustration of...'
2. **Character and Action Description**: Clearly describe the characters and their actions as depicted in the scene.
3. **Setting/Background**: Include details of the environment or background where the action takes place.
4. **Mood and Theme**: Reflect the mood and thematic elements of the sentence in the illustration details.
5. **Visual Elements**: Incorporate specific visual elements that should be highlighted, such as darkness, specific emotions, or unique environmental features.
The aim is to receive creative, engaging prompts that will inspire detailed and lively illustrations, encapsulating the essence of the story through the lens of comic book art.
Here's the story I want to use:"

dark_fact_story_type.image_height  = 576
dark_fact_story_type.image_width   = 1024
dark_fact_story_type.output_height = 1080
dark_fact_story_type.output_width  = 1920
dark_fact_story_type.scene_text_min_chars = 70
dark_fact_story_type.scene_text_max_chars = 100
dark_fact_story_type.save

source = "Chronological Summary of The Cabin in the Woods

The film begins with a group of college friends—Dana, Curt, Jules, Holden, and Marty—preparing for a weekend trip to a remote cabin. At the same time, two technicians, Sitterson and Hadley, arrive at a mysterious underground facility and begin preparing for an operation. The connection between the two groups is initially unclear.

The friends drive into the countryside and stop at a rundown gas station, where a strange attendant gives them ominous warnings about the road and the cabin. They eventually arrive and settle in. The cabin seems ordinary, although there are several unsettling details.

Meanwhile, the technicians monitor the friends through hidden cameras. It becomes apparent that the cabin has been deliberately designed to manipulate what happens to the group. The facility can control aspects of the environment and is secretly influencing the friends' behavior.

That night, the group discovers strange objects in the cabin, including an old diary. Dana reads from it, unintentionally triggering a supernatural threat. The friends are attacked by a family of zombie-like creatures. During the chaos, the group becomes separated, and one of the friends is killed.

The survivors attempt to escape, but the cabin and surrounding area have been engineered to prevent them from leaving. The technicians watch the events unfold and treat the deaths as part of a carefully planned ritual rather than an unexpected disaster.

As more members of the group are killed, the film reveals that the people in the underground facility are deliberately orchestrating the horror. They use chemicals, environmental controls, and other technology to influence the characters while allowing them to believe they are making their own choices.

The group members also fit stereotypical horror roles: the Virgin, the Athlete, the Scholar, the Fool, and the Whore. The facility's purpose is to ensure that these characters die in an appropriate order. Their deaths are not simply entertainment; they are sacrifices intended to satisfy ancient supernatural beings known as the Ancient Ones.

The operation is part of a worldwide system. Similar facilities exist in other countries, each conducting its own ritual with different types of monsters. The sacrifices must be completed successfully to prevent the Ancient Ones from awakening and destroying humanity.

As the situation deteriorates, Dana and Marty begin to realize that something much larger is happening. Marty, who has been suspicious from the beginning, survives longer than expected because he has avoided being manipulated as easily as the others.

Eventually, the facility releases a huge collection of monsters, revealing that almost every classic horror creature imaginable is being kept underground. The resulting chaos allows Dana and Marty to escape into the facility.

Inside, they discover the truth about the operation and encounter the technicians. They realize that the entire weekend was designed to produce their deaths as part of the ritual.

Dana and Marty eventually reach a control area where they confront the people responsible. They learn that they are the final surviving participants and that their deaths would complete the ritual.

However, they refuse to cooperate. The film makes clear that their survival is not enough: if the required sacrifices are not completed, the Ancient Ones will awaken.

The technicians argue that sacrificing the remaining survivors is necessary to save billions of people. Dana and Marty are forced to consider whether they should allow themselves to die for humanity's survival.

Ultimately, they choose not to participate in the ritual. Their refusal means the ritual fails.

The movie ends with the consequences of that decision. The Ancient Ones begin to awaken beneath the facility, and a gigantic hand emerges from the ground, demonstrating that humanity's failure to complete the ritual has doomed the world.

The story therefore turns the traditional horror-movie formula upside down: what initially appears to be a group of young people accidentally encountering a supernatural threat is actually a carefully controlled ritual designed to make them behave like characters in a conventional horror movie. Their decision to reject that role ultimately causes the apocalypse."