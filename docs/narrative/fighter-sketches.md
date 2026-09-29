# Fighter sketches: the Hero and VORR

Owner: Narrative and Fighter Identity. Version 1, 2026-09-28 (P0 wave 1). A first sketch for the EP, not canon until Orb confirms tone and names.

- The hero's name is open (KAI is a no-go; candidates are in `hero-name-longlist.md`), so this file says "the Hero".
- VORR stays as the working name for the villain (Legal RL-003).
- Orb's answer on tone is pending. The core voice below works in every tone. Section 6 gives a line per tone so Orb can hear the difference.
- The Hero's gender is not decided. I use they/them until Orb or Art decides.
- Numbers in section 4 are proposals for Encounter Systems and Game Design, who own the final scoring and mechanics. Nothing here is implemented. I have not created `data/fighters/*.json`; the Tools schema comes first.

## 1. The idea in one paragraph

The two fighters sit at opposite ends of one axis: what they do with consequence. The Hero tends things. VORR mourns them in advance. You can hear it in grammar. The Hero speaks in the future tense ("I'll fix it", "I'll be back with hands"). VORR speaks in the past tense about things that are still standing ("It was a lovely harbour"). That one habit gives a viewer the personality after a single beat, and it belongs to nobody else.

The player should be able to read either fighter within about a minute, from four tells: where they take the fight, what they do when something falls, how they use cover, and what they say.

## 2. The Hero

**Role.** A Warden: an office, not a birthright. Someone who looks after the land and knows it by name. (The prototype title "Meridian Warden" stays for now; both words may change with the game's name.)

**Values.** Keeping promises. Repair over victory. The small and specific over the abstract: "that roof", not "the people".

**Ego.** Pride in being the careful one. The Hero believes that if anything falls, it is on them. The flaw is martyrdom: they refuse help, over-carry, hide fear behind competence, and cannot enjoy a win if anything was lost.

**Fears.**
- Becoming the crater with their name on it: winning a fight and losing a place they can never get back.
- Choosing speed over care, once, at the wrong moment.
- That their strength is only a slower way of breaking things.

**Voice.** Plain, measured, dry. Short sentences and concrete nouns: a roof, a road, a harbour. Names places. Speaks in promises and the future tense. Gentle to bystanders, blunt to VORR. Humour, when there is any, is dry and aimed at themself.

**Under anguish.** Quieter, not louder. Lines get shorter. At the peak, a cold fury aimed at the destroyer, never at the ruins.

**What they do to the world.** Fewer craters. They lure fights toward ocean, desert and open ground, and they step between a blast and a town.

**Contrast cues for Art (identity level only).** Grounded, low centre of gravity, open posture, reaching toward things; something worn or carried that reads as a keeper's kit, not armour. Colour and hair are Art's call; the prototype's gold hair is a legal flag (RL-014) and must not carry over.

## 3. VORR

**Role.** The Sovereign, in title only (the prototype's "Calamity Sovereign"). VORR's authority comes from taste and patience, not rank or lineage. VORR sees themself as the world's witness at the end, not its destroyer: "I don't break things. I finish them."

**Values.**
- Finality. Ruin is the only honest permanence; anything kept alive by upkeep is pretending.
- Attention. A thing is only truly ended when someone watches it end.
- Taste. VORR only mourns what was made well: harbours, boulevards, villages. Open ocean and empty desert hold nothing worth losing.

**Ego.** VORR needs a witness. Destruction nobody sees is waste, so VORR wants the Hero to look, and will wait for it. The vanity is aesthetic supremacy: only VORR really sees the world, and everyone else is busy maintaining it.

**Fears.**
- Repair. Being undone, watching the Hero rebuild what was finished.
- A world that outlasts them, or the quiet after, with nothing left to lose interest in.

**Voice.** Unhurried, courteous, warm. Speaks in the past tense about what still stands. Never shouts. Compliments the thing they are about to take. Calls the Hero by their office. The politeness is about the place, never about VORR's rank; there is no royal formality and no speech about being strongest.

**What they do to the world.** Seek populated ground, fire along boulevards, pause over wreckage, and wait in cover for the Hero to tire from saving people.

**Contrast cues for Art (identity level only).** Composed and vertical, hands still, one sweeping line. Stands at rest while others move. Nothing spiky, pale, horned or crowned (originality rules).

## 4. How identity maps to the director

### 4a. What already exists in the prototype (values read from `prototype/index.html`)

| Hook | Hero | VORR | Where |
|---|---|---|---|
| `care` (launch scoring: score += -care x 34 x population near the landing) | +1.0 | -0.8 | `chooseLaunch` |
| Gain per casualty | anguish +0.5 (+0.9 if the Hero caused it) | menace +0.9, power +0.09 | `casualty` |
| Damage modifier | up to x1.5 at low HP (comeback) | up to x1.25 at full menace | `hit` |
| Recovery | regen falls with anguish; anguish decays 0.6 per second | regen rises with menace | `stepFighter` |
| Luring the fight away from populated ground | on, when population near is above 0.2 | none | hard-coded in `aiInput` |

Recommendation: the lure is a personality trait, not a hero-only rule. It should read from data like the rest.

### 4b. Proposed personality weights (starting values, all tunable)

| Weight | Hero | VORR | What the viewer sees |
|---|---|---|---|
| `care_for_civilians` (today's `care`) | +1.0 | -0.8 | The Hero's launches and beams drift over ocean and desert. VORR's land on cities. |
| `lure_when_pop_near_above` | 0.20 | none | The Hero drags the fight out of the city unprompted. VORR never does. |
| `stance_bias` (aggressive, defensive, evasive, escape) | 0.9, 1.4, 1.1, 0.7 | 1.4, 0.7, 0.8, 1.1 | The Hero holds ground and slips away. VORR presses. |
| `hide_wait_before_ambush_s` | 1.8 | 3.0 | VORR's ambushes land with the full bonus and feel patient. |
| `hide_abort_on_casualty` | true | false | The Hero bursts out of cover when something falls. VORR stays hidden. |
| `interpose_willingness` (new) | 0.8 | 0.0 | The Hero takes a hit meant for a town. |
| `savour_pause_s` (new) | 0.0 | 0.6 to 1.2, scaled by the last beat's casualties | VORR stops to look, and can be punished for it. |
| `witness_seek` (new) | 0.0 | 0.7 | VORR delays a signature until the Hero is in view of the wreckage, up to about 1.5 s. |
| `hesitation_near_pop` (new, risky) | at high anguish, wind-ups near populated ground run 0.15 to 0.4 s longer | 0.0 | The Hero pulls punches near people. VORR can exploit it. |
| `signature_variant_bias` | penalise variants that cross populated ground | reward them | Same term as `care`, applied to beam variants. |
| `barks_per_minute` | 2 to 3, event-triggered | 3 to 4, event-triggered | Lines fire on events, never on a timer (section 6). |

`hesitation_near_pop` is the risky one: it makes the Hero worse in exactly the places the player most wants them to fight well. Game Design should decide whether anguish is a pure penalty (as today) or a two-sided pressure.

### 4c. What the debug feed should show

The charter says the weights must be visible. My suggestion is that each personality term appears as its own line in the scored candidates, and non-scored choices get a `persona` line, so anyone can see why a fighter acted in character:

```
SLAM DOWN 61.2 = base 40.1 + variety -4.0 + noise 3.3 + persona[care +1.0 x pop 0.62 x -34 = -21.1]
persona Hero lure: pop_near 0.62 > 0.20, heading to x=3100
persona VORR savour: 3 casualties, pausing 0.9 s
```

Encounter Systems owns the format. This is only what Narrative needs to see.

## 5. Ego-based abilities: first ideas for Game Design

These make the two ego loops into things a player can play, not only see.

**The Hero: Interpose.** When a beam or launch is aimed across populated ground and the Hero is close enough, they can step in front. They take the hit (reduced by stance) and the collateral is cancelled. It costs HP and sheds anguish. VORR's counter is to aim through a village behind the Hero, on purpose, to force it. That is a story the systems tell without a script (pillar 6). Suggest it is player-triggered with a director-assisted window, so the director never overrides player intent.

**The Hero: Resolve.** The comeback multiplier already exists. Suggest it becomes a visible state change (voice, animation, aura) when anguish is high and HP is low: the Hero has stopped being careful. Art and Audio decide how it looks and sounds.

**VORR: Savour.** After a collapse, VORR may spend up to about a second taking it in. It converts a burst of menace into power, and it leaves the guard open. The AI does it automatically. A human playing VORR can choose to skip it. That turns menace into a risk-and-reward loop and not just a buff.

**VORR: Foretell.** Before a signature that will cross populated ground, VORR names the target aloud (one short line, about a second). That is a fair telegraph: the Hero can intercept it, or lure the fight away.

Open questions for Game Design, through the EP:
1. Is anguish only a cost, as it is today, or can it also power the Hero?
2. Should menace ever cost VORR something? Savour is my proposal.
3. Is Interpose automatic, or a decision the player makes?

## 6. Sample lines (all original)

Barks fire on events (a launch near a town, a collapse, a KO), never on a timer. VORR's lines lean on the past tense, the Hero's on the future.

**The Hero, core voice**
1. Leading the fight away: "Not over the harbour. Follow me out where the water can take it."
2. After a structure falls: "That was somebody's roof. I'll be back with hands."
3. On winning: "It's over. The work isn't."

**VORR, core voice**
1. Aiming a signature at a town: "Such a lovely harbour. Someone should have said so while it stood."
2. Savouring a collapse: "There. Now it's finished, and nobody can make it worse."
3. To the Hero mid-fight: "You are so busy mending, you never look. Look."

**Tone dial** (one line each, so Orb can hear the difference)

| Tone | The Hero | VORR |
|---|---|---|
| Earnest epic | "Every roof I stand over is a promise, and I keep mine." | "Stand aside, Warden. Some things are only made true by ending." |
| Heroic with humour | "I'd say mind the roof, but you're already through it." | "Don't mind me. I'm only admiring the ruins-to-be." |
| Comedy | "Sir, that was a working city. It had a bus." | "Lovely town. Terrible parking. Was." |
| Dark | "Count them for me. I'll want the number when this is done." | "Listen. How quiet it has become. I did that gently." |

## 7. The one-match test

"A player can guess a fighter's personality from one match" is a Done-when for this role. If the weights work, a viewer should be able to say these things after a minute:

| What the viewer sees | What they conclude |
|---|---|
| The fight drifts to the sea before the first beam. A hero steps in front of a village. | This one cares, and pays for it. |
| The fight stays in the city. A beam runs the length of a boulevard, then the fighter stops to look. | This one enjoys it, and wants to be watched. |
| A fighter vanishes into forest cover, waits, then strikes with full weight. | Patient, and a hunter. |
| A fighter bursts out of cover the moment something collapses. | Cannot stand by. |
| The same words in the past tense about a place still standing. | That is VORR. |

Playtest note for QA: this is a hypothesis to test with real viewers, not a result.

## 8. What I steered away from

- Fighters as jobs and attitudes, not species. No shared lore with the franchise: no afterlife, no tournaments, no wish-granting objects.
- The Hero is not a cheerful newcomer who fights for the love of it, and has no transformation by hair colour.
- VORR is not an emperor by rank, not pale, not horned, and gives no speeches about being the strongest.
- No scanner-style readouts of anyone's power.
- Speech habits are grammar (tense), not catchphrases. I searched none of the sample lines; Legal's checklist says to search the boldest lines in quotes before they ship, so please route the bark sheet through Legal when it exists.

## 9. Room for the other two fighters

The Hero and VORR are set on the axis of consequence. The two planned fighters should sit on different axes, so the roster contrasts in play and tone and not just in colour. Two candidates: a relationship to the audience (a showman against a recluse), and a relationship to their own power (afraid of it against hungry for it). No decisions yet.
