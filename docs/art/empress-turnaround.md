# The Empress: turnaround

Owner: Art Director. 2026-09-29. A turnaround of the empress for modelling and for Animation, in the same format as the Coil's. Concept art, working labels, **pending Legal review**. Sheet: `art/concepts/turnaround/empress-turnaround.svg`. `node art/concepts/turnaround/gen-fighters.mjs` regenerates it (and the other two).

## What is on the sheet

- **Front, three-quarter right, three-quarter left, back** at one size with guide lines (top of head, chin, shoulders, chest, waist, hip, knee, ground). Three-quarter left is the right view mirrored, because the game mirrors a fighter who faces left. The front and back are for modelling and are not staged in play.
- **The pose in play** (the upright, sweeping stance): three-quarter right, three-quarter left and profile.
- **Read at play sizes:** 80, 40, 24 and 12 px, in colour and as a silhouette.
- **Wear:** fresh, bruised, battered, broken.
- **The mask:** neutral, taunt, hurt, rage and triumph in three-quarter, and the back of the head.
- **The guard of honour:** a small retinue figure, three-quarter right and left.
- **A part list** with triangle estimates, the palette and the rig notes.

There is no forms row (the Coil's spine plates were one per form). This fighter's stages are not fixed yet, so a forms row will follow when Game Design fixes them.

## The design, view by view

| View | What reads |
|---|---|
| Front | A pale bone mask with three offset moss chevrons on the brow, a light headband across the hair line, a topknot; a low collar flare at the shoulders, below the eye line; a dark olive tunic panel with a wide belt; a long tabard to the shin; accent bracers on both forearms; the mantle flaring out behind the legs with its blade hem |
| Three-quarter | The mantle as a long stiff cape-train sweeping back, an accent band across the shoulders and a hem of blades; the low collar flare at the shoulder; the tabard hanging in front |
| Back | The head is hair with the topknot; the low collar flare; the mantle covers the whole back: an accent band across the shoulders, a centre seam and a hem of nine blades |
| Pose in play | Upright and sweeping, the near arm forward; the mantle trailing behind |

**Proportions.** About 5.3 heads tall (the measure on the sheet: 106 units to the top of the topknot, a head of 20.0 units).

**Palette.** Body `#2a2f1e`, gear `#e0deb8`, accent moss `#b8c96a`, mask `#e6e0c4` (pale bone, approved by Orb), skin `#d9a67f`, hair `#1e2413`. No purple, no horns.

## Notes for the modeller

- Build: wide, sweeping, upright. Torso 0.95 wide and 1.08 tall, legs 1.08, arms 1.02, head 0.98. Taller than the others by a topknot.
- Staging: three-quarter in play, mirrored when the fighter faces left. The mantle trails behind, so the front stays clear. The front and back are for modelling and are not staged in play.
- The value rule: dark olive body, light gear and mask. Tunic #2a2f1e, gear #e0deb8, mask #e6e0c4, accent #b8c96a. No horns, no purple, not pale overall.
- The mantle is a stiff cape-train with a hem of eight to nine blades and an accent band across the shoulders. It is a cloth sim on two spring chains of three. It is not a flame or hair shape.
- The mask is a polished bone shape. The sigil is three chevrons of different sizes, offset, in moss: an odd count, never a tidy double chevron, never in a car or oil brand's colours.
- Front features (tunic panel, tabard, belt, bracers) sit on the front surface. Back features (mantle, collar flare) sit on the back surface. Her flashes are a wide, low crest behind the head, so nothing tall stands above the topknot.
- The guard of honour is a separate retinue figure, not a fighter (see the small row): one shared model with a tabard and a helm, and no sigil.

Suggested near-LOD budget, about 1,840 triangles against the 2,500 budget in the style guide:

| Part | Note | Tris |
|---|---|---|
| Mask and topknot | A polished bone mask with a chevron decal slot, and a topknot ball on the hair. No face rig. | 200 |
| Headband | A light band across the brow, over the hair line. | 30 |
| Hair | A cap over the skull, tucked. The topknot is a ball on a 1-bone spring. | 60 |
| Neck and torso | A dark olive tunic with a high collar. | 300 |
| Tabard and belt | A long light tabard to the shin and a wide belt. | 90 |
| Mantle (cape-train) | A stiff cloth panel on two spring chains of three, with an accent band across the shoulders. | 200 |
| Hem blades, nine | Sharp shapes along the trailing hem, alternate two shades. Rigid, parented to the mantle. | 90 |
| Collar flare | Two low stiff flares at shoulder height, below the eye line, rigid on the upper spine. They never rise beside the head, so they never read as horns. | 50 |
| Arms, two | Sleeved upper arm and forearm each. | 240 |
| Bracer and hands | An accent bracer on the near forearm, open and closed hands. | 180 |
| Legs and boots | Long legs (1.08) and boots with a light cuff. | 400 |

Bones, about 30: root, pelvis, two spine, neck, head, topknot, six mantle (two chains of three, spring), two shoulders, upper arms, forearms, hands, thighs, shins, feet. Palette masks: red channel body, green gear, blue accent, alpha the emissive sigil (the chevrons). Wear is five floats (head, core, arms, legs, crown). The mantle has an intact and a torn variant.

## What I added to the design

The base design was drawn in three-quarter. The turnaround adds a front (tunic panel, tabard, belt, bracers, the mantle behind) and a back (the mantle as a closed cape-train, the collar crescent and the hair with topknot), and the small guard of honour row. These are proposals for Orb and Legal. They keep the Legal conditions in `docs/legal/q3-screen.md`: no eye or mouth slots or dots on any mask, no rays at the sigil, no red or gold glow for the hero and the anti-hero, and nothing tall and upswept above any head.

## Limits and risks

- The figure is a procedural concept model with a 2D approximation of the turn, so proportions and the front and back mask shapes are an approximation. The real model replaces it.
- The front and back views use extra spreads at the arms and legs so they clear the body. A real A-pose model will differ.
- The mantle is the largest part of her silhouette, and a wide flat cape-train is expensive in cloth sim and in screen width. Rendering and Animation should cost it early.
- The chevrons on a pale bone mask are quiet at 24 px. They pass the three-flat-colour test on the checks sheet, but the mask itself carries her at play sizes.
- The Empress's collar is a low flare at shoulder height, checked in the 12 px silhouette so it never reads as horns or antennae. The guard of honour has a small plume on the helm that can read as an ear from the side; the real model can drop it.
- No human has authored the design yet (Legal 8.5.3), and I could not run a fan-recognition check.

## Files

`art/concepts/turnaround/`: `empress-turnaround.svg`, `gen-fighters.mjs`, `README.md`. Shared code: `art/concepts/shared/marks.mjs`. The prompt record is `art/prompts/ART-0008-fighter-turnarounds.md`.
