# Prompt record: ART-0010, the rule-of-cool art pass

Rules: `docs/art/ai-prompt-policy.md`. Record for `art/concepts/faces/gen.mjs`, `art/concepts/damage/gen.mjs`, `art/concepts/forms/gen.mjs`, `art/concepts/shared/styled.mjs`, the face, damage and forms sheets, `data/art/damage.json` and `data/art/auras.json`, and the surge-pose fix in `art/concepts/marked-aura/gen.mjs`.

- asset id: ART-0010
- date (UTC): 2026-10-01
- tool, model and version: Claude Code (desktop app), model claude-sonnet-5-5. The session is titled "Meridian - Art"
- settings and seed (if any): none. Deterministic
- purpose: the art side of Orb's rule-of-cool picks: face cut-in portraits, battle-damage stages, the Anti-hero's aura colours for three forms, and the stacking-rule check
- input images: none. No reference image of any kind was used
- outputs kept: the sheets, the generators and the two data files
- outputs rejected: the first aura renders (a filled silhouette, not an outline), and the surge pose with arms thrown wide
- what a human changed: Orb's picks and the EP's brief direct the work; Orb picks the aura colour
- originality checklist: `docs/art/rule-of-cool-art.md`; the frame avoids a static-filled or green codec look, a known portrait layout, a flame aura, gold, white or red flash and a shouted form name
- reverse-image search: not yet run
- Legal review: pending
- disclosure category: development aid until Orb picks

## Prompt (the brief, as relayed by the EP on 2026-10-01)

> The art side of Orb's rule-of-cool picks: (1) face cut-in portraits, four expressions (neutral, smirk, strain, hurt) for each of the four fighters, square, 512 px or more, readable at about 200 px, our own frame (no green codec look), as SVG concept sheets, with how final textures are made under zero budget; (2) battle damage that stays and builds: torn clothing, scuffs and bruises, a hanging limb, aura flicker, heavy breathing, three stages per outfit; (3) the Anti-hero's aura colour, hue 260 to 320 with a lighter tint of the same hue for the core and never pure white: exact values for his aura, flashes and glow across Regalia, Sovereign and Apex; (4) check the transformation and aura sheets against the stacking rule and Game Design's staging (moveset-rules.md 10.8).

## Negative prompt

None. No franchise names, no franchise images.
