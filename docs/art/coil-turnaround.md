# The Coil: turnaround

Owner: Art Director. 2026-09-29. A first turnaround of the Anti-hero as the Coil (Orb's round 2 pick), for modelling and for Animation. Concept art, working labels, **pending Legal review**. Sheet: `art/concepts/turnaround/coil-turnaround.svg`. `node art/concepts/turnaround/gen.mjs` regenerates it.

## What is on the sheet

- **Front, three-quarter right, three-quarter left, back** at one size with guide lines (top of head, chin, shoulders, chest, waist, hip, knee, ground). Three-quarter left is the right view mirrored, because the game mirrors a fighter who faces left. The front and back are for modelling and are not staged in play (the cheat-out never shows the back).
- **The crouch** (the Coil's signature stance): three-quarter right, three-quarter left and profile. The front and back of the crouch are foreshortened and are left to the real model.
- **Forms F1 to F6:** one spine plate per form.
- **Wear:** fresh, bruised, battered, broken.
- **The mask:** neutral, taunt, hurt, rage and triumph in three-quarter, and the back of the head.
- **A part list** with triangle estimates, the palette and the rig notes.

## The design, view by view

| View | What reads |
|---|---|
| Front | A dark wedge mask with the lit slash sigil down the middle; a chest harness of two crossing straps and a round buckle carrying the slash mark; a belt plate; forearm guards (from form 4) on the near arm; closed fists; short legs and boots with a light cuff |
| Three-quarter | The mask turned so the sigil sits on the face plane; the harness across the chest; the spine plates standing off the back as rounded slabs; the short tied tail flicking behind |
| Back | The head all hair (dark, never changing) with the tail hanging down the spine; six spine plates stacked down the middle as wide rounded slabs; the belt across the back |
| Crouch | Low and coiled, weight forward, fists at the chin; the plates read as a serrated back |

**Proportions.** Compact: about 4.9 heads tall (the measure on the sheet: 88 units to the top of the head, a head of 17.8 units), with the torso at 0.87, the legs at 0.84 and the arms at 0.95 of the standard figure, the head at 1.06 and the torso width at 1.12.

**Palette.** Body `#2a2043`, gear `#cbd3e2`, accent orchid `#9a80d8`, mask `#2b2444` (dark, approved by Orb), skin `#b98462`, hair `#1d1630` (never changes). The sigil is emissive on the dark mask.

## For the modeller

Suggested near-LOD budget, about 1,700 triangles against the 2,500 budget in the style guide:

| Part | Note | Tris |
|---|---|---|
| Mask | Blank wedge, a sigil decal slot, no face rig | 190 |
| Hair | A cap and a short tail on a 3-bone spring chain | 70 |
| Neck and torso | The bodysuit | 330 |
| Chest harness | Front only | 70 |
| Spine plates, six | Rigid on the spine bones, toggled by form, a cracked variant with core wear | 150 |
| Belt plate | Front and back | 30 |
| Arms | Upper arm and forearm each | 240 |
| Forearm guards, three | Toggled by form | 90 |
| Hands | Closed, with open variants | 140 |
| Legs | Thigh and shin each | 240 |
| Boots | With a light cuff | 140 |

About 24 bones: root, pelvis, two spine, neck, head, three tail (spring), two shoulders, upper arms, forearms, hands, thighs, shins and feet. Palette masks: red for body, green for gear, blue for accent, alpha for the emissive sigil. Wear is five floats (head, core, arms, legs, crown). Regalia pieces (the plates and the guards) are separate meshes with an intact and a broken variant.

## What I added to the design

The Coil in round 2 had no front design. To make the three-quarter and front views work, the turnaround adds a chest harness (two straps and a buckle with the slash mark), a belt plate that shows front and back, and a back view with the plates centred. These are proposals for Orb and Legal. They keep every condition: no shoulder pads with white gloves and boots, no flame or upswept hair, no hair-colour change, no gold or red glow, no cape.

## Limits and risks

- The figure is a procedural concept model with a 2D approximation of the turn, so proportions and the front and back mask shapes are an approximation. The real model replaces it.
- The front and back views use extra spreads at the arms and legs so they clear the body. A real A-pose model will differ.
- In the front view the mask is a plain wedge with a single lit slash. It reads, but it is the least expressive view. Expression lives in the three-quarter mask and the head flashes.
- No human has authored the design yet (Legal 8.5.3), and I could not run a fan-recognition check.

## Files

`art/concepts/turnaround/`: `coil-turnaround.svg`, `gen.mjs`, `README.md`. The figure kit (`art/concepts/anti-hero/kit.mjs`) gained a front-on view, a back view and limb spread. Earlier sheets regenerate identical. The prompt record is `art/prompts/ART-0006-coil-turnaround.md`.
