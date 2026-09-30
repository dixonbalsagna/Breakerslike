# The dialogue director

Owner: Narrative and Fighter Identity. Version 1, 2026-09-30. Extends `line-system.md`. A design, not an implementation. Names are placeholders. Lines are original and unsearched. Orb's questionnaire answers may refine it.

**The brief (Orb, playtest 2).** Voice lines play like a classic platformer's: each character has distinct grunts, laughs and chattering noises while captions appear. The lines are chosen automatically from each fighter's stance, position, current or recent actions and anything special that happened. A procedural system sets the mood of the fight and chooses back-and-forth one-liners, reactions, thoughts and taunts that progress over the battle. One battle is a whole set (7 to 8 minutes), and across many fights a player should keep seeing lines that are new to them. **The core principle:** the player is in charge of macro strategy, pacing and positioning, and the fight director is in charge of combos, tactics, blitzing and voice lines.

**In one paragraph.** A **dialogue director** sits beside the fight director. It reads the sim's event stream (never writing it), keeps a **fight-mood model** (momentum, dominance, stakes, rivalry heat and more), and lets that mood move through the match's arc. From the mood and the last few events it opens **conversations**: a taunt, a reply, a retort, and later a callback. Lines come from **templates with live slots** in each fighter's own voice, and a **memory** of what the player has already seen steers it toward lines they have not met. A **pacing** layer keeps it from talking over the choreography and uses silence as a tool.

## 1. The fight-mood model

### 1.1 State variables

All derived from the sim's events and state. The dialogue director reads them and never writes them. Ranges and half-lives are working values.

| Variable | Range | What it tracks | How it moves |
|---|---|---|---|
| `momentum` | -1 to +1 (per fighter) | Who is winning the recent exchanges. | A moving average of decisive exchange results, half-life 20 s. |
| `dominance` | -1 to +1 (per fighter) | Who is ahead overall: wounds, tier, brink. | Slow; half-life 90 s. Jumps at a region break, a transformation or the brink. |
| `stakes` | 0 to 1 | How much is on the line. | Starts from the matchup (`sparring` 0.2, `rivalry` 0.5, `world_at_stake` 0.9), then rises with collateral, transformations and the brink. It never falls. |
| `fatigue` | 0 to 1 | Drama fatigue: how much has been said, and how worn the fighters are. | Rises with talk and wear. Thins the line budget (section 4). |
| `rivalry_heat` | 0 to 1 | How personal it has become. | Rises with taunts that land, humiliations, near misses and callbacks. Decays slowly. It drives how fast a conversation runs. |
| `collateral` | 0 to 1 | The share of people lost or evacuated, and structures lost. | From World's counters. Each fighter reacts by his or her `care`. |
| `recent_events` | a ring of 12 | What just happened, with salience and age. | Every event gets a salience (a region break 0.9, a light hit 0.1) and fades. |
| `arc_phase` | opening, escalation, turning, brink, finale | Where the match is (section 1.2). | From the events, not only the clock. |

Each fighter also carries his or her own state: ego meters (Pride, Respect, Wrath, Hunger), the form or revision, and active bits (running jokes, section 2.4).

### 1.2 How mood evolves across the arc

A match runs about 7 to 8 minutes. The phases come from events first and the clock second, so a quick match still has an arc.

| Phase | Typical time | What triggers it | What the talk is like |
|---|---|---|---|
| **Opening: sizing up** | 0:00 to about 1:30, or until the first break | Match start | Greetings, feel-out taunts, "so you're the one". Light and curious. Few lines, long gaps. |
| **Escalation** | about 1:30 to 5:00 | The first region break, a big launch, first collateral | Insults with edges, the first callbacks, running jokes starting. More lines. |
| **Turning points** | Any time from about 3:00 | A momentum swing beyond ±0.6, a transformation, the fold, an evacuation | A shift of register: the talk changes character. Longer exchanges. |
| **Brink** | About 5:30 on | Either fighter on the brink | Short lines, breathing, silence. The registers show their cracks. |
| **Finale** | The finisher | `finisher_open` | Few words. Set-piece lines only. Then the aftermath. |

### 1.3 Moods and the mood graph

Each fighter's mood is a node from a small set: `sizing_up`, `playful`, `cocky`, `heated`, `grim`, `contemptuous`, `rattled`, `desperate`, `triumphant`, `spent`, `reverent`. Moves between nodes are edges with triggers. Each **matchup register family** has its own graph, so the same event moves different fighters differently.

| Register family | Nodes in order | The pattern |
|---|---|---|
| **Sparring / respect** (Protagonist v the Anti-hero or a mirror) | sizing_up, playful, heated, respectful-grim, reverent | Fun that turns serious as the fight does, and ends in respect. |
| **Rivalry / contempt** (the Anti-hero v others) | sizing_up, contemptuous, heated, rattled (facade), cold | Coolness that breaks under pressure. |
| **World at stake** (the Protagonist v the Empress or Cyborg) | grim, grim-heated, desperate, resolved | No play. The Protagonist never enjoys it. |
| **Appetite** (the Cyborg v anyone) | polite, hungry, frantic | Politeness over an appetite that outgrows it. |

**Example: Protagonist v Anti-hero.**

| From | To | Trigger |
|---|---|---|
| Protagonist: sizing_up | playful | The first exchanges are even (`momentum` within ±0.3). |
| Protagonist: playful | heated | A region breaks, or `rivalry_heat` above 0.5. |
| Protagonist: heated | respectful-grim | Either fighter on the brink, or a fold. |
| Anti-hero: sizing_up | contemptuous | The first hit he lands. |
| Anti-hero: contemptuous | heated | He takes a heavy hit, or the Protagonist transforms. |
| Anti-hero: heated | rattled | His Pride falls below half (the facade cracks). |
| Either | spent | `fatigue` above 0.8. |

## 2. Conversation, not barks

### 2.1 Threads

A **thread** is a back-and-forth. It has an opener, a reply, a retort and optionally a button. The director opens one when the mood and a window allow (section 4), then keeps the floor until it ends or is cut.

| Step | Who | What | Window |
|---|---|---|---|
| **Opener** | The fighter with the initiative | A taunt, a boast, a remark, a compliment | Chosen from his mood and the last events. |
| **Reply** | The other fighter | Answers the opener's tag | Within 2.5 s, or the thread lapses. |
| **Retort** | The first fighter | A comeback | Optional, if `rivalry_heat` is high. |
| **Button** | Either | A short final line, or a grunt | Ends the thread. |

Thread types: **banter** (friendly), **insult trade**, **compliment and deflect**, **argument about collateral**, **the running joke**, and **a wager or challenge**.

### 2.2 Callbacks

The director keeps a **match memory** of what was said and what happened: the first structure destroyed (what, where, when), first blood, the first transformation, and the ids and tags of the last 30 spoken lines. A callback line has a `requires_fact` and quotes it:

- "You said that about the bridge. It is still down." (the Anti-hero, after the Protagonist promised to fix something)
- "That was my arm. It was a good arm." (the Protagonist, at a broken arm)
- "You said that before the mountain fell." (any fighter, when the earlier line and the event are both on record)

A callback is only picked if the fact is in memory, so it can never lie.

### 2.3 Thoughts

An inner line is a **thought**, shown differently (smaller, italic, softer colour, no full grunt, only a low mutter or a breath). Thoughts reveal what a fighter will not say, and they fire in silences, at set pieces and at the turning points.

- The Anti-hero thinks: "He means it. That is what makes it unbearable."
- The Protagonist thinks: "I keep breaking things. I'll say sorry in a minute."
- The Empress thinks: "The forms. The FORMS."
- The Cyborg thinks: "I am so, so hungry."

### 2.4 Running jokes ("bits")

A **bit** is a joke that a fighter carries across the match and escalates. Each has levels, and each level has its own lines.

| Fighter | The bit | Level 1 | Level 2 | Level 3 |
|---|---|---|---|---|
| Protagonist | "I'll fix it after" | "Sorry about the bridge! I'll help fix it once we're done." | "Sorry about the tower! I'll help fix it once I'm done with you." (the second time) | Sincere: "I'll help you up. After." |
| Anti-hero | The rank gag | "Fifth. Behind the goons." | "Fifth. Behind the goons. And the furniture." | "You have fallen below the furniture." |
| Empress | The paperwork dread | "Do not ask about the paperwork." | "The forms alone. A month of them." | "We will be filing until the sun goes out." |
| Cyborg | The manager | "May I speak to your manager?" | "I would like the other manager." | "I would like a manager for the manager." |

## 3. The freshness engine

### 3.1 Templates and slots

A line is a **skeleton** with **slots**, in one fighter's voice. Slots are filled from the live context and typed so that nonsense cannot be built.

| Slot | Filled from | Example |
|---|---|---|
| `{place}` | The place under the fight (`places.md`) | "Bellgate was lovely." |
| `{thing}` | The structure just destroyed | "Sorry about the {thing}!" |
| `{part}` | The body region hit | "That was my {part}." |
| `{form}` | The fighter's stage or revision | "Revision {n}." |
| `{opp_move}` | The opponent's last move | "That {opp_move} was sloppy." |
| `{count}` | A live number (people lost, breaks, minutes) | "That is the third time." |
| `{weather}`, `{time}` | The world | "Nice night for it." |

**Lexicon variation per voice.** Each fighter has synonym sets for his or her habitual words (the Anti-hero's contempt words, the Protagonist's warm words, the Empress's court words), so a skeleton rarely reads the same twice.

### 3.2 A real estimate of unique lines

I count carefully, and I separate what is authored from what is combined. Assumptions are per fighter: 40 trigger families, 6 skeletons per family, 2 slot banks of about 8 values each, and about half of the combinations passing compatibility.

| Quantity | Estimate |
|---|---|
| Skeletons per fighter | 40 x 6 = 240 |
| Distinct surface strings per fighter | 40 x 6 x (8 x 8 x 0.5) = about 7,700, plus about 150 authored jewels: **about 7,800** |
| Lines per matchup (both fighters, plus reply lines for the pair) | 2 x 7,800 + about 800 pair-specific replies = **about 16,400** |
| Distinct two-line exchanges per matchup | About 10 thread types x 80 openers x 12 replies = **about 9,600** |
| Lines a player meets in one match (about 6 per minute at peak, 45 to 55 in all) | About 50 |

If the memory steered perfectly, a player would see no repeats for **about 300 matches** in one matchup. **The honest number is smaller.** Players notice skeleton repetition long before string repetition. A fighter uses about 25 lines a match from 240 skeletons, so a skeleton returns after about **10 matches**, unless the slots and the lexicon change its face. So the freshness that matters is measured in **skeletons and jewels**, not combinations, and the cheapest way to raise it is more skeletons and more jewels: one authored jewel is worth more than a thousand combinations. Expect a player to feel the game is fresh for 20 to 40 matches, and to be surprised by a jewel long after that.

### 3.3 Cross-match memory

A local save (`user://dialogue_seen.json`) records what the player has seen: per line id a `seen_count` and the last match it appeared in, per skeleton a count, and flags for jewels. The selector steers toward the unseen:

- **Novelty term.** Multiply a line's score by 1 / (1 + seen_count), with a stronger penalty for a skeleton seen recently.
- **Forgetting.** After about 30 matches a line regains half its novelty, so favourites can return.
- **Size and privacy.** About 50 KB, stored only on this device, never sent anywhere. A setting resets it.
- **Callbacks and jewels** are never suppressed by memory when they are the only fit for a moment.

## 4. Pacing and priority

**Never talk over the choreography.** Exchanges have atoms, hit-stops and launches. The rules:
- **No lines during hit-stop**, and none that start in the middle of a launch.
- **In an exchange**, only very short captions (about six words or fewer) and grunts.
- **In downtime** (1.5 to 4 s between exchanges), full lines and threads.
- **In set pieces** (the fold, a transformation cinematic, the finisher), lines of any length, and the opponent's waiting lines.
- A **priority** decides who may cut whom: finisher, transformation, set piece, reaction, ambient.

**A line budget that rises with drama.** `lines per minute per fighter = base x (0.6 + 1.2 x drama)`, with `drama` from `stakes`, `rivalry_heat` and the phase, capped by `fatigue`.

| Phase | Budget (per fighter) |
|---|---|
| Opening | 3 to 4 per minute |
| Escalation | 5 to 7 |
| Turning points | 7 to 8, in short exchanges |
| Brink | 4 to 6, in short lines |
| Finale | Set pieces only |

**Silence as a tool.** After a major event (a region break, an evacuation, a guard falling) a **hush** of 2 to 3 s is enforced. Silence before a finisher raises the tension. When `fatigue` is high the budget is cut, because a fighter who talks endlessly loses weight. Grunts run through silence, so a fighter never feels absent.

## 5. Data format

The lines format from `line-system.md` is extended. New fields are marked *(new)*.

```json
{
  "id": "anti.callback.bridge.001",
  "kind": "callback",
  "trigger": "downtime",
  "priority": 1,
  "when": { "matchup": "anti_hero>protagonist", "mood": ["contemptuous", "heated"] },
  "requires_fact": "spoke.promise_fix",
  "thread": { "replies_to": ["promise.fix"], "then": ["retort.sincere"] },
  "text": "You said that about the {thing_earlier}. It is still down.",
  "cues": [{ "at": 0, "gesture": "scoff", "intensity": 1 }],
  "sets_fact": "spoke.callback_bridge",
  "bit": { "id": "fix_it_after", "level": 2 },
  "display": { "style": "caption", "dur_s": 2.4 }
}
```

- `kind` *(new)*: `line`, `reply`, `retort`, `callback`, `thought` or `jewel`.
- `thread` *(new)*: `opens` (tags this line offers), `replies_to` (tags it answers), `then` (what may follow).
- `mood` in `when` *(new)*, and `requires_fact` and `sets_fact` *(new)* for callbacks.
- `bit` *(new)*: the running joke and its level.
- `display` *(new)*: `caption`, `thought` or `shout`, and a duration.

The **mood graph** lives in `data/dialogue/mood/<register>.json`: nodes, edges and triggers. The **seen memory** is the local save above. The **skeletons and banks** are unchanged from `line-system.md`.

**Determinism.** Lines are presentation. The dialogue director reads the sim's events and state and **never writes them**. It uses its own **seeded stream** (the match seed plus the event index), so a replay shows the same lines, and the sim never reads dialogue state. The seen-memory snapshot is recorded in the replay header, or the chosen line ids are stored in the replay log. In online play each client picks its own lines, and captions may differ between clients.

## 6. Three sample 60-second transcripts: Protagonist v Anti-hero

Each shows a phase of one match and how the mood moves. Timestamps are match time. `[grunt]` is a vocal gesture, *italic* is a thought, and (silence) is a deliberate hush. The rank gag and "I'll fix it after" are the running bits.

### Transcript 1: the opening (0:00 to 1:00), sizing up

Moods: Protagonist **playful**, Anti-hero **contemptuous**. Stakes 0.2. Budget 3 to 4 lines a minute.

| Time | Speaker | Line | Kind |
|---|---|---|---|
| 0:04 | Protagonist | "Good. You came. I was worried you'd stay home and sulk." | opener |
| 0:07 | Anti-hero | "You were always worried. It was your best quality." | reply |
| 0:09 | Protagonist | [laugh.short] "Ha! Fair." | button |
| 0:14 | | (silence: the first exchange runs) | |
| 0:21 | Anti-hero | [scoff] "Slow." | reaction (first blood) |
| 0:24 | Protagonist | [wince] "Ow. I'll remember that one." | reaction |
| 0:31 | Anti-hero | *He is holding back. He always holds back.* | thought |
| 0:38 | Protagonist | "You're doing the face again." | opener (banter) |
| 0:41 | Anti-hero | "I do not make faces." | reply |
| 0:43 | Protagonist | "Ha! You just did." | retort |
| 0:46 | Anti-hero | [sneer] (no words) | button |
| 0:52 | Protagonist | [effort.heavy] "There it is!" | reaction |
| 0:55 | Anti-hero | "You were quicker than I recall. You will not be again." | reply |

The mood is light. Neither is heated. The first thread is friendly, and the thought shows the Anti-hero's envy.

### Transcript 2: escalation and a turning point (4:20 to 5:20), heated

Moods: Protagonist **heated**, Anti-hero **contemptuous, edging to heated**. Stakes 0.6. `rivalry_heat` 0.6. Budget 6 to 8. Callbacks are live.

| Time | Speaker | Line | Kind |
|---|---|---|---|
| 4:20 | Protagonist | "Sorry about the tower! I'll help fix it once I'm done with you." | bit level 2 |
| 4:24 | Anti-hero | "You said that about the bridge. It is still down." | callback |
| 4:27 | Protagonist | "I meant it about the bridge too! I'll fix that one first." | retort |
| 4:31 | Anti-hero | *He means it. That is what makes it unbearable.* | thought |
| 4:38 | Protagonist | "You're not even winded." | opener |
| 4:40 | Anti-hero | "You were winded ages ago." | reply |
| 4:44 | Protagonist | "They're getting out! Good." | evacuation (budget) |
| 4:46 | Anti-hero | "Run, then. You were never the point." | evacuation |
| 4:52 | Anti-hero | [growl] "Fifth. Behind the goons. And the furniture." | bit level 2 |
| 4:54 | Protagonist | "The furniture?! Rude." | reply |
| 4:58 | | (silence: a region breaks, and a 2.5 s hush) | |
| 5:02 | Protagonist | [wince] "That was my arm. It was a good arm." | reaction |
| 5:10 | Protagonist | [steam] "Okay. Warm." | transformation (cinematic) |
| 5:14 | Anti-hero | "Take your moment. You will need it." | waiting (polite) |

The talk is faster and personal. A callback closes a loop, the rank gag escalates, and a hush marks the break.

### Transcript 3: the brink and the finale (7:00 to 8:00), grim, then reverent

Moods: Protagonist **respectful-grim**, Anti-hero **rattled**. Stakes 0.7. Budget 4 to 6 in short lines, then set pieces only.

| Time | Speaker | Line | Kind |
|---|---|---|---|
| 7:02 | Protagonist | "Not here. There are people under us. Stay close. I'm taking us somewhere nobody can get hurt." | the fold |
| 7:05 | Anti-hero | "Running from your own mess. How like you." | reply |
| 7:07 | Anti-hero | *...Nobody is watching. Better.* | thought |
| 7:20 | Protagonist | "We can't hurt anyone innocent here. Now. Everything." | arrival |
| 7:22 | Anti-hero | "Everything. Good. It was overdue." | reply |
| 7:28 | | (silence: 3 s) | |
| 7:40 | Anti-hero | [ragged] "I can't feel my arms. Help me." | the facade cracks (present tense) |
| 7:43 | Protagonist | "I'll help you up. After." | bit level 3 (sincere) |
| 7:48 | Anti-hero | "Don't. ...I don't need you." | reply |
| 7:50 | Anti-hero | *I do.* | thought |
| 7:55 | | (silence: the finisher opens) | |
| 7:57 | Protagonist | [effort.heavy] "That's it. That's the one. Thank you." | finisher (landed) |
| 8:00 | Anti-hero | "...This does not count." (then, quietly) "Next time." | aftermath |

The mood has turned. The bit that started as a joke ends sincere, and the Anti-hero's contractions return when he cracks.

## 7. What this needs from other directors

- **Encounter Systems and Simulation:** the event stream and the state the mood model reads (wear stages, brink, tier, meters, chain, stance, position, hidden), and the arc-phase events.
- **Audio:** the babble voices and the hush (`docs/audio/grunts.md`).
- **UI/UX:** the three display styles (caption, thought, shout), the durations, and a settings toggle to reset the seen memory.
- **Game Design:** the drama-to-budget curve and the match arc (the seven to eight minute target).
- **Legal:** the boldest jewels and callback templates.
- **Localization:** slotted templates need per-language grammars, and the tense devices may not carry.

---

## 8. After Orb's questionnaire 4 (2026-09-30)

Orb's answers: inner thoughts, often; mostly fresh lines plus a few recurring signature lines per fighter; a dialogue density of 6 out of 10; the mood drives crowd behaviour and the director's aggression; move names only for specials, signatures and finishers. And the key ask: fighters' personalities should match up with how the player's fighting style is shaping the fight. A player who holds defensive patterns all game might see the character think "Only a little longer...", and a player who plays aggressively and sees the opponent start to evade might see the character boast about a training regimen.

### 8.1 A correction to the architecture: the mood lives in the sim

Because the mood now **drives the crowd and the director's aggression**, it is **simulation state**, not presentation. So:
- The **mood model and the player-style profile are sim components**: pure functions of sim events, in fixed-point, part of the state hash, and reproducible in replays.
- The **line selection, the freshness engine and the memory remain presentation.** They read the mood and the style profile but never write the sim.
- The **outputs** the sim reads from the mood: `director.aggression` (a scale on how hard the fight director pushes each fighter) and `crowd.state` (`excited`, `nervous`, `fleeing`, the same input as evacuation and the runners).
- The dialogue director's separate seeded stream is unchanged: it chooses lines, and the sim never reads which lines were chosen.

### 8.2 The player-style model

A **rolling profile** of how each fighter is being played (a human's controls, or the AI's choices), over a **60-second window** and a **match-long average**. It is a sim component (section 8.1).

| Measure | What it is |
|---|---|
| `stance_share` | The fraction of time in each stance (Press, Guard, Dodge, Escape). |
| `aggression` | Attacks per minute, and the share of time spent closing distance. |
| `retreat` | Time in Escape and Dodge, and how much distance was opened. |
| `charge_habit` | Time charging, and how many charges were interrupted. |
| `special_use` | Specials and signatures fired, and the share that landed. |
| `hide_habit` | Time hidden in cover. |
| `repetition` | Runs of the same attack kind. |

**Labels** derived from the profile (with hysteresis so they do not flicker): `turtle` (Guard above 55% for 45 s), `rusher` (Press above 60%), `runner` (Escape and Dodge above 50%), `charger` (long charge time), `sniper` (special-heavy), `hider`, and `mixer` (varied). Also **style shifts**: `was_rusher_now_runner` and so on.

**The opponent's reaction.** The fight director adapts to a style (a rusher meets evasion, a turtle meets guard breaks), and the dialogue director reads **both** the style and the reaction: the fighter who is *being* the style, and the one *reacting* to it.

| Style | The styled fighter thinks or boasts | The other fighter's taunt or thought |
|---|---|---|
| `turtle` | A thought: "Only a little longer..." | "Hiding behind your own arms. You were always small." |
| `rusher` | A boast about pace and training | A thought about being pushed |
| `runner` | A thought about escape | "Running again. Fifth. Behind the goons." |
| `charger` | A thought about the build-up | "Charge all you like. I will wait." |
| `rusher meets runner` | A boast about a training regimen | The runner's excuse or thought |

The authored lines for Protagonist v Anti-hero are in `skeletons-protagonist-v-anti-hero.md`.

### 8.3 Stakes framing (what is at stake, spoken)

Fighters say what is on the line, in three kinds of line:
- **`stakes_open`** at the start: what the fight is about.
- **`stakes_raise`** when a stake grows (collateral, a transformation, the planet threatened, the brink).
- **`stakes_reminder`** occasionally, so the stakes are heard during a long fight.

The stakes come from the matchup (`sparring`, `rivalry`, `world_at_stake`, `appetite`) and rise with the fight.

### 8.4 Density, thoughts, signature lines and move names

- **Density 6 of 10.** The budget's `base` is the density setting times 0.9, so the default 6 means a base of 5.4 lines a minute per fighter at neutral drama. The setting runs from 0 to 10, and the accessibility settings can lower it.
- **Thoughts, often.** Thoughts get their own budget: about 2 to 3 a minute per fighter in quiet stretches, so about a quarter of what a player sees is a thought. They fire in silences, at set pieces and at turning points, and at style patterns.
- **Mostly fresh, with a few signature lines.** Each fighter has three or four recurring **signature lines** that are exempt from the novelty term, and that fire at most once a match, at moments that suit them (the Protagonist's "I'll fix it after", the Anti-hero's "You were adequate"). Everything else is steered toward the unseen.
- **Move names only for specials, signatures and finishers.** The `{opp_move}` slot is filled only for those. Ordinary exchanges are never named.
