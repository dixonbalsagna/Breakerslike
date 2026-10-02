# Pending schema changes

Owner: Tools and Pipeline. Nothing in this folder is run, validated or loaded by CI, `tools/validate.js`, the sim or Godot. It holds changes that must land in the same commit as data that is not committed yet.

## `apply-2b.cjs`: Encounter's step 2b (replaces apply-q4.cjs)

Schema changes for the parked merged data in `docs/combat/pending/` (`templates.2b.json`, `finishers.2b.json`, `styles.2b.json`; ten changes listed in that folder's README). Run once, from the repo root, in the same commit that copies those three files over `data/combat/`: `node docs/tools/pending/apply-2b.cjs`. It is re-runnable (a second run changes nothing). It edits `combat-templates`, `combat-finishers` and `combat-styles` schemas, `tools/lib/xref.js`, `tools/lib/xref-fight.js` and `tools/fixtures/cases.json` (38 new cases, plus one retargeted).

| # | Change |
| ---: | :--- |
| 1 | `trigger.defender` gains `NEUTRAL`; `trigger.context` (`riposte`) as an alternative to `defender` (one of the two is required) |
| 2 | a template or branch may carry `only`; a branch's `parity`, `spaced` and `spacedTiming` are optional in the schema and required by the new `xref:branch-profiles` unless the branch or its template has `only` (with `dynamic` it also needs `dynamicTiming`) |
| 3 | a strike's `o.class` (opener, heavy, ender, blast, mid, none); `noParry` stays valid |
| 4 | `selectorByProfile`; selector kind `condition`; a selector `else` may be a condition; `defenderAdd`; the condition form `{"var", "is"}`; selector branch references are checked in all of them |
| 5 | `profiles.dynamic` gets its own definition: `tempo.enderWindup`, `approach.minHeavy`, `windups`, `perfectBlock`, `strikeClass` (all required there) |
| 6 | top-level `interrupts` (required), a branch's `interrupts` list, the beat op `stagger`, `when: "riposteLaunch"`, dotted `ref` names |
| 7 | `beam.outcomeByProfile` and the `DEFLECT` outcome |
| 8 | `finisher.kind` (required) and `contest.struggle.byState` |
| 9 | `chains.chainP.heat` (required, replaces `heatBoiling`) and `chains.blitz.chance.cap` (required, with the `style-blitz-cap` warning) |
| 10 | the new cue names are in the data's own cue vocabulary, so the existing cue check covers them; a style weight of 0 is allowed (a held style, e.g. blink_clash) |

Tested in a scratch copy of `git archive HEAD` with the three parked files swapped into `data/combat/`: before the script the validator shows 90-odd errors; after it, 0 errors and 0 warnings, and the self-test passes (771 of 771). If Combat edits the parked files again, re-run that test; a shape the script does not know shows up as a validator error in the scratch copy.

## `apply-m1b.cjs`: Simulation's M1b mood and style shapes

Run from the repo root in the same commit that lands the M1b data: `node docs/tools/pending/apply-m1b.cjs`. Re-runnable (a second run changes nothing). It edits `fight-mood.schema.json`, `fight-style.schema.json`, the two virtual fixtures and `cases.json`:

- **fight.mood/1:** `rates.proportional` {on boolean, base integer at least 0, perMille integer at least 0}, required; and a new required `actBeats` {every: array of `regionBreak` or `form`; oncePerMatch: array of `limbBattered`, `coreBruised` or `coreBattered`}.
- **fight.style/1:** a new required top-level `minHeldS` (integer at least 0). The mixer keeps `leaveMaxStancePct` and `leaveHoldS`. `qaBands` stays an open object, so Narrative's nested form (`judgedOnAI`, `judgedOnHumanOrScriptedPlay`) and the flat form both pass.
- 9 cases. Tested in a scratch copy: with today's live M1 data the only errors after the script are the missing new keys (`minHeldS`, `actBeats`, `rates.proportional`), and the self-test passes 560 of 560.

## `apply-contact.cjs`: Combat's contact spacing data

Schema changes for `docs/combat/pending/templates.contact.json` and `finishers.contact.json` (`docs/combat/contact-spacing.md` section 6). Run **after `apply-2b.cjs`** (it refuses to run before it), once from the repo root, in the commit that lands the data: `node docs/tools/pending/apply-contact.cjs`. It adds the schema keys, copies the two parked files over `data/combat/templates.json` and `finishers.json`, and adds 27 cases. Re-runnable (a second run changes nothing). It edits `combat-templates.schema.json`, `tools/lib/xref.js` and `tools/fixtures/cases.json`, and replaces the two data files.

| # | Change |
| ---: | :--- |
| 1 | a branch's `endSides` (`same` or `swapped`). New `xref:branch-end-sides`: a branch with `dynamic` beats must state it, and it is `swapped` exactly when a beat has `args.side` `cross`. New `xref:beat-side`: a beat's `args.side` is `own` or `cross` |
| 2 | `profiles.dynamic.tempo.stepIn` and `tempo.chainClose` (ticks, required in the dynamic profile) |
| 3 | `profiles.dynamic.contact` (`reach`, `offset`, `minSeparation`, `sameHeight`, `placementReaches` (above 0); all required, closed). New `xref:contact-range`: reach is not below offset, and offset is not below minSeparation |
| 4 | `tempo.stepAround` (ticks, required). New `xref:dodge-cross` (an error): a `dodge` beat with `args.side` `cross` has `dur`, `rise` and `off`, `rise` is above 0 and `off` is not below `contact.minSeparation` (Encounter reads all three without fallbacks) |

`finishers.contact.json` needs no schema change. Tested on a fresh `git archive HEAD` (2b already live there), then this script and apply-launch.cjs, with the draft launch data copied: 0 errors and 0 warnings, self-test 1026 of 1026. Run in the wrong order it stops with a message and changes nothing.

## `apply-launch.cjs`: Encounter's landing-mix data

Schema for `data/director/launch.json` (`docs/director/landing-mix.md`; the draft is `docs/director/pending/launch.json`, `schema` "director.launch/1"). Run once from the repo root, in the commit where Encounter copies the draft to `data/director/launch.json`: `node docs/tools/pending/apply-launch.cjs`. It does **not** copy the data. It adds `director-launch.schema.json` (all keys required, objects closed except underscore keys), the map entry, a validator fixture (`tools/fixtures/virtual/data/director/launch.json`, from the live file if present, else the draft), 27 cases and the rules `launch-order` (`drive.lowDeg` at most `highDeg`; `lowBh` below `highBh`) and `launch-direction` (a warning if `craterSlam.uy` is not negative). Re-runnable. Independent of the other two scripts. Tested on a fresh `git archive HEAD` with the draft copied to `data/director/launch.json`: 0 errors and 0 warnings.

## `apply-biomes-contact.cjs`: World's ground-contact data (G2) (APPLIED in df7f1b0)

**Applied.** World landed the data and ran this script in df7f1b0, so the schema, map entry, rules, fixture and cases are live. The script stays as the record; do not run it again (a second run changes nothing).

Schema for `data/biomes/contact.json` (`docs/world/ground-contact.md`; the draft is `docs/world/scratch-build/contact.json`, `schema` "biomes.contact/1"). Run once from the repo root, in the commit where World copies the draft to `data/biomes/contact.json`: `node docs/tools/pending/apply-biomes-contact.cjs`. It does **not** copy the data. It adds `biomes-contact.schema.json` (every key required, objects closed except underscore keys; the seven biomes and five surfaces are closed lists), the map entry, a validator fixture (`tools/fixtures/virtual/data/biomes/contact.json`, from the live file if present, else the draft; a fixture wins over the live file in the self-test), 42 cases and the rules `contact-order` (nothingBelow below tumbleBelow, skidSin2 below slamSin2, each bounce keeps less than the one before; skidToTumble outside the two, and bounces or spin caps that fall with the tier, are warnings) and `contact-surface` (every biomeSurface value is a surface; every paving biome has a biomeSurface). Re-runnable. Tested on a fresh `git archive HEAD` with the draft copied to `data/biomes/contact.json`: 0 errors and 0 warnings, self-test 1449 of 1449.

## `apply-uppercut.cjs`: Encounter's slam lever (UPPERCUT's direction)

Schema for the new `uppercut` key of `data/director/launch.json` (`docs/director/pending/step3/apply-slam.cjs`; the live value is `{"ux": 0.85, "uy": 1.0, "_note": "..."}`, placed before `craterSlam`). Run once from the repo root, in the commit where Encounter adds the key: `node docs/tools/pending/apply-uppercut.cjs`. It does **not** edit `data/`. It makes `uppercut` a required, closed object in `director-launch.schema.json` (`ux` a number of 0 or more, `uy` a number above 0), adds the error rule `launch-direction` for `uppercut.uy` (it must be above 0, next to the existing check that `craterSlam.uy` is below 0), puts `uppercut` in the validator fixture `tools/fixtures/virtual/data/director/launch.json` and adds 12 cases. Re-runnable. Before it runs, adding `uppercut` to the data fails the validator (the schema is closed); after it, 0 errors. Tested on a fresh `git archive HEAD` with the key added to the data: 0 errors and 0 warnings, self-test 2066 of 2066.

## `apply-laststand.cjs`: Animation's last-stand body cue

Schema for `data/anim/laststand.json` (`anim.laststand/1`; `docs/architecture/last-stand.md`). The data is on HEAD already, so the validator only warns "no schema" until this runs. Run once from the repo root, after Encounter's slice is committed (the tree's tools files are modified by it): `node docs/tools/pending/apply-laststand.cjs`. It does **not** edit `data/`. It adds `anim-laststand.schema.json` (closed; `ready` must have `default` and maps shape keys to sequence ids; `hold_weight` 0 to 1; `in` and `out` seconds of 0 or more), the map entry, 18 cases and two rules: `laststand-shape` (every ready key is `default` or a shape in `ragdoll_motion.json` shapes) and `laststand-seq` (every ready sequence, and `ls.slump` which the expired end plays, is in `data/anim/waves/laststand1.sequences.json`). The `laststand1` wave files already pass the wave schemas. Re-runnable. Tested on a clean `git archive HEAD`: 0 errors and 0 warnings, self-test 2082 of 2082.

## `apply-slice3.cjs`: Encounter's agency slice 3

Schema keys for the far taunt, the held charge, the meeting and the AI's reactions. Run once from the repo root, in the commit that lands the slice's data (after the slice 2 `bands` schema, which is already live): `node docs/tools/pending/apply-slice3.cjs`. It does **not** edit `data/`. It makes these keys required: `data/director/interrupts.json` `bands.hysteresisBh` (0 or more; there is no edgeSlackBh), `bands.taunt` {enabled, windowTicks of 1 or more}, `bands.charge` {light, heavy: each {holdTicks, speed, minTicks, maxTicks}} and `bands.meet` {speed, minTicks, maxTicks, chargerEdge (0 to 100: points off the attacker's chance; a share of 0 to 1 fits too)}; the notes `_edge` and `_far` are allowed in `bands` and `_far` in ai.json; `data/director/ai.json` `reactTicks` and `answerTicks` (integers of 0 or more) and, in each level, `farTaunt`, `farCharge`, `farHeavy`, `answerTaunt` (chances) and `approachReact` (three chances). Rules: `bands-order` now covers the charge and the meeting approaches (minTicks at most maxTicks) and requires the light charge's holdTicks to be below the heavy's; the new `ai-approach-react` requires the three chances to sum to at most 1. The two virtual fixtures are built from the brief's shapes (their numbers are placeholders); the earlier bands cases, which build the whole block, are updated to carry the new keys. 58 cases. Re-runnable. Tested on a clean `git archive HEAD` with data carrying the final keys: 21 errors before, then 0 errors and 0 warnings, self-test 2429 of 2429.

## `apply-targets.cjs`: Animation's re-aimed hand and foot targets

Schema for `data/anim/targets.json` (`anim.targets/1`; `docs/animation/joint-limits.md`). The data is on HEAD already, so the validator only warns "no schema" until this runs. Run once from the repo root, after Encounter's slice 3 is committed (the tree's tools files carry its edits): `node docs/tools/pending/apply-targets.cjs`. It does **not** edit `data/`. It adds `anim-targets.schema.json` (closed; pose id to at least one of `hand_r`, `hand_l`, `foot_r`, `foot_l`, each [x, y, z]), the map entry, 19 cases and two rules: `targets-pose` (every pose is in `poses.json` or a wave's poses file; the live 30 are) and `targets-limb` (the hand or foot that lands a blow, the key set's `limb` or `limb2`, is never retargeted in that key set's contact pose, which the data's own description promises; the live data keeps it). Two earlier limb2 test cases are adjusted to avoid that conflict. Re-runnable. Tested on a clean `git archive HEAD`: 0 errors, and the self-test passes.
