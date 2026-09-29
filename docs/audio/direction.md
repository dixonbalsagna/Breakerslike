# Sound direction for Orb Combat EX

Owner: Audio and Music. Version 1, 2026-09-29. A pitch and a plan for the EP and Orb, not a locked spec. Orb said "Music: let Audio pitch", so section 3 is a choice for Orb. The rest is my recommendation. Nothing here is composed yet; the only sound that exists is the prototype in `audio/` (see `audio/README.md`).

This replaces the four wave-1 documents (SFX catalogue, adaptive music, mix, sourcing). What still fits is folded in: the mix rules (section 6), the sourcing options and licence handling (section 8), the adaptive plan (section 4) and the cue sources (section 9). The full event-by-event SFX catalogue waits for the Wounds events to exist (section 9).

The grunt palettes and how to make them for free are in `grunts.md`.

## 1. What Orb decides

Orb answered on 2026-09-29 (through the EP): music is chosen by ear from the three sketches (`audio/preview/`); grunts are synthesis first, with Orb possibly recording laughs and the munch later; AI-generated audio is allowed once Legal clears the specific tool's terms; the wear and heat audio is on by default with a slider; the 2D-panning default stands. Row 1 is therefore still open, and the rest are settled. The table keeps the original defaults for reference.

| # | Question | My default if Orb says nothing |
| :--- | :--- | :--- |
| 1 | Which music direction (section 3): A The Town Band, B Furnace, C Kitchen Drums | A, with C's found-sound percussion, and B as the fallback that code alone can make |
| 2 | Where the grunts come from: synthesis only, Orb's own recordings, or both | Synthesis first (it works today); Orb records the laughs and the munch later if they want more realism |
| 3 | May AI-generated audio ship? (`vision.md` says AI assets are allowed; `licence-recommendation.md` 8.5 asks Orb to decide for audio) | No AI-generated audio in the first sound bank. Legal has to read a tool's terms first, and grunts define characters, which the licence advice says need real human authorship |
| 4 | Spatial sound for the 2.5D side view | 2D panning by on-screen position and wrap-aware distance (what the prototype does) |
| 5 | Is the wear-and-heat audio (breathing, heartbeat, kettle) on by default? | On, with a slider, and never the only channel |

Please also listen to `audio/preview/` (or run the demo) and tell me whether the impact weight and the grunt are on the right track. I checked them with numbers, not ears.

## 2. Principles

1. **Weight before beauty.** Every hit has a snap, a body and a tail. Bigger means lower, longer and later to fade (pillar 4). A crater is a deep, slow crash; a jab is a short knock.
2. **The land answers.** Destruction has its own voice: things crack, slide, burn, flood and go quiet afterwards (pillars 4 and 7). The score reacts to the wreckage too (section 4).
3. **Hear the fight with your eyes shut.** Each gameplay event has its own sound, and the states that matter (a region breaks, someone is on the brink, a transformation starts, someone hides) are audible. No sound is ever the only channel: captions and visual cues carry the same information (Accessibility).
4. **Silence is an instrument.** The respected cinematics are held breaths. The fold ends in a hush. The proving ground is bare and dry.
5. **Original by construction.** Synthesised, or recorded by us, or a CC0 or CC BY source logged for Legal. Moods are described in words, never "in the style of" a named track. No shouted attack names and no voice clips.
6. **The tone is all four at once** (`vision.md`): graphic sound (wet, heavy, unflinching), a humorous voice (contrast: a tuba under a planet-cracking blast, a kettle at the top of a transformation) and sincere melody. Humour lives in the orchestration and the barks, not in cartoon sound effects.

## 3. Three music directions

Reference moods are described, not named. Each direction has the same job: follow the match arc in section 4 with tempo-locked layers, so it can escalate within a seven-minute fight.

### A. The Town Band (recommended)

- **The mood.** A small-town brass band on a bandstand at dusk: warm, a little out of tune, sincere. Then the fight arrives.
- **The idea.** The band is the town. Its sections drop out as civilians are lost, so collateral is audible (pillar 4) and the loss is felt, not counted. Each 20% of the population lost silences one section of the bed: high winds, brass, low brass, mallets. By the late match only the tuba and a drum are left, with the planet's own drone underneath. It is funny and sad at once.
- **Palette.** Euphonium, tuba, cornets, trombones, clarinets, piccolo, snare and bass drum, glockenspiel. Later: overdriven brass, low choir "oo", big drums, stone and metal percussion.
- **Personalities in the score** (pillar 5). The hero is pressured by wreckage: as damage mounts, the warm bed detunes and thins, leaving a lone cornet. The villain feeds on it: a chromatic low-brass line grows under the same music.
- **Fighter colours.**
  - The Protagonist: a warm cornet or flugelhorn line built on rising fourths that end open, because he speaks in promises and the phrase is finished later. Sincere.
  - The Anti-hero: a solo cello or bassoon, dotted, rigid, exactly on the beat. When his facade cracks, the rhythm loosens and a breath enters. That is the audible tell.
  - The Empress: a pompous parade of piccolo, snare and accordion wheeze. Every revision adds an instrument (the hat is a slide whistle). The Encore is a full snare cadence and fanfare.
  - The Cyborg: corporate hold music on electric piano, marimba and a soft pad, stuttering and glitching. Each molt is a "system update": a new timbre and a chime.
- **Funny and sincere.** The comedy is the contrast between the music's politeness and the destruction. The sincerity is the melodies, played straight.
- **Making it for free.** Compose in a free sequencer and render with CC0 sampled instruments (section 8), or synthesise in Godot for a rougher cut. The percussion layer can be found-sound (direction C).
- **Risk.** It needs a tune-writer with a good ear. If nobody with that ear is available, it drifts towards direction B.

### B. Furnace

- **The mood.** A night-shift foundry and a low-ceilinged club: hot metal, pistons, steam.
- **Palette.** Analogue-style synth bass, pulse leads, gated drums, anvil and pipe hits, sequenced 16th arpeggios, bit-crushed textures.
- **Escalation.** Filters open, distortion rises, arpeggio density doubles, the kick goes half-time at tier 3 so power feels heavier.
- **Fighter colours.** The Protagonist: a warm pad over an analogue pulse. The Anti-hero: a cold FM bell and a rigid sequence. The Empress: a baroque synth-harpsichord "court" over hard beats. The Cyborg: chiptune and glitch.
- **Funny and sincere.** Deadpan mechanical fussiness for the humour; sincerity depends on the melodies, which are harder to make heartfelt on synths.
- **Making it for free.** The only direction that code alone can make: a synth voice and a step sequencer in Godot, all ours. Cheapest and most deterministic.
- **Risk.** It sounds "gamey" and less emotional, and it is the most crowded genre sound, so it needs care to be distinctive.

### C. Kitchen Drums (found-sound percussion)

- **The mood.** A household in an earthquake: pots, pans, a kettle, cutlery, crates, stones, bowed glasses and human breath, played big.
- **Escalation.** The objects get bigger with the tiers (saucepan, then oil drum, then girder). Layers are added by rhythm and density more than by melody.
- **Funny and sincere.** The humour is the object (a saucepan lid at a beam clash). The sincerity is a simple hummed tune.
- **Ties to the game.** The Protagonist's heat track is literally a kettle and a heartbeat; the Cyborg's kitchen is his weapon.
- **Making it for free.** Orb records a kitchen with a phone. Cheapest in money, but it needs Orb's time, and Orb's room and voice end up in a public repo.
- **Risk.** Little melodic identity; recording quality varies; it may not feel epic without a melody on top.

### Recommendation

**A, built on C's percussion, with B as the fallback.** A gives the game an identity that fits its two big ideas (the world answers; collateral has a cost) and is the most original. C makes A's percussion cheap and personal. B is what I can make with no other person and no third-party file, so it is the safe floor. Orb asked for sketches, so they exist: `audio/preview/sketch-a-town-band.wav`, `sketch-b-furnace.wav` and `sketch-c-kitchen-drums.wav` (30 s each, one shared arc and tune, see `audio/README.md`). All three are synthesised stand-ins, so judge the mood, the arrangement and the escalation, not the instrument realism: A's brass wants sampled brass and C wants real recordings.

## 4. The adaptive score

One tempo, one grid, stems that come and go. Everything below is direction-agnostic: the stems are roles, and A, B or C fill them.

**Time base.** 96 BPM, 4/4: a beat is 0.625 s, a bar is 2.5 s. The heartbeat in the heat track steps 96, 120 and 144 BPM (Heated, Simmering, Boiling), which is 4:5:6, so it always lines up with the bar. Escalation comes from density and orchestration, not tempo. At tier 3 and above the drums go half-time.

**Key and mode.** The planet has one root, D. The mode darkens with the highest tier on the field: tier 1 Dorian, 2 Aeolian, 3 Phrygian, 4 Phrygian dominant. Each fighter's motif keeps its own colour on top (the Protagonist's fourths, the Anti-hero's dotted rhythm) and rises a step at that fighter's transformation.

### 4.1 What drives it

All of these are read from the sim and never written (section 9 lists the events I still need).

| Driver | Source |
| :--- | :--- |
| `tier` | the higher `fighter.tier` of the two (1 to 4) |
| `collateral` | civilians lost as a fraction: `S.world.casualties / pop0` (0 to 1) |
| `breaks` | region breaks so far in the match (each one is a chapter, `spec-wounds.md` section 1) |
| `brink` | either fighter on the brink |
| `edge` | the higher of the destruction rate over the last 10 s and the leading fighter's ego meter (Respect, Pride, Wrath or Hunger, scaled 0 to 1) |
| `heat` | the Protagonist's heat stage, 0 to 3 |
| `state` | normal, hidden, cinematic (a transformation, Drop the Act, a finisher), fold, proving ground, encore |

### 4.2 The stems

| Stem | Role | Enters | Exits | Fade |
| :--- | :--- | :--- | :--- | :--- |
| S0 Ground | Drone on D and room tone; the planet's voice | Always | Never; alone in the proving ground's opening seconds | n/a |
| S1 Pulse | Low percussion, the march or beat | After the first exchange | `state` = cinematic or hidden (drops to a heartbeat) | in 1 bar, out 2 bars |
| S2 Town | The warm bed (A: the band; B: pads; C: tuned objects) | `collateral` < 0.8 | Sections leave at `collateral` 0.2, 0.4, 0.6 and 0.8; gone in the proving ground | out 2 bars per section |
| S3 Motif | The leading fighter's theme. Only the fighter with the initiative plays; it changes on the beat when the lead changes | Start of the first exchange | On the brink it thins to a solo | 1 bar cross |
| S4 Edge | The dark layer: villain menace, a chromatic ostinato | `edge` > 0.5 | `edge` < 0.3 for 8 s | in 1 bar, out 4 bars |
| S5 Wound | Chapter texture: a tense rhythmic figure. One variant per chapter, so each break "turns a page" | First region break | Replaced, never removed; on the brink it becomes a suspended pedal that does not resolve until the finisher contest is decided | in 1 beat |
| S6 Body | Heartbeat and breath, locked to the bar | A region is battered, or heat > 0 | Both fighters fresh again | in 1 bar |
| S7 Peak | Full ensemble and choir | `tier` 4, a finisher, the planet-destruction run | The stinger after the KO | in 2 bars |

Changes are quantised to the next beat, or to the next bar for an entry. Stingers are the exception: they fire in the tick of the event and snap to the next 1/8 note (78 ms) at most.

### 4.3 The match arc

| Moment | What the score does |
| :--- | :--- |
| Overture (before the first exchange) | S0 only, then S1 enters after the first exchange. The band is warming up |
| Act I (fresh) | S0, S1, S2, S3. A light, warm march. Tier-ups move the mode |
| A region breaks (a chapter) | The score drops out to S0 for one beat, then re-enters with a new S5 variant: the break launch is accented, the chapter sting is one big hit with a short tail |
| A transformation (respected cinematic, 2 to 3 s) | Duck to S0 in 100 ms, a rising "inhale" riser of one bar (2.5 s) under the cinematic, and a held last chord if it runs long. On completion, on the beat: the transformation hit, the mode lifts, that fighter's motif rises a step |
| Tier 3 to 4 | S1 goes half-time; S7 enters at tier 4; the mode reaches Phrygian dominant |
| Hiding (`state` = hidden) | Music low-passed to 900 Hz and down 4 dB; S1 becomes a heartbeat; S3 and S4 fade. The power-signature hum goes away (that absence is the cue) |
| Ambush | A sharp stab, a reverse swell, and the filter opens within one beat |
| The brink | S2 thins to a solo, S5 becomes the suspended pedal, S6 enters or comes forward. Tension that does not resolve |
| The Encore (Empress) | A snare cadence and a fanfare on the recall call; a formation pattern in S1 while it lasts; on a completed mend, a resolved cadence and a small sarcastic round of applause |
| Rally | A reversal sting: a rising brass "second wind" and every stem that was dropped re-enters over 2 bars |
| The fold (respected cinematic, up to 6 s) | See 4.4 |
| The finisher | The score holds on a suspended chord for the cinematic; on the last blow, the tone stops |
| KO | Slow motion at 0.35: everything but the heartbeat low-passes and drops in pitch; a long, single KO stinger, then silence, then the outro theme |

### 4.4 The fold and the proving ground

The fold is the moment of the whole game where "space folds inward" toward the Protagonist. It is a sound event first.

1. **Ring closes (0 to 2 s).** The orbiting fragments hum: a tremolo that speeds up from 4 to 12 Hz while the pitch rises to a bright point. Never a rising column or a thunder roll: the sky pales and does not darken (Legal, `q3-screen.md` round 4), so there is no storm sound.
2. **Space slides in (2 to 5 s).** The world's sounds are pulled towards him: ambience and effects high-pass and swell in reverse, the score ducks to S0 plus a shimmering sustained chord.
3. **The hush (0.4 s).** Everything gates to almost nothing except the ring's tone.
4. **The proving ground.** Dry: no room tone, no crowd, no reverb, no wind (there is no cover and no civilian). The score is Bare: S0, a single hand-drum pulse and the Protagonist's motif alone, sincere and stripped. Impacts use a hard stone variant with a short bright slap-back. Nobody is lost here, so S2 and S4 stay off.
5. **The unfold.** The reverse: the ambience fades in from silence and the Town returns, damaged, because the collateral count carries over.

### 4.5 A worked timeline

A seven-minute Protagonist against Cyborg match on the greybox planet. Times are illustrative and follow the bands in `spec-wounds.md` (first brink 4:30 to 7:00, fold 4:30 to 6:30). A dot means the stem is on, a half means it is thinned, blank means off.

| Time | Event | Tier | Collateral | S0 | S1 | S2 | S3 | S4 | S5 | S6 | S7 | What you hear |
| :--- | :--- | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :---: | :--- |
| 0:00 | Match start | 1 | 0% | ● | | | | | | | | The band warming up over the planet's drone |
| 0:15 | First exchange | 1 | 0% | ● | ● | ● | ● | | | | | March enters; the Protagonist's fourths lead |
| 1:05 | Protagonist tier 2 (cinematic 2.5 s) | 2 | 6% | ● | duck | duck | duck | | | | | Inhale riser, then the hit; the motif rises a step |
| 1:40 | Cyborg starts pressing civilians | 2 | 14% | ● | ● | ● | ● | ◐ | | | | A chromatic low-brass line appears under the tune |
| 2:20 | Region break 1 (a leg) | 2 | 22% | ● | ● | ● | ● | ◐ | ● | | | Drop-out for one beat, then the tense figure enters |
| 2:50 | Protagonist hides in cover, ambushes | 2 | 25% | ● | heart | ◐ | | | ● | ● | | Muffled, a heartbeat; the stab on the ambush |
| 3:20 | Cyborg molts | 3 | 31% | ● | ● (half-time) | ● | ● | ● | ● | | | A "system update" chime, drums go half-time, mode darkens |
| 3:50 | Collateral crosses 40% | 3 | 41% | ● | ● | ◐ | ● | ● | ● | | | Two band sections drop out |
| 4:30 | Heat stage Simmering | 3 | 46% | ● | ● | ◐ | ● | ● | ● | ● 120 | | The heartbeat and kettle bubbles over the music |
| 5:00 | Ring closes; fold (6 s) | 3 | 47% | ● | | | | | | | | Ring hum, world sucked in, the hush |
| 5:10 | Proving ground | 3 | 47% | ● | ● (hand drum) | | ● (solo) | | | | | Bare: drone, one drum, the motif alone |
| 5:45 | Final form (reveal 4 s) | 4 | 47% | ● | ● | | ● | | | | ● | The hit, Phrygian dominant, the full ensemble arrives |
| 6:30 | Cyborg's chip splits: brink | 4 | 47% | ● | ● | | ● | | ● pedal | ● | ● | Suspended chord, heartbeat, no resolution |
| 6:50 | Finisher cinematic | 4 | 47% | ● | hold | | | | hold | ● | hold | The score holds still |
| 7:00 | KO, slow motion 2.2 s | 4 | 47% | ● | | | | | | ● | | Low-passed heartbeat, the KO stinger, silence |
| 7:04 | After | | | ● | | | | | | | | The outro theme over the drone |

## 5. Sound effects: the palette by class

Every sound is layered as snap (0 to 20 ms, bright), body (20 to 300 ms, the pitch drop) and tail (the room, debris, the aftermath). Sizes scale pitch down and length up. The first three rows exist in the prototype. "Tell apart" is the rule that keeps neighbouring sounds from being confused.

### 5.1 Impacts and melee

| Class | Recipe | Scales with | Tell apart |
| :--- | :--- | :--- | :--- |
| Light strike | Noise snap, mid slap at 1 kHz, a quick thump falling 230 to 85 Hz; 0.12 s (prototype) | Damage: a little lower and louder | Shortest and brightest; no tail |
| Heavy strike, launch impact | Crack, a boom falling 125 to 40 Hz, a swept air-shock, debris patter; 0.8 s (prototype) | Damage; the biome (stone, water, wood variants) | Long low body and a debris tail |
| Ground impact, crater | Crack, a very deep thump, a rolling rumble, falling rocks; 1.7 s (prototype) | Crater energy: bigger is lower and longer. Rim height adds the crumble of ejecta | The only sound with a rumble and rock tail |
| Guard hit | A dull forearm thud and a cloth-and-leather creak, no crack | Attack kind | Muffled: no snap layer, which is how it differs from a strike |
| Guard break | The guard thud, then a glassy crack and a bass drop, with a short rattle | Attack kind | The only hit with a glassy layer and a drop |
| Parry | A bright dry clack (wood block) and a tiny air pop | none | Shortest and highest sound in the game |
| Clash and heavy clash | Two hits a hair apart, a shock ring, a ringing tone; the clash shockwave adds a sub swell | Tier | Two-tone with a ring |
| Dodge, dash, afterimage | An air whip whose pitch follows speed; a rush is a tearing zip | Speed | Airy: no low body at all |
| Teleport ripple | A soft, low, watery wobble: a modulated tone and filtered noise, not a zip | none | Watery and low; nothing else wobbles |
| Chain hits | The strike sound with a rising pitch per hit in the chain, up to the fifth | Chain length | The pitch climbs |
| Water entry, skim | Splash by size, then a sudden muffled world (the underwater filter); a skim is a hiss with a skipping tick | Speed, size | The world going dull is the cue |

### 5.2 Movement, charge, tiers and transformation

| Class | Recipe | Notes |
| :--- | :--- | :--- |
| Charge | A hum that swells in, not a rising whine: filtered noise plus close partials drawn inward, with a pulse that follows the fighter's breath | See the heat track for the heartbeat |
| Tier up on the ground | A rising tone under a rumble, and the crater sound when the ground breaks | The land answers (pillar 4) |
| Protagonist heat track | **Heated:** a heartbeat at 96 BPM, faint kettle ticks, breath. **Simmering:** 120 BPM, chest bubbling, steam hisses on the beat. **Boiling:** 144 BPM, a rolling boil, and a steam whistle that rises with heat. **Boil-over:** the whistle peaks and cuts to a 0.15 s silence with a skipped heartbeat, then a vent (a steam release sweeping down) and a low burst. **Cooling:** the pitch falls and the heart slows over 2.5 s | Orb liked this: a heartbeat, a kettle and a steam whistle |
| Anti-hero transformations | Metal clasps sliding, a deep pulse and a bell; regalia is heard as a rank | Drop the Act: the facade is a held breath and a crack |
| Empress revisions | A dreadful sigh (voice), a guard's heel-clicks and salutes in three stages, an aide's watch ticking. No stamps and no typing (diegetic paperwork only, per Orb) | The three gestures are the fill gauge, heard |
| Cyborg molts, Press | A servo whirr, a start-up chime, a pneumatic hiss; Press is hydraulic plates clamping with a wet crunch. Portals are kitchen: a service bell and a conveyor whirr | No ray and no sparkle (Legal, Press) |

### 5.3 Beams (the world's voice)

The charge is an inhale and the beam has no shouted name. A beam sounds like what it does to the land, which is the same rule as its name:

| Variant | The land | The sound |
| :--- | :--- | :--- |
| HORIZON CLEAVE | Sea and open plain | A long tearing zip over water, steam hiss |
| BOULEVARD RAZE | City | A grinding metal shriek with glass |
| FIRESTORM | Forest | A roaring flame bellows and crackle |
| RIDGE BORE | Mountains | A drill-like resonant grind with rock cracks |
| GLASS TRENCH | Desert | Vitrifying crackle with glass chimes |
| MERIDIAN SCAR | Anywhere, the largest | A deep tone and a long tearing sheet |

A beam's scorch trail sizzles by beam power. A beam clash is two tones that beat against each other: the winner's tone rises and the loser's falls, so you can hear who is winning. A beam's result is a different tail each: HIT, GUARD, DODGE, ESCAPE. Beam names may change when Orb picks replacements; the rule (sound follows the land) stays.

### 5.4 Destruction

| Class | Recipe |
| :--- | :--- |
| Building cracks, wrecks | Layered groans and cracks by damage; a wreck adds a shatter |
| Collapse, implosion (controlled demolition) | A low charge thump, the collapse sucks in (a descending crumble), then a heavy whump and a dust hiss |
| Burst through a building (brunt) | A heavy crash, glass, a steel scream. A chain through several buildings is a crescendo: each crash a little higher and louder |
| Topple | A long groan, a creak, a long fall, a ground slam |
| Blast wave | Arrives late by distance (capped at 0.6 s) so scale is heard; a ridge muffles it |
| Fire | A crackle whose density follows the burning count; whooshes as it jumps; a firestorm roars |
| Landslide | A rising granular rumble, a rolling front that passes by |
| Quake | A warning rumble at 25 to 40 Hz and creaks a few seconds before; then a sharp step and a roll |
| Rift, lava | A deep tearing resonance; lava hisses, bubbles slowly and ticks as it cools |
| Flood | A rising rush and roar; a crater filling gurgles |

### 5.5 Fight state (hidden and ambush cues, Wounds)

| Class | Recipe |
| :--- | :--- |
| Hide | The fighter's power hum stops and the world dulls (the absence is the cue) |
| Lock lost | A soft two-tone tick-down |
| Found | A single sonar-like ping |
| Ambush | A sharp stab and a reverse swell |
| Region stage, break | Stage change: a soft tick. A break is the chapter sting (one big hit, short tail) |
| Brink | A heartbeat and laboured breath, and the aura guttering as a stuttering hum |
| Rally | A rising "second wind" inhale and a brass swell |
| Finisher, KO | A fighter-specific finisher sound; KO is a heavy hit at half speed, then silence |
| Wound cards, UI | A soft card tick; no per-letter text blips |

### 5.6 Head-flash cues

Art's thirteen active head flashes (plus the held Primed) (`docs/art/marked-aura.md`, `art/concepts/marked-aura/flashes.json`) each have one short cue, cut to the flash's own time (`max_s`), so a sound is never longer than its flash. The recipe is the same for every fighter; the fighter's shape family sets only the timbre, so the Protagonist's flashes sound round, the Anti-hero's thin and metallic, the Empress's nasal and theatrical and the Cyborg's stepped. Brink was cut from the set and Hazard, Primed and Respect added (EP and Orb, 2026-09-29); their times and priority ranks are provisional until Art's `data/art/flashes.json` lands. Recipes: `audio/data/flash_cues.json`; synth: `audio/synth/flash_synth.gd`.

| Family (fighter) | Timbre |
| :--- | :--- |
| Circles (Protagonist) | Near-sine, soft attack, warm |
| Blades (Anti-hero) | A thin FM edge, quick attack |
| Wedges (Empress) | A narrow pulse, filtered, with a light vibrato |
| Steps (Cyborg) | A square wave whose pitch moves in semitone steps every 35 ms, with 5-bit level steps |

| Flash | Cue (as the Protagonist hears it) | Length |
| :--- | :--- | :--- |
| Danger sense | A low dry tick and a quiet upward noise sweep. No pitched chirp | 0.32 s |
| Hazard | Two low dry ticks a beat apart over a low rumble swell, no upward sweep: the world is about to hit you | 0.45 s |
| Found | One soft-attack note rising a whole step, mid register | 0.60 s |
| Searching | A wavering low two-note phrase, falling | 0.90 s |
| Primed (held, not loaded: hiding was removed from the base game) | A short breath in, then one low held note that lifts a semitone: sprung and live | 0.60 s |
| Fear | A shiver: breath noise with a 13 Hz tremolo | 0.80 s |
| Rage | A low creaking growl that swells and is cut off | 0.59 s |
| Hurt | A short falling blip and a knock, layered under the pain grunt | 0.31 s |
| Resolve | A breath in, then a low held note. It fires just after the crown's Rally pop fades | 0.80 s |
| Respect | Two notes that meet from either side and settle into a soft chime | 0.90 s |
| Triumph | A two-note bell chime a fifth apart (the fighter's laugh joins when the laugh gesture exists) | 1.00 s |
| Pride | A slow exhale and a soft held fifth | 0.90 s |
| Taunt | A nasal sneer and a dry "tch" | 0.41 s |
| Surge | A three-second rising swell that resolves on a chord that differs per family (major, minor, suspended, open fifth) | 4.45 s |

**Veto check against known alert cues** (Art asked me to veto anything that sounds like a stealth-game alert or a spider-sense cue). The rules I applied, and how the set does:
1. No fast repeated staccato notes or "stab" (the classic alert): no cue has three or more repeated notes (Hazard has two low ticks); the fastest attack on a pitched note is 15 ms and the danger cue has no pitched note at all.
2. Nothing high and shrill (a spider-sense chirp sits in the 2 to 4 kHz range): the highest fundamental in any cue is 587 Hz, with one quiet partial at 1.2 kHz in the wedges' found cue.
3. No tremolo or vibrato on a high pure tone: the fear shiver is on breath noise, and its only pitched part is a quiet tone at about 150 Hz.
4. Info cues are softer and lower than an alert would be: found is a 0.6 s note and danger is a tick and a noise sweep.
Result: nothing vetoed. This is a design check on the numbers, not a listening check, and Legal's screen still applies. The flash cues are also `audio` cues, so any that Orb finds close to a known sound can be retuned in data.

**Hook.** The flash prototype does not exist yet, so audio has two ways in. Rendering can call `AudioCues.flash(S, actor, id)` when a flash starts and append the returned cue to the host's pending cues, or emit the cosmetic `flash` event `{actor, id}` (the spec's audio hook) and `AudioCues.consume` will pick it up. Priority follows Art's rank, so the surge outranks everything, and the cue is in the fighter's own group, so a new flash cue replaces that fighter's earlier one.

## 6. The mix

### 6.1 The priority ladder

Highest first. A higher class can steal a voice from a lower one and ducks the classes under it.

1. Grunts and barks (one mouth per fighter)
2. Critical combat: parry, guard break, region break, brink, ambush, finisher, KO, transformation hits
3. Beams and beam clashes
4. Melee impacts
5. Destruction (crashes, collapses, fire, slides)
6. Movement (dash, flight, charge)
7. Ambience
8. Music

### 6.2 Ducking

| While | Ducks | By | Attack, release |
| :--- | :--- | :--- | :--- |
| A grunt or bark plays | Music, ambience | 4 dB, 6 dB | 30 ms, 400 ms |
| A transformation, Drop the Act or the fold cinematic runs | Music to S0 only; effects except the cinematic's own | full | 100 ms, 600 ms |
| A finisher runs | Everything except the finisher, the heartbeat and S0 | full | 50 ms, 800 ms |
| A beam fires | Ambience | 6 dB | 100 ms, 500 ms |
| A heavy impact lands | Music | 3 dB | instant, 120 ms |
| Hit-stop | Music low-passed to 2 kHz and down 3 dB, released over 80 ms after | | |

### 6.3 Voice cap

32 voices on desktop and 20 on web and mobile (the prototype uses 16). Class limits: impacts 8, destruction 6, beams 2 plus 1 clash, grunts 2 (one per fighter), ambience 6 loops, music 8 stems. A new sound takes the quietest, lowest-priority voice if its priority is equal or higher, and is dropped otherwise.

### 6.4 Loudness

Targets, to be measured on a real match and adjusted: integrated −16 LUFS over a match, short-term −24 LUFS in the quietest stretch, −10 LUFS at the loudest (a beam clash over a collapse), true peak −1 dBTP. Grunts sit about 6 dB under the impacts. Music sits about 8 dB under effects in a fight and comes up in the quiet beats and the outro. A limiter on the master bus catches the rest (the prototype uses one). Players get sliders for Master, Music, Effects and Voices (Accessibility).

### 6.5 Space, height and the sim's clock

- **Distance** is the shortest arc (`sdx`) between the camera and the sound, so a fight across the seam is as loud as it really is. Level falls by `mix.json`'s curve to silence at 2,600 units. Panning follows the on-screen position.
- **Underwater** low-passes at 900 Hz and adds bubbles. **Cover** (a hide) low-passes at about 1.6 kHz. **High altitude** thins the air: a high-pass at about 150 Hz and less reverb. **Space**, if the planet goes: no air, so the effects low-pass hard and only the fighters' bodies and the score are heard.
- **Hit-stop and slow motion.** Audio follows the sim and never changes its timing. A frozen tick has only a `tick` event: the impact that caused it plays at its own tick and its tail keeps ringing; music and ambience carry on (a pause would sound like a bug) under the duck in 6.2. During the KO slow motion (the sim's clock is 0.35 for 2.2 s, `S.dt / DT`), music and ambience low-pass to 1.2 kHz and drop in pitch to 0.7 over 150 ms, the KO blow plays at half speed, and the heartbeat stays at normal speed to contrast.

## 7. The grunt system

Orb: lines are unvoiced text, and each character's distinct grunts, growls and laughs carry the emotion. Narrative owns the lines and cues (`docs/narrative/line-system.md` section 4); Audio owns the sounds and the machine that plays them.

- **A gesture is a small object.** A fighter has a bank of gestures (`effort.light`, `effort.heavy`, `wince`, `laugh.short`, `growl`, `sneer`, `cackle`, `chirp` and so on). A line carries cues (a character offset, a gesture and an intensity 0 to 3, and a mood). The cue asks for `voice.<fighter>.<gesture>`; the bank picks a variant, and the player varies pitch by about 3% and level by about 1 dB from the audio stream, so a gesture never plays twice identically.
- **Anti-repetition.** A variant never plays twice in a row for a gesture, and a fighter's grunt has a cooldown (1.1 s for the prototype's effort). Silence is a feature: the bark budget (Narrative, Accessibility) decides how often a fighter speaks.
- **One mouth.** Each fighter has one voice group: a new grunt cuts that fighter's earlier one. Barks (priority 70 and up) beat effort grunts.
- **Wear changes the voice.** Breathing becomes audible from battered (`damage-model.md` section 3). Grunts get breathier and higher at brink. The Anti-hero's facade crack changes his palette to the ragged set. The Empress's palette has no sincere gestures.
- **The text follows the sound.** The bank tells UI how long a gesture lasts (`AudioBank.duration`), so the text speed can follow it (line-system section 4). A laugh before a line changes how the words read.
- **Captions.** Every gesture has a caption string (`[effort]`, `[short laugh]`). The cue carries it, so UI can show it when sound is off or the player is deaf (Accessibility).
- **Made at runtime.** A source-filter voice (`audio/synth/grunt_synth.gd`): a glottal pulse train with a falling pitch and breath noise through three moving formant resonators, then a chest resonance and saturation. Every number is in `audio/data/grunts.json`. A gesture renders in about 10 ms on a desktop. Six grunts exist now (`effort.heavy`, `pain.head`, `pain.limb` for two fighters). Palettes and the plan for the rest are in `grunts.md`.
- **Budget.** Nine to ten gestures, three variants each, per fighter: about 115 clips for four fighters, about 2 MB in memory and about 1.2 s to render on a desktop (estimated from the 9 to 12 ms each of the two working grunts). Only the two fighters in the match are rendered, in slices behind the loading beat (`AudioBank.warm_begin`, `warm_step`). Web timing is not measured yet.
- **Language.** Grunts are language-neutral, which helps Localization: the captions are the only text.

## 8. Sourcing, licence and Legal

Rules that bind everything (`originality-rules.md`, `licence-register.md`): original or logged; no sound-alikes, no ripped clips, no voice clips; CC BY 4.0 and CC0 accepted for audio, NC and unlicensed rejected; Legal writes `docs/legal/asset-origins.md`, and I send proposed rows in my reports (proposed rows for the prototype are in `audio/README.md`).

| Option | Cost | Quality | Licence | Legal risk | Origin fields to fill |
| :--- | :--- | :--- | :--- | :--- | :--- |
| Synthesis (the prototype's generators, plus a synth for music) | Zero | Good for impacts, air and tones; uncanny for laughs; a good floor for music | Ours; whatever the repo settles on | Lowest: no third-party file and no voice | One row per generator: Origin = procedural, Author, Licence, and the seed rules |
| Our own recordings (Orb's kitchen, breath, voice) | Zero money, Orb's time | Highest realism; depends on the room and mic | Orb's own; Orb picks CC BY 4.0 or CC0 | Low. Real people's voices are personal data: Orb's voice ends up public if the repo is public | Origin = human-made, Author = Orb, recording date and device, Licence, consent |
| CC0 and CC BY libraries | Zero | Very good for orchestral and ambience; sound effects vary | See below; each file has its own | Medium: a "CC0" upload can still be someone else's ripped clip. Prefer packs with a known author; keep the URL and uploader | Origin = third-party or public domain, Author or source with URL, Licence (SPDX), attribution text if CC BY |
| Volunteers (composer, sound designers) | Zero, their time | Potentially the best; unpredictable | The contributor's, under the project's terms (DCO) | Medium: needs the contribution rules and the originality note on each piece | Origin = human-made, Author, licence, contributor's originality note |
| AI-assisted generation | Free tiers often bar commercial use | Uneven; voices and music risk sound-alikes | Depends on the tool and its terms | High: unclear terms are rejected, and human authorship is needed for characters | Origin = AI-assisted, tool, model, date, prompt location (no franchise words) |

**Orb decides:** AI (default off for audio, see section 1), and the spatial approach for the presentation (default 2D panning by on-screen position, wrap-aware).

Sources I checked on 2026-09-29 (re-check at use, as the register says):

- **VSCO 2 Community Edition** (Versilian Studios): about 3,000 orchestral instrument samples, all CC0. Fits direction A.
- **Versilian Community Sample Library (VCSL)**: an open CC0 library, including percussion and unusual instruments.
- **Kenney's audio packs**: all CC0, no attribution needed.
- **Freesound**: each file is CC0, CC BY or CC BY-NC (plus a retired Sampling+ set). Only CC0 and CC BY are usable; filter by licence, and log the URL and uploader.

Not chosen: anything under NC or ND; any "royalty-free" track without an open licence; any sample whose source I cannot name.

## 9. What I need from the sim

Today the fx stream (`fx-events.md`) gives me `damage`, `crater`, `spark`, `ring`, `debris`, `dust`, `splash`, `fire`, `after`, `charge`, `scorch`, `beamSplash`, `banner`, `shake` and `tick`. That is enough for the prototype (hits and craters), but a `damage` event does not say who hit whom, so the prototype guesses the victim as the fighter nearest the hit, which only works in a 1v1. The beam has no start or end event (only `scorch` samples and a banner). I need these, in the fx stream, as names and rough fields (all read-only for me):

| Group | Events |
| :--- | :--- |
| Hits | `damage` with `attacker`, `victim`, `region`, `kind` (light, heavy, guard, guard_break, beam, impact) |
| Wounds | `region_stage`, `region_broken`, `brink_enter`, `brink_exit`, `rally`, `finisher_start`, `finisher_contest`, `ko` (already in the plan, `wounds-plan.md`) |
| Beams | `beam_charge`, `beam_fire` (variant, power, owner), `beam_end` (outcome), `beam_clash` (start, end, winner) |
| Forms | `transform_fill`, `transform_start`, `transform_end` (fighter, form), `tier_up` |
| Heat | `heat_stage`, `boil_over` |
| Fold | `fragment_shed`, `fragment_grab`, `fragment_lost`, `ring_closed`, `fold_start`, `fold_flicker`, `unfold` |
| Fighters | `facade_crack`, `drop_act`, `shame_stack`; `hatch_open`, `chip_stage`, `press_start`, `press_end`, `molt`, `backup_dock`; `encore_start`, `guard_fall`, `encore_end`, `revision_reprint`, `revision_fill_reset` |
| Hiding | `hide_start`, `found`, `ambush`, `lock_lost` |
| World | `building_hit` (outcome), `building_fall` (mode), `chain_link`, `launch_depth` (from `buildings-in-depth.md`), and start and end events for fire, landslide, quake, flood and lava (World) |
| Clock | the slow-motion factor and whether a tick is in hit-stop (`tick.frozen` exists; `S.dt / DT` is readable) |

The game state I read each tick: fighters (tier, hidden, state, stance), the collateral count and start population, camera x and zoom, `groundY` and `seaAt` for height and water.

## 10. Open questions

For Orb: the five in section 1, and whether to make three 30-second sketches (A, B, C) for a listening choice.

For the EP:
1. The event list in section 9, routed to Simulation and Encounter Systems.
2. The grunt file shape. Narrative's `data/fighters/<id>/grunts.json` lists clips by name (`line-system.md` section 6); mine holds recipes and a variant count. I propose keeping Narrative's gesture names, intensity and mood, and mapping `voice.<fighter>.<gesture>` to my recipes, so Tools' schema stays one file per fighter.
3. Someone to own the hook-up in `sim_host.gd` and `main.gd` (Rendering or UI, `audio/README.md`).
4. Whether the caption strings belong in Narrative's or Accessibility's data.
