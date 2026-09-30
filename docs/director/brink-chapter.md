# The brink chapter

Owner: Encounter Systems Director (sim editor for this slice). Rule: `docs/design/spec-wounds.md` §1b "The brink chapter" and the §1 finisher row; bands in `balance-targets.md` §13. Status: in the tree, goldens regenerated, gates passing. The data validator needs Tools' schema entry for `contest.brinkSetups`.

## What the director does

| Rule | Where |
| :--- | :--- |
| **The exchange that causes the brink never finishes or sets up.** Each exchange records who was on the brink when it began (`ex.startBrink`). A decisive win against a fighter who was not on the brink at the start does nothing more than the call-out | `exchange.gd` `requestAttack`, `decisive` |
| **The set-up.** A decisive win against a fighter already on the brink counts toward `brinkSetups` (at most one per exchange). At the count, the fighter is **open**: it is staggered (its own `staggerTicks`), and `brink_open` carries the rival's finisher kind and id for the dropped-guard pose and the tell | `exchange.gd` `_openBrink` |
| **The finisher** starts on the rival's next decisive win while the opening holds, in a later exchange than the set-up (`f.brinkEx`) | `exchange.gd` `decisive` |
| **The opening closes** (`brink_close`) when the fighter on the brink wins a decisive exchange (after Spite fires), survives a finisher, or leaves the brink by a Rally. The set-up count starts over | `exchange.gd`; `sim/core/wounds.gd` `updateStages` |
| **The time-cap flag:** with `S.game.timeCap` set, every decisive win against a fighter on the brink is a finisher. Nothing sets it yet; the 11:00 event will | `sim/core/state.gd`, `exchange.gd` |

**Data.**
- `data/combat/finishers.json` `contest.brinkSetups` = 1. The key is new, and Tools' `combat-finishers.schema.json` needs `brinkSetups: integer ≥ 1` under `contest`. With that entry added in a scratch copy, the validator reports 0 errors.
- `guardWearSplit` is 0.5 / 0.5 in both fighters' `wounds.json`.
- `parity.gd`'s wiring test for that value now edits it to 0.6 / 0.4, since the data already holds 0.5 / 0.5.

## Results

Seeds 1 to 100, default and swap arms, capped at 15:00. The probe counts the first brink by either fighter.

| Measure | Band | `brinkSetups` 1 (the tree) | `brinkSetups` 2 (scratch) |
| :--- | :--- | ---: | ---: |
| First brink to KO, median (p10 to p90) | 45 to 90 s | **26 s** (12 to 71) | 44 s (17 to 123); 51 s default arm, 37 s swap arm |
| Match length, median (p10, p90) | 6:00 to 8:00; p10 at least 5:00 | 7:18 (5:33, 9:02) | 7:36 (5:51, 9:52) |
| First brink, median | 4:30 to 7:00 | 6:43 | 6:43 |
| Timeouts at 15:00 | at most 1% | 0 | 0 |
| Rallies per match | 0.3 to 0.7 | 0.33 | 0.29 |
| Finisher survival | 25 to 40% | 31.3% | 29.6% |
| Openings per match | | 2.06 | 2.13 |
| Limb breaks per match; arms' share | 0.3 to 0.5; 35 to 65% | 0.55; **68.8%** | 0.66; 65.6% |
| KAI | at least 42% | 47% | 44.5% |

With `brinkSetups` 2 and `guardWearSplit` 0.4 / 0.6 (default arm, 100 matches), the arms' share is 59.5%, brink to KO 52 s and the match median 8:12.

Before this slice, brink to KO had a 4 s median (Game Design's probe).

## For Game Design (the ruling's next steps, measured)

- **`brinkSetups` 2** brings brink to KO to about 44 s, the band's edge. The match median then passes 7:30, which the ruling answers with a higher k (up to 0.045).
- **`guardWearSplit` 0.4 / 0.6** brings the arms into band.

All three are data. I kept the tree at the briefed values: `brinkSetups` 1 and a 0.5 / 0.5 split.
