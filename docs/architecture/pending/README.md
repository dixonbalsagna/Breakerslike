# Pending core slices

Owner: Simulation and Engine. Nothing in this folder is run by CI, the validator, the sim or Godot. It holds slices that are built and proven in a scratch copy and wait for the sim slot. Each script edits files by exact text and stops if a line it expects has changed, so on a later HEAD it either applies cleanly or says which line moved.

## The intro phase, the last stand and the mood's form impulse

Built and proven on a `git archive` of 3fca9ac (2026-10-02), stacked in this order. Plans: `docs/architecture/intro-phase.md`, `last-stand.md`. Run from the repo root; `golden.gd` regenerates, `parity.gd` checks, `python sim/core/tools/golden_cmp.py <old golden.json> <new golden.json>` compares light digests.

| Step | Command | Result on 3fca9ac |
| :--- | :--- | :--- |
| 1 | `python docs/architecture/pending/intro.py . code` (copies `intro.gd` to `sim/core/`), import | parity passes on the untouched goldens (9 matches, 179,242 ticks), with the new check "the intro phase" |
| 2 | `intro.py . hash`, regenerate | light digests and tick counts identical |
| 3 | `intro.py . flip` (`START_GAP` 900; the batch runs the intro skipped), regenerate | a behaviour change (the opening gap); parity passes |
| 4 | `python docs/architecture/pending/laststand.py . code`, then `. director` | parity matches every match on step 3's goldens; only the roster data hash differs (a new key in wounds.json) |
| 5 | `laststand.py . hash`, regenerate | light digests and tick counts identical |
| 6 | `laststand.py . flip` (the window 20 s), regenerate | a behaviour change; parity passes, with "the last stand" checked end to end through the director's gates |
| 7 | `python docs/architecture/pending/mood_form.py . 900`, regenerate | a behaviour change in the mood only; parity passes, with "the form impulse" checked on a frozen tick |
| 8 | `node docs/architecture/pending/schemas.cjs` | the validator: 0 errors; self-test 1,803 of 1,803 |

In the real slot the goldens are regenerated at steps 2 and 5 only to run the comparison; one golden file comes out at the end. Also green in the scratch copy after step 8: determinism, the seam sweep, `npm test` (5 stages), the touch test.

**Lines outside `sim/core` and the data I was told to change** (they need the EP's grant when the slot opens):
- Encounter: `laststand.py . director` edits the signature's gates in `sim/director/exchange.gd` (three places), `beam.gd` (two) and `ai.gd` (one).
- Tools: `schemas.cjs` adds `tools/schemas/fight-intro.schema.json`, a rule in `map.json`, the fixture `tools/fixtures/virtual/data/fight/intro.json`, `lastStand` in `fighter-wounds.schema.json` and in the fixture wounds files, and seven cases in `cases.json`.
- QA: its harness (`qa/`) should start matches with `{"intro": "skip"}` as `sim/core/tools/batch.gd` does after step 3.

**100 matches in the scratch copy after step 7** (default arm, seeds 1 to 100): KAI 60%; length median 438 s (p10 332, p90 535); first brink 348 s; finisher survival 30.1%; rallies 0.39; mood calm 41.4, tense 51.7, frenzied 6.9%; frenzied in act 4 13.1%; acts at 101, 216, 292 s; last stands 1.45 a match, 141 of 145 used; signatures 3.38 a match. The form impulse changes only the mood rows (before it: 45.1, 51.3, 3.6%, and 8.8% of act 4).
