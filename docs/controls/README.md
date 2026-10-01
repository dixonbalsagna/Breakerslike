# docs/controls: Controls and Game Feel

Owner: Controls and Game Feel. Date: 2026-09-29. Design first; code in `sim/input/` follows when the EP hands over the tree (ADR 0006).

| File | What it is |
| :--- | :--- |
| [input-scheme.md](input-scheme.md) | **Current (ADR 0008):** actions, the three controller layouts, tap and hold rules, keyboard (solo and shared), touch Simple and Full, the intent record, stage plan, tests |
| [input-schema.md](input-schema.md) | **Current:** data model, presets and schemas for Tools (`actions`, `layouts`, `timing`, user file) |
| [rulings.md](rulings.md) | Rulings on Combat's proposals: parry, chain and wind-up widths in ticks, buffering, anti-mash, hit-stop table, finisher struggle, latency budget, draft data, ranked risks with tests |
| [input-map.md](input-map.md) | Keyboard (P1, P2) and gamepad maps, the intent record, special and transform holds per fighter, parity rules |
| [shake-pass.md](shake-pass.md) | Per-event shake for Camera, and the split's per-pane rule |
| [prompt-glyphs.md](prompt-glyphs.md) | Prompt glyphs per device family for UI |
| [stage-c-spec.md](stage-c-spec.md) | **Final Stage C spec:** sticky weight, the signature intent, the sim shape, tests, draft data, the final stage plan |
| [stage-a-proof.md](stage-a-proof.md) | Stage A proof checklist for QA (integer hit-stop, inert intent fields, bit-identical goldens) |
| [stage-c-tests.md](stage-c-tests.md) | Stage C test scripts and batch checks (weight, signature intent, holds) |
| [feel-schema.md](feel-schema.md) | JSON Schema and cross-reference rules for `data/input/feel.json`, for Tools |
| [intent-queue-plan.md](intent-queue-plan.md) | options considered before Game Design's answers (superseded by stage-c-spec.md) |
| [platform-plan.md](platform-plan.md) | Gamepad in the web build and on desktop (Godot input), rebinding, tests, and mobile's two schemes |

This folder replaces the wave-1 plan for `docs/feel/` (tuning table, input map, risks): its content is folded into `rulings.md` and `input-map.md`.
