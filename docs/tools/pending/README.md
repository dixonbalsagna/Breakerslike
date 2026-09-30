# Pending schema changes

Owner: Tools and Pipeline. Nothing in this folder is run, validated or loaded by CI, `tools/validate.js`, the sim or Godot. It holds changes that must land in the same commit as data that is not committed yet.

## `apply-q4.cjs`: Combat's parked Q4 batch

Schema changes for the batch described in `docs/combat/pending/README.md` and `docs/combat/variety-pass.md` section 6, items 1 to 3:

1. **`finisher.kind`** in `combat-finishers.schema.json`: an enum of `launch`, `melee`, `beam`, required on every finisher.
2. **`contest.struggle.byState`** in the same schema: a closed object (`base`, `stanceRead` with `match`, `other` and `matches`, `kiBonus`, `rallyPenalty`, `tiltPerMinute`, `tiltAfter`, `floor`, optional `fighterState` and `pulses`). The press fields (`halfWidthTicks`, `assistHalfWidthTicks`, `debounceTicks`, `inputs`, `aiHitChance`, the press `scoring`) stay required for now. Making them optional is the later step; do that by hand when Combat says so.
3. **`selectorByProfile`** on a template in `combat-templates.schema.json`: profile name (`parity`, `spaced`, `dynamic`) to a selector, same shape as `selector`. The condition variable `defHeld` needs no schema change (conditions take any variable name).

It also makes `tools/lib/xref.js` check that a `selectorByProfile` selector points at branches of its own template (rule `selector-branch`), and adds 9 cases to `tools/fixtures/cases.json`.

### How to run

1. Put Combat's batch data in place: copy `docs/combat/pending/templates.q4.json` over `data/combat/templates.json` and `finishers.q4.json` over `data/combat/finishers.json`. The parked copies were cut from commit `b3eaf4b`; if the data files changed since, merge rather than overwrite, and read the case pointers below.
2. From the repo root: `node docs/tools/pending/apply-q4.cjs`. It edits the two schemas, `tools/lib/xref.js` and `tools/fixtures/cases.json`, and throws (changing nothing further) if a place it expects to edit has moved.
3. Run `node tools/validate.js` (expect 0 errors) and `node tools/validate.js --self-test` (expect every check to pass).
4. Commit the data and these edits together, then delete this script or move it to a "done" note. Run it **once**: it is not idempotent (a second run would add the cases twice).

### What was checked

In a scratch copy, before the changes the parked copies fail with exactly six errors (`byState`, four `kind`, `selectorByProfile` unknown), and after them: 0 errors, 0 warnings, and the self-test passes 452 of 452 (9 new cases). Cases assume the parked shapes: template 3 is `pressure`; finishers 0 to 3 are `generic.placeholder`, `generic`, `kai`, `vorr`.

Re-check after the run: if `data/combat/` has moved on (for example new templates before `pressure`), the case pointers `/templates/3/...` and `/finishers/2/...` need updating; the self-test says "fixture path missing" if so.
