# The line system

Owner: Narrative and Fighter Identity. Version 1, 2026-09-29. Draft for the EP. A design, not an implementation. Encounter Systems, Audio, UI/UX and Localization each own a piece of it, so the hand-offs are listed at the end.

**What Orb asked for.** Text lines on screen, carried by each character's own grunts, growls and laughs. A very large pool of one-liners, taunts and reactions that depend on many variables. Barks during play, plus short pauses at set pieces. No voice acting.

**The idea in one paragraph.** A line is a small object: a trigger, a set of conditions, some text, and a vocal cue. Each fighter owns a voice: a lexicon and a set of sentence shapes. The game emits **events** carrying a bundle of **tags** (who, where, how hurt, how proud). A selector finds the lines whose conditions match, favours the most specific, penalises what it has just said, and plays it with a grunt. A **template layer** with slots lets a few hundred authored pieces make thousands of lines, all in voice.

## 1. Triggers

Each event is emitted by the sim and read by the line system. The line system never writes sim state, and it uses its own seeded RNG stream so replays show the same lines (rendering reads the sim and never writes it).

| Family | Events (examples) |
|---|---|
| **Match** | match start, first blood, seven-minute mark, stalemate (no damage for N seconds), comeback, near KO |
| **Exchange** | hit landed (by location), heavy hit, launch, parry, guard break, chain of N, pursuit caught or slipped, clash, charge interrupted |
| **Beams** | signature fired, hit, dodged, escaped, beam clash, beam struggle won or lost |
| **World** | structure destroyed, civilians lost (by threshold), crater, first fire, entering a place, day to night, weather change, altitude (space), mantle eruption, planet destroyed |
| **State** | an ego meter crossing a line (Respect, Pride, Wrath, Hunger), transformation start, interrupted, completed, reverted, a drain state |
| **Fighter-specific** | orb picked up, held, scattered (Protagonist); a fusion beat (Anti-hero); a goon falls, a revision (Tyrant); a civilian consumed, a portal used, the backup drive chased or docked (Cyborg) |
| **Set pieces** | finisher, KO, revive, relocation, final form reveal. These pause the fight and may run 3 seconds or more |

## 2. Variables

Every event carries a tag bundle. A line's `when` block tests any of them.

- **Speaker and target:** who, which fighter, human or AI, in 1v1 or 2v2, partner or opponent.
- **Ego meters** (Respect, Pride, Wrath, Hunger) for the speaker and the target, as levels 0 to 3.
- **Body:** location hit (head, torso, arm, leg), locations already damaged, and how many.
- **Form:** the speaker's stage or revision, the target's stage, transformation state.
- **Space:** distance, altitude, place name and biome, day or night, weather.
- **Collateral:** civilians lost, structures lost, and how much of each just now.
- **Flow:** chain length, who leads, the match phase (opening, middle, late), the last event, the last line spoken and by whom.
- **History:** how often this trigger has fired, and "memory facts" for callbacks (first structure destroyed, where the opponent fell, how often the head has been hit).
- **Rivalry pair:** a two-fighter tag, so the Protagonist and the Anti-hero can have their own lines in a mirror or an ally pairing.

## 3. Selection and anti-repetition

1. **Candidates.** All lines for the trigger whose `when` passes. If none pass, fall back to a generic line for that trigger. Every trigger must have at least one fallback per fighter (a lint rule).
2. **Score.** `weight × specificity × novelty × mood`.
   - *Specificity*: the number of matched conditions. A line that fits six facts beats one that fits one.
   - *Novelty*: a decay that rises with recency. Every line has a cooldown; every template family has a shorter one; every slot value is penalised if used in the last N lines; every word bigram is lightly penalised.
   - *Mood*: a fit against the ego meters, so a high-Wrath fighter growls more than he quips.
3. **Pick.** A weighted random draw from the top few, using the narrative RNG.
4. **Budget and priority.** A bark queue with priorities: finisher, transformation, set piece, reaction, ambient. A fighter speaks at most one line at a time. During intense stretches the system speaks less. Silence is a feature. A higher priority can cut a lower one off.
5. **Memory.** Each fighter records what he has said this match. Callbacks ("Told you about the {thing}") only fire if the fact is on record.
6. **Jewels.** Hand-authored lines can be marked `once_per_match` or `once_per_session`, so the best lines land as events, not wallpaper.

## 4. Pairing grunts with text

Each fighter has a **grunt bank**: gestures like `effort.light`, `effort.heavy`, `pain.head`, `pain.limb`, `laugh.short`, `laugh.long`, `laugh.cruel`, `growl`, `scoff`, `sigh`, `gasp`, `roar`, `munch`. Each has several clips, an intensity range and a mood tag.

- A line carries **cues**: at a character offset, play a gesture at an intensity. Most lines have one cue at the start. A longer line can have two, on clause breaks.
- The engine picks a clip that matches the gesture, the intensity and the mood, and varies pitch and tempo slightly, so the same gesture never sounds identical.
- The text speed follows the intensity, and punctuation gives the pauses. A laugh before a line changes how it reads: the same words after `laugh.cruel` and after `sigh` mean different things. That is how a line "evokes emotion" without a voice actor.
- Where there is no sound (muted, or a deaf player), captions carry the gesture: `[short laugh]`. That is an accessibility requirement, not an option.
- The bank can be synthesised or recorded. That is a call for Audio (Orb allows procedural and AI-generated assets).

## 5. Making thousands of lines that stay in voice

**Shared skeletons, voice-owned lexicons.** A skeleton is a sentence shape, like *observation, judgement, button*. The lexicon belongs to one fighter and holds his address words, verbs, intensifiers and jokes. Two fighters never share a bank, so the same skeleton sounds different.

- **Slots** are typed: `{part}` (a body location), `{thing}` (a structure kind), `{place}` (a place name), `{count}`, `{opp_addr}` (how he addresses his opponent), `{callback}`.
- **Compatibility tags** stop nonsense: a value for a head hit will not fill a leg slot.
- **The count.** A conservative estimate for one fighter: about 40 triggers, about 6 templates each, and about 100 valid slot fills per template gives well over **20,000 distinct lines**. With compatibility filters removing two thirds, still thousands. Add about **150 authored jewels** per fighter for the moments that matter.
- **Voice guardrails.** Each voice has a banned list (words and structures it never uses), a tense rule (the Protagonist speaks in the future, the Anti-hero about his opponent in the past), and a length range.
- **A lint step.** Every build generates 200 random lines per fighter and checks tense, length, banned words and grammar. A human reads a sample each release.
- **Legal.** Jewels get the boldest lines searched in quotes (the originality checklist). Template output stays inside lexicons that were reviewed once.
- **Translation.** Slotted sentences break in languages with agreement. Localization should ship fully formed jewels in every language and decide, per language, how much of the template layer to keep.

## 6. Data format

Path: `data/fighters/<id>/lines.json` and `grunts.json` (both inside Narrative's owned paths), read by the game at load. Schema version 1, subject to Tools and Encounter Systems.

```json
{
  "schema": 1,
  "fighter": "protagonist",
  "voice": { "tense": "future", "banned": ["insect", "fool"], "len": [2, 14] },
  "lexicon": {
    "opp_addr": ["mate", "champ", "friend"],
    "part": { "head": ["skull", "face"], "arm": ["arm", "fist"], "leg": ["leg", "knee"] }
  },
  "lines": [
    {
      "id": "prot.lure.001",
      "trigger": "lure_start",
      "priority": 2, "weight": 1.0, "cooldown_s": 90,
      "when": { "place_pop_near": ">0.2", "opp.ego.pride": ">=2" },
      "text": "Not over {place}. Follow me out onto {sea}.",
      "cues": [{ "at": 0, "gesture": "effort.light", "intensity": 1 }],
      "tags": ["earnest", "future"]
    }
  ],
  "templates": [
    {
      "id": "prot.hit_taken.t1",
      "trigger": "took_hit",
      "skeleton": ["{obs}", "{judge}", "{button}"],
      "banks": { "obs": "hit.obs", "judge": "hit.judge", "button": "hit.button" },
      "cooldown_s": 25
    }
  ],
  "banks": {
    "hit.obs": [
      { "text": "Ha! My {part}.", "when": { "part": ["arm", "leg"] } },
      { "text": "Ow. Fair.", "when": { "intensity": "<=1" } }
    ]
  }
}
```

`grunts.json`:

```json
{
  "fighter": "protagonist",
  "gestures": {
    "laugh.short": { "clips": ["prot_laugh_s_01", "prot_laugh_s_02"], "intensity": [0, 2], "mood": ["delight"] },
    "effort.heavy": { "clips": ["prot_eff_h_01"], "intensity": [2, 3] }
  }
}
```

Conditions are simple predicates on the tag bundle: equality, membership, numeric comparison. Triggers are a closed list in one file, so a typo fails a lint check.

## 7. The four voices

The Warden and VORR were prototype placeholders. I carry the tense device forward like this (an assumption for the EP to confirm): the Protagonist keeps the **future tense** (promises), the Anti-hero speaks about his opponent in the **past tense** (a dismissive obituary), the Tyrant refers to himself by **revision number**, and the Cyborg speaks in **customer-service politeness** over an appetite. All he/him. No catchphrases from any source.

| Fighter | Voice | Grunts |
|---|---|---|
| **The Protagonist** | Earnest, delighted by the fight, plain words, promises, oblivious about collateral until it is late. | Hearty efforts, a delighted laugh, a wince. |
| **The Anti-hero** | Brooding, clipped, ranks people, talks about the opponent as already finished. | Low growls, a sneer's exhale, rare and cold laughs. |
| **The Tyrant** | Confident, leering, boastful, quick to anger; revision numbers as a tic; sneering at his goons. | A wheezing cackle, a snort, an escalating shriek. |
| **The Cyborg** | Polite, corporate, hungry; sandwich and order language; glitches when hit on the chip. | Static-tinged growls, munching, a digital chirp. |

## 8. Sample lines (10 per fighter, original)

Each line shows its trigger and its first cue. Some are jewels; some are template output.

### The Protagonist

| # | Trigger | Line | Cue |
|---|---|---|---|
| 1 | match start | "Good. You came. Now show me everything." | effort.light |
| 2 | heavy hit landed | "There it is! I'll remember that one." | laugh.short |
| 3 | took a hit (arm) | "Ha! My arm. I'll need that later." | wince |
| 4 | structure destroyed | "Sorry about the {thing}! I'll fix it after." | laugh.short |
| 5 | opponent's Respect rises | "Now you're really fighting me. Thank you." | sigh |
| 6 | orb picked up | "Got one. Hold that thought, we're moving." | effort.light |
| 7 | late and losing | "I've been holding back on your behalf. Not anymore." | growl |
| 8 | beam dodged | "Missed me! I'll hit you next time." | laugh.short |
| 9 | transformation starts | "Give me a second. It's a long one." | effort.heavy |
| 10 | KO won | "Best fight of my year. Rest. I'll carry you home." | laugh.long |

### The Anti-hero

| # | Trigger | Line | Cue |
|---|---|---|---|
| 1 | match start | "You were something once. Let me see what's left." | scoff |
| 2 | hit landed | "Fourth. You rank lower with every breath." | sneer |
| 3 | took a hit (head) | "You touched my face. You were alive a moment ago." | growl |
| 4 | long fight | "This could have ended ages ago. It ends when I say." | sigh |
| 5 | Pride high | "Bow. It's the only thing you'll do right today." | scoff |
| 6 | partner revive (2v2) | "I didn't ask. ...Give it here." | growl |
| 7 | structure destroyed | "Nobody will remember that {thing}. Or you." | scoff |
| 8 | Wrath high | "Stay down. You're a story I've already finished." | growl |
| 9 | transformation starts | "Regalia. Now you'll know who was watching." | roar |
| 10 | finisher | "You were adequate. That is the highest thing I say." | sigh |

### The Tyrant

| # | Trigger | Line | Cue |
|---|---|---|---|
| 1 | match start (goons) | "Go on, boys. Warm him up. I'll be along, Revision One and half asleep." | cackle |
| 2 | goon falls | "Fine. I'll do it myself. Revision Two, if you please." | snort |
| 3 | sniping support | "Hold still. It's a precision matter." | cackle |
| 4 | took a hit | "You hit me! Do you know what revision this is?" | shriek |
| 5 | Wrath high | "That's the last time you'll do that in this revision!" | shriek |
| 6 | joke revision | "Revision Four. It's the same, but I've added a hat." | cackle |
| 7 | opponent hurt | "Ohoho. Cute. Cute!" | cackle |
| 8 | cutting beam | "One straight line. Try not to be on it." | snort |
| 9 | structure destroyed | "Redecorating. You're welcome." | cackle |
| 10 | finisher | "Final Approved Revision. Sign here." | cackle |

### The Cyborg

| # | Trigger | Line | Cue |
|---|---|---|---|
| 1 | match start | "Welcome. Your order is you." | chirp |
| 2 | civilian consumed | "Mm. Crunchy. Five stars." | munch |
| 3 | Hunger high | "Sorry. I skip lunch when I'm working." | growl |
| 4 | portal used | "Order up. Please stand clear of the counter." | chirp |
| 5 | sandwich pickup | "Extra pickles. Structural integrity, plus twelve percent." | munch |
| 6 | backup drive chase | "Backup! Heel!" | chirp |
| 7 | chip hit | "Not the chip! Anything but the chip!" | static |
| 8 | molt | "One moment. Under new management." | growl |
| 9 | opponent hurt | "You'll keep. I'll be back with a container." | munch |
| 10 | finisher | "Your order has been fulfilled. Please rate your experience." | chirp |

## 9. Hand-offs

- **Encounter Systems:** the event list in section 1 and the tag bundle in section 2. The line system reads them; it never writes sim state.
- **Audio:** the grunt banks, the clip counts, and the choice between synthesis and recording.
- **UI/UX:** the line display (speaker, duration between 1.2 and 3.5 seconds for barks, longer for set pieces), captions for gestures, and a speed setting.
- **Localization:** template layer or jewels only, per language, and the tense devices.
- **Tools:** the JSON schema and the lint step.
- **Legal:** the boldest jewels are searched before they ship.
- **Accessibility:** captions, speed, and the volume of the bark budget.

## 10. Matchup and stakes tags (added 2026-09-29)

Orb: lines should change with who faces whom. A line can now key on the pairing, the stakes, and the register between the two.

**New tags on every event.**

| Tag | Values | Meaning |
|---|---|---|
| `matchup` | an ordered pair such as `protagonist>anti_hero`, or a wildcard such as `protagonist>*` and `*>tyrant` | Speaker, then opponent. Mirrors are `protagonist>protagonist`. |
| `stakes` | `sparring`, `rivalry`, `grudge`, `world_at_stake`, `appetite` | What is on the line. Comes from the matchup table in `matchups.md`, and can change mid-fight (for example when a planet is threatened). |
| `register` | `playful`, `respectful`, `contemptuous`, `grim`, `leering`, `polite_menace`, `disgusted`, `competitive` | How the speaker is talking to this opponent right now. Starts from the matchup default and shifts with the fight. |
| `shift` | `winning`, `losing`, `brink`, `transformed`, `in_fold` | Where the fight is, which moves the register. |

**How they are used.**
- **Selection.** `matchup` and `stakes` count as conditions. A line that fits the exact pair beats one that fits `*`. A line with a matching `register` gets a mood bonus. The fallback chain is: exact matchup, then wildcard matchup, then stakes, then the fighter's general line.
- **Register data.** Each fighter has `data/fighters/<id>/registers.json`: for each opponent, a default register and the shift rules.
- **Fold.** The `in_fold` shift only exists for matchups that include the Protagonist.

```json
{
  "id": "prot.fold.vs_tyrant.001",
  "trigger": "fold_arrival",
  "priority": 3,
  "when": { "matchup": "protagonist>tyrant", "stakes": "world_at_stake", "shift": "in_fold" },
  "text": "We can't hurt anyone innocent here.",
  "register": "grim",
  "cues": [{ "at": 0, "gesture": "sigh", "intensity": 2 }]
}
```

```json
{
  "fighter": "protagonist",
  "registers": {
    "anti_hero": { "default": "respectful", "shifts": { "winning": "playful", "losing": "respectful", "brink": "grim" } },
    "tyrant":    { "default": "grim",       "shifts": { "winning": "grim",    "losing": "grim",       "brink": "grim" } },
    "cyborg":    { "default": "grim",       "shifts": { "winning": "grim",    "in_fold": "grim" } },
    "protagonist": { "default": "playful",  "shifts": { "brink": "grim" } }
  }
}
```

**A lint rule.** Every fighter has a general fallback for each register, and every matchup has at least one line per shift, so no matchup goes silent.
