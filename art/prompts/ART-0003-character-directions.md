# Prompt record: ART-0003, the character art direction sheets

Rules: `docs/art/ai-prompt-policy.md`. Record for `art/concepts/directions/gen.mjs`, `fighters.mjs`, the style hooks added to `art/concepts/anti-hero/kit.mjs`, and the five SVG sheets in `art/concepts/directions/`.

- asset id: ART-0003
- date (UTC): 2026-09-29
- tool, model and version: Claude Code (desktop app), model claude-sonnet-5-5. The session is titled "Meridian - Art"
- settings and seed (if any): none. Deterministic. The ink look uses SVG turbulence filters with a fixed seed
- purpose: four character art directions, each drawing the four fighters, for Orb to choose from
- input images: none. No reference image of any kind was used. The only images viewed were this generator's own renders
- outputs kept: `dir-1-blank.svg`, `dir-2-ink.svg`, `dir-3-toy.svg`, `dir-4-poster.svg`, `directions-comparison.svg`, and the generator files
- outputs rejected: none kept. Earlier passes were overwritten
- what a human changed: nothing yet. Orb has not picked or authored a design (Legal 8.5.3)
- originality checklist: `docs/art/directions.md`, pending Legal review. No franchise or feel-reference look was used as input
- reverse-image search: not yet run
- Legal review: pending
- disclosure category: development aid until Orb picks a direction

## Prompt (the brief, as relayed by the EP on 2026-09-29; the feel-reference series and its constraint are named in the brief and are not repeated here)

> Orb's reaction to round 2: "F Coil looks like a good start. Can we do a few more style passes? I'm not entirely happy with the current character designs. I want them to be striking and recognizable. If the style is distinct enough the faces won't be necessary; blank character heads could be a style choice. Let me see some proposals for the overall art direction as far as characters are concerned."
> Brief: 4 character art directions, one sheet each plus a comparison sheet. For each direction, show all four fighters: Protagonist (teal lane), Anti-hero based on the Coil (violet), Empress (chartreuse, bladed mantle as a cape-train, guard of honour), Cyborg (dark red, wiring and chain-mail, Rail chip hatches). Show each as a silhouette plus a colour figure at gameplay size (12 and 40 px) and at a larger showcase size, with a civilian for scale. Say what makes each direction striking and recognizable, and how it builds as low-poly faceted cel in Godot.
> Explore a real range: a bold graphic, faceless look; a heavy-ink or brush-edge look; a sculpted or toy-like look; a stark two-tone or poster look. Your call on the four.
> Constraints: Legal: nothing borrowed from the feel reference's look (no grey round-headed figures with cross-mark eyes or its line style), and from no franchise. Keep your readability rules (value rule, two-tone edge, far beacon). Blank heads are allowed but must still read direction and emotion through posture and the head's shape or tilt.
> Deliverables: docs/art/directions.md and SVG sheets in art/concepts/directions/. Recommend one, and include 2 or 3 short questions for Orb. No workflows. The standard report, short.

## Negative prompt

None.
