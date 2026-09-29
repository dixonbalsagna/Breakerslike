# Marked plus flashes: the character style

Owner: Art Director. 2026-09-29. Round 4, revised twice on Orb's notes. Concept art for Orb to choose from. Working labels and placeholder looks. Results are **pending Legal review**.

Orb's pick was Marked plus Aura. On seeing it, Orb found the standing aura distracting ("could be useful to convey emotions briefly, but then disappear") and pointed to the way a spider-sense flash or a stealth game's exclamation mark appears above a head. So the aura became **head flashes**: brief, iconic pops at the head that say what a fighter senses or feels. At rest there is nothing. Only a transformation surge lasts longer.

**Sheets** (`art/concepts/marked-aura/`):
- `ma-1-style.svg`: the four fighters at rest, the mask tones, 40 px and 12 px reads, and the neutral, taunt, hurt, rage and triumph strip per fighter with a head close-up.
- `ma-2-flashes.svg`: all twelve flashes in the four shape families, and a table of what each is for, its timing, priority and sound pairing.
- `ma-3-staging.svg`: four staged moments in the greybox scene (face-off, clash, transformation, hurt or brink) with the blocking rules.
- `ma-4-flash-rules.svg`: a flash in time, priority and arbitration, the flash against the HUD crown, and the Legal fallback.
- `flashes.json`: the draft data for Rendering, UI and Audio.

`node art/concepts/marked-aura/gen.mjs` regenerates all of them. The in-engine prototype is specified in `docs/art/flash-prototype-spec.md`.

## The idea in one line

**The sigil is who they are and a small flick of how they feel. A head flash is what they sense or feel right now, for under a second.** The mask cannot shout, so the flash does, and some flashes carry game information (a danger sense, a found rival) as well as emotion.

## Mask tone per fighter (approved by Orb)

| Fighter | Tone | Why |
|---|---|---|
| Protagonist | Pale | Earnest, open, approachable. A light spot over the dark tunic at 40 px |
| Anti-hero | Dark | Guarded and formal: a closed front. The lit sigil is the face |
| Empress | Pale (warm bone) | Image-focused and theatrical. No horns |
| Cyborg | Dark | A machine wearing politeness: a display face with a lit sigil grid |

## The flash vocabulary

Twelve flashes, each tied to a real game moment. Timings are attack + hold + fade in seconds, and every flash except the surge is under a second. Priority 1 is the highest. Full table, cooldowns and sound pairings are on `ma-2-flashes.svg` and in `flashes.json`.

| Flash | Class | Moment (sim event) | Time (s) | Priority |
|---|---|---|---|---|
| Danger sense | info | An ambush from hiding, a telegraphed heavy or beam, an attack from off screen | 0.05 + 0.15 + 0.15 = 0.35 | 2 |
| Found | info | A hidden rival is found, or a lost lock-on is regained | 0.06 + 0.30 + 0.24 = 0.60 | 3 |
| Searching | info | Lock-on lost, hunting a hidden rival (re-pops at most every 3 s) | 0.10 + 0.50 + 0.30 = 0.90 | 4 |
| Brink | emotion | The fighter enters the brink | 0.08 + 0.35 + 0.55 = 0.98 | 5 |
| Fear | emotion | An opponent starts a finisher, or the fighter watches a rival transform | 0.08 + 0.35 + 0.37 = 0.80 | 6 |
| Rage | emotion | Drop the Act, a wrath spike, a boil-over, a humiliating parry | 0.12 + 0.45 + 0.35 = 0.92 | 7 |
| Hurt | emotion | A heavy hit or a break launch, when the crown is not up | 0.04 + 0.16 + 0.30 = 0.50 | 8 |
| Resolve | emotion | A Rally or Second Wind | 0.10 + 0.35 + 0.35 = 0.80 | 9 |
| Triumph | emotion | A finisher lands, or a KO for the winner | 0.14 + 0.50 + 0.36 = 1.00 | 10 |
| Pride | emotion | A decisive exchange won | 0.20 + 0.50 + 0.20 = 0.90 | 11 |
| Taunt | emotion | A taunt line or gesture | 0.10 + 0.35 + 0.30 = 0.75 | 12 |
| Surge | emotion | A transformation: held for the respected cinematic (up to 3 s), then faded in 1.2 s | 0.25 + 3.0 + 1.2 | 1 |

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

### Colour

The fighter's accent, two steps (a rim and a lighter core), never anything else. No red, red-orange or gold for the Protagonist or the Anti-hero. Protagonist teal, Anti-hero orchid violet, Empress moss, Cyborg brick coral (the Cyborg's red lane may use coral).

### Sound pairing (with Audio; all original)

Each flash pairs with one short sound, described in words on the sheet: a low dry tick with a short sweep for danger sense, one bright rising note for found, a wavering low phrase for searching, a heartbeat thump for brink, a tremolo shiver for fear, a swelling growl for rage, the fighter's pain grunt for hurt, a breath and a held note for resolve, a chime and a laugh for triumph, an exhale and a soft chord for pride, a sneer for taunt, a rising swell for the surge. **No stealth-game alert sting and no spider-sense chirp**: the sounds must be original, and Audio can veto a pairing that sounds too close to a known cue.

## Timing, priority and the crown

- **Transient.** A flash lasts 0.3 to 1 s and then it is gone. At rest, nothing (not even a faint trace): the fight area is clean.
- **One channel per fighter.** A flash and a crown are never up together. The crown owns wear (a stage change, brink, Rally, facade crack, boil-over). A flash owns emotion and sense.
- **Arbitration.** A wear event arriving while a flash is up fades the flash in 0.1 s and the crown takes the fighter. A flash due while the crown is up waits up to 0.25 s and is then dropped. A higher priority preempts a lower one (the lower fades in 0.1 s). The same priority extends the hold and never replays the attack. Each flash has its own cooldown per fighter.
- **Info flashes are never dropped for an emotion flash,** only for the surge. During a transformation cinematic the surge owns the fighter and the crown stays down. A hidden fighter shows no flash.
- **Placement.** Behind and above the head, never over the mask, the sigil or the chest. Rage sweeps forward, away from the camera-facing side.

### How a flash stays distinct from the HUD crown

| | Head flash (Art) | HUD aura crown (UI) |
|---|---|---|
| Shape | Filled shapes in a family. Never a thin line, never a closed ring | Thin arcs and rings, always round |
| Place | At and above the head, in the scene, behind the fighter | Around the whole body, on the HUD layer above the fighter |
| Colour | The fighter's accent, two steps | Neutral role colours in thin strokes |
| Motion | Changes shape, never blinks. Pops in 0.05 to 0.25 s and fades in 0.15 to 0.55 s | Pops and fades over 1 to 1.5 s, a regular 4 Hz flicker, a slow brink ring |
| Time | Under a second, an emotion or a sense | 1 to 1.5 s, an event about wear |

**Suggested changes for UI:**
1. The crown pops only for a stage change, brink, Rally, facade crack and boil-over, not for every hit, so the hurt flash and the crown do not compete for the same moment.
2. The crown's strokes stay in neutral role colours and never take the fighter's accent.
3. The crown stays down during a transformation cinematic, so the surge owns the fighter.
4. The parry window keeps the crown's ring. The flash does not duplicate it.
5. The pop for tier-up and transformation can go, because the surge carries it.
6. Camera: leave about one body height above the head for a surge.

## Legal

- **Staples yes, signatures no.** Exclamation marks, question marks, sweat drops and anger marks are general comics staples and are fine in our own style. They are drawn here in each fighter's own shapes with a keyline, not as a font glyph. Danger sense is short, straight bursts in the fighter's family, not a wavy squiggle.
- **No copying of a specific franchise's look or sound:** no spider-sense squiggle, no copy of a stealth game's "!" graphic or alert sound. Legal screens the set.
- **Glow rules:** no red, red-orange or gold flash for the Protagonist or the Anti-hero; no full-body glow as a power-stage signature for anyone (the surge is head and shoulder anchored and settles after the cinematic); the Protagonist's heat stays steam and veins.
- **Round-tipped fallback, ready.** The Anti-hero's pride flash is tall blades above the head, and the Empress's is a wedge fan, which could recall an upswept spiky aura. `ma-4-flash-rules.svg` shows the round-tipped version (pointed then round) for both. Blades and wedges switch to round tips and the shapes stay in their families.
- **Still to screen:** the sigils (ring, slash, chevrons, grid) against real symbols, and the Protagonist's dome mask.

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

## Questions for Orb (through the EP, two at most)

1. **Is twelve the right set?** Is any flash missing that you would want, or any you would cut?
2. **Should the info flashes** (danger sense, found, searching) **be always on,** or an option, since they also help players who cannot see the HUD?

## Files

`art/concepts/marked-aura/`: `ma-1-style.svg`, `ma-2-flashes.svg`, `ma-3-staging.svg`, `ma-4-flash-rules.svg`, `flashes.json`, `gen.mjs`, `README.md`. The in-engine prototype spec is `docs/art/flash-prototype-spec.md`. The prompt record is `art/prompts/ART-0005-marked-aura.md`.
