# Marked plus Aura: the character style

Owner: Art Director. 2026-09-29. Round 4. Orb's pick: "I like marked, I like aura. Combine them, and make sure the aura is there to exaggerate or convey appropriately," staged with the blocking rules. Concept art for Orb to choose from. Working labels and placeholder looks. Results are **pending Legal review**.

**Sheets** (`art/concepts/marked-aura/`):
- `ma-1-style.svg`: the four fighters, the mask tone per fighter with its reason, 40 px and 12 px reads with a civilian, and the neutral, taunt, hurt, rage and triumph strip per fighter with a head close-up.
- `ma-2-aura-rules.svg`: the aura in seven states and four shape families, the aura set against the HUD crown on one figure, and the rules.
- `ma-3-staging.svg`: four staged moments in the greybox scene: a face-off, a clash, a transformation and a hurt or brink moment, all with the four fighters and the blocking rules.

`node art/concepts/marked-aura/gen.mjs` regenerates all three. Scene backdrops are the repo's own renders in `docs/rendering/img`, embedded by reference.

## The idea in one line

**The sigil is who they are and a small flick of how they feel. The aura is how big the feeling is and what state they are in.** The mask alone cannot shout, so the aura does: rage flares, hurt gutters, pride stands tall, triumph blooms, a transformation surges.

## Mask tone per fighter (recommendation)

| Fighter | Tone | Personality | Readability | Sigil |
|---|---|---|---|---|
| Protagonist | Pale (`#e8f1ee`) | Earnest, open, approachable | A light spot over the dark tunic at 40 px | Painted teal ring, lit only at rage and transformation |
| Anti-hero | Dark (`#2b2444`) | Guarded and formal; the face is a closed front | Dark reads well against sky, and the lit sigil is the only face | Emissive orchid slash that cracks with the facade |
| Empress | Pale (`#e6e0c4`, warm bone) | Image-focused and theatrical: a polished mask | A beacon on a dark olive body. No horns | Painted moss chevrons |
| Cyborg | Dark (`#34313d`) | A machine wearing politeness: a display face | Dark reads as a screen, and the lit grid is its expression | Emissive coral grid |

Two pale and two dark, so any pair in a face-off differs in head tone as well as in shape. Dark masks carry an emissive sigil (the glow is the face). Pale masks carry a painted sigil that only glows in rage and transformation.

## The aura

**Shape families (from each fighter's shape lane):** circles (Protagonist), blades (Anti-hero), wedges (Empress), steps (Cyborg). One layout per state, drawn in the family, so the four look different in every state.

| State | Layout | Reads as |
|---|---|---|
| Neutral | A faint hint (12% opacity) | The fight stays clean |
| Pride | Tall, symmetrical, steady, above the head | Standing tall (the Anti-hero's front) |
| Taunt | Lopsided and drifting to one side | Smugness |
| Hurt | A few small fragments, low and detached, dim and jittering | Flickering and guttering |
| Brink | Two dim fragments and a cracked sigil | Nearly out |
| Rage | Forward-swept, jagged, larger, a bright core | Flare |
| Triumph | Radial, opening upward, bright | Bloom |
| Transformation | Tall shapes, radial shapes and ground shards from the head and shoulders | Surge |

### How it stays distinct from the HUD aura crown

The crown (`docs/ui/hud-spec.md`) is transient thin arcs and rings around the whole body on the HUD layer. The diegetic aura must never be mistaken for it.

| | Diegetic aura (Art) | HUD aura crown (UI) |
|---|---|---|
| Shape | Filled cel shapes in two steps, in a family (circles, blades, wedges, steps). Never a thin line, never a closed ring | Thin arcs and concentric rings, always round |
| Place | Head and upper back, in the scene, behind the fighter. Rises up to about one body height | Centred on the chest, around the whole body, on the HUD layer above the fighter |
| Colour | The fighter's accent in two steps at 12 to 55% opacity | Neutral role colours in thin strokes |
| Motion | Changes shape, never blinks. Hurt jitters irregularly. Rage swells over about 0.15 s and settles | Pops and fades over about 1 to 1.5 s. Flicker is a regular 4 Hz on and off. The brink ring is a slow 1.2 Hz breath |
| Time | A state: lasts as long as the emotion or state. Faint at neutral | An event: pops for a hit, a stage change, a brink change |

**Suggested changes for UI (small):**
1. Keep the crown's strokes in neutral role colours, never the fighter's accent, so the two never share a hue.
2. Consider dropping the crown pop for tier-up and transformation, because the aura surge and the cinematic already carry it. Keep the pops for wound changes.
3. Keep the crown's flicker regular and the brink ring thin, dashed and round, as specified.
4. Camera should leave headroom above the head (about one body height) for a surge.

### Legal's glow rules

- **Protagonist:** no red, red-orange or gold aura. The aura is teal. It is head and shoulder anchored, never body-wide, and never a power-stage signature: Hot Blood stays steam and veins on the body.
- **Anti-hero:** no gold or red glow. The aura is orchid violet.
- **No full-body aura as a power-stage signature for anyone.** The aura is a mantle at the head and upper back. The transformation surge is a burst during a respected cinematic, then it settles to a pride aura.
- **Watch item for Legal:** the Anti-hero's pride aura is tall blades above the head, and the Empress's is a wedge fan. A tall pointed aura above the head could recall an upswept spiky aura. The colours are not gold, and it is an aura and not hair, but Legal should look. A fallback is smooth, round-tipped columns.

## Staging (blocking rules)

Applied on `ma-3-staging.svg`:
- **Three-quarter cheat-out:** torso, hips and head turned about 32 degrees toward the camera, the chest design and the mask face showing.
- **Mirrored on side-swap:** a fighter facing left is the mirror image, so the front always faces the camera and the back is never shown. The sigil sits on the face plane, so it reads either way.
- **Downstage reads as commanding:** in the face-off the Protagonist and Cyborg are downstage (larger, lower in frame) and the Anti-hero and Empress upstage.
- **The aura sits behind the head and shoulders,** so it never hides the mask, the sigil or the chest. In rage it leans forward.

The four moments: a face-off (pride, taunt, and the leads waiting), a clash (two leaning in, auras overlapping at the contact), a transformation (the Anti-hero surges, the others watch), and a hurt or brink moment (the Protagonist folded, aura guttering, next to UI's dashed brink ring to show the difference).

## What the checks showed

1. **The aura does the exaggerating the mask cannot.** In the strips the mask sigil alone is a small change, and the aura carries the size of the emotion. At 40 px the aura is the readable part: a flare, a bloom and a fragment cloud are unmistakable, and the sigil confirms who it is.
2. **At 12 px the aura is a colour hint,** a small spot of the lane colour above the head. It helps the far read but does not replace the far beacon.
3. **The aura and the crown are visibly different** on the same figure: filled and irregular against thin and round.
4. **Dark masks work because of the sigil glow.** Without the lit sigil, the Anti-hero's and Cyborg's heads would vanish against dark bodies.
5. **The aura crowds the sky at showcase size** because it rises up to one body height. Camera and framing need headroom.

## Questions for Orb (through the EP, two at most)

1. **Are the mask tones right?** Pale for the Protagonist and Empress, dark for the Anti-hero and Cyborg.
2. **Is the Anti-hero's pride aura right as tall blades,** or would you prefer a calmer, round-tipped column?

## Files

`art/concepts/marked-aura/`: `ma-1-style.svg`, `ma-2-aura-rules.svg`, `ma-3-staging.svg`, `gen.mjs`, `README.md`. The prompt record is `art/prompts/ART-0005-marked-aura.md`. This round reuses the figure kit (`art/concepts/anti-hero/kit.mjs`) and the four fighters (`art/concepts/directions/fighters.mjs`) unchanged.
