# Prompt record: ART-0011, the close-up face directions

Rules: `docs/art/ai-prompt-policy.md`. Record for `art/concepts/closeups/engine.mjs`, `gen.mjs`, the sheets and `rounds/` in that folder.

- asset id: ART-0011
- date (UTC): 2026-10-02
- tool, model and version: Claude Code (desktop app), model claude-sonnet-5-5. The session is titled "Meridian - Art"
- settings and seed (if any): none. Deterministic
- purpose: stylized close-ups of the fighters' faces so the on-screen close-ups are memorable and recognizable: three style directions, six rounds, a damage ladder and a recommendation
- input images: none. No reference image of any kind was used
- outputs kept: round 6 as the candidate set (round 7 adds eight expressions, the Anti-hero's transition and the two crops), and every earlier round in `rounds/` (the path)
- outputs rejected: a lifted dome (a shower cap), eye cutouts (sunglasses), a lower-face veil (a beard), a fringe that read as a cap; all kept in `rounds/` to show the path
- what a human changed: Orb's request and the EP's brief direct the work; Orb picks the direction
- originality checklist: `docs/art/closeup-directions.md`; no known face shapes, hair silhouettes or eye styles; our own frame
- reverse-image search: not yet run
- Legal review: pending
- disclosure category: development aid until Orb picks

## Prompt (the brief, as relayed by the EP on 2026-10-02)

> Orb: "loop on the art style to create stylized closeups of the fighters' faces so the on-screen closeups can be memorable and recognizable." Produce, for the Anti-hero first and then the other three: three distinct style directions for the close-up, each with the four expressions at 420, 200 and 120 px in colour and greyscale: (A) the mask as a face, (B) the mask partly off or broken, (C) no mask. Loop: render each sheet, criticise it against "memorable and recognizable at a glance, four fighters never confused, expression readable at 120 px", revise at least twice, keep the rejected rounds. A one-page comparison for Orb with a recommendation. Constraints: originality, Legal's stacking rule and screen, the Anti-hero's colours in the violet range, our own frame, the damage stages carried onto the face, SVG as final art.

## Negative prompt

None. No franchise names, no franchise images, no known face shapes or hair silhouettes.
