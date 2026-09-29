# S3b loader note for Encounter Systems

Owner: Combat and Choreography. Audience: Encounter Systems (loader and ops in `sim/director/`). Date: 2026-09-29.

The data is `data/combat/templates.json` and `data/combat/finishers.json`; the schema is in `data-fields.md` section 10.

## The contract in six lines
1. **Load both files once, at match start.** Their contents are part of the match's inputs: hash them into the replay header, so a replay names the data it used.
2. **The planner reads the template for (attack kind, defender state).** It runs the selector: same draws, same order, as in `data-fields.md` section 10.4. It sets `ex.tag` from the branch. Then it schedules `shared` and then the branch's beats, in array order, through `DirExchange.schedule`.
3. **The chain link** (`chainLink`) and **the finisher** (`finishers.json`, chosen by `select`) are scheduled the same way, relative to `ex.t` when they start.
4. **Ops stay in code.** Data chooses ops, times, args and branches; it never adds behaviour. Six new ops are listed in `data-fields.md` section 10.5, all small. Only `contest` draws directly (once, as today). The launches that `finalBlow` and `fixedLaunch` trigger draw exactly as `launch` and `breakLaunch` do today (planner noise, launch spin).
5. **One switch per file:** `profile`. `parity` must be bit-identical to 69c4a2f. `spaced` and `authored` are the new timings.
6. **Tags are exact strings.** `launchBeat` compares `ex.tag` with "HEAVY CLASH", "GUARD BREAK" and "CHARGE INTERRUPT". `tagProposed` is ignored until Narrative's and Game Design's names are ruled on.

## Proving it bit-identical before any timing changes
Do these in order, with both files on `profile: "parity"`. Do not change timing until all four pass.

1. **Plan-level diff (fast, and pinpoints errors).** Keep the code path for now. For every exchange, plan it twice, once through the code and once through the data, on cloned RNG states. Assert that the beat lists are identical: same count; for each beat, the same `op`, the same `t` bits and deep-equal `args`, with the same `o` keys and `null` where the code passes `null`. Also assert the same `ex.tag` and the same RNG state after planning. Run it over the golden seeds, then 1,000 default-arm seeds. It must catch every template branch at least once; assert the coverage counts.
2. **Golden hashes.** Switch the planner to the data path only and run QA's golden and determinism tests. The hashes must equal the ones regenerated at 69c4a2f.
3. **The finisher.** `generic.placeholder` must reproduce `startFinisher`: seven beats in the same order, the same times as `t + x`, and the contest in `ko_now` mode. The golden matches end in a finisher, so step 2 covers it. Assert it in step 1 as well.
4. **Mutation check.** Change one number in the data (for example TRADE BLOWS' `0.17` to `0.18`) and confirm steps 1 and 2 fail. Revert.

Then delete the code-path templates (the data is the source) and keep the step 1 test as a regression test against a frozen copy of the parity data.

## Then switch to the new timing
- Set `templates.json` to `spaced` and `finishers.json` to `authored`. QA regenerates the goldens; the change is intended.
- Measure with `tempo.gd` and `batch.gd` against `balance-targets.md` section 10:
  - exchange length (median 2.5 to 4.0 s);
  - spacing between contacts (0.25 to 0.40 s);
  - exchanges per minute (8 to 12; longer exchanges will lower it, so the cooldown may come down);
  - match length and first break (longer exchanges slow the wear rate, so k may need a step, per spec-wounds.md section 1b's lever order);
  - finisher length (3 to 8 s);
  - the AI's parry success (it should stay near 41% with the wider window; `aiParryPressDelay` is the knob).
- **The tuning knob is `profiles.spaced.tempo.step`**, currently 21 ticks (0.35 s). Each +3 ticks adds about 0.2 s to a typical exchange. My estimate at 21 ticks is a median of about 2.5 to 2.9 s with hit-stop and chains; it is an estimate from the timelines, to be measured.

## What changes and what stays identical in `spaced`
| Template, branch | Timing in `spaced` | Beats (without the closing hold) | Release at a 0.40 s approach, before hit-stop |
| :--- | :--- | ---: | ---: |
| charge_interrupt | changes | 6 | 1.75 s |
| pursuit, slips | changes, short by design (an escape) | 4 | 1.27 s |
| pursuit, caught | changes | 6 | 1.75 s |
| dodge, read | changes; the dead wind-up is dropped (CC-009) | 8 | 2.45 s |
| dodge, counter | changes; the dead wind-up is dropped | 8 | 2.20 s |
| pressure, holds | changes | 7 | 2.40 s |
| pressure, counter | changes | 7 | 2.15 s |
| guard_break | changes | 8 | 2.45 s |
| trade_blows, won | changes | 10 | 3.15 s |
| trade_blows, lost | changes | 10 | 2.90 s |
| heavy_clash, won / countered / shockwave | changes | 7 / 7 / 7 | 2.45 / 2.20 / 2.50 s |
| chain link | changes (0.35 s rhythm) | 4 | +1.10 s per link |
| signature (all outcomes) | **identical** in this pass: its follow-on timing lives inside the beam ops. Proposed values are in `beam.laterSpaced` | 2 plan beats | 1.7 s, clash 3.4 s |
| finishers | new (`authored`); `generic.placeholder` stays for parity | 9 to 11, plus the outcome beats | 3.1 to 4.1 s to the final blow |

**Unchanged in every profile:**
- outcomes, damages, forces and tags;
- which strikes are parryable;
- the order of RNG draws within the selectors.

The one exception is DODGE's dropped wind-up, which removes the AI defender's press draws there. Game Design's rule changes (R1 to R8, such as no chain after GUARD HOLDS) are not in this slice.
