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

Schema changes for `docs/combat/pending/templates.contact.json` and `finishers.contact.json` (`docs/combat/contact-spacing.md` section 6). Run **after `apply-2b.cjs`** (it refuses to run before it), once from the repo root, in the commit that lands the data: `node docs/tools/pending/apply-contact.cjs`. It adds the schema keys, copies the two parked files over `data/combat/templates.json` and `finishers.json`, and adds 17 cases. Re-runnable (a second run changes nothing). It edits `combat-templates.schema.json`, `tools/lib/xref.js` and `tools/fixtures/cases.json`, and replaces the two data files.

| # | Change |
| ---: | :--- |
| 1 | a branch's `endSides` (`same` or `swapped`). New `xref:branch-end-sides`: a branch with `dynamic` beats must state it, and it is `swapped` exactly when a beat has `args.side` `cross`. New `xref:beat-side`: a beat's `args.side` is `own` or `cross` |
| 2 | `profiles.dynamic.tempo.stepIn` and `tempo.chainClose` (ticks, required in the dynamic profile) |
| 3 | `profiles.dynamic.contact` (`reach`, `offset`, `minSeparation`, `sameHeight`; required, closed). New `xref:contact-range`: reach is not below offset, and offset is not below minSeparation |

`finishers.contact.json` needs no schema change. Tested on a fresh `git archive HEAD` with the 2b files swapped in and `apply-2b.cjs` run, then this script: 0 errors and 0 warnings, self-test 866 of 866 (849 after 2b alone). Run in the wrong order it stops with a message and changes nothing.
