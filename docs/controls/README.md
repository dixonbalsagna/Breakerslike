# docs/controls: Controls and Game Feel

Owner: Controls and Game Feel. Date: 2026-09-29. Design first; code in `sim/input/` follows when the EP hands over the tree (ADR 0006).

| File | What it is |
| :--- | :--- |
| [rulings.md](rulings.md) | Rulings on Combat's proposals: parry, chain and wind-up widths in ticks, buffering, anti-mash, hit-stop table, finisher struggle, latency budget, draft data, ranked risks with tests |
| [input-map.md](input-map.md) | Keyboard (P1, P2) and gamepad maps, the intent record, special and transform holds per fighter, parity rules |
| [shake-pass.md](shake-pass.md) | Per-event shake for Camera, and the split's per-pane rule |
| [prompt-glyphs.md](prompt-glyphs.md) | Prompt glyphs per device family for UI |
| [platform-plan.md](platform-plan.md) | Gamepad in the web build and on desktop (Godot input), rebinding, tests, and mobile's two schemes |

This folder replaces the wave-1 plan for `docs/feel/` (tuning table, input map, risks): its content is folded into `rulings.md` and `input-map.md`.
