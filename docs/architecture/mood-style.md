# Fight mood, acts and player style as sim components (plan)

Status: plan, approved (Simulation, 2026-09-30). It is updated with Game Design's numbers and Narrative's thresholds. Sources:
- Game Design, `docs/design/spec-wounds.md` §9 (7e87793, b04fd8b): the acts, the mood's impulses, decay, bands and aggression, and the sign-off on the style thresholds;
- Narrative, `docs/narrative/dialogue-director.md` §1 and §8: the mood model and the player-style profile;
- Narrative, `docs/narrative/style-thresholds.md` and `style.draft.json` (92a1913): the label thresholds and stability rules.

Slice **M1** (Simulation, size M). It lands after D1a and reuses D1a's data loader and hash. The outputs are consumed afterwards: by Encounter's Q4 slice (aggression), and by World and Rendering (the crowd state).

## 1. What moves into the sim, and what stays out

| In the sim: `sim/core/mood.gd`, state in `S.mood` and `f.style` | Stays presentation (Narrative, Audio, Camera) |
| :--- | :--- |
| The mood value, its band and the act index | Line selection, the freshness engine, seen-memory, cross-match memory |
| The per-fighter style profile: a 60 s window, match-long totals, labels and shifts | The mood-graph nodes per fighter (`playful`, `grim`, ...) and the register families |
| The outputs `S.mood.aggression` and `S.mood.crowd` | `momentum`, `dominance`, `stakes`, `fatigue`, `rivalry_heat` (§1.1). The dialogue director derives these from events. They move into the sim only if a sim reader needs one |
| Events when the band, act, crowd or a label changes | The dialogue director's own seeded stream |

The rule from dialogue-director §8.1 holds: presentation reads the mood and never writes it, and the sim never reads which lines were chosen.

## 2. State layout

Everything is an integer. There are no floats in the component's state, so it is exact on every platform.

**The mood's unit is 1/60 of a point.** At 60 ticks a second, a rate of one point per second is exactly one unit per tick. So every number in spec §9 is a whole number of units, and the per-second rates apply every tick, smoothly and with no rounding:
- 1.5 points is 90 units, 2.5 is 150 and 0.5 is 30;
- −6 per second is −6 units a tick, −4 per second is −4 and +1 per second is +1;
- the range 0 to 100 is 0 to 6000, and the thresholds 30 and 70 are 1800 and 4200.

**Match: `S.mood` (class `MoodState`)**

| Field | Type | Meaning |
| :--- | :--- | :--- |
| `t` | int | non-frozen ticks the component has run (hit-stop ticks do not count) |
| `v` | int | the mood, 0 to 6000 (0 to 100 points) |
| `band` | int | 0 Calm, 1 Tense, 2 Frenzied |
| `cand`, `candT` | int | the band the value is in when it differs from `band`, and the ticks it has stayed there (the dwell) |
| `act` | int | 1 to 4, never lowered (a Rally does not undo an act) |
| `breaks`, `forms` | int | region breaks and transformations so far, both fighters; `act = min(4, 1 + breaks + forms)` |
| `aggression` | int | the output, in permille |
| `crowd` | int | the output: 0 `excited`, 1 `nervous`, 2 `fleeing` |
| `casGiven` | int | the casualty impulse given so far, in units (see §4) |
| `lastCombo` | int | the running exchange's chain count last tick (chain links, §4) |

**Per fighter: `f.style` (class `StyleState`)**

| Field | Type | Meaning |
| :--- | :--- | :--- |
| `cur` | int[M] | the current second's counters (M measures, below) |
| `buckets` | int[60 × M] | the last 60 one-second buckets, a ring |
| `bi`, `filled` | int | the ring index, and how many seconds are filled (up to 60) |
| `win` | int[M] | the running window sums: add the new bucket and subtract the oldest, so there is no rescan |
| `total` | int[M] | match-long sums |
| `label` | int | the current label, or −1 for none |
| `leaveT` | int | seconds the current label's leave condition has held |
| `enterT` | int[6] | seconds each label's enter condition has held |
| `leftAt` | int[6] | when each label last ended, in component seconds (the refractory rule) |
| `shiftAt` | int | when the last style-shift event fired (the minimum gap) |
| `runKind`, `runLen`, `runMax` | int | repetition: the current run of the same attack kind, and the match's longest |

**Measures (M = 11 per bucket), from Narrative's §8.2:**
- `stance0` to `stance3`: ticks in AGGRESSIVE, DEFENSIVE, EVASIVE and ESCAPE;
- `light`, `heavy`, `sig`: attacks. **An attack is an exchange the fighter's director started, counted by its weight at the start, not a button press** (Game Design, b04fd8b). The source is the `attack` event (`actor` and `kind`), which the director emits when it accepts a request and starts the exchange;
- `closing`: ticks spent closing on the opponent (the shortest-arc distance fell by more than a dead zone);
- `opened`: units of distance opened;
- `charge`: ticks charging;
- `chargeCut`: charges interrupted.

Signature hits are not in the window. `sigLanded` goes into `total` only, as match-long `special_use` for Narrative; no label reads it.

Hiding is out of the base game (EP ruling), so there is no `hidden` measure and no `hider` label. The stealth fighter's profile adds both (`hide_habit`) when that fighter lands. The measure list is data, so adding them is a data change plus one counter.

The cost is about 680 ints per fighter, plus a dozen for the match, all hashed. The hash walk is linear, so this adds a few microseconds per checkpoint.

## 3. Update rate

- **Every tick** (non-frozen, at the end of `SimCore.step`, after `dirUpdate` and the beams), `SimMood.tick(S)` does the following:
  1. Adds this tick's impulses (§4) to `v`, then the rates: both AGGRESSIVE +1; the decay −6 toward the act floor; −4 more while both hold DEFENSIVE or ESCAPE. It then clamps to 0 to 6000.
  2. Updates the band candidate and the dwell (§4). Emits `mood_band` when the band changes.
  3. Adds to each fighter's `cur` counters. Counts `region_broken`, and `form_change` later, into `breaks` and `forms`. Emits `act_change` when the act rises.
  4. Recomputes `aggression` and `crowd` when the band or act changed. Emits `crowd_state` when the crowd changed.
- **Every 60 ticks** (`t % 60 == 0`): each fighter's bucket rotates (`win` and `filled`), and the labels are evaluated (§5). Emits `style_label` on a change.

**Inputs are events and state, not hooks.** The component reads this tick's `S.out.fx` and a few state values, so director and world code need no edits. The cost: the input events become gameplay-relevant. Removing or renaming one changes the goldens. `fx-events.md` will mark each one "mood input".

## 4. The mood's rules (Game Design, spec §9; the values in `data/fight/mood.json`)

| Impulse | Points | Units | Source in the sim |
| :--- | ---: | ---: | :--- |
| strike landed | 1.5 | 90 | a `damage` event with a number, kind `light` |
| heavy strike landed | 2.5 | 150 | `damage`, kind `heavy` |
| chain link | 3 | 180 | the running exchange's `combo` rose this tick (state; no event needed) |
| parry | 4 | 240 | `parry` |
| signature beam lands (HIT or GUARD, not a clash; Game Design) | 6 | 360 | `decisive` with kind `beam` (the director's signature hit or guard) |
| heavy or beam clash | 8 | 480 | `clash_draw`, or `decisive` with kind `clash` or `beam_clash` |
| region break | 12 | 720 | `region_broken` |
| launch through a building | 6, or 10 for a chain | 360 or 600 | a new core event, `building_hit` {actor, n}, from `SimFighter._buildingHits` (mine); `n` is the building's number within this flight, and 2 or more is a chain. World's brunt chain uses the same event when it lands |
| transformation cinematic | 10 | 600 | `form_change` (F1) |
| finisher start | 15 | 900 | `finisher_start` |
| taunt or banter line | 3 | 180 | a `taunt` event, when taunts exist. Barks are presentation, so only a taunt the sim performs counts |
| casualties | 0.5 each, normalised, at most 8 per event | 30 each, at most 480 | the world's casualty count (below) |

**Rates, every tick:**
- both fighters in AGGRESSIVE: +1;
- decay −6 toward the **act floor** (0, 600, 1200 and 1800 for acts 1 to 4). The decay stops at the floor. It never lifts a mood that is below the floor, since events do the lifting;
- while both fighters hold DEFENSIVE or ESCAPE (each in either): −4 more, also stopping at the floor.

The value is then clamped to 0 to 6000.

**Casualties, normalised with no drift.**
- Each tick, `target = floor(30 × 425 × S.world.casualties / pop0)`: the float64 product, floored once to an int.
- The impulse is `min(480, target − casGiven)`, and then `casGiven = target`.
- So a tick's casualties are one "event": the cap drops the excess of a big collapse instead of leaking it into later ticks, and fractional people carry over exactly through the cumulative count.

**Bands.** Calm is below 1800, Tense 1800 to 4200, Frenzied above 4200. The value must stay in another band for a **180-tick (3 s) dwell** before `band` changes. There is no further hysteresis. A return to the current band resets the dwell.

**Act.** `min(4, 1 + breaks + forms)`, never lowered.

**`aggression`** (permille, one match-wide scalar): `1000 + 100 × (act − 1) + {0, 250, 500}[band]`, capped at 1800. Each fighter's own difference comes from stance cadence (`stance-matrix.md` R9) and personality data, and multiplies with it. How Encounter spends it (cadence, blitz chance, the 0.6 s gap) is Encounter's Q4.

**`crowd`.** Calm is `excited` (they watch from a distance), Tense `nervous` (they retreat), Frenzied `fleeing`. World combines this global state with local danger (the fight's distance, B1 and B2's evacuation), so crowd behaviour stays World's rule.

## 5. The style labels (Narrative's thresholds, signed off by Game Design; `data/fight/style.json`)

The labels are evaluated at 1 Hz on the 60 s window `win`, using integer cross-multiplication. There is no division: "share above 55%" is `100 * part > 55 * whole`.
- `stanceTotal` is `stance0 + stance1 + stance2 + stance3`.
- The attack total is `light + heavy + sig`: exchanges started, by weight at the start.

| Label | Measure | Enter above | Hold to enter | Leave below | Hold to leave |
| :--- | :--- | ---: | ---: | ---: | ---: |
| `turtle` | stance1 / stanceTotal | 55% | 45 s | 45% | 5 s |
| `rusher` | stance0 / stanceTotal | 60% | 20 s | 50% | 5 s |
| `runner` | (stance2 + stance3) / stanceTotal | 50% | 20 s | 40% | 5 s |
| `charger` | charge / stanceTotal | 20% | 15 s | 12% | 5 s |
| `sniper` | sig / attacks, with at least 4 attacks in the window | 35% | 20 s | 25% | 5 s |
| `mixer` | real variety (below) | | 30 s | see below | 5 s |

**Mixer** (style-thresholds.md §2). All three must hold:
1. no stance above 40%;
2. at least 3 stances used at 15% or more each;
3. at least 6 attacks in the window, with no attack kind above 70% of them.

It leaves when any other label enters, or when the largest stance share has been above 50% for 5 s.

**Stability rules:**
- `minWindowFillS` 30: no label is evaluated until the window holds 30 s (`filled >= 30`).
- `startUnlabelled`: a match starts with no label.
- `priority` (turtle, runner, rusher, charger, sniper, mixer): when more than one label is ready to enter, the first in this order wins.
- `shift.refractoryAfterLeaveS` 10: a label cannot re-enter within 10 s of ending (`leftAt`).
- `shift.minGapS` 20: a `style_label` event that changes one label into another (a style shift) fires at most once per 20 s per fighter (`shiftAt`). A label whose enter hold completes inside the gap waits, still ready, until the gap ends.

**The data shape**, which is Narrative's draft (`style.draft.json`) as the file:
- `schema` `fight.style/1`;
- `windowS` 60, `evalHz` 1, `minWindowFillS` 30;
- `priority`;
- `shift` {`minGapS`, `refractoryAfterLeaveS`, `startUnlabelled`};
- `labels` {name: {`enterPct`, `enterHoldS`, `leavePct`, `leaveHoldS`}}. The sniper adds `minAttacksInWindow`. The mixer adds `maxStancePct`, `minStancesUsed`, `stanceUsedPct`, `maxAttackKindPct`, `minAttacksInWindow` and `leaveMaxStancePct` 50.
- Each label's `measure` is a fixed key the code implements (`share(stance1)`, `share(stance2+stance3)`, ...), not a formula string.
- `qaBands` stays in the file for QA. The sim ignores it.

**The opponent's reaction** (a rusher meets evasion) needs no extra state. It is the pair of both fighters' labels, read by Encounter and Narrative.

**`data/fight/mood.json`** (schema `fight.mood/1`):
- `unitPerPoint` 60;
- `impulses` {name: units}, the table above;
- `casualty` {`perPerson` 30, `capPerEvent` 480, `popRef` 425};
- `rates` {`bothAggressive` 1, `decay` 6, `bothGuarded` 4};
- `actFloors` [0, 600, 1200, 1800];
- `bands` {`tense` 1800, `frenzied` 4200, `dwellTicks` 180};
- `aggression` {`base` 1000, `perAct` 100, `bandBonus` [0, 250, 500], `max` 1800};
- `crowd` ["excited", "nervous", "fleeing"].

Every value is an integer.

## 6. Events (into `S.out.fx`; rows go into `fx-events.md` with M1)

| Type | Fields | When |
| :--- | :--- | :--- |
| `mood_band` | kind (`calm`, `tense`, `frenzied`), amount (the mood in points, `v / 60`), n (the act) | the band changed, after the dwell |
| `act_change` | n (1 to 4), kind (`break` or `form`, the cause) | the act rose |
| `style_label` | actor, kind (the new label, or "" when a label ends with nothing to replace it), text (the previous label, or "") | a label entered, ended or shifted |
| `crowd_state` | kind (`excited`, `nervous`, `fleeing`) | the crowd output changed |
| `building_hit` | actor, x, n | a launched fighter hit a building (a mood input; also useful to Audio and Camera) |

There is no per-second mood event. Readers that want the value read `S.mood` (a render reader reads state freely). The events are only for changes, so Audio's music layers and Camera's stances key on them, and QA gets time-in-band and the label bands from them.

## 7. Who reads what

| Reader | Reads | Where it runs | Notes |
| :--- | :--- | :--- | :--- |
| Encounter (Q4) | `S.mood.aggression`, `band`, `act`, both fighters' `style.label` | sim (director) | Cadence, blitzes and the style reaction (a rusher meets evasion, a turtle meets guard breaks), within every tier cap |
| World | `S.mood.crowd` | sim (collateral, evacuation, runners) | Combined with local danger |
| Rendering | `S.mood.crowd`, `crowd_state` events | presentation | Crowd dressing and animation (cities.md: dressing is Rendering's) |
| Audio | `mood_band`, `act_change` | presentation | Music layers per act and band |
| Camera | `act_change`, `mood_band` | presentation | Camera stance per act |
| Narrative | all of `S.mood` and `f.style` (window, totals, runs), all the events | presentation | Line choice, thoughts, boasts and density. Never writes |
| QA | the events, and `S.mood` at the KO | tools | Frenzied ≤ 25% of match time; Calm ≥ 15%; blitzes 2 to 6 a minute in Tense and Frenzied (from Encounter's events); the label bands in `style.json` |
| UI | nothing | | Acts and mood are invisible (spec §9). There is a debug overlay only |

## 8. Determinism and the hash

- The state is all integers, so the mood cannot drift. The only float is the casualty product, floored once from values that are already sim state.
- The 1 Hz step is keyed to `S.mood.t`, not `S.T`, so hit-stop and the KO slow-down cannot shift it.
- `S.mood` and every `f.style` field go into the state hash in declaration order. The five events join `FX_FIELDS`.
- **M1's proof, in two parts.**
  1. With M1 observing only (no reader wired), fighter trajectories are unchanged. The goldens are regenerated once, because the hash gains fields and the new `building_hit` event. The check is a one-off run with the mood block and the new event left out of the hash, which must reproduce the pre-M1 goldens exactly.
  2. A forced vector (like `rallyHash`) drives scripted stances and events through band and dwell, act floors, the casualty cap, every label's enter, leave and refractory timing, the shift gap and the window-fill rule. It is hashed into the goldens.
- Encounter's and World's readers come after M1, each with its own golden change.

## 9. Open points

- **Taunts and transformations** have no sim events yet. Their impulses are in the data and dormant until `taunt` (Encounter or Narrative) and `form_change` (F1) exist.
- **World:** how `crowd` combines with local danger in evacuation.
- **Tools:** the schemas for `fight/mood.json` and `fight/style.json`, from §5's shapes, when the files land.
