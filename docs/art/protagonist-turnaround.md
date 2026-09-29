# The Protagonist: turnaround

Owner: Art Director. 2026-09-29. A turnaround of the hero for modelling and for Animation, in the same format as the Coil's. Concept art, working labels, **pending Legal review**. Sheet: `art/concepts/turnaround/protagonist-turnaround.svg`. `node art/concepts/turnaround/gen-fighters.mjs` regenerates it (and the other two).

## What is on the sheet

- **Front, three-quarter right, three-quarter left, back** at one size with guide lines (top of head, chin, shoulders, chest, waist, hip, knee, ground). Three-quarter left is the right view mirrored, because the game mirrors a fighter who faces left. The front and back are for modelling and are not staged in play.
- **The pose in play** (the forward-leaning open stance): three-quarter right, three-quarter left and profile.
- **Read at play sizes:** 80, 40, 24 and 12 px, in colour and as a silhouette.
- **Wear:** fresh, bruised, battered, broken.
- **The mask:** neutral, taunt, hurt, rage and triumph in three-quarter, and the back of the head.
- **A part list** with triangle estimates, the palette and the rig notes.

There is no forms row (the Coil's spine plates were one per form). This fighter's stages are not fixed yet, so a forms row will follow when Game Design fixes them.

## The design, view by view

| View | What reads |
|---|---|
| Front | A pale designed dome with the open temple arc, high teal fringe; a V of light collar trim; bare arms with tone-on-tone wraps on the near forearm; a wide light belt with a round buckle over a sash apron; closed wrapped fists; boots with a light cuff |
| Three-quarter | The dome turned so the open arc sits at the temple above the brow ridge; the swept-back tuft behind; the belt knot standing out behind the hip as one round disc; the apron and two sash tails |
| Back | The head is all hair, a smooth cap with a rounded tuft down the nape; the belt across the back with the knot as one disc and two sash tails; the sash apron |
| Pose in play | Leaning forward, wrapped fists forward, weight on the front foot; the knot swings behind |

**Proportions.** About 5.5 heads tall (the measure on the sheet: 99 units to the top of the head, a head of 18.1 units).

**Palette.** Tunic `#1a3d46`, gear `#c4ece6`, accent teal `#4fb9a8`, mask `#e8f1ee` (pale, approved by Orb), skin `#a56d4d`, hair `#3fae9c` (never changes). The arc is painted on the pale mask, and is emissive only in the surge.

## Notes for the modeller

- Build: round, open, forward-leaning. Torso 1.0 of the standard height and 1.1 wide, legs 1.0, arms 1.05, head 1.08.
- Staging: three-quarter in play, mirrored when the fighter faces left, so the left view is the right view mirrored. The front and back are for modelling and are not staged in play.
- The value rule: dark tunic, light gear and mask. Tunic #1a3d46, gear #c4ece6, mask #e8f1ee, hair #3fae9c, accent #4fb9a8. Hair never changes colour.
- The mask is a designed dome: a faceted crown, a brow ridge, a jaw plane and a crown seam. No eye or mouth slots or dots. The sigil is a single open arc (a \"C\" with a gap facing forward), off-centre at the temple above the brow ridge: never a closed ring, no dot, never with the slash. Hurt widens the gap.
- Front features (belt, buckle, collar trim, sash apron) sit on the front surface. Back features (knot, sash tails, apron) sit on the back surface. The back knot is one disc: no concentric rings.
- Legal conditions kept: the hair is a swept-back cap, never spiky or upswept, and never gold; no red or gold glow; the heat (Hot Blood) is steam and veins on the body, never a body aura.

Suggested near-LOD budget, about 1,600 triangles against the 2,500 budget in the style guide:

| Part | Note | Tris |
|---|---|---|
| Mask (head) | A designed dome with brow ridge, jaw plane and crown seam. A sigil decal slot (an open arc, off-centre). No face rig. | 180 |
| Hair | A swept-back cap and a rounded tuft on a 3-bone spring chain. Never changes colour or shape. | 80 |
| Neck and torso | A sleeveless dark tunic with a light collar trim. | 320 |
| Belt, knot and sash tails | A wide light belt, a solid disc knot at the back and two sash tails on a 2-bone spring chain each. | 110 |
| Sash apron | A light cloth panel to the hip, front and back. | 60 |
| Arms, two | Bare upper arm and forearm each. | 240 |
| Forearm wraps, three | Tone-on-tone wraps with a diagonal edge on the near forearm, toggled by stage. Not contrasting wristbands. | 90 |
| Hands, two | Wrapped fists. Open variants for taunt and guard. | 140 |
| Legs, two | Thigh and shin each. | 240 |
| Boots, two | Dark, with a light cuff. | 140 |

Bones, about 26: root, pelvis, two spine, neck, head, three hair tuft (spring), two sash tails of two (spring), two shoulders, upper arms, forearms, hands, thighs, shins, feet. Palette masks: red channel tunic, green gear, blue accent, alpha the emissive sigil (the arc). Wear is five floats (head, core, arms, legs, crown). Steam and veins are separate decals and particles.

## What I added to the design

The base design had no front. The turnaround adds a light collar trim, a buckle on the belt and a sash apron to the front and the back, changes the back knot from two concentric rings to one solid disc (Legal: no concentric rings), makes the temple sigil an open arc so the face-on view is safe for key art (Legal, second pass), and makes the forearm wraps tone-on-tone rather than contrasting wristbands. These are proposals for Orb and Legal. They keep the Legal conditions in `docs/legal/q3-screen.md`: no eye or mouth slots or dots on any mask, no rays at the sigil, no red or gold glow for the hero and the anti-hero, and nothing tall and upswept above any head.

## Limits and risks

- The figure is a procedural concept model with a 2D approximation of the turn, so proportions and the front and back mask shapes are an approximation. The real model replaces it.
- The front and back views use extra spreads at the arms and legs so they clear the body. A real A-pose model will differ.
- The sigil is an open arc at the temple, above the brow ridge, with no dot and no second one. Legal asked for the open arc so the face-on view cannot read as an eye; it is worth a look on the real model.
- The hair fringe was raised so the ring shows, which makes the front head read as a tall cap. The real model can tuck the fringe and keep the ring visible.
- No human has authored the design yet (Legal 8.5.3), and I could not run a fan-recognition check.

## Files

`art/concepts/turnaround/`: `protagonist-turnaround.svg`, `gen-fighters.mjs`, `README.md`. Shared code: `art/concepts/shared/marks.mjs`. The prompt record is `art/prompts/ART-0008-fighter-turnarounds.md`.
