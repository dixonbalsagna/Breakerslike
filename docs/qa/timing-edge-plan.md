# The timing-edge test plan (QA, 2026-10-02)

Owner: QA and Balance. Orb: "lets run balance tests on your recommendation, consistent timing should give the fighter a substantial edge." The rules are Game Design's (`docs/design/agency-pass.md`, section 2 and "What QA measures"); they are not built yet, so this plan is ready to run and today's run is the baseline: the sim has no timing rules, so every timed player should read about 50% against its untimed twin.

## What is in the harness

| Piece | Where | What it does |
| :--- | :--- | :--- |
| Scripted players | `qa/godot/players.gd` | A masher, a holder, a tapper with adjustable timing accuracy, a fixed mix, and the AI at a level, played against each other through the real input path (a v2 human slot, forms taken). Each keeps the press log the sim will keep, reads it with Controls' classifier (`sim/input/press_read.gd`, thresholds from `data/input/timing.json` `read`: hold 12 ticks, rhythm 2 of the last 3 within 4 ticks, mash 4 presses with gaps of 10 or less) and reports what it reads |
| Matchup runner | `qa/timing-edge.js` | The matchups below, 3 Godot processes at a time (6 Windows processes), win rates with Wilson intervals against Game Design's bands, damage per exchange, launches earned, turn-taking |
| Exchange endings | `qa/godot/records.gd`, `bands.js` | Standing rows `10.end.launch`, `10.end.knockback`, `10.end.continue` in every run (section "Brawl endings") |

**The players.** Spec strings: `masher[:gap=8]` (a press every `gap` live ticks; a press that falls in hit-stop is held for the next live tick), `holder[:hold=16][:rest=24]` (press and hold a heavy, then rest), `holder:timed=1:acc=A:win=6` (a hold released within `win` ticks of a blow's contact, `A` percent of the time), `tapper:acc=A:win=4:mix=LLH` (presses its own blows: `A` percent of presses land within `win` ticks of the blow's contact, the rest miss it by 3 to 10 ticks more; `jit` adds jitter; it requests an exchange every `idle` ticks between exchanges), `mix:mix=LLH:gap=12`, `ai:level=easy|medium|hard`. Add `:forms=1` to take every ready form (the pure masher without forms fights at tier 1 and cannot win, `docs/director/masher-probes.md`). The tapper reads the blows' contact ticks from the running exchange's scheduled strikes (read-only), so it can press on, before or after them by an exact amount; Game Design's thresholds are `win`: taps 4, a steady mash 3, a hold's release 6.

**Styles and the players that stand for them** (agency pass section 2): blur = a mash, power = a hold, combo = taps.

| Style | Untimed | Timed (80% of beats) |
| :--- | :--- | :--- |
| Blur | `masher` | `tapper:win=3:acc=80:mix=L` (a steady mash within 3 ticks of the beat) |
| Power | `holder` | `holder:timed=1:acc=80:win=6` (released within 6 ticks of the flash) |
| Combo | `tapper:acc=0:mix=LLH` (the style-only player: a sensible mix, never on the beat) | `tapper:acc=80:win=4:mix=LLH` (taps within 4 ticks of a blow landing) |

The classifier can hold a player to the style it meant: the harness prints how many presses read as rhythm, hold, mash or taps, and the share on the beat, so a script that is not doing what it claims shows up.

## The matchups

Everything else equal: same fighters (slot and spawn alternate by seed so they cancel), same forms policy, same AI level where an AI is present. Win share is of decided matches; intervals are Wilson 95%.

**Core (Game Design's three bands first):**

| ID | A against B | Band for A's win share |
| :--- | :--- | :--- |
| T1 | timed (80% of beats) against a masher | **72 to 82%** (agency pass) |
| T2 | timed against a style-only player | **62 to 70%** (agency pass) |
| T3 | style-only against a masher | **55 to 62%** (agency pass) |
| T4 | both timed (a mirror) | 45 to 55%: timing is the skill, so equal timing is a fair fight |
| T5 | both style-only (a mirror) | 45 to 55% |
| T6 | timed mash against a plain mash | 62 to 82% (the same upgrade, per style) |
| T7 | timed hold against a plain hold | 62 to 82% |
| T8 | timed against the medium AI | 60 to 80% (a skilled player beats the medium AI; the masher stays 35 to 50%) |
| T9 | masher against the medium AI | 35 to 50% (`control-rules.md` section 6; already a standing row) |

**Accuracy sweep (the shape of the edge):** a tapper at 0, 20, 40, 60, 80 and 100% accuracy against a masher and against a style-only player. Expected: the win share rises with accuracy, passes 50% somewhere around the accuracy where an off-beat press stops mattering, does not exceed about 90% even at 100% (so timing is an edge, not a lock), and the steps are smooth (no cliff at one threshold).

**Run size.** 100 matches per matchup for a verdict, 40 for a baseline; the 95% half-width is about 10 points at 100 and 15 at 40, so a result inside 3 points of a band edge needs 300.

## The measures

1. **Win rate** (the bands above).
2. **Damage per exchange** for each side (damage dealt over exchanges started as the attacker). Proposed: the timed player deals at least 25% more per exchange than its untimed twin (the combo upgrade alone is +15% per timed strike; blur and power add more).
3. **Launches earned** per match for each side (`launch` events caused). Proposed: the timed player earns at least 1.5 times the launches of its twin, because flow 3 or more is what lets a heavy ender launch.
4. **How exchanges end:** launches, knock-backs and continues as a share of melee exchanges, for each side's exchanges and for the pairing. Proposed for two timed players: brawl-continue at least 50% (the trade of stomach punches Orb pointed at), and turn-taking (the attacker changes from one exchange to the next) at least 45%.
5. **Flow**: how many timed presses in a row (the harness reads the press log; the flow count itself is sim state and needs an event once it exists, `flow` per fighter).
6. **Style read**: for each player the classifier's read of its presses (a masher should read mash, a timed tapper rhythm, a holder hold). A script that reads wrong is a script bug, not an edge.

## Proposed bands for "a substantial edge" (for Game Design to confirm)

Game Design's three bands stand; QA adds the following, each with its reason.

| Band | Why |
| :--- | :--- |
| Timed against an equal untimed twin, same style: **62 to 82%** | A substantial edge is a 60-plus; above about 85% timing is a lock and the untimed player has no game |
| No player above **90%** at any accuracy against any of the scripted players | Timing must stay beatable by a good style choice |
| Timed against timed: **45 to 55%** | The edge belongs to the timing, not the slot or the spawn |
| Win share rises with accuracy, 40% accuracy at least 55% against a masher | A half-good player is already ahead of a masher |
| Timed player's damage per exchange at least **1.25 times** the twin's; launches earned at least **1.5 times** | The edge is in damage and in endings, not only in luck |
| A timed player beats the medium AI **60 to 80%**; the masher stays 35 to 50% | Skill beats the AI, mashing only competes |
| Signatures deal at most **30%** of a match's damage (agency pass, provisional) | Beams must not decide every match: measured from the existing damage events by kind (a beam hit is kind `beam`); the standing row comes with the signature retune |
| Blow for Blow (when built): reached by two timed power players in at least 30% of their exchanges and by none of two masher; ends by a missed beat | The named set piece must come from timing |

## Brawl endings (standing rows)

Agency pass section 3: a melee exchange ends with the brawl continuing (both in reach) 40 to 50%, a knock-back 20 to 30%, a launch 25 to 35%. `records.gd` now classes every melee exchange (light or heavy) by its ending: a launch event inside it is a launch; the sim has no knock-back or continue state yet, so everything else is counted as "other" until `exchange_end {actor, kind: continue | knockback | launch}` events exist (it reads them as soon as they do). Rows: `10.end.launch` (25 to 35%, live: it fails today at about half the exchanges), `10.end.knockback` and `10.end.continue` (pending until the events), and an INFO row for the share that is not a launch. The old row "exchanges that end in a launch (40 to 65%)" is retired to INFO.

## What needs to exist before the edge can be measured

| Needed | From | Used for |
| :--- | :--- | :--- |
| The alchemist: the press log per fighter in sim state, the three timing upgrades, the flow count, the earned-launch rule, knock-backs | Encounter, Simulation, Combat (slice 4) | the edge itself |
| `exchange_end {actor, kind}`, a `flow` field or event per fighter, a `flash` event at the blow's wind-up (the hold's release target) | Encounter | the endings rows, the flow measure, the timed hold (today the hold script targets the blow's contact tick) |
| `lightHeld` and `heavyHeld` in the intent | Simulation (I3) | the holder (the scripts set them when the fields exist) |
| The final thresholds | Controls, Game Design | the scripts read the beat window from `timing.json`; steady-mash 3 and hold 6 are script parameters (`win`) until they are data |

## The baseline today

The first run of the core matchups on today's sim (HEAD `43f5f21`, no timing rules) is in `timing-edge-baseline.md`, with the same command the agency-pass sim will be measured with:

```
node qa/timing-edge.js --matches=100 --plan=all --md=docs/qa/timing-edge-results.md
```

Machine rule: 3 jobs, headless only (`--headless --script`).
