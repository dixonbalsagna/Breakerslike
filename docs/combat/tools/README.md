# Combat feel probes

Read-only probes behind `docs/combat/dynamic-feel.md`. They step AI-vs-AI matches and sort every frame into three classes:
- **freeze:** hit-stop.
- **active:** a fighter moved faster than 100 u/s, or a strike-type event happened in the last 6 frames.
- **idle:** everything else.

They report idle share and still stretches inside exchanges (all exchanges, and melee alone), the time to the first strike, the gaps between strikes, the time from release to the next request, and close standoffs.

**Handover:** QA moves these into `qa/` when it adopts them. Until then, Combat keeps them here.

| File | Build | Run from the repo root | Time |
| :--- | :--- | :--- | :--- |
| `feel_probe.gd` | the live GDScript sim | `godot --headless --path . --script res://docs/combat/tools/feel_probe.gd -- 40 1 [profile or templates.json path] [label]` | about 1 min for 40 matches |
| `proto_probe.js` | the prototype (`prototype/index.html`) | `node docs/combat/tools/proto_probe.js 60 100001` | about 1 min |

Notes:
- **Profile argument (`feel_probe.gd`).** A name (`parity`, `spaced`) forces `DirData.templatesProfile`. A path to a `templates.json` swaps that file in, which is how to measure a profile today's loader cannot select by name.
- **Strike detection.** The Node probe reads strikes from state: an hp drop, a new launch, or a parry feed line. The GDScript probe reads them from fx events: damage, parry, clash and launch. The thresholds are the same in both.
- **Melee** excludes signatures (both probes) and exchanges that turn into a finisher (the GDScript probe; the prototype has no finishers).
- Machine rule: at most 6 Godot processes at once.
