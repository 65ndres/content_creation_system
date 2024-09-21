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

story_type.scenes_json_prompts = "I have a story for which I need to generate AI image generation prompts. Each prompt should be designed as a vivid, dynamic comic book illustration. The prompts must include an overall description, character actions, character appearances, and the setting/background, tailored to each sentence in the story.
Please format the results as a JSON object containing an array called 'pairs'. Each object within the array should have two keys: 'original', with the original sentence from the story, and 'aiImagePrompts', which contains an array of three strings. Each string should be a detailed prompt for generating an image in a comic book style, focusing on the narrative content of the sentence it corresponds to.
Guidelines for the prompts:
1. **Comic Book Style Declaration**: Start each prompt with 'Create a vivid, dynamic comic book illustration of...'
2. **Character and Action Description**: Clearly describe the characters and their actions as depicted in the scene.
3. **Setting/Background**: Include details of the environment or background where the action takes place.
4. **Mood and Theme**: Reflect the mood and thematic elements of the sentence in the illustration details.
5. **Visual Elements**: Incorporate specific visual elements that should be highlighted, such as technology, specific emotions, or unique environmental features.
The aim is to receive creative, engaging prompts that will inspire detailed and lively illustrations, encapsulating the essence of the story through the lens of comic book art.
Here's the story I want to use:"

story_type.image_height  = 576
story_type.image_width   = 1024
story_type.output_height = 1080
story_type.output_width  = 1920
story_type.save



# Second story

"Recent archaeological discoveries in Nevada have reignited interest in a long-held legend of red-haired giants who once roamed the Americas, according to The Independent.
The story began in 1911, when miners digging for fertiliser in Lovelock Cave unearthed unusual artifacts. This led to official excavations in 1912 and 1924, uncovering thousands of artefacts and the remains of individuals nicknamed the 'Lovelock Giants'. These mummies measured an astonishing 8 to 10 feet tall, according to the news outlet.

Archaeologists also found a 15-inch-long sandal showing signs of wear, and a boulder with a seemingly giant handprint etched onto it. A 1931 local newspaper article reported the discovery of two more giant skeletons, around 8.5 and 10 feet tall, in a nearby dry lake bed. These remains were even described as being mummified in a similar way to those of the Ancient Egyptians.

Intriguingly, the Paiute tribe inhabiting the region for millennia possesses a legend of cannibalistic red-haired giants called the Si-Te-Cah. These giants, according to the legend, arrived by sea and dominated the area due to their superior size and strength.
further supporting the legend, a 16th-century Spanish conquistador documented an ancient Peruvian tale about giants who crossed the ocean on large reed rafts. He described them as being so tall that their legs from the knee down were as long as an average man's entire body.

Elongated skulls, possibly 3,000 years old and much larger than normal human skulls, have also been found high in the Andes mountains. Some of these skulls are reported to have had red hair, although some scientists attribute this coloration to the burial environment
The story doesn't end there. The Paiute legend continues with the tribes uniting to defeat the Si-Te-Cah after years of war. The last remaining giants were supposedly chased into Lovelock Cave, where they were trapped and ultimately burned alive by a fire set at the entrance. Interestingly, archaeologists did find evidence of significant burning near the cave's entrance during the initial excavations.
While the existence of 10-foot giants remains unconfirmed, these discoveries and their connection to local legends offer a fascinating glimpse into the past and the power of storytelling across generations."