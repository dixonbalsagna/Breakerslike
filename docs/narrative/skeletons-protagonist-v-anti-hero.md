# Skeleton set 1: Protagonist v Anti-hero

Owner: Narrative and Fighter Identity. Version 1, 2026-09-30. The first authored skeleton set for the dialogue director (`dialogue-director.md`). Names are placeholders. Lines are original and unsearched. Both fighters are he/him.

**The frame.** Stakes: `rivalry`, a sparring rival. Registers: the Protagonist warm and respectful, the Anti-hero contemptuous with a hidden envy. Voice rules: the Protagonist uses contractions, speaks in the future tense and puts the fight first and repairs after. The Anti-hero uses **no contractions** and speaks of the other in the past tense, always compares a rank to something absurd, and says "Filth." for pure contempt. When his facade cracks (mood `rattled`), his contractions return and he speaks in plain present tense.

**How to read a skeleton.** `{slot}` is filled from the live context and the banks in section 1. Alternates inside a cell are separated by a slash. Thoughts are *italic* and use their own display. `kind` is `line`, `reply`, `retort`, `callback`, `thought` or `jewel`.

## 1. Slot banks (the lexicon)

| Slot | Values |
|---|---|
| `{part}` (by region hit) | head: skull, face, head. core: ribs, chest, gut. arms: arm, fist, shoulder. legs: leg, knee, ankle. |
| `{thing}` (by structure) | bridge, tower, warehouse, roof, lighthouse, chimney, wall, market |
| `{place}` | Bellgate, Netmend, Kilnstead, Farwatch, Furrowlea, Windlea, Deepholt, Sunwaste, Anvilfell, Longwater (all placeholders) |
| `{ordinal}` | second time, third time, fourth time |
| `{duration}` | an hour, all week, ages, a year |
| `{rank}` and `{behind}` (Anti-hero) | rank: Third, Fourth, Fifth, Sixth. behind: the goons, the furniture, the civilians, the rubble, the weather. Level 2 chains two ("the goons and the furniture"). |
| `{addr}` (Protagonist) | friend, champ, buddy |
| `{warm}` (Protagonist) | good, great, brilliant, fair |
| `{contempt}` (Anti-hero) | adequate, noise, decoration, an accident |
| `{training}` (either) | morning stairs, the mountain steps, sand drills, cold-water dawns |
| `{stay_home}` | stay home and sulk, send a letter, bring a chair, hide behind a wall |

## 2. Skeleton families

### 2.1 Opening greeting (mood `sizing_up`)

| Speaker | Skeleton | Kind |
|---|---|---|
| P | "Good. You came. I was worried you'd {stay_home}." | line |
| P | "Ready when you are, {addr}. I'll go easy. ...I'll try." | line |
| P | "It's been {duration}. Let's see what you've been doing." | line |
| P | "Ha! You brought the cape. I'll try not to step on it." | line |
| A | "You were {praise_past} once. Show me what is left." (praise_past: strong / promising / a fighter) | reply |
| A | "You were always worried. It was your best quality. Begin." | reply |
| A | "I gave you {duration} to improve. You were {contempt}." | reply |
| A | "You are late. You were always late to be first." | reply |

### 2.2 First blood and hits

| Speaker | Skeleton | Kind |
|---|---|---|
| A (first blood) | "{dismiss}." (Slow / Careless / Predictable) | line |
| A (a hit lands) | "You were {quick_past} before. You will not be again." (quick_past: quick, sharp, dangerous) | reply |
| A (a hit lands) | "{rank}. Behind {behind}. You rank lower with every breath." | bit |
| A (a hit lands) | "Adequate. That is all you were, and it was generous." | line |
| P (a hit lands) | "{obs_p}! I'll remember that one." (obs_p: There it is / Got you / That one landed) | line |
| P (a hit lands) | "Nice one, {addr}. Now try to catch this." | line |
| P (a hit lands) | "That's the one! Thank you. Do it again." | line |
| P (took a hit) | "{ow}. My {part}. I'll need that later." (ow: Ow / Ha / Hm) | reaction |
| P (took a hit) | "That was a good {part}. It's going to be a bad {part}." | reaction |
| P (took a hit) | "Fair! That one's yours." | reaction |
| A (took a hit) | "You touched my {part}. You were alive a moment ago." | reaction |
| A (took a hit) | "My {part}. You will regret it. You will regret being {contempt}." | reaction |
| A (took a hit) | [growl] "Remember that. It is the last time." | reaction |

### 2.3 Structures and collateral

| Speaker | Skeleton | Kind |
|---|---|---|
| P | "Sorry about the {thing}! I'll help fix it once we're done." | bit L1 |
| P | "Sorry about the {thing}! I'll help fix it once I'm done with you." (the {ordinal}) | bit L2 |
| P | "That was somebody's {thing}. I'll help rebuild it once I'm done here." | line |
| P | "...That was a lot of {thing}s. I'll help fix them once I'm done with you. All of them." | line |
| A | "Nobody will remember that {thing}. Or you." | line |
| A | "{place} was fine. It was never mine." | line |
| A | "The crowd was decoration. Decoration falls." | line |
| A | "You broke the {thing}. Then you promised. You were always both." | line |

### 2.4 Region breaks and the brink

| Speaker | Skeleton | Kind |
|---|---|---|
| P | "That was my {part}. It was a good {part}." | line |
| P | "Okay. My {part}'s gone. That's fine. I've got another." | line |
| A | "Your {part}. It was your best feature. It is broken." | line |
| A | "You were fast because of that {part}. You are not now." | line |
| P (brink, self) | "Hold on. Hold on. I've got one more." | reaction |
| P (brink, self) | "Not yet. I'll be fine in a minute." | reaction |
| P (opponent on brink) | "Stay with me. Don't stop. I want the real you." | reaction |
| A (brink, self, rattled) | "I can't feel my {part}. Help me." (present tense, contractions) | reaction |
| A (brink, self, rattled) | "Don't. Don't look at me like that." | reaction |
| A (opponent on brink) | "You were at the edge. I was never." | reaction |

### 2.5 Callbacks (each needs the fact on record)

| Speaker | Skeleton | Requires |
|---|---|---|
| A | "You said that about the {thing_earlier}. It is still down." | P promised a fix earlier |
| A | "You said that before the {thing_earlier} fell." | An earlier P line and a structure fall |
| A | "{ordinal}. You have said 'sorry' {count} times. You have not fixed anything." | P said sorry at least twice |
| P | "That's twice you've called me {their_word}. I've been saving it." | A repeated a word |
| P | "You said 'adequate' before the {thing_earlier}. I liked it better then." | A said "adequate" earlier |
| P | "I owe you a {thing_earlier}. Remember? I'll pay it after." | A structure fell on P's watch |

### 2.6 Banter threads (opener, reply, retort)

| Thread | Opener | Reply | Retort |
|---|---|---|---|
| The face | P: "You're doing the face again." | A: "I do not make faces." | P: "Ha! You just did." |
| Winded | P: "You're not even winded." | A: "You were winded ages ago." | P: "Ha! Wait. I'll catch up." |
| Old days | P: "Remember when we used to do this for fun?" | A: "You did it for fun. I was working." | P: "Then you were working very hard at losing." |
| Rank | A: "{rank}. Behind {behind}." | P: "Behind the {behind}?! Rude." | A: "Rude was the {ordinal} you fixed nothing." |
| Sulk | P: "Did you practise the scowl?" | A: "I was born with it." | P: "You were born with a lot of things. Let's see them." |
| Cape | P: "Nice cape. Very... sweeping." | A: "It was a gift." | P: "From who? I want to thank them." |

### 2.7 Thoughts (inner lines, often)

| Speaker | Mood | Thought skeletons |
|---|---|---|
| P | playful | *He's holding back. So am I. That's the fun of it.* / *I keep breaking things. I'll say sorry in a minute.* |
| P | heated | *He's angrier than usual. That's good. Angry gets sloppy.* / *Don't stop. Don't give him room.* |
| P | grim | *I can't lose this one. There are people under us.* / *He's still my friend. That's what makes it hard.* |
| A | contemptuous | *He is holding back. He always holds back.* / *He means it. That is what makes it unbearable.* |
| A | heated | *Why does he never tire?* / *I should end this. I do not.* |
| A | rattled | *He is better than me.* / *I can't. I can't feel my arms.* / *I do need him.* |

## 3. Style-reactive lines (the player-style model)

The styled fighter thinks and boasts; the other reacts. Each cell has alternates.

| Style | Styled fighter's thought | Styled fighter's boast | Other's taunt | Other's thought |
|---|---|---|---|---|
| **turtle**, Protagonist | *Only a little longer...* / *Hold. It'll turn.* | "You can't break what won't bend!" / "I could do this all week." | A: "Hiding behind your arms. You were braver last time." / "Guard, guard, guard. Fifth. Behind the goons." | A: *He will not break. I must make him.* |
| **turtle**, Anti-hero | *Not yet. Let him spend himself.* / *This is not caution. It is patience.* | "You were never going to break through. You were never able." | P: "Come out, friend! I promise not to be gentle." / "You're doing the wall again. I like the wall. I'll knock it down." | P: *He's waiting for me to tire. Good plan. Bad plan.* |
| **rusher**, Protagonist | *Keep going. Don't give him room.* | "Twelve years of {training} and I'm still only warming up!" | A: "Loud. Fast. Pointless." | A: *He never tires. That is the trouble.* |
| **rusher**, Anti-hero | *Press. Allow him no air.* | "I do not waste motion. You wasted yours." | P: "You're crowding me! I love it!" | P: *He's angry. That's fine. Angry gets sloppy.* |
| **runner**, Protagonist | *Keep moving. Keep it away from the town.* | "Catch me if you can!" | A: "Running again. Fifth. Behind the goons." / "You were quick. You will be tired." | A: *He leads me away from something. What is he hiding?* |
| **runner**, Anti-hero | *Retreat is a shape of patience.* | "You will not touch what you cannot reach." | P: "Hey! Come back! I've barely started!" | P: *He's leaving on purpose. Why?* |
| **charger**, Protagonist | *Almost there... almost...* | "You're going to want to see this!" | A: "Charge all you like. I will wait." | A: *Every second he glows I could end this. I do not.* |
| **charger**, Anti-hero | *Slowly. Deliberately.* | "Watch. This is how a rank is earned." | P: "Ooh, the glow! Nice colour!" | P: *Should I stop him? ...No. I want to see it.* |

**Adaptation pairs** (the styled fighter meets the other's reaction to it):

| Pattern | Boast | The other's response |
|---|---|---|
| Protagonist rushes, Anti-hero starts evading | P: "Twelve years of {training}, and you're the one out of breath!" / "This is what six a.m. looks like!" | A (thought): *I am not running. I am repositioning.* A: "It is strategy." |
| Anti-hero rushes, Protagonist starts evading | A: "Years of drills, and you cannot stand still." | P (thought): *Keep it going. Let him tire himself.* |
| A rusher smashes a turtle | "Every wall has a hinge!" | The turtle (thought): *Still standing. Still standing.* |
| A turtle turns rusher (a style shift) | P: "Okay. Enough waiting." / A: "You were always going to break. Finally." | The other: "There you are!" / *Good. That was overdue.* |

## 4. Stakes framing (spoken)

| Kind | Protagonist | Anti-hero |
|---|---|---|
| `stakes_open` | "Loser fixes the bridge." / "Winner buys the rebuild!" | "First place. That is what is at stake. You were never in it." / "The loser was always going to be you." |
| `stakes_raise` (collateral rises) | "We're wrecking the place. Whoever wins pays for it." | "The city is the price. I have paid it before." |
| `stakes_raise` (a transformation) | "Okay. Now it matters." | "Now the rank is real." |
| `stakes_raise` (the brink) | "Somebody's going down. Make it count." | "Whoever falls, falls for good. Remember it." |
| `stakes_reminder` | "Still your bridge to fix, remember?" | "Still first place. Still mine." |

## 5. Signature lines (recurring, exempt from the novelty term, at most once a match)

- **Protagonist:** "I'll fix it after." / "Again. Once more." / "Thank you. Really."
- **Anti-hero:** "You were adequate." / "It ends when I say." / "This does not count."
- **The inner signature (thought, at the brink):** A: *He is better than me.*

## 6. Jewels (once a session)

1. P: "You know I don't hate you, right?"
2. P: "If I lose, take the bridge. It needs fixing."
3. P: "I've been thinking about this since we were kids. It's better than I thought."
4. A: "I ranked you first once. Do not tell anyone."
5. A: "Ask me who is third. ...Nobody. There was never a third."
6. A: "You were the only one who ever made me want to win."
7. A: "This is the longest anyone has stood in front of me."
8. Both (after the fold, quiet): P: "Just us." A: "Just us. ...Good."

## 7. How much this is

| Count | Number |
|---|---|
| Skeletons and authored lines in this set | about 90 |
| Slot values in the banks | about 60 |
| Style-reactive cells (2 fighters x 4 styles x 4 cells, plus 4 adaptation pairs) | 36 |
| Threads (opener, reply, retort) | 6 |
| Jewels and signatures | 8 and 7 |
| Distinct lines this set can produce (rough) | about 700 |

That is a start for one matchup, about 4 percent of the ceiling in `dialogue-director.md` section 3.2. It is enough to play, to test the mood graph and the style model, and to see what Orb thinks of the voices before writing more.
