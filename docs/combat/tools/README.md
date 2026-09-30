# Combat feel probes: moved to QA

The dynamic-feel probes now live in `qa/godot/feel/` (QA adopted them; `docs/combat/dynamic-feel.md` still holds the definitions).

| File | Where | Run from the repo root |
| :--- | :--- | :--- |
| `feel_probe.gd` (live GDScript sim) | `qa/godot/feel/feel_probe.gd` | `godot --headless --path . --script res://qa/godot/feel/feel_probe.gd -- 40 1 [profile or templates.json path] [label]` |
| `proto_probe.js` (prototype) | `qa/godot/feel/proto_probe.js` | `node qa/godot/feel/proto_probe.js 60 100001` |

`node qa/run-godot.js` runs the GDScript probe on 40 default-arm matches (`--feel=N`, `--feel=0` skips it) and reports the §10 dynamic-feel targets as bands: melee idle share, still stretches, first strike, strike gaps, strikes per minute, release to the next request, standoffs, time inside exchanges and hit-stop share. See `docs/qa/README.md`. Machine rule: at most 6 Godot processes at once.
