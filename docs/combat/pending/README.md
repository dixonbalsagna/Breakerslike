# Parked data batch (Q4)

Finished copies of `data/combat/templates.json` and `data/combat/finishers.json` carrying the EP-approved Q4 batch. They are parked here because they change the combat data hash and the goldens. Files under `docs/` are not loaded or hashed by the sim.

The batch (`variety-pass.md` section 6):
1. a finisher `kind` on every finisher;
2. `contest.struggle.byState`;
3. PRESSURE's R4 counter as `selectorByProfile.dynamic`;
4. about 30 new cue names.

**When to land it:** after World's slice and the dynamic slice, in one commit with Tools' schema changes (items 1 to 3) and Encounter's Q4 loader work.

**Before copying back:** these copies were cut from the data files as of commit `b3eaf4b`. If either file has changed since, merge rather than overwrite. Known change since then: `da5fb09` set `templates.json` `"profile": "dynamic"` (Encounter's dynamic slice). Keep that value when merging.

**`styles.json` in the same commit.** Tools' Q4 schema script makes `chains.chainP.heat` and `chains.blitz.chance.cap` required and removes `heatBoiling`. When the batch lands, `data/combat/styles.json` must:
- drop `chains.chainP.heatBoiling`;
- add `chains.chainP.heat`: `{ "Heated": 0.05, "Simmering": 0.10, "Boiling": 0.20 }`;
- add `chains.blitz.chance.cap`: 0.60;
- delete the `_heat` and `_cap` notes that hold these values today.

The numbers are Game Design's (`balance-targets.md` section 12).

## Review under ADR 0008 (control scheme), 2026-09-30

Nothing here lands until Orb gives the go on ADR 0008 and Encounter revises its Q4 plan. Details are in `variety-pass.md` section 9.

| Item | Status |
| :--- | :--- |
| 1. finisher `kind` | still valid |
| 2. `contest.struggle.byState` | still valid. On merge, set the base to Game Design's current value (0.23 since `6be4c3a`; this copy says 0.15) and rename the stance labels to held states |
| 3. PRESSURE's R4 counter (`selectorByProfile.dynamic`) | **on hold** until Game Design re-rules R4 with the perfect block |
| 4. cue names | still valid |

**Drift since the copies were cut** (`b3eaf4b`): `finishers.json` gained `contest.brinkSetups` and the struggle scoring base moved to 0.23; `templates.json` is on `"profile": "dynamic"`. Merge by field, never overwrite.
