# Close-ups of the fighters' faces: three directions, a recommendation

> **Parked (2026-10-02, Orb's decision).** The mask aesthetic and the broken masks are for one future character, not the game's house style. Directions A and B and everything below are kept as a seed for that character; the house style is the unmasked faces and the current silhouettes, being refined in `art/concepts/refine/`.

Owner: Art Director. 2026-10-02. Orb: "loop on the art style to create stylized closeups of the fighters' faces so the on-screen closeups can be memorable and recognizable." Concept art, working labels, **pending Legal review**. Orb picks. This replaces the faceless portraits as the thing to choose from (`rule-of-cool-art.md` section 1 still holds the frame, the sizes and the zero-budget texture note).

**The one page for Orb:** `art/concepts/closeups/closeups-comparison.svg`. The path (nine rounds, the rejected ones kept): `art/concepts/closeups/rounds/NOTES.md` and `rounds/round-1/` to `round-9/`.

## The three directions

| | What it is | Sheets (Anti-hero, then the other three) |
|---|---|---|
| **A: the mask as a face** | The mask carries the expression: lit eyes, brows and a mouth that change shape, bold and graphic. No skin | `anti-hero-A.svg`, `others-A.svg` |
| **B: the mask partly off or broken** | A real stylized face (an eye, a brow, a mouth) framed by the mask, which is broken a different way for each fighter: a vertical lit crack (Anti-hero), a diagonal chunk (Protagonist), a bone jaw plate (Empress), a display half (Cyborg) | `anti-hero-B.svg`, `others-B.svg`, and the blank-mask variant `anti-hero-B-blank.svg`, `others-B-blank.svg` |
| **C: no mask** | A full stylized face with one unmistakable feature each: the Anti-hero's lit cheek slash and long tail, the Protagonist's swept teal hair with its long tuft and temple arc, the Empress's diadem with three moss chevrons and topknot, the Cyborg's steel half with a lit square eye | `anti-hero-C.svg`, `others-C.svg` |

Every sheet shows the four expressions (neutral, smirk, strain, hurt) at 420 or 300, 200 and 120 px in colour and greyscale, and in Camera's slanted panel (56 percent of the width by 20 percent of the height, the ends slanted, cropped to the eye band). Silhouettes are big flat shapes in limited values with one accent each. The Anti-hero stays in his violet range (orchid, hue 266). The four never share a skin tone, a hair silhouette or a head shape: a long tail (Anti-hero), a swept tuft (Protagonist), a topknot and diadem (Empress), a box (Cyborg).

## Battle damage on the face

`art/concepts/closeups/damage-ladder-B.svg`: fresh, scuffed, torn, ruined, for all four fighters in direction B. At each stage the mask retreats and the face comes out: scuffs and a bruise (stage 1), a crack in the mask, a cut and a loose strand (stage 2), a swollen eye and a second crack (stage 3). The damage stays and builds, as for the body (`rule-of-cool-art.md`). The same overlay set ports to A (chips and cracks on the mask) and C (cuts and bruises).

## Recommendation

**Take B as the standard close-up.** It gives Orb the talking character's real face, keeps every fighter masked and recognisable by the way their mask is broken (a break nobody else has), keeps the sigils, and makes the damage stages show on the face. Use **A** as the composed, fresh state where a face would be wrong (the Anti-hero's Proud front, before his facade cracks), so one Anti-hero reads composed, then cracked, then broken. **C** is the safe fallback if Legal will not accept lit eyes on masks, but it drops the masks (the fighters' identity) and is the least ownable.

## Open questions

- **Orb:** B or A as the default, and whether the Anti-hero's composed state uses A.
- **Legal:** A, and B's masked half, put lit eye and mouth shapes on the masks, which meets the earlier condition on the dome ("no eye or mouth slots or dots"; `q3-screen.md`). B with a blank mask half (`anti-hero-B-blank.svg`) keeps the masked side free of eyes and mouths and is the fallback. C has no masks, so no mask rule, but the faces need the same originality screen (no known face shapes, hair silhouettes or eye styles; no spiky hair, no gold; the stacking rule is not engaged by a face).
- **UI:** the portraits are 512-unit squares in our own frame, as in `rule-of-cool-art.md`; the art faces right and UI mirrors it for the right-hand speaker.

## Files

`art/concepts/closeups/`: `engine.mjs` (the face engine), `gen.mjs` (`node art/concepts/closeups/gen.mjs <round> [--final]`), the final sheets, `rounds/`. The prompt record is `art/prompts/ART-0011-closeup-directions.md`.

## Round 7: B as the lead (iterating while Orb is away)

Sheets in `art/concepts/closeups/`: `expressions-B.svg`, `anti-hero-transition.svg`, `crops-sheet.svg`, and the regenerated direction sheets, comparison and damage ladder. Files: `crops/square/` and `crops/strip/`.

- **Eight expressions** (neutral, smirk, strain, hurt, plus laugh, contempt, shock, grief) for all four fighters. Laugh squeezes the eyes into arches and opens the mouth; contempt has one brow high, heavy lids, a sneer and a head tipped back; shock opens the eyes wide with small pupils and a round mouth; grief pulls the brows up in the middle, drops the eyes, adds one tear and a quivering mouth. `ui/data/faces.json` has four expression slots per fighter; UI and Tools need four more (laugh, contempt, shock, grief), and Narrative's lines decide which are used.
- **Finer faces.** The Anti-hero: a longer tail with a second strand and a fatter lit cheek slash with a halo. The Protagonist: a longer, hooked tuft and a bolder temple arc. The Empress: the diadem with two hanging blades and larger chevrons (the first try, wings running out sideways, read as a hat brim and was dropped). The Cyborg: a lit eye with scan bars, a halo and a three-pip readout.
- **The Anti-hero's Proud front breaks** (`anti-hero-transition.svg`): composed mask and smirk (direction A), a hairline crack, the split, the far half letting go and falling, broken (direction B), ruined (stage 3). One number, t from 0 to 1, drives the crack and the fall; the engine does the same for the other three along their own break lines (shown under the Anti-hero's row). It can be driven from the facade value or stepped (0, 0.28, 0.5, 0.74, 1).
- **Two crops per portrait.** The square is the 512 portrait in our frame, checked at 200 px and at the 72 px floor (it reads in colour and in greyscale). The strip is 500 by 100 (5 to 1, which is 56 percent by 20 percent of a 16 by 9 screen), the ends slanted 22 percent of the height, cropped to the brows and eyes with the fighter's own feature in it. **Camera's panel is a live second-camera render (`rule-of-cool-shots.md` row 11), so the strip art is an option, not a need:** it fits the "still" panel mode, a KO or finisher freeze, or the face over the live strip. Camera decides.
- **Silhouettes for Animation:** `art/concepts/silhouettes/ragdoll-silhouettes.svg` (ART-0012).

Regenerate: `node art/concepts/closeups/gen.mjs 7 --final` (the crops are written only with `--final`).

## Round 8: Legal's constraints applied (RL-044, `docs/legal/q3-screen.md`)

Legal screened the close-ups: the blank-mask fallback is not required, lit shapes may stay with constraints, and the silhouettes and the frame are GO. Every sheet, the eight expressions, the transition and the crops were regenerated under them; the damage ladder and direction C, which Legal did not look at, were checked against the same rules.

| Constraint | How it is met |
|---|---|
| No matched pair of round eyes plus a line mouth on a smooth white mask | The Protagonist's lit eyes are tilted capsules (never round); his A mask and the Empress's carry a seam (the line their B break follows), so neither is a smooth white face; the lit mouth is a thin lane-colour line |
| No X or cross marks, goggles, red lips or red mouth marks; mouths are thin lines in the lane colour | Lit mouths are thin lines in the lane colour (a deeper lane tone on the pale masks); teeth are off-white, no tongue colour; the loose strand in the damage stages now ends above the brow (round 7's crossed it, a cross), and the two mask cracks no longer intersect |
| Lit shapes from each fighter's own family | Anti-hero: blades and hexagons. Protagonist: capsules and ring arcs. Empress: wedges. Cyborg: rectangles |
| The Protagonist's lit circle becomes a capsule or ring arc | A capsule (B and A) |
| No lone glowing red eye on a metal half | Round 8 gave the Cyborg's lit eye a display cluster; Legal found a scanner on the eye, so round 9 replaced it with a plain pale lit rectangle (see below) |
| The Cyborg's split diagonal or off-centre (about a third to two thirds), in B and C | A stair that runs diagonally down and to the right; the display or steel is about a third of the face (more at the brow, less at the jaw), and the transition and damage retreat it further. The Anti-hero's jagged vertical break stays (a mask with lit shapes against a plain face) |
| No bolts or stitches on the box head, no spiky hair, no gold, no torn-paper frame | The stitch ticks on the damage cuts are gone; no bolts anywhere; the hair is unchanged (smooth masses, a swept tuft); no gold; the frame is the chamfered square |

Also in round 8: the Empress's diadem tabs are shorter and hug the head (so they cannot read as a winged helmet), the Protagonist's tuft is shorter, and `damage-expressions-B.svg` shows the four damage stages on all eight expressions for each fighter.

## Round 9: Legal's two round 8 conditions (RL-045), and damage for direction A

- **The Cyborg's lit eye** is now a plain lit rectangle in a pale cream-peach (high lightness, low colour). The scan bars, pips and halo are gone from the eye. The lit brow is the same pale tone (dark steel on the steel half in direction C), and every lit edge, crack and scuff on him is the same pale tone, so the 120 px greyscale view reads as light, not red. The readout is three small pale pips on the jaw plate, away from the eye.
- **The Protagonist's swollen eye** (damage stage 3) is a plain opaque swollen shape with a slit; the eye under it no longer shows through as a ring. The same swelling is used for all four fighters.
- **Damage stages for direction A** (`damage-expressions-A.svg`, next to `damage-expressions-B.svg`): stage 1 scuffs and one chip, stage 2 a crack down the cheek, more chips (the mask broken away to show skin) and a bruise showing through, stage 3 a long crack beside the nose, a corner of the mask gone and a second bruise. The cracks never cross, and there are no stitch marks. Orb can now compare A and B across all eight expressions and four damage stages.

Stop here and wait for Orb's pick (B, or A as the Anti-hero's composed state).
