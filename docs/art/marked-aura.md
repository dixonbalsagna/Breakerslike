# Marked plus flashes: the character style

Owner: Art Director. 2026-09-29. Round 4, revised twice on Orb's notes, then again for Legal's conditions. Concept art for Orb to choose from. Working labels and placeholder looks. Legal's conditions are applied below; results are **pending Legal's confirmation**.

Orb's pick was Marked plus Aura. On seeing it, Orb found the standing aura distracting ("could be useful to convey emotions briefly, but then disappear") and pointed to the way a spider-sense flash or a stealth game's exclamation mark appears above a head. So the aura became **head flashes**: brief, iconic pops at the head that say what a fighter senses or feels. At rest there is nothing. Only a transformation surge lasts longer.

**Sheets** (`art/concepts/marked-aura/`):
- `ma-1-style.svg`: the four fighters at rest, the mask tones, 40 px and 12 px reads, and the neutral, taunt, hurt, rage and triumph strip per fighter with a head close-up.
- `ma-2-flashes.svg`: all thirteen flashes in the four shape families, and a table of what each is for, its timing, priority and sound pairing.
- `ma-3-staging.svg`: four staged moments in the greybox scene (face-off, clash, transformation, hurt or brink, where the crown owns the brink) with the blocking rules.
- `ma-4-flash-rules.svg`: a flash in time, priority and arbitration, the flash against the HUD crown, and the Legal fallback.
- `ma-5-legal-checks.svg`: the checks Legal asked Art to run, because Legal cannot view SVGs (masks in three flat colours and silhouette, each sigil beside the generic patterns to avoid, the flashes beside the two patterns to avoid, the dome, and the Coil's chest).
- `data/art/flashes.json`: the canonical data for Rendering, UI and Audio, now with the Legal rules (`legal_rules`).

`node art/concepts/marked-aura/gen.mjs` regenerates all of them. The sigils, the dome mask and the palettes are in `art/concepts/shared/marks.mjs`, shared with the turnarounds. The in-engine prototype is specified in `docs/art/flash-prototype-spec.md`.

## The idea in one line

**The sigil is who they are and a small flick of how they feel. A head flash is what they sense or feel right now, for under a second.** The mask cannot shout, so the flash does, and some flashes carry game information (a danger sense, a found rival) as well as emotion.

## Mask tone per fighter (approved by Orb)

| Fighter | Tone | Why |
|---|---|---|
| Protagonist | Pale | Earnest, open, approachable. A light spot over the dark tunic at 40 px |
| Anti-hero | Dark | Guarded and formal: a closed front. The lit sigil is the face |
| Empress | Pale (warm bone) | Image-focused and theatrical. No horns |
| Cyborg | Dark | A machine wearing politeness: a display face with a lit sigil grid |

## The sigils (Legal's conditions applied)

| Fighter | Sigil | Where | Rules kept |
|---|---|---|---|
| Protagonist | A single open arc (a "C" with a gap facing forward), teal on the pale mask | Off-centre at the temple, above the brow ridge, under the raised hairline. Never centred on the forehead | No inner ring, no centre dot, never with the slash. Hurt and brink open a gap in the ring (a "C"), never a line across it |
| Anti-hero | A leaning slash and a small dot, lit orchid on the dark mask | Mid-face, a mark with no pair | Never with a ring, never crossed into an X. Hurt and brink split the slash with a gap. The chest has one diagonal sash, so nothing lines up into an X |
| Empress | Three chevrons of different sizes, offset, in moss | The brow, under the gear band | An odd count, not a tidy double chevron, moss and bone (never a car or oil brand's colours). Hurt drops the middle one |
| Cyborg | A stair of four lit squares of growing size | Mid-face on the display | Not a line grid, no cross bars, no plus. Hurt drops one step |

No sigil sits as an eye or a mouth: none is one of a pair, and none has a line beneath it. `ma-5-legal-checks.svg` shows each next to the generic patterns to avoid (a slashed ring, a target, four linked rings, a double chevron, a line grid, a cross), and each mask in three flat colours and as a silhouette.

**The Protagonist's dome** is a designed shape and not an egg: a faceted crown, a raised brow ridge, a jaw plane and a crown seam, with no eye or mouth slots or dots. The hair is a swept-back teal cap, never upswept, never gold, and its fringe sits high so the temple ring shows.

## Playtest revision (2026-09-29)

Orb played it: "a little too large and visible, a bit distracting", and the Protagonist's surge cloud and the Anti-hero's blade rays "obstruct my view". Orb's suggestion: pulse two or three times to signal a thought, then disappear. Done in `data/art/flashes.json` (version 3):
- **Half the size** (the surge a third): the largest shape is 40, most are 30 or less. Thinner blades and wedges. Fewer shapes: rage is three, triumph five, the surge a crest of three.
- **Pulses replace hold-and-fade.** Two or three quick swell-and-shrink pulses with a beat of nothing between, 0.4 to 0.8 s in all. The surge is three slow pulses, 1.85 s, and is never a standing cloud or held for the cinematic.
- **Keep-out.** Every shape sits up and back of the head (65 to 175 degrees), never forward toward the opponent and never below the head centre, so nothing ever covers a torso or a face on either fighter. The rage rays no longer sweep forward.
- **Hurt** has a six-second cooldown, so a flurry gives one flash.

## The flash vocabulary

Thirteen flashes (Orb added Hazard and Respect; the EP cut Brink, kept Resolve and kept Pride apart from Triumph; Orb then removed hiding from the base game, so Primed is held), four of them info. Each is tied to a real game moment. Timings are pulses (count, on, off, fade) in seconds: each flash pulses two or three times, then is gone, in 0.4 to 0.8 s, and the surge takes 1.85 s. Priority 1 is the highest. Full table, cooldowns and sound pairings are on `ma-2-flashes.svg` and in `data/art/flashes.json`.

| Flash | Class | Moment (sim event) | Time (s) | Priority |
|---|---|---|---|---|
| Danger sense | info | A telegraphed heavy or beam, an attack from off screen or behind (a pointer train, turned to the threat) | 3 x 0.08 on, 0.05 off, fade 0.08 = 0.42 s | 2 |
| Hazard | info | The world is about to hit the fighter: a falling building, a collapsing crater rim, a beam path, rising water. Not a fighter attack | 2 x 0.125 on, 0.08 off, fade 0.12 = 0.45 s | 3 |
| Found | info | A lost lock-on is regained: the rival is back in line of sight | 2 x 0.14 on, 0.08 off, fade 0.12 = 0.48 s | 4 |
| Searching | info | Lock-on lost: the rival has dropped out of line of sight (re-pops at most every 3 s) | 3 x 0.14 on, 0.10 off, fade 0.14 = 0.76 s | 5 |
| Fear | emotion | An opponent starts a finisher, or the fighter watches a rival transform | 3 x 0.10 on, 0.07 off, fade 0.12 = 0.56 s | 6 |
| Rage | emotion | Drop the Act, a wrath spike, a boil-over, a humiliating parry | 3 x 0.14 on, 0.08 off, fade 0.14 = 0.72 s | 7 |
| Hurt | emotion | A heavy hit or a break launch, when the crown is not up | 2 x 0.10 on, 0.06 off, fade 0.14 = 0.40 s | 8 |
| Resolve | emotion | A Rally or Second Wind. Sequenced: it starts 0.1 s after the crown's wear pop fades, waits up to 2 s and is never dropped by arbitration | 2 x 0.18 on, 0.10 off, fade 0.20 = 0.66 s | 9 |
| Triumph | emotion | A finisher lands, or a KO for the winner | 3 x 0.14 on, 0.08 off, fade 0.16 = 0.74 s | 10 |
| Pride | emotion | A decisive exchange won | 2 x 0.22 on, 0.12 off, fade 0.20 = 0.76 s | 11 |
| Respect | emotion | A clash ends in a draw, a finisher is blocked, or a rival gets back up after a heavy hit | 2 x 0.22 on, 0.12 off, fade 0.20 = 0.76 s | 12 |
| Taunt | emotion | A taunt line or gesture | 3 x 0.10 on, 0.07 off, fade 0.14 = 0.58 s | 13 |
| Surge | emotion | A transformation: three slow pulses of a small crest at the start of the cinematic, then gone | 3 x 0.35 on, 0.25 off, fade 0.30 = 1.85 s | 1 |

**Cut and held.** Brink is cut: the crown's dashed brink ring covers it, and the sigil still dims and gaps. Winded, Smug and Bored are held for later, and so is Primed (the ambush window needs hiding, which is held for a future stealth fighter; it keeps its layout in the data) (they are in the pitch, `ma-6-flash-pitch.svg`, and listed in the data as `held`).

Notes on the moments: a parry window keeps the crown's ring (a flash would double it). The Protagonist's transformation surge is not a power-stage signature: Hot Blood stays steam and veins on the body. Sim events for danger sense, searching, taunt and the drop-act family come with Encounter's and Game Design's slices, and the rest exist today (`docs/architecture/fx-events.md`).

### Shapes: ours, not generic

Each flash is drawn in the fighter's shape family. That is what makes it ours, and it keeps the four fighters recognisable even in a flash.

| Family | Fighter | Shapes | The "!" | The "?" |
|---|---|---|---|---|
| Circles | Protagonist | Round-ended bars, dots, arcs | A capsule and a dot | A hook of circles |
| Blades | Anti-hero | Tapered blades, diamonds | A blade over a diamond (his sigil, a slash and a dot) | A tapered hook |
| Wedges | Empress | Wedge triangles | A wedge over a small triangle | An angular hook |
| Steps | Cyborg | Squares snapped to a grid | Stacked squares | A pixel hook |

**Two classes, so a player can tell them apart at a glance:**
- **Info flashes** (danger sense, found, searching) are solid, at full opacity, with a dark keyline in the lane colour. Gameplay information: crisp and legible on any backdrop.
- **Emotion flashes** (all the rest) are translucent, with a rim and a lighter core, at 34 to 55% opacity. Feeling and state.

**Legal's conditions on shape:**
- **Danger sense is a pointer train.** Three shapes of growing size along one ray, up and behind the head (a default of 132 degrees). Rendering turns the ray to the threat's bearing and keeps it above or behind (65 to 175 degrees). It is never a ring of short lines around the head and never wavy.
- **The Anti-hero's upward flashes are round-tipped** (pride, triumph, surge, danger sense). His rage stays pointed, because it sweeps forward, not up.
- **The Empress's upward flashes are a wide, low crest** behind the head (pride, triumph, surge, resolve): the angles are flattened and turned back, and the shapes are shorter. The Anti-hero's surge takes the same wide, low crest, so no transformation is a tall upswept shape.
- **Info flashes** are a pale core inside a thin keyline in the lane's dark step. No yellow, no red-orange, no thick black outline. The Cyborg's are neutral steel.

### Colour

Emotion flashes use the fighter's accent, two steps (a rim and a lighter core). Info flashes use a pale core inside a thin keyline in the lane's dark step (the Cyborg's are steel), never yellow or red-orange. No red, red-orange or gold for the Protagonist or the Anti-hero. Protagonist teal, Anti-hero orchid violet, Empress moss, Cyborg brick coral (the Cyborg's red lane may use coral).

### Sound pairing (with Audio; all original)

Each flash pairs with one short sound, described in words on the sheet: a low dry tick with a short sweep for danger sense, one bright rising note for found, a wavering low phrase for searching, a heartbeat thump for brink, a tremolo shiver for fear, a swelling growl for rage, the fighter's pain grunt for hurt, a breath and a held note for resolve, a chime and a laugh for triumph, an exhale and a soft chord for pride, a sneer for taunt, a rising swell for the surge. **No stealth-game alert sting and no spider-sense chirp**: the sounds must be original, and Audio can veto a pairing that sounds too close to a known cue.

## Timing, priority and the crown

- **Transient.** A flash lasts 0.3 to 1 s and then it is gone. At rest, nothing (not even a faint trace): the fight area is clean.
- **One channel per fighter.** A flash and a crown are never up together. The crown owns wear (a stage change, brink, Rally, facade crack, boil-over). A flash owns emotion and sense. The one sequenced flash is Resolve: on a Rally the crown pops first, and Resolve starts 0.1 s after the crown goes down.
- **Arbitration.** A wear event arriving while a flash is up fades the flash in 0.1 s and the crown takes the fighter. A flash due while the crown is up waits up to 0.25 s and is then dropped. A higher priority preempts a lower one (the lower fades in 0.1 s). The same priority extends the hold and never replays the attack. Each flash has its own cooldown per fighter.
- **Info flashes are never dropped for an emotion flash,** only for the surge. During a transformation cinematic the surge owns the fighter and the crown stays down. A hidden fighter shows no flash.
- **Placement.** Behind and above the head, never over the mask, the sigil or the chest. Rage sweeps forward, away from the camera-facing side.

### How a flash stays distinct from the HUD crown

| | Head flash (Art) | HUD aura crown (UI) |
|---|---|---|
| Shape | Filled shapes in a family. Never a thin line, never a closed ring | Thin arcs and rings, always round |
| Place | At and above the head, in the scene, behind the fighter | Around the whole body, on the HUD layer above the fighter |
| Colour | The fighter's accent, two steps | Neutral role colours in thin strokes |
| Motion | Changes shape, never blinks. Two or three quick pulses, 0.4 to 0.8 s in all | Pops and fades over 1 to 1.5 s, a regular 4 Hz flicker, a slow brink ring |
| Time | Under a second, an emotion or a sense | 1 to 1.5 s, an event about wear |

**Suggested changes for UI:**
1. The crown pops only for a stage change, brink, Rally, facade crack and boil-over, not for every hit, so the hurt flash and the crown do not compete for the same moment.
2. The crown's strokes stay in neutral role colours and never take the fighter's accent.
3. The crown stays down during a transformation cinematic, so the surge owns the fighter.
4. The parry window keeps the crown's ring. The flash does not duplicate it.
5. The pop for tier-up and transformation can go, because the surge carries it.
6. Camera: leave about one body height above the head for a surge.

## Legal conditions applied (2026-09-29, `docs/legal/q3-screen.md`)

| Legal's condition | What was done | Where to see it |
|---|---|---|
| Ring: single, no concentric rings, no centre dot | The Protagonist's sigil is a single open arc, no inner ring, no dot, off-centre at the temple (open, so the face-on view cannot read as an eye; Legal, second pass). Hurt widens the gap | `ma-5` section 2 |
| Slash: never with the ring, never an X | The Anti-hero's slash leans and stands alone. Hurt splits it with a gap. The Coil's chest has one sash, not two crossing straps, and the buckle has a diamond and no slash | `ma-5` sections 2 and 5, `coil-turnaround.svg` |
| Chevrons: an odd count, different sizes or offset, not a car or oil colour | Three chevrons of three sizes, offset, in moss on bone | `ma-5` section 2 |
| Grid: not a glowing line grid | A stair of four lit squares. No lines, no cross bars | `ma-5` section 2 |
| Dome: a designed shape, no eye or mouth slots or dots, sigil not as eyes or mouth | A faceted dome with brow ridge, jaw plane and crown seam. The ring is a lone temple mark | `ma-5` sections 1 and 4 |
| Anti-hero pride: the round-tipped fallback | Round tips are now the default for his pride, triumph, surge and danger sense | `ma-5` section 4, `ma-4` |
| Empress fan: wide and low | A wide, low crest behind the head for pride, triumph, surge and resolve. Shorter than before. The Anti-hero's surge uses it too | `ma-5` section 4, `ma-4` |
| Danger sense: directional, never radiating, never wavy | A pointer train of three growing shapes along one ray, above and behind the head | `ma-5` section 3 |
| No yellow or red-orange "!" with a thick black outline | Info flashes are a pale core with a thin keyline in the lane colour. The Cyborg's are steel | `ma-5` section 3 |
| Silhouette and three-flat-colour test on the four masks | Run. All four masks read in three flat colours and as silhouettes | `ma-5` section 1 |
| Sigil thumbnails beside the named symbols | Run, using generic drawings of each avoided pattern | `ma-5` section 2 |
| Flashes beside the two reference graphics | Run, using generic drawings of the two avoided patterns | `ma-5` section 3 |

**Kept from before**
- **Staples yes, signatures no.** Exclamation marks, question marks, sweat drops and anger marks are general comics staples and are drawn in each fighter's own shapes with a keyline, not as a font glyph.
- **Sound:** original only (see the sound pairing). No four-note alert sting, no chirp. Audio can veto a pairing that sounds close to a known cue.
- **Glow rules:** no red, red-orange or gold flash for the Protagonist or the Anti-hero; no full-body glow as a power-stage signature for anyone (the surge is a small crest above and behind the head, three slow pulses, gone in under two seconds); the Protagonist's heat stays steam and veins.
- **Legal's second pass (confirmed the above):** the Protagonist's ring moved off the mid-forehead to an off-centre temple mark above the brow ridge (a centred forehead ring recalls a known three-eyed fighter), and the short rays at the sigil in rage and triumph are cut. The sigil has no rays in any state. The Cyborg's four squares are a diagonal stair, never a 2 by 2 block.
- **Legacy view:** the earlier pointed and tall shapes stay visible on `ma-4` and `ma-5` (marked "before") so Legal can compare.

## Staging (blocking rules)

Applied on `ma-3-staging.svg`, with each flash at its peak:
- Three-quarter cheat-out, about 32 degrees toward the camera, chest design and mask face showing.
- Mirrored on side-swap, so the front and the sigil always face the camera and the back is never shown.
- Downstage reads as commanding: the face-off leads are larger and lower in frame.
- The four moments: a face-off (found, pride, taunt, at rest), a clash (two rages, a danger sense and a search), a transformation (the Anti-hero surges, the Protagonist fears) and a brink moment (the Protagonist's brink flash, the Anti-hero's pride, the Empress's triumph, next to UI's dashed brink ring).

## What the checks showed

1. **The flashes read even at 40 px.** A "!" or a "?" over a head is unmistakable, and the family shapes keep each fighter distinct. At 12 px a flash is a spot of colour and does not read as a glyph, so the flashes are a 40 px and closer language.
2. **Info against emotion is clear** when solid and keylined sits next to translucent and soft.
3. **The glyphs need scale.** The first pass at the size of the aura was too small to read; the "!" and "?" are drawn at about 1.7 times the emotion flashes' size.
4. **The crown and the flash can share a fighter only in turns.** The arbitration rule makes that explicit.

## The flash-set pitch

**Decided.** Orb added Hazard, Primed and Respect and left the cuts to the EP, who cut Brink, kept Resolve (sequenced after the crown's wear pop, not dropped) and kept Pride apart from Triumph: then hiding left the base game, so Primed is held too: thirteen flashes, four of them info. Winded, Smug and Bored are held. The pitch that led here:

Orb asked for a pitch before the set settles on twelve: `ma-6-flash-pitch.svg`. Six candidate additions (Winded, Smug, Respect, Bored, Hazard, Primed), three cuts or merges (Brink, Resolve, Pride into Triumph), each with its game moment, whether it is info or emotion, and the event it needs. My recommendation: twelve, plus Hazard, Primed and Respect, minus Brink and Resolve (the HUD crown already owns both), so thirteen flashes with five info flashes (Danger sense, Hazard, Primed, Found, Searching). Lock-on acquired is a merge into Found. Info flashes are a setting, on by default. The candidates are drawn in the four shape families but are not in `data/art/flashes.json` until Orb picks.

## Questions for Orb (through the EP, two at most)

1. **Answered:** the set is thirteen (see the pitch section). Any further flash is a new pitch.
2. **Should the info flashes** (danger sense, found, searching) **be always on,** or an option, since they also help players who cannot see the HUD?

## Files

`art/concepts/marked-aura/`: `ma-1-style.svg`, `ma-2-flashes.svg`, `ma-3-staging.svg`, `ma-4-flash-rules.svg`, `ma-5-legal-checks.svg`, `ma-6-flash-pitch.svg`, `gen.mjs`, `README.md`. Shared code: `art/concepts/shared/marks.mjs`. The data is `data/art/flashes.json`. The in-engine prototype spec is `docs/art/flash-prototype-spec.md`. The prompt records are `art/prompts/ART-0005-marked-aura.md` and `art/prompts/ART-0007-legal-conditions.md`.
