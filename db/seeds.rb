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


# Then talk extensively about the facts and storyline of the story
# create story types
conspiracy_story_type = StoryType.new
conspiracy_story_type.name = "Dark Fact"
conspiracy_story_type.story_prompt_text = "Read the story above.
You're a mystery story teller. Let's create a 70 word factual review of the story where you will
explain the timeline of the story.
to finalize ask the reader to take action by subscribing to the channel and to leave a comment saying whether they still view our government the same."

conspiracy_story_type.scenes_json_prompts = "I have a story for which I need to generate AI image generation prompts. Each prompt should be designed as a dark, obscure comic book illustration.The prompts must include an overall description, character actions, character appearances, and the setting/background, tailored to each sentence in the story, the prompts must never be too graphic or generate realistic images.
Format the results as a JSON object containing an array called 'pairs'. Each object within the array should have two keys: 'original', with the original sentence from the story, and 'aiImagePrompts', which contains an array of three strings. Each string should be a detailed prompt for generating an image in a comic book style, focusing on the narrative content of the sentence it corresponds to.
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




# generate a 2000 word story detailing the CIA mk ultra experiments, describe what it is, where it was started, who approved it, how it affected its victims and how it ended




"The Shadow of MKUltra: A Dark Chapter in American History
Introduction: The Origins of MKUltra

In the annals of American intelligence history, few programs have sparked as much controversy, speculation, and outrage as MKUltra. Conducted during the height of the Cold War, this covert CIA program sought to explore the limits of human cognition, control, and manipulation. Spanning from the early 1950s to the late 1960s, MKUltra was a secretive experiment in mind control and psychological warfare, approved at the highest levels of the U.S. government. Its ultimate aim was to develop techniques that could be used to extract information, control behavior, and create 'Manchurian candidates'—people programmed to perform tasks under post-hypnotic suggestion.

What unfolded, however, was a series of ethically dubious, often illegal experiments on unwitting subjects, many of whom suffered permanent psychological damage. MKUltra remains one of the most notorious chapters in the history of American intelligence, raising profound questions about the moral boundaries of state power, especially when operating in the shadows.

The Origins of the Program: Paranoia and the Cold War
MKUltra's inception was rooted in the intense paranoia of the early Cold War. The post-World War II world was defined by a deepening rivalry between the United States and the Soviet Union, with each nation seeking every possible advantage in their geopolitical struggle. By the late 1940s, American intelligence agencies, especially the CIA, grew concerned about the possibility that Soviet, Chinese, or North Korean forces had developed methods of mind control, potentially using psychological manipulation to brainwash captured soldiers or spies. These concerns were compounded by the perceived threat of communism, with its ideological fervor and mass conformity.

In 1950, the CIA created Project Bluebird, the precursor to MKUltra, to investigate ways to control human behavior through various means, including hypnosis, interrogation techniques, and drug administration. By 1951, this program had evolved into Project Artichoke, expanding the research to explore whether a person could be forced to perform an act against their will, such as committing an assassination, under the influence of drugs and psychological conditioning.

The Creation of MKUltra

By 1953, the CIA's interest in mind control had reached its zenith, and CIA Director Allen Dulles approved the creation of a new, far more expansive program: MKUltra. Dulles, a key architect of Cold War strategy, believed that mastering mind control was essential to national security, especially if the Soviet Union had already made advances in this area. MKUltra was placed under the direction of Dr. Sidney Gottlieb, a chemist with a background in biology and pharmacology, and became one of the most secretive projects in the agency's history.

Officially sanctioned on April 13, 1953, MKUltra was intended to explore the possibility of altering human behavior through a wide array of psychological, chemical, and biological methods. The CIA hoped to use these techniques not only in interrogations but also to create potential sleeper agents or saboteurs who could be activated without their conscious awareness.

The program had an expansive mandate, with more than 150 subprojects that included experiments with hypnosis, electroshock therapy, sensory deprivation, and, most famously, the use of hallucinogenic drugs like LSD. It would take place at universities, hospitals, prisons, and pharmaceutical companies across the U.S. and Canada—often without the knowledge or consent of the participants.

The Experiments: A Journey into the Depths of Human Consciousness
At the heart of MKUltra was an obsessive focus on LSD, a powerful psychedelic drug that had only recently been discovered. The CIA believed that LSD might be the key to unlocking the mysteries of the human mind. Could it break down a person's resistance to interrogation? Could it induce amnesia, making individuals forget sensitive information? Could it be used to reprogram individuals entirely?

Sidney Gottlieb, sometimes referred to as the 'Black Sorcerer', was the mastermind behind many of MKUltra's most insidious experiments. Under his direction, agents conducted experiments on both willing and unwitting subjects, administering LSD in increasingly reckless dosages and combinations.

The Unwitting Victims

One of the most infamous aspects of MKUltra was the CIA's use of unwitting individuals as test subjects. Prostitutes were hired to lure men into 'safe houses' where the unsuspecting victims were surreptitiously dosed with LSD as CIA agents observed them from behind one-way mirrors. These 'safe house' operations, codenamed Operation Midnight Climax, were particularly shocking due to their combination of psychological and physical manipulation.

Prisoners, mental patients, and drug addicts were also among the most vulnerable populations subjected to MKUltra's experiments. In one experiment at a federal prison in Kentucky, the CIA gave seven prisoners a steady diet of LSD for 77 days to see how long-term exposure to the drug would affect their mental state.

Perhaps most chilling was the case of Frank Olson, a biochemist and Army officer who worked for the CIA. Without his knowledge, Olson was dosed with LSD during a retreat with CIA colleagues. He quickly began to unravel mentally and emotionally, suffering from paranoia, depression, and psychotic episodes. Just nine days after he was dosed, Olson plunged to his death from a New York City hotel window in what was initially deemed a suicide, though later investigations raised the possibility that he was either coerced or pushed.

The Canadian Experiments: Dr. Ewen Cameron

In Canada, MKUltra was particularly destructive in the hands of Dr. Ewen Cameron, a Scottish-born psychiatrist who worked at McGill University's Allan Memorial Institute in Montreal. Cameron was obsessed with erasing memories and reprogramming individuals. He believed he could 'de-pattern' a patient's mind—wiping out their memories, personalities, and even basic motor skills—before rebuilding their psyche from the ground up.

Cameron's techniques included massive doses of LSD, electroconvulsive therapy administered at 30 to 40 times the normal power, and sensory deprivation. His patients, many of whom had sought treatment for depression or anxiety, were subjected to weeks or months of these treatments, often leaving them with profound memory loss, cognitive impairment, or severe mental illness. The Canadian government later acknowledged these abuses, and many of Cameron's victims successfully sued for compensation.

Effects on Victims: Lifelong Trauma and Mental Breakdown

The effects of MKUltra on its victims were devastating. Many of the people who were subjected to these experiments suffered from permanent psychological damage, including paranoia, anxiety, depression, and post-traumatic stress disorder (PTSD). Some lost their memories entirely, rendering them unable to remember basic facts about their own lives, such as their families, professions, or even their names.

In many cases, the experimentation left individuals with a shattered sense of reality. Some victims recounted horrifying hallucinations, periods of dissociation, or feeling like they were trapped in an altered state of consciousness from which they could not escape. Others reported long-term struggles with substance abuse, exacerbated by the CIA's repeated exposure to drugs like LSD.

The case of Frank Olson serves as a particularly tragic example of MKUltra's human cost. Olson's mysterious death, which was initially classified as a suicide, left his family with deep suspicions about the circumstances of his demise. Years later, declassified documents and interviews suggested that Olson may have been silenced by the CIA because of his growing disillusionment with MKUltra and the agency's biological weapons program.

The End of MKUltra: Exposing the Shadowy Program
MKUltra remained hidden from the public eye for decades. The program's end was not the result of any internal reckoning within the CIA but rather external events that forced the agency's hand. By the mid-1960s, the widespread use of LSD in countercultural movements raised public awareness of the drug, which in turn increased scrutiny of any government involvement with psychedelics. Additionally, several of the CIA's top officials involved in MKUltra began to retire, leaving the program without key leadership.

However, it was the Watergate scandal in the early 1970s that indirectly led to the exposure of MKUltra. As investigative reporters and congressional committees began to dig into the abuses of executive power, the CIA found itself under increasing scrutiny. In 1973, as the scandal mounted, CIA Director Richard Helms ordered the destruction of all MKUltra files, attempting to erase the program from history. But he failed to eliminate everything. Some financial documents and project files survived, and these fragments were enough to spark further investigations.

The Church Committee and Public Revelation

In 1975, the Church Committee, led by Senator Frank Church, was established to investigate abuses by the CIA, NSA, and FBI. The committee uncovered a treasure trove of previously classified documents detailing MKUltra's experiments and shocking human rights violations. The revelations were staggering: the U.S. government had conducted mind control experiments on its own citizens without their knowledge or consent.

Later that year, the Rockefeller Commission also released a report that exposed MKUltra, further shocking the public and increasing demands for accountability. Lawsuits were filed by victims and their families, with some, like the family of Frank Olson, receiving settlements from the U.S. government.

In 1977, under increasing pressure, the CIA released thousands of additional documents related to MKUltra, following a Freedom of Information Act request by investigative journalist John Marks. The details were grim: people had been drugged, harassed, and experimented on in the name of national security, often without any medical justification.

The Aftermath: Ethical Repercussions and Legacy

MKUltra's exposure triggered widespread outrage and fundamentally altered the relationship between the U.S. government and its citizens. Public trust in the intelligence community, already weakened by the Watergate scandal, was further eroded. In response, new safeguards were put in place, including tighter oversight of CIA activities and congressional reviews of covert operations"



