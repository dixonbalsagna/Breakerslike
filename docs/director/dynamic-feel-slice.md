# Dynamic-feel slice

Owner: Encounter Systems Director. Inputs: `docs/combat/dynamic-feel.md` §2.2 (Combat); `docs/design/balance-targets.md` §10 dynamic rows and §4b rulings 3 and 6 (Game Design); `spec-wounds.md` S4 ruling 3 (the overtime ramp). The measurements that led here are in `pace-measurements.md`.

**Status.** Applied to the tree on Orb's go-ahead (2026-09-30), 9 files, goldens regenerated. The gates on the tree all pass: the golden check, `loader_check` (15,014 plans) and `npm test` (5 of 5 stages). Render determinism passes on HEAD's render code with the tree's `sim/` and `data/` applied. The tree also holds World's uncommitted window (collateral, terrain, water, `hasMenace`), and the regenerated goldens cover both. The results below were measured on a scratch copy of HEAD. A re-run on the applied tree agrees: melee idle 10.4%, 118 strikes a minute, release to request 0.97 s, first strike 0.63 s, 17.6 exchanges a minute, KAI 46.5% over 200 matches.

## Changes

| # | Change | Where |
| :--- | :--- | :--- |
| 1 | **The profile by name.** Step lists come from `branch[profile]`, `shared[profile]` and `chainLink[profile]`. Tick timing applies when the profile's `timeUnit` is `"tick"` (`DirData.ticked()` replaces `spaced()`). The dynamic profile's cue beats now fire, so Rendering's cue poses show | `sim/director/data.gd`, `melee.gd` |
| 2 | **The switch:** `"profile": "dynamic"` | `data/combat/templates.json` line 4 |
| 3 | **Cooldown:** 0.25 s + 0.1 s per second of exchange, at most 0.6 s (was 0.8 + 0.3, at most 1.5) | `exchange.gd` |
| 4 | **AI cadence:** AGGRESSIVE 0.5 to 1.2 s, DEFENSIVE 1.0 to 2.0 s, the others 0.8 to 1.6 s. `P_ATTACK` 0.9 / 0.8 / 0.85. `CAD_MIN` 0.5 / 1.0 / 0.8 / 0.8 | `ai.gd` |
| 5 | **No wasted beats:** the AI does not spend a beat on a press the director would refuse (the cooldown, or a launched or locked target). It waits and swings when it can | `ai.gd` |
| 6 | **No close-range halt:** in reach (260 u), AGGRESSIVE circles the opponent on a 120 × 70 u ellipse, a turn in about 2.6 s, the two slots half a turn apart. DEFENSIVE sways (half-speed step back and in, and a bob). No random draws | `ai.gd` |
| 7 | **The beam-dodge hang (CC-005):** the dodger is freed at the dodge and drifts up and away (420 and 180 u/s) instead of hanging locked for 0.9 s | `beam.gd` |
| 8 | **The overtime ramp:** past 9:00, k rises by 25% of itself per minute (read as linear, 1 + 0.25 × minutes past 9:00). **k itself is unchanged (0.065)** until QA measures the damage rate | `sim/core/wounds.gd` |
| 9 | **Composure off** (§4b ruling 6): `COMPOSURE_BONUS` 0 | `sim/core/damage.gd` |
| 10 | **Open-ground spawn** (§4b ruling 3): `START_X` 5,600 × PS = 89,600, the desert's west edge. The pair is 89,600 and 90,350. The `-flip` arms already swap from `START_X` (Simulation's S4 fix), so they follow | `sim/core/constants.gd` |

**Why the desert edge.** The layout is fixed, not seeded. The plains between the harbour village and the city are only 9,900 u wide, so no point there is more than 4,900 u from a town. The nearest open ground (plains or desert) at least one village width (about 7,000 u) from every building is the desert's west edge. The nearest town from there is the outskirts village, about 18,400 u west past the forest. It is one constant, so Game Design can move it.

## Results

Default arm, seeds 1 to 100 (tempo also 101 to 200 and the swap arm; feel probe `qa/godot/feel/feel_probe.gd`, 40 matches). Before is HEAD.

| §10 dynamic row | Target | Before | After |
| :--- | :--- | ---: | ---: |
| Melee idle share | at most 15% | 42.5% | **10.2%** |
| Still stretch, median / p90 | at most 0.25 / 0.5 s | 0.85 / 1.28 s | **0.10 / 0.28 s** |
| Request to first strike, median | at most 0.6 s | 1.45 s | **0.72 s** (see below) |
| Gap between strikes, median / p90 | at most 0.25 / 2.0 s | 0.17 / 4.17 s | **0.08 / 1.85 s** |
| Strikes per minute | at least 80 | 53 | **121** |
| Release to next request, median | at most 1.0 s | 2.85 s | **0.93 s** |
| Standoff p90 | at most 0.6 s | 1.60 s | **0.12 s** |
| Share of time in exchanges | at least 50% | 48% | **62%** |
| Hit-stop share | 7 to 13% | 6.9% | 9.7% |
| Exchanges per minute | 15 to 24 | 9.65 | **17.6** |
| No gap over 10 s | at least 95% | 100% | 100% (swap 99.5%) |

| Other bands | Target | Before | After |
| :--- | :--- | ---: | ---: |
| Match length, median | 6:00 to 8:00 | 7:22 | **3:06** (k not yet retuned) |
| KAI win rate | 45 to 55% | 66.7% (P1, 100) | 48.8% over 400 (both slots) |
| Launches per minute | 4 to 6 | 4.56 | **10.8** |
| Largest launch type | at most 40% | SMASH ACROSS 36.9% | **SMASH ACROSS 44.5%** |
| Planner long hauls | at least 30% | 31.5% | 35.3% |
| New biome after a launch | at least 25% | 49.9% | 50% |
| Slides among ground landings | 60 to 85% | 71.1% | 78.7% |
| Civilians lost, mean | 25 to 50% | 16.7% | **14%** |
| Fight time underwater; over the ocean | at most 10% | 1.0%; 8.8% | 0.1%; 0.2% |
| Contests survived | 20 to 35% | 26.7% | 22.5% |

## Findings for the next step

- **k.** At 17.6 exchanges a minute, matches run about 3:06. Before the spawn and composure changes, a scratch sweep with this slice gave these medians:

  | k | Median | First brink | Timeouts |
  | :--- | ---: | ---: | ---: |
  | 0.030 | 7:58 | | 1 |
  | 0.035 | 6:27 | 6:16 | 0 |
  | 0.040 | 5:23 | | |

  That matches Game Design's expected "about 0.03". QA's damage-rate measurement sets it.
- **First strike (0.72 s) is the pursuit.** Split by distance at the request:

  | Distance at the request | Share of melee | First strike, median |
  | :--- | ---: | ---: |
  | Within 700 u | | 0.25 s |
  | 700 to 2,500 u | | 0.63 s |
  | Past 2,500 u (pursuit flight) | 27% | 2.0 s |

  The far attacks mostly follow a long launch. They fly §10's own pursuit row (0.8 to 2.0 s), so the two rows conflict. There are two ways out:
  - measure first strike over non-pursuit melee (QA, Combat);
  - or have the AI close in before swinging at long range, which costs release-to-request.

  That is a ruling for Game Design.
- **Launch rate and SMASH ACROSS.** Launches doubled per exchange on open ground: with no buildings to stop a flight, the planner's distance term lifts SMASH ACROSS over the no-launch shove. Raising `NONE_BASE` alone trades one band for the other:

  | `NONE_BASE` | Launches per minute | SMASH ACROSS |
  | ---: | ---: | ---: |
  | 25 (today) | 10.8 | 44.5% |
  | 32 | 7.2 | 50% |
  | 38 | 4.2 | 53% |

  The fix is a planner retune: the distance term or a SMASH ACROSS cap, together with the no-launch threshold. It depends on where the spawn lands and on World's B2 brunts, so it belongs to the next planner pass.
- **Civilians lost 14%** (band 25 to 50%). Fights start far from towns and matches are short. The k retune lengthens matches, and World's next window adds relocation and evacuee menace. Measure after both.
- **Brunts.** BUILDING SMASH is at 2.9% on open ground; the B2 brunt work applies here.
