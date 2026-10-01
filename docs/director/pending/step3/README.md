# Parked: control-scheme step 3, the slam lever and the queue tie-break

Owner: Encounter Systems Director. Nothing here is loaded by the sim (`docs/` is ignored by Godot).

**Step 3 is applied** (in the tree on `4fe8052`); `apply-step3.cjs`, `interrupt.gd`, `interrupts.json` and `ai.json` stay here as the record and as Tools' drafts for the schemas. **The slam lever and the tie-break are still parked**; they follow as their own small slices, in that order, each with its own goldens.

| File | What it is |
| :--- | :--- |
| `apply-step3.cjs` | Applies step 3 to a tree: copies `interrupt.gd` to `sim/director/`, `interrupts.json` and `ai.json` to `data/director/`, and edits `exchange.gd`, `melee.gd`, `data.gd`, `beam.gd` and `ai.gd`. Re-runnable |
| `interrupt.gd` | `DirInterrupt`: the perfect block, the dodge-cancel, the burst, the reversal, the punish window, staleness |
| `interrupts.json` | The director's numbers for them (Game Design's costs, cooldowns and staleness). New file: needs Tools' schema |
| `ai.json` | The AI's skill numbers with three levels. It replaces `data/director/ai.json`: new keys `perfectBlock`, `level` and `levels`, so Tools' `director-ai.schema.json` needs them |
| `apply-slam.cjs` | The slam lever: UPPERCUT's direction moves to `data/director/launch.json` (`uppercut.ux`, `uppercut.uy`). New key: Tools' launch schema needs it |
| `apply-tiebreak.cjs` | The queue's tie-break in `exchange.gd` `_drain`. Needs step 3 (it reads `DirInterrupt.LAST_START`) |

```
node docs/director/pending/step3/apply-step3.cjs .
node docs/director/pending/step3/apply-slam.cjs .
node docs/director/pending/step3/apply-tiebreak.cjs .
```

**Two lines are Simulation's** (in since `d7d3db3`; `apply-step3.cjs . --core` writes them for scratch copies of an older HEAD only):

- `sim/core/state.gd`, in `ActState` after `breakIn`: `var dirI: PackedInt32Array = PackedInt32Array()`
- `sim/core/hash.gd`, before the act queue's lines: `out.append(float(act.dirI.size())); for v in act.dirI: out.append(float(v))`

A new class needs Godot's import step once (`--import`) before any headless run, or `DirInterrupt` is not found.

The rules, the numbers and what is still open are in `docs/director/control-scheme-plan.md`, "Step 3 as built".
