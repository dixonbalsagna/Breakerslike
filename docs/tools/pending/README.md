# Pending schema changes

Owner: Tools and Pipeline. Nothing in this folder is run, validated or loaded by CI, `tools/validate.js`, the sim or Godot. It holds changes that must land in the same commit as data that is not committed yet.

## `apply-q4.cjs`: Combat's parked Q4 batch

Schema changes for the batch described in `docs/combat/pending/README.md` and `docs/combat/variety-pass.md` section 6, items 1 to 3:

1. **`finisher.kind`** in `combat-finishers.schema.json`: an enum of `launch`, `melee`, `beam`, required on every finisher.
2. **`contest.struggle.byState`** in the same schema: a closed object (`base`, `stanceRead` with `match`, `other` and `matches`, `kiBonus`, `rallyPenalty`, `tiltPerMinute`, `tiltAfter`, `floor`, optional `fighterState` and `pulses`). The press fields (`halfWidthTicks`, `assistHalfWidthTicks`, `debounceTicks`, `inputs`, `aiHitChance`, the press `scoring`) stay required for now. Making them optional is the later step; do that by hand when Combat says so.
3. **`selectorByProfile`** on a template in `combat-templates.schema.json`: profile name (`parity`, `spaced`, `dynamic`) to a selector, same shape as `selector`. The condition variable `defHeld` needs no schema change (conditions take any variable name).

4. **`chainP.heat`** in `combat-styles.schema.json`: a required stage table `{Heated, Simmering, Boiling}` of numbers, replacing `heatBoiling` (which the script removes from the schema, so the data must drop it in the same commit).
5. **`blitz.chance.cap`** in the same schema: a required number 0 to 1. A new warning, `style-blitz-cap` in `tools/lib/xref-fight.js`, fires when the Tense or Frenzied chance is above the cap (it would always be clipped).

Items 4 and 5 need `data/combat/styles.json` to carry the new fields (Combat moves them out of the `_heat` and `_cap` notes in the same batch). It also makes `tools/lib/xref.js` check that a `selectorByProfile` selector points at branches of its own template (rule `selector-branch`), and adds 16 cases to `tools/fixtures/cases.json`.

### How to run

1. Put Combat's batch data in place (including the `styles.json` edits for items 4 and 5): copy `docs/combat/pending/templates.q4.json` over `data/combat/templates.json` and `finishers.q4.json` over `data/combat/finishers.json`. The parked copies were cut from commit `b3eaf4b`; if the data files changed since, merge rather than overwrite, and read the case pointers below.
2. From the repo root: `node docs/tools/pending/apply-q4.cjs`. It edits the two schemas, `tools/lib/xref.js` and `tools/fixtures/cases.json`, and throws (changing nothing further) if a place it expects to edit has moved.
3. Run `node tools/validate.js` (expect 0 errors) and `node tools/validate.js --self-test` (expect every check to pass).
4. Commit the data and these edits together, then delete this script or move it to a "done" note. Run it **once**: it is not idempotent (a second run would add the cases twice).

### What was checked

In a scratch copy, before the changes the parked copies (with a `styles.json` carrying `heat` and `cap`) fail with exactly eight errors (`byState`, four `kind`, `selectorByProfile`, `heat`, `cap`). After them the data validates and the self-test passes (16 new cases). `sigCooldown` was moved into the fighter schema directly (step 2a), so this script no longer touches it. The script adds cases by parsing `cases.json`, so it does not depend on its layout. Cases assume the parked shapes: template 3 is `pressure`; finishers 0 to 3 are `generic.placeholder`, `generic`, `kai`, `vorr`.

Re-check after the run: if `data/combat/` has moved on (for example new templates before `pressure`), the case pointers `/templates/3/...` and `/finishers/2/...` need updating; the self-test says "fixture path missing" if so.

## `apply-m1b.cjs`: Simulation's M1b mood and style shapes

Run from the repo root in the same commit that lands the M1b data: `node docs/tools/pending/apply-m1b.cjs`. Re-runnable (a second run changes nothing). It edits `fight-mood.schema.json`, `fight-style.schema.json`, the two virtual fixtures and `cases.json`:

- **fight.mood/1:** `rates.proportional` {on boolean, base integer at least 0, perMille integer at least 0}, required; and a new required `actBeats` {every: array of `regionBreak` or `form`; oncePerMatch: array of `limbBattered`, `coreBruised` or `coreBattered`}.
- **fight.style/1:** a new required top-level `minHeldS` (integer at least 0). The mixer keeps `leaveMaxStancePct` and `leaveHoldS`. `qaBands` stays an open object, so Narrative's nested form (`judgedOnAI`, `judgedOnHumanOrScriptedPlay`) and the flat form both pass.
- 9 cases. Tested in a scratch copy: with today's live M1 data the only errors after the script are the missing new keys (`minHeldS`, `actBeats`, `rates.proportional`), and the self-test passes 560 of 560.
