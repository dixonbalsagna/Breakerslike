# Voice lab: the packet for Orb

Owner: Narrative and Fighter Identity. Version 2, 2026-10-01. For Orb.

**What this is.** One spreadsheet per fighter, each holding draft lines in that fighter's voice, written the raw way an AI writes by default. **They are not polished, and they are meant to be rewritten by a person.** You can spot AI-written dialogue on sight, so we want your edits. We turn what you change into style rules for each character, a banned-patterns list, and an automatic check, so the game's lines stop sounding machine-written.

**Be unkind to them.** A line that is fine but not them is worth rewriting. A line that is wrong is worth cutting. The more you change, the more we learn. You do not have to finish a file; send what you have.

## The files

| File | Fighter | Lines |
|---|---|---|
| `protagonist.csv` | Protagonist (a refresh of batch 1, plus today's new lines) | 187 |
| `anti_hero.csv` | Anti-hero | 165 |
| `empress.csv` | Empress | 185 |
| `cyborg.csv` | Cyborg | 160 |
| `kai.csv` | KAI (the prototype Hero, a placeholder) | 130 |
| `vorr.csv` | VORR (the prototype villain, a placeholder) | 131 |
| `known-tells.md` | The patterns you called out as machine-written, with examples. Read it first. | |
| `batch-01-protagonist.csv` | Your earlier batch. **Untouched.** If you already edited it, those edits still count; the new Protagonist file keeps the same lines. | |

## How to edit

You need nothing but a spreadsheet or a text editor.

**In Excel, Numbers or Google Sheets:** open the `.csv`. Accents and quotes open cleanly (UTF-8 with a BOM). Each row is one line.

| Column | What it is | Who fills it |
|---|---|---|
| `id` | A stable id. **Do not change it.** | (given) |
| `fighter` | Who says it. | (given) |
| `kind` | The sort of line: bark, reply, retort, taunt, thought, hurt, collateral, waiting, transformation, shout, finisher, on the chin, intro, last stand, victory, defeat. The file is sorted by kind, most-heard first, so the lines you will hear most often come first. | (given) |
| `situation` | What is happening when they say it, in plain words. Some lines have `{part}`, `{thing}` or `{place}`: the game fills those in (a body part, a landmark, a place). Leave them in. | (given) |
| `line` | The line as the AI wrote it. | (given) |
| `Orb's edit` | **Your rewrite.** Say it the way you would. Shorter, longer, weirder, one word, a different idea, or nothing at all. | **You** |
| `note` | Optional. Why, in a few words ("too neat", "they'd never say that", "funny"). Even "boring" is useful. | **You** (optional) |
| `keep / cut / rewrite` | **keep** (the line is fine as it is), **rewrite** (your edit is in `Orb's edit`), or **cut** (nobody says it). If you fill `Orb's edit` and leave this blank, we treat it as a rewrite. | **You** |

**In a plain text editor:** each line is one record in quotes, with eight fields separated by commas. Put your rewrite in the sixth field (between the quotes after the empty one that follows the line) and keep the quotes. A spreadsheet is much easier.

**Saving:** keep the same file name and columns, do not add, delete or reorder rows, and in Excel use **Save As, CSV UTF-8 (Comma delimited)**. Then tell the EP.

**How long:** a keep-or-cut pass is about 15 minutes per file. A full rewrite pass is 45 to 60 minutes per file. Do one fighter at a time, or only the one you care about most first. The Protagonist's file is the one most likely to be closest to right.

## What happens after

The EP diffs your edits against our drafts to see what you keep changing: words, rhythm, length, tone, jokes, structure. From that the EP writes **style rules** per fighter ("they say X, never Y"), a **banned-patterns list**, and a **lint check** that tests new lines against your rules before you see them. Then Narrative writes a second round, better and shorter, and you get a smaller batch.

The lines are original. No franchise names or catchphrases appear. If one sounds familiar, cut it and say so in the note.

---

## Voice briefs (what we currently think each fighter sounds like)

These are our best understanding, and they may be wrong. If a brief is wrong, say so in a sentence. That will help more than editing fifty lines.

### Protagonist

A sincere, plain-spoken fighter who would rather be fixing things than fighting, and fights anyway. He speaks in contractions and the **future tense**: promises, plans, "I'll". He fights first and repairs after ("I'll help fix it once I'm done with you"). He is kind to bystanders and honest with the enemy, and he jokes at his own expense. His humour is mild and a little awkward, a boxer's grin more than a quip. When the collateral mounts he turns quiet and apologetic, and the lines get shorter. He never gloats, never insults someone's looks, and never gives a speech.

**Five questions**
1. When he hits someone, does he say anything, or is he silent? What does he say when he is enjoying himself?
2. How sorry is he, really? Does he apologise to the victims, to the city, to the enemy, or to nobody?
3. Is he funny, and if so, what sort? (Dry, goofy, nervous, deadpan, none.)
4. How does he talk to the Anti-hero: as a friend, a rival, an old friend gone wrong?
5. What is the one word or habit that would make you say "that is him" in a single beat?

### Anti-hero

A proud rival who ranks everyone and is never impressed. He speaks without contractions and in the **past tense about his opponent**, as if the match were already over ("You were adequate"). He ranks things against something absurd ("Fifth. Behind the goons."), and saves "Filth." for pure contempt. His voice is cold, short and formal. When his Pride cracks (he is rattled or on the brink) the facade slips: contractions and the **present tense** come back ("I can't. I can't feel my arms"). On the Chin, the move where he absorbs a signature, he is bored.

**Five questions**
1. Does he ever lose his temper out loud, or is it all coldness until it breaks?
2. Is the rank joke ("Fifth. Behind the goons.") a keeper, or has it already worn out?
3. What does he think of the Protagonist: a fraud, a threat, a friend he will not admit?
4. What does he sound like when he is truly afraid? Does he say it, or go silent?
5. How long are his lines meant to be: a clipped sentence, or a sneering paragraph?

### Empress

A galactic empress obsessed with her image and her record, who dreads every transformation because of the paperwork it costs. She speaks in the **royal "we"** and slips to **"I"** when hurt ("You struck ME. ...Us."). She calls her opponents "petitioner" and her guard of honour (the Shield, the Herald-Archer, the Runner, and a pained aide) by their titles. The paperwork is heard, never seen: form numbers muttered, complaints about revisions, "in triplicate". She is confident, leering and quick to anger. She never apologises sincerely, never admits fear, and never comments on looks or bodies.

**Five questions**
1. Is the paperwork joke funny to you, or is it the first thing that should be cut?
2. How cruel is she: a sneering pleasure or just bureaucratic indifference?
3. Does the "we" slipping to "I" land as a character beat, or is it a gimmick?
4. How should she treat the guard: affection, contempt, or both?
5. When she is truly angry, is she louder or colder?

### Cyborg

A cheerful, polite, corporate machine with a bottomless appetite, who treats mass violence as good service. He talks like a call-centre script wrapped around something appalling ("Please stand clear of the counter. Or stay. I have room."). Civilians are stock and ingredients; a planet is a kitchen. He never raises his voice, he only speeds up. When someone hits the chip on his head he glitches into stutters and a shrill "not the chip". His food is sandwiches, never sweets. He never makes a direct threat, only offers a menu, and his apologies are always "our sincere apologies", which means nothing.

**Five questions**
1. Is the customer-service gag still fresh, or has it been done to death?
2. How hungry is too hungry? Where does the cute turn into horror, and do you want that line crossed?
3. Does he ever stop being polite? What does that sound like?
4. The chip glitch: is the stutter funny, or is it too much?
5. What does he sound like when he is losing?

### KAI (placeholder Hero)

KAI is the prototype's hero: a Warden, plain, measured and dry, who names places (a roof, a road, a harbour) and speaks in promises and the **future tense**. Gentle to bystanders, blunt to VORR. When the collateral rises, his lines break into apology: "I'm sorry. I'll fix it." His humour, when there is any, is dry and aimed at himself. KAI's name is a placeholder (Legal says no), and the real Hero is now the Protagonist, so this file mainly tests whether the older, graver version of the voice is worth keeping.

**Five questions**
1. Is KAI the Protagonist with the jokes removed, or a different person? Which do you want?
2. How much should the anguish show? Is "I'm sorry. I'll fix it." too much?
3. Should he be gentle with bystanders, or too busy to be?
4. Is the "Warden" office worth keeping, as VORR uses it?
5. If KAI and the Protagonist are the same character at two stages, which stage is this?

### VORR (placeholder villain)

An elegist, unhurried, courteous and warm, who sees himself as the world's witness at the end. He speaks in the **past tense about things that are still standing** ("It was a lovely harbour"), compliments what he is about to take, and calls the Hero by their office, "Warden". He never shouts and gives no speeches about being the strongest. "I don't break things. I finish them." The politeness is about the place, never his rank. He stops to look at a collapse and can be punished for it.

**Five questions**
1. Is the past tense for standing things a keeper? Does it stay creepy, or turn into a trick?
2. How warm is he? Should he be actually kind, or is it a mask?
3. Does he ever show anger, and what does it sound like?
4. What does he say to the other fighters (Anti-hero, Empress, Cyborg), as opposed to the Warden?
5. Should he ever be funny?
