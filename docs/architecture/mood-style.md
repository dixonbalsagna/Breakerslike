# Fight mood, acts and player style as sim components (plan)

Status: plan only (Simulation, 2026-09-30), following the EP's architecture ruling. Sources:
- Game Design, `docs/design/spec-wounds.md` §9: invisible acts and the fight's mood;
- Narrative, `docs/narrative/dialogue-director.md` §1 and §8: the mood model, and the player-style profile.

Proposed slice **M1** (Simulation, size M). It lands after D1a and reuses D1a's data loader and hash. The outputs are consumed afterwards: by Encounter's Q4 slice (aggression), and by World and Rendering (crowd state).

## 1. What moves into the sim, and what stays out

| In the sim: `sim/core/mood.gd`, state in `S.mood` and `f.style` | Stays presentation (Narrative, Audio, Camera) |
| :--- | :--- |
| The mood value, its band and the act index | Line selection, the freshness engine, seen-memory, cross-match memory |
| The per-fighter style profile: a 60 s window, match-long totals, labels and shifts | The mood-graph nodes per fighter (`playful`, `grim`, ...) and the register families |
| The outputs `S.mood.aggression` and `S.mood.crowd` | `momentum`, `dominance`, `stakes`, `fatigue`, `rivalry_heat` (§1.1). The dialogue director derives these from events. They move into the sim only if a sim reader needs one |
| Events when the band, act or a label changes | The dialogue director's own seeded stream |

The rule from dialogue-director §8.1 holds: presentation reads the mood and never writes it, and the sim never reads which lines were chosen.

## 2. State layout

Everything is an integer. There are no floats in the component, so it is exact on every platform and needs no parity care beyond the hash.

**Match: `S.mood` (class `MoodState`)**

| Field | Type | Meaning |
| :--- | :--- | :--- |
| `t` | int | ticks the component has run (non-frozen ticks; hit-stop ticks do not count) |
| `raw` | int | the instantaneous mood, in units of 1/1000 of a point, 0 to 100000 |
| `ring` | int[10] | `raw` sampled at 1 Hz, the last 10 seconds |
| `ri` | int | ring index |
| `sum` | int | the sum of `ring`. **The mood is `sum / 10`.** It is never stored divided; bands compare `sum` with 10 × thresholds |
| `band` | int | 0 Calm, 1 Tense, 2 Frenzied |
| `bandT` | int | seconds in the current band (the minimum dwell) |
| `act` | int | 1 to 4. It never goes down (a Rally does not undo an act) |
| `breaks`, `forms` | int | region breaks and transformations counted so far, both fighters; `act = min(4, 1 + breaks + forms)` |
| `aggression` | int | the output, in permille (1000 = the director's normal cadence) |
| `crowd` | int | the output: 0 `excited`, 1 `nervous`, 2 `fleeing` |
| `seenCas`, `seenLost` | int | the last world counters read (the casualty and structure deltas) |

**Per fighter: `f.style` (class `StyleState`)**

| Field | Type | Meaning |
| :--- | :--- | :--- |
| `cur` | int[M] | the current second's counters (M measures, below) |
| `buckets` | int[60 × M] | the last 60 one-second buckets, a ring |
| `bi` | int | bucket ring index |
| `win` | int[M] | the running window sums: add the new bucket and subtract the oldest, so there is no rescan |
| `total` | int[M] | match-long sums |
| `label` | int | the current label (below) |
| `labelT` | int | seconds the current label's condition has held |
| `candidate`, `candT` | int | the label waiting on its hold time (hysteresis) |
| `runKind`, `runLen`, `runMax` | int | repetition: the current run of the same attack kind, and the match's longest |

**Measures (M = 13 per bucket), from Narrative's §8.2:**
- `stance0` to `stance3`: ticks in AGGRESSIVE, DEFENSIVE, EVASIVE and ESCAPE (Narrative's Press, Guard, Dodge and Escape);
- `light`, `heavy`, `sig`: attack requests;
- `closing`: ticks spent closing on the opponent (the shortest-arc distance fell by more than a dead zone);
- `opened`: units of distance opened;
- `charge`: ticks charging;
- `chargeCut`: charges interrupted;
- `sigLanded`: signatures that hit;
- `hidden`: ticks hidden. This keeps `hide_habit` for the stealth fighter; it is always 0 for today's roster.

The cost is about 800 ints per fighter, plus 20 for the match, all hashed. The hash walk is linear, so this adds a few microseconds per checkpoint.

## 3. Update rate

- **Every tick** (non-frozen, at the end of `SimCore.step`, after `dirUpdate` and the beams), `SimMood.tick(S)` does four things:
  1. Adds to each fighter's `cur` counters (stance, closing and opening, charging, hidden).
  2. Reads this tick's events for impulses (below) and adds them to `raw`.
  3. Reads the world's casualty and structure deltas.
  4. Counts `region_broken` (and `form_change` later) into `breaks` and `forms`.
- **Every 60 ticks** (`t % 60 == 0`), the 1 Hz step:
  1. `raw` decays, and the long-guard drain runs (below).
  2. `raw` is sampled into `ring`, and `sum` is updated.
  3. Each fighter's bucket rotates (`win` updated) and its labels are evaluated.
  4. The band, act and outputs are recomputed.
  5. Change events are emitted.

**Why events as inputs.** The component reads this tick's `S.out.fx` rather than taking hooks at each call site, so director and world code need no edits. The cost: the input events (`damage`, `clash_draw`, `decisive`, `region_broken`, `launch` and `attack` today; signature landings come from `damage` with kind `beam` until Encounter's `beam_*` events exist) become gameplay-relevant. Removing or renaming one changes the goldens. `fx-events.md` will mark them "mood input".

## 4. The mood's rules (numbers are placeholders, in data)

Numbers live in `data/fight/mood.json` and `data/fight/style.json`. Game Design owns them, Tools owns the schemas, and they are loaded and hashed like the roster data (D1a), so they go into the replay header's `data` hash.

- **Impulses, in units added to `raw`:**
  - strike landed 1500;
  - clash 4000;
  - decisive 3000;
  - region broken 8000;
  - launch 2000;
  - structure lost 3000;
  - casualty 200 each, capped at 3000 a second;
  - a taunt (when taunts exist) 1000.
  - An impulse whose actor is in AGGRESSIVE is ×1.5 (applied as `* 3 / 2`, integer).
- **Decay, at 1 Hz:** `raw -= raw * decayPermille / 1000`, with `decayPermille` 70, a half-life of about 10 s.
- **Long-guard drain:** each second a fighter has been continuously in DEFENSIVE or ESCAPE for more than 5 s, `raw -= 1500`. `raw` floors at 0 and caps at 100000.
- **Bands, with hysteresis and a 3 s minimum dwell:**
  - Calm to Tense at ≥ 30; Tense back to Calm below 25.
  - Tense to Frenzied at ≥ 70; Frenzied back to Tense below 62.
  - All compared on `sum` (10 × the mood).
- **Act:** `min(4, 1 + breaks + forms)`, monotone.
- **`aggression` (permille):** `1000 + actStep × (act − 1) + bandBonus[band]`.
  - `actStep` 100: the spec's +10% cadence per act.
  - `bandBonus`: 0, 250, 500. The +25% is the spec's Tense blitz figure. How Encounter spends aggression (cadence, blitz chance, the gap to 0.6 s) is Encounter's call in Q4. The sim publishes one scalar.
- **`crowd`:** Calm is `excited` (they watch from a distance), Tense `nervous` (they retreat), Frenzied `fleeing`. World combines this global state with local danger (the fight's distance, B1 and B2's evacuation), so crowd behaviour stays World's rule.

## 5. The style labels (Narrative's §8.2, with hysteresis)

The labels are evaluated at 1 Hz on the 60 s window `win`, using integer cross-multiplication. There is no division: "share > 55%" is `100 * part > 55 * whole`.

| Label | Enter when (on the window) | Hold to enter | Leave when |
| :--- | :--- | :--- | :--- |
| `turtle` | DEFENSIVE > 55% | 45 s | < 45% for 5 s |
| `rusher` | AGGRESSIVE > 60% | 20 s | < 50% for 5 s |
| `runner` | EVASIVE + ESCAPE > 50% | 20 s | < 40% for 5 s |
| `charger` | charge ticks > 20% | 15 s | < 12% for 5 s |
| `sniper` | signatures ≥ 35% of attacks, with at least 4 in the window | 20 s | < 25% for 5 s |
| `hider` | hidden > 30% (stealth fighter only) | 20 s | < 20% for 5 s |
| `mixer` | none of the above, and no stance above 40% | 30 s | any other label enters |

- **One label at a time.** When two qualify, priority is turtle, runner, rusher, charger, sniper, hider, mixer. There is no label until the first one holds (a new match starts unlabelled).
- **A style shift** is a change from one label to another. The event carries both, `was_rusher_now_runner` in Narrative's terms.
- **The opponent's reaction** (a rusher meets evasion) needs no extra state. It is the pair of both fighters' labels, read by Encounter and Narrative.

## 6. Events (into `S.out.fx`; rows go into `fx-events.md` with M1)

| Type | Fields | When |
| :--- | :--- | :--- |
| `mood_band` | kind (`calm`, `tense`, `frenzied`), amount (the mood, 0 to 100), n (the act) | the band changed |
| `act_change` | n (1 to 4), kind (`break` or `form`, the cause) | the act rose |
| `style_label` | actor, kind (the new label), text (the previous label, or "") | a label entered or changed |
| `crowd_state` | kind (`excited`, `nervous`, `fleeing`) | the crowd output changed |

There is no per-second mood event. Readers that want the value read `S.mood` (a render reader reads state freely). The events are only for changes, so Audio's music layers and Camera's stances key on them, and QA gets time-in-band from them.

## 7. Who reads what

| Reader | Reads | Where it runs | Notes |
| :--- | :--- | :--- | :--- |
| Encounter (Q4) | `S.mood.aggression`, `band`, `act`, both fighters' `style.label` | sim (director) | Cadence, blitzes and the style reaction (a rusher meets evasion, a turtle meets guard breaks), within every tier cap |
| World | `S.mood.crowd` | sim (collateral, evacuation, runners) | Combined with local danger |
| Rendering | `S.mood.crowd`, `crowd_state` events | presentation | Crowd dressing and animation (cities.md: dressing is Rendering's) |
| Audio | `mood_band`, `act_change` | presentation | Music layers per act and band |
| Camera | `act_change`, `mood_band` | presentation | Camera stance per act |
| Narrative | all of `S.mood` and `f.style` (window and totals), all four events | presentation | Line choice, thoughts, boasts and density. Never writes |
| QA | the events, and `S.mood` at the KO | tools | Frenzied ≤ 25% of match time, Calm ≥ 15%; blitzes 2 to 6 a minute in Tense and Frenzied (from Encounter's events) |
| UI | nothing | | Acts and mood are invisible (spec §9). There is a debug overlay only |

## 8. Determinism and the hash

- The fields are integers, so the mood cannot drift. The 1 Hz step is keyed to `S.mood.t`, not `S.T`, so hit-stop and the KO slow-down cannot shift it.
- `S.mood` and every `f.style` field go into the state hash in declaration order. The four events join `FX_FIELDS`.
- **M1's proof, in two parts.**
  1. With M1 observing only (no reader wired), fighter trajectories are unchanged. The goldens are regenerated once, because the hash gains fields. The check is a one-off run with the mood block left out of the hash, which must reproduce the pre-M1 goldens exactly.
  2. A forced vector (like `rallyHash`) drives scripted stances and events through band, act and label changes, including hysteresis and dwell, and is hashed into the goldens.
- Encounter's and World's readers come after M1, each with its own golden change.

## 9. Open points (routed by the EP)

- **Game Design:**
  - the impulse table, decay, drain and band numbers, tuned against the QA bands;
  - whether `aggression` should be per fighter (for example, scaled by `care`) or one scalar.
- **Narrative:** the label thresholds and hold times in §5 (from §8.2, with exit thresholds added), and `mixer`'s definition.
- **Encounter:** Q4's use of `aggression`, and the style reaction.
- **World:** how `crowd` combines with local danger in evacuation.
- **Tools:** the schemas for `fight/mood.json` and `fight/style.json`.
