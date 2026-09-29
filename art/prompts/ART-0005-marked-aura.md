# Prompt record: ART-0005, the Marked plus Aura sheets

Rules: `docs/art/ai-prompt-policy.md`. Record for `art/concepts/marked-aura/gen.mjs` and the three SVG sheets in `art/concepts/marked-aura/`.

- asset id: ART-0005
- date (UTC): 2026-09-29
- tool, model and version: Claude Code (desktop app), model claude-sonnet-5-5. The session is titled "Meridian - Art"
- settings and seed (if any): none. Deterministic
- purpose: the Marked plus Aura character style, the aura rules against the HUD crown, and staged mock-ups in the greybox scene
- input images: none for the figures. The staging sheet embeds the project's own renders (`docs/rendering/img/civilians-after.png`, `craters-after.png`, `world-high-after.png`) as backdrops. No franchise, fan-game or third-party image was used
- outputs kept: the three sheets and the generator
- outputs rejected: none kept
- what a human changed: nothing yet. Orb has not authored a design (Legal 8.5.3)
- originality checklist: `docs/art/marked-aura.md`, pending Legal review
- reverse-image search: not yet run
- Legal review: pending
- disclosure category: development aid until Orb picks a direction

## Prompt (the brief, as relayed by the EP on 2026-09-29; the feel-reference series named earlier is not repeated here)

> Orb's pick: "I like marked, I like aura. Combine them, and make sure the aura is there to exaggerate or convey appropriately. I want to see these mocked up in the new style with the rules about blocking and facing the camera however." Mask tone: per fighter (pale or dark, your call per character, justified by personality and readability).
> Brief, round 4: Marked plus Aura as one style. The sigil carries identity and small expression; the aura exaggerates emotion and state (rage flares, hurt flickers and gutters, pride stands tall, triumph blooms, transformation surges) and conveys what the mask can't. The aura is diegetic and must stay distinct from UI's HUD aura crown (a thin transient ring; docs/ui/hud-spec.md). Define shape, colour and motion rules so players never confuse them, and tell me if UI should adjust. Legal's glow rules: no red, red-orange or gold aura for the Protagonist, no full-body aura as a power-stage signature (Hot Blood uses steam and veins), no gold or red glow for the Anti-hero. Mock-ups with the blocking rules: three-quarter cheat-out, front always to camera and mirrored on side-swap, the downstage feel. Show at least three staged moments per the four fighters together: a pre-fight face-off, a mid-exchange clash, and a transformation (respected cinematic). Also a hurt or brink moment, all in the greybox scene. Plus the neutral, taunt, hurt, rage and triumph strip per fighter. Legal still screens the sigils (check against real symbols) and the Protagonist's dome. Recommend the per-fighter mask tones. No workflows. The standard report, short.

## Follow-up briefs (the EP, 2026-09-29)

> Orb's answers: mask tones approved. On the pride aura, verbatim: "I'm unsure how I feel from screenshots alone. Like the HUD graphics around the fighters, it seems distracting, and could be useful to convey emotions briefly, but then disappear." So the aura becomes transient, like UI's crown revision: at rest there is no aura; it flares on emotional beats and fades. Update docs/art/marked-aura.md: triggers, hold and fade times, a cap so aura and crown never both stand at once, and the Legal fallback (round-tipped) ready. Then write the spec for a small in-engine aura prototype (flat filled quads behind the head, driven by a state uniform, on the placeholder fighters), and start the Coil turnaround (front, three-quarter left and right, back).
> More from Orb on the transient aura: "I'm thinking along the lines of how a spider-sense is portrayed in some media, an aura or flash depicted briefly around the head, or how an enemy in a stealth game might have an exclamation mark or a question mark above their head." So the aura becomes a head-flash language: a vocabulary of about 8 to 12 flashes, each tied to a real game moment (danger sense, alert, searching or confused, rage, taunt, hurt, pride, triumph, fear or brink, a transformation cue), each shaped in the fighter's sigil and shape family, with timing (about 0.3 to 1 s), colour rules, sound pairing (with Audio) and priority when several fire. Legal: staples yes, signatures no; do not copy a specific franchise's look or sound. Spec it in docs/art/marked-aura.md.

## Negative prompt

None.
