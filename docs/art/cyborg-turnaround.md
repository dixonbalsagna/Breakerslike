# The Cyborg: turnaround

Owner: Art Director. 2026-09-29. A turnaround of the cyborg for modelling and for Animation, in the same format as the Coil's. Concept art, working labels, **pending Legal review**. Sheet: `art/concepts/turnaround/cyborg-turnaround.svg`. `node art/concepts/turnaround/gen-fighters.mjs` regenerates it (and the other two).

## What is on the sheet

- **Front, three-quarter right, three-quarter left, back** at one size with guide lines (top of head, chin, shoulders, chest, waist, hip, knee, ground). Three-quarter left is the right view mirrored, because the game mirrors a fighter who faces left. The front and back are for modelling and are not staged in play.
- **The pose in play** (the heavy, planted stance): three-quarter right, three-quarter left and profile.
- **Read at play sizes:** 80, 40, 24 and 12 px, in colour and as a silhouette.
- **Wear:** fresh, bruised, battered, broken.
- **The mask:** neutral, taunt, hurt, rage and triumph in three-quarter, and the back of the head.
- **A part list** with triangle estimates, the palette and the rig notes.

There is no forms row (the Coil's spine plates were one per form). This fighter's stages are not fixed yet, so a forms row will follow when Game Design fixes them.

## The design, view by view

| View | What reads |
|---|---|
| Front | A dark boxy display head with the stair of four lit squares and the head hatch bar; heavy dark red plating with a mail overlay; the rail down the chest with the open chest hatch and its chip, and the hip hatch; a mail apron to the thigh with a zig hem; two cables over the shoulders; heavy plated forearms and closed fists |
| Three-quarter | The display face turned so the stair reads; the squared backpack unit with its four vents standing off the back; the cables looping from the pack over the shoulder to the rail and the hip |
| Back | A blank dark box for the back of the head; the backpack unit with four vents and the back hatch; the belt; two cables from the pack to the shoulders |
| Pose in play | Heavy and planted, fists forward, chin down |

**Proportions.** About 5.3 heads tall (the measure on the sheet: 99 units to the top of the head, a head of 18.8 units).

**Palette.** Plating `#3a161c`, gear `#cfc7cb`, accent coral `#d8705f`, mask `#34313d` (dark, approved by Orb), skin `#a99fa5`, hair `#3a161c` (unseen). The plating is dark red and the mask cool grey, so the pair does not read as black-and-red.

## Notes for the modeller

- Build: heavy and blocky. Torso 1.36 wide, legs 0.95, arms 1.02 with 1.38 wide limbs, head 1.12 (a boxy head).
- Staging: three-quarter in play, mirrored when the fighter faces left. The front and back are for modelling and are not staged in play.
- The value rule: dark red plating, light gear and mail. Plating #3a161c, gear #cfc7cb, mask #34313d, accent #d8705f. No black-and-red look: the plating is dark red, the mask is a cool dark grey, the sigil is soft coral.
- The mask is a dark display face. The sigil is a stair of four lit squares of growing size on a diagonal: never a line grid, never a cross or plus, never a 2 by 2 block. Hurt and brink drop a step.
- Four hatches: head (a bar on the mask), chest (open, the chip shows there), back (behind the backpack) and hip. The rail runs down the chest between them.
- Front features (rail, chest and hip hatches, mail apron, shoulder cables) sit on the front surface. Back features (backpack unit with four vents, back hatch, belt) sit on the back surface.
- The mail is a tiled pattern in the shader (a normal-map look), not geometry. The cables are two spring chains. Its flashes are steel for information and coral for emotion.

Suggested near-LOD budget, about 1,980 triangles against the 2,500 budget in the style guide:

| Part | Note | Tris |
|---|---|---|
| Mask (head) | A boxy head with a display face. A sigil decal slot (a stair of squares) and a head hatch bar. | 140 |
| Neck and torso | Heavy plating over a dark under-suit. | 380 |
| Chain-mail apron | A mail apron to the thigh with a zig hem. The mail is a tiled shader pattern. | 80 |
| Rail and four hatches | A rail down the chest, chest and hip hatches on the front, a back hatch, the head hatch bar. | 120 |
| Backpack unit | A squared unit with four vents and a back hatch. | 220 |
| Cables, two | Two looping cables from the pack over the shoulders to the rail and hip, on spring chains. | 100 |
| Arms, two | Heavy mail upper arm and plated forearm each. | 300 |
| Shoulder plates | Two plates, rigid on the shoulders. | 60 |
| Hands, two | Heavy closed fists. | 160 |
| Legs, two | Thigh and shin each, short (0.95). | 260 |
| Boots, two | Heavy dark boots with a light cuff. | 160 |

Bones, about 26: root, pelvis, two spine, neck, head, backpack, four cable (two chains of two, spring), two shoulders, upper arms, forearms, hands, thighs, shins, feet. Palette masks: red channel plating, green gear, blue accent, alpha the emissive sigil (the squares). Wear is five floats (head, core, arms, legs, crown). The chest hatch has a closed and an open variant with the chip.

## What I added to the design

The base design had no back. The turnaround adds the front rail as a symmetric strip with the hatches on it, a backpack unit seen from behind, and the mail as a shader pattern. The sigil is now a diagonal stair of four lit squares (Legal: no line grid, never a 2 by 2 block). These are proposals for Orb and Legal. They keep the Legal conditions in `docs/legal/q3-screen.md`: no eye or mouth slots or dots on any mask, no rays at the sigil, no red or gold glow for the hero and the anti-hero, and nothing tall and upswept above any head.

## Limits and risks

- The figure is a procedural concept model with a 2D approximation of the turn, so proportions and the front and back mask shapes are an approximation. The real model replaces it.
- The front and back views use extra spreads at the arms and legs so they clear the body. A real A-pose model will differ.
- A dark red body with a dark mask is the lowest-contrast of the four at 12 px; it reads by the mail and the coral squares, and the rim rule keeps it off dark backdrops. See the style guide.
- The mail is a tiled shader pattern; the tile scale will need a look on the real model so it does not shimmer.
- A boxy head with a lit stair can read as a screen; that is the intent, but it must not become a goggle or a visor.
- No human has authored the design yet (Legal 8.5.3), and I could not run a fan-recognition check.

## Files

`art/concepts/turnaround/`: `cyborg-turnaround.svg`, `gen-fighters.mjs`, `README.md`. Shared code: `art/concepts/shared/marks.mjs`. The prompt record is `art/prompts/ART-0008-fighter-turnarounds.md`.
