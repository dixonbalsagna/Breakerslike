# The next big update: the director's apply order

Owner: Encounter Systems Director. Date: 2026-10-03. Status: a plan for the EP's windows. Scope: the director's three parts of the update (`docs/ep/vision.md`, last section): (a) the beam plays, (b) the director's side of the wild deflect, the spray cone and mines, (c) the first cut of the alchemy layer.

Everything below runs only in the `dynamic` profile. The parity profile and its frozen copy (`sim/director/test/combat-parity`) are not touched, so the loader check needs no refresh.

## The order

Each step is one apply: its script from `docs/director/pending/`, the gates on a clean copy, the goldens, 100 AI matches before and after, the masher and bolt-only rows, a doc, a report.

| # | Slice | What goes in | Not mine, by grant | Goldens | Depends on |
| ---: | :--- | :--- | :--- | :--- | :--- |
| 1 | **8: the beam plays** (a) | `sim/director/beamplay.gd` (new); `beam.gd`, `exchange.gd`, `interrupt.gd`, `data.gd`, `ai.gd`; `interrupts.json` `beamPlays`, `perfectBlock.windows.beam`; `ai.json` `beamDodge`, `beamWade`, `beamLate`, `beamLook` | None | **Regenerated** (every dynamic match with a signature moves) | Simulation's shots slice committed, so the tree is still |
| 2 | **9: the wild deflect, the spray, mines** (b) | `blast.gd` (the deflect's free approach, the context deflect, the spread and the seek-or-miss draw, the mine's press, its hit rule and knock-back); `bands.gd` (an approach no shot stops); `interrupt.gd`, `melee.gd` (a blow sets a mine off), `ai.gd`; `interrupts.json` `blast.spray`, `blast.mine`, `blast.deflect`; `ai.json` `mineShare` | Simulation's `data/fight/shots.json`: `deflect.scatter` true (one value). Simulation's `sim/core/shots.gd` only if the wild shot that meets its own shooter is handed to the director (one condition in `hitFighter`; not needed for the first cut) | **Regenerated** (Simulation measured 7 of 9 golden matches moving with `scatter` alone) | Slice 8; Simulation's next core commit for Game Design's §17 numbers (the wild flight's speed and arcs, the fuse by cause, `chainR` at 3 bh) |
| 3 | **10: A1 and A2** (c) | `alchemy.gd` (the log Controls' `SimPressRead` reads, the beat from the strike schedule, the flash stamp, grading at `S.tick - h`; the phrase planner: style from the last five, the ending from the last press, the pool from `SimAim`); `data.gd`, `exchange.gd`; a new `data/director/alchemy.json` | Combat's `data/combat/recipes.json` (its parked draft, moved in by Combat); Tools' schemas for both files and the `press_read` event | **Regenerated** (the per-fighter state grows, so every state hash moves; with A2 the strings change) | Slice 9; Combat's recipes live; Tools' schema |
| 4 | **11: A4, and A3's blur and combo upgrades** (c) | `launch.gd` `earned` (the string's ender at flow 3 or more; the stick earner only as its own exchange), the showcase ender at flow 5; `melee.gd` and `alchemy.gd` (the perfect blur and its pattern, the clean and hard combo tap) | None in code. Combat's showcase gates and blur patterns are data in `recipes.json` | **Regenerated** | Slice 10 |

## Why this order

- **Slice 8 first:** it is measured and waiting, and it touches signatures only. The others don't depend on it, but each later slice re-tunes the masher's band, and it is cheaper to do that on top of the beam plays than twice.
- **The shots before the alchemy:** they are Orb's first item, their core side is already in the tree behind switches, and they move the same bands the alchemy slices will (blast share, structures, the bolt-only rows).
- **A1 with A2:** A1 alone changes no play but moves every state hash, so it would cost a golden regeneration for nothing visible.
- **A4 after A2:** the flow gate changes two of the four launch earners, and the launch shares have to be re-tuned on the strings A2 produces, not on today's.

## What each step re-measures

| Slice | Bands at risk |
| :--- | :--- |
| 8 | The masher against medium (35 to 50%; 35 of 100 in scratch on the old HEAD), KAI's share over the four arms |
| 9 | Blasts' share of damage (10 to 25%), structures lost and the per-tier structure rates, the bolt-only rows (the spray lands 40% of spammed bolts, so the AI's `barrageGuard` moves again), a blast-heavy script against a rush-heavy one (40 to 60%) |
| 10 | The masher, the styles' counts, exchanges a minute |
| 11 | Launch, knock-back and stay shares; launches of the separating exchanges (25 to 40%); the timed player's edge (§2's three mirrors) |
