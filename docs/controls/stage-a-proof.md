# Stage A proof checklist (for QA)

Owner: Controls and Game Feel (draft). Audience: QA and Balance, who run the proof and regenerate nothing in Stage A. Date: 2026-09-30. Status: draft; it is executed when the tree is handed over (after Encounter's dynamic slice and the k retune).

**Stage A content (`stage-c-spec.md` §8):**
1. Hit-stop becomes an integer tick counter that reproduces today's *effective* freeze exactly.
2. `SimIntent` gains `special`, `transform` and `stanceStep`. They are inert: nothing reads them until Stage C.
3. No press ticks, no buffers, no lockout, no behaviour change.

**The claim to prove:** every golden vector, every replay and every QA record is bit-identical before and after. `sim/core/test/golden.json` is **not** in the commit.

## 1. What Stage A must not touch (and why)

| Item | Rule | Why |
| :--- | :--- | :--- |
| `hash.gd` `INTENT` list, `golden_recipes.gd` `INTENT`, `replay.gd` `INTENT` | **unchanged** (still the eight fields) | Adding fields to these lists changes the hash and the replay format. The new fields are inert in Stage A, so leaving them out is correct; Stage C adds them and bumps the replay `v` |
| The state hash's `dirS.stop` entry (`hash.gd:101`, keys `cool`, `stop`, `lastLaunch`) | **the legacy float keeps being written and hashed** (a "shadow", section 2) | The hash reads the float in seconds. An integer counter cannot reproduce its value bit for bit, so the float stays as the hash's source until Stage B, where the golden regeneration is intended |
| `SimKeyboard.KEYS`, `RenderKeys` | unchanged | No key is bound to the new actions until Stage C |
| Any template, finisher or director data | unchanged | Stage A is representation only |

## 2. The design that makes it provable: a shadow float

- The **integer** `stopTicks` drives the freeze (`sim.gd` `step()` freezes while it is above 0 and decrements it by one).
- The **legacy float** `dirS.stop` is still written by every `max(...)` site and still counted down by `dtReal`, exactly as today, but it **drives nothing** except the hash.
- Each stop write converts the literal seconds to ticks through a **table** generated once from the old float loop (the table is data): `0.02→2`, `0.05→4`, `0.06→4`, `0.08→5`, `0.10→7`, `0.12→8`, `0.14→9`, `0.16→10`. QA's test in section 3.1 regenerates the table from the float loop and compares it to the shipped one, so a typo cannot hide.
- Stage B deletes the shadow and the `stop` hash entry in the same commit as the new values and the regenerated goldens.

## 3. The checks, in order

Run each on a clean export of the previous commit (`QA_GODOT_ROOT`, `git archive`) and on the working tree, as `docs/qa/README.md` describes. Every check compares old against new.

| # | Check | How | Pass |
| :-: | :--- | :--- | :--- |
| A0 | Baseline is healthy on the parent commit | `godot --headless --path . --script res://sim/core/tools/parity.gd -- --no-bench`; `node qa/run-godot.js --quick` | both green; save the digests |
| A1 | **Counter equivalence, exhaustive** | a headless script (mine: `sim/input/test/stop_equivalence.gd`) takes every ordered pair of the stop literals `(v0, v1)` and every tick `k` in `0..N(v0)` at which `v1` could arrive, runs the old float path and the new integer path, and compares "frozen this tick" for every following tick | zero differences over all pairs and offsets; the table equals the one regenerated from the float loop |
| A2 | **Shadow agrees, tick by tick** | in the eight golden matches plus 200 seeds from `batch.gd`, assert at every tick entry: `(stopTicks > 0) == (dirS.stop > 0.0)` | never fails |
| A3 | Goldens unchanged | `parity.gd` against the unmodified `golden.json`; `git diff --stat sim/core/test/golden.json` is empty | exit 0; no golden diff in the commit |
| A4 | Frozen-tick trace | dump `tick {frozen}` events for the eight golden matches on old and new; hash the sequence | identical hashes |
| A5 | QA records identical | `node qa/run-godot.js --md=...` (or `--quick` first): every arm's digest against the parent's | all digests equal, all bands equal |
| A6 | Replays | the two human-input replays in the golden recipes pass through `SimReplay` unchanged; the JS record `sim/core/test/frozen/golden-js.json` check still passes only as it does today | unchanged results |
| A7 | **New intent fields are inert** | fuzz: 100 seeds, both slots, random values in `special`, `transform` and `stanceStep` on random ticks (and a human-driven slot), against the same seeds with them unset | the state hashes are identical |
| A8 | Mutation | change one entry in the tick table (for example `0.10→6`) | A2, A3 and A4 fail; revert |
| A9 | Determinism lint | the existing `LIT_RE` literal check in `parity.gd`; qualified built-in names; no long float literals in the new table | clean |
| A10 | Frozen JS core | `npm test --prefix sim` | unchanged (the twin is frozen; ADR 0006) |
| A11 | Performance | the tick cost that `parity.gd` prints | within 2% of the parent |
| A12 | Web build boots | `node tools/build-site.mjs`, open `/play/`, run the bench page (`tools/bench-web.mjs`) | boots; no new console error; frame time within noise |

## 4. Failure handling

- A1 or A2 fails: the tick table or the conversion is wrong. Do not adjust the golden; fix the table.
- A3 fails but A1, A2 and A4 pass: something else changed the hash (a field I added to a hashed list). Look at `INTENT` and the fighter key lists.
- A7 fails: an inert field leaked into behaviour, most likely through `applyIntent` or `control()` reading it. Remove the read.
- Anything else fails: stop and report; Stage A is representation only, so any other diff is a bug.

## 5. What QA delivers

A one-page result (the check table with pass or fail and the digests), a line in `docs/qa/` for the commit, and the parent commit id used for the comparison. No baseline regeneration in Stage A.

## 6. Hand-off to Stage B

Stage B changes behaviour on purpose (the hit-stop values of `rulings.md` §5, the shake decay hold, diagonal normalisation) and regenerates the goldens and `baseline-g0` in the same commit, with the reason in the message. QA's Stage B proof is different: the changed rows are named in advance (`rulings.md` §5, "Proposed ticks" column) and the checks compare the *changed* set against expectation.
