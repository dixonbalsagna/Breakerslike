# Close-ups of the fighters' faces: three directions, a recommendation

Owner: Art Director. 2026-10-02. Orb: "loop on the art style to create stylized closeups of the fighters' faces so the on-screen closeups can be memorable and recognizable." Concept art, working labels, **pending Legal review**. Orb picks. This replaces the faceless portraits as the thing to choose from (`rule-of-cool-art.md` section 1 still holds the frame, the sizes and the zero-budget texture note).

**The one page for Orb:** `art/concepts/closeups/closeups-comparison.svg`. The path (six rounds, the rejected ones kept): `art/concepts/closeups/rounds/NOTES.md` and `rounds/round-1/` to `round-6/`.

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
