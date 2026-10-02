# Ground contact: leaving the ground, landing, bouncing, rims (plan)

Owner: World and Environment. Status: plan, docs only (2026-10-01), written against Game Design's rules (`docs/design/balance-targets.md` section 20). Nothing here is in the sim. Orb's brief: a fighter who skids up the side of a crater like a ramp should leave the lip with his speed and fly on, not follow the ground down the inside; fighters should be "ragdolled and skid, tumble, bounced over the course of the fight", ocean skipping being the example that already looks great. The approved rule: a skidding fighter leaves the ground whenever the terrain curves away beneath him faster than gravity pulls him down (a ballistic step ends above the ground), keeping his speed and direction; on coming down he resumes the skid with the tangent part of his velocity, or bounces. Encounter is the sim editor now; this takes the slot after its step 2a.

## 0. What the code does today (`slide.gd`, `fighter.gd`)

- **A skid follows the ground, kinematically.** `WorldSlide.step` moves the fighter horizontally and then sets `f.y = groundY(S, x2)` every tick, with `f.vy = 0`. Speed changes only by friction (`MU` 1200 and `KV` 1.2 times speed) and by the slope ahead (`GRAV` 1000 times rise over run). His vertical velocity is never carried: a ramp does not turn horizontal speed into upward speed.
- **At a crest or a crater lip nothing happens.** The only way off the ground is the cliff rule: a drop steeper than `CLIFF` = 1.0 (drop over run, one tick's step) ends the slide with `vx` kept and **`vy` set to 0**. A lip with a gentle outer slope never trips it, so he rides over and down the inside of the bowl, which is what Orb saw. Even when the cliff rule fires he leaves flat, not along the ramp.
- **A rise steeper than `WALL` = 0.8 stops the skid** (a stop-impact dent and some damage) if he still has speed over `STOP`.
- **Nothing bounces on land.** `SimFighter.impact` (fighter.gd:31) decides by the vertical share of the velocity: a slam (`SLAM_VERT`, 0.94 after Game Design's section 19) digs one crater and the fighter goes down; anything shallower starts a skid; a very hard slam (speed 2,000 or more) hops once. The only repeated bounce is the **water skim** in `stepLaunched` (up to `SKIM_MAX` = 6, lift 0.65, keep 0.85, for a fast shallow entry).
- **The impact angle is measured against the horizontal, not the surface.** A body hitting the steep wall of a crater at a shallow angle to the horizontal is "a slide" though it meets the wall nearly head-on, and the vertical part of its velocity is thrown away at touch-down.
- **Wrap-safe:** every x uses `SimWrap.wrap` and `groundY` wraps its columns.
- **Craters already have rims, but small ones, and the big ones are walls.** From the probe on flat ground: E = 1: R 160, depth 35, rim 11.7 units (0.33 of the depth, 0.16 of a fighter height); E = 4: rim 27 (0.39 d); E = 8: 56 (0.56 d); E = 16: 110 (0.83 d). Measuring the steepest slope of the whole profile on its way up to the lip (bowl wall and rim together; rim = x of the depth, lip 0.3 R wide):

  | Rim | Steepest inner slope |
  | :--- | ---: |
  | none | 0.34 |
  | 0.25 d | 0.50 |
  | 0.33 d | 0.585 |
  | 0.50 d | 0.77 |
  | 0.83 d | 1.13 |

  The ratio does not depend on size. So today's rims are ramps only up to E = 4 (0.33 to 0.39 d, slope about 0.6); **from E = 8 the rim is over 0.5 d and its inner slope passes 0.77, and at E = 16 it is 1.13, past `WALL` (0.8): a skid that climbs into a big crater's lip is stopped by a wall instead of launched.**

## 1. Against section 20: what I accept, and where I disagree

**Accepted as written:** the state table (airborne, skid, bounce, slam, tumble, skip, down); the angle bands (a contact angle is the angle between the velocity and the surface: shallow under 30 degrees, bounce 30 to 70, slam over 70: `sin` 0.5 and 0.94, which is the same 0.94 as section 19's `SLAM_VERT`, now measured against the surface normal and not the horizontal); the speed bands (nothing under 350; tumble 350 to 900; skid and bounce over 900; a skid falls to a tumble under 600); bounce keeps 80% along the ground and 45%, 35%, 25% of the vertical speed for the first, second and third bounce; bounces by tier (1, 2, 3, 3); bounds on a journey (8 contacts, 4 s, then a tumble to a stop); one journey costs at most one impact of wear; water skips as today; every outcome decided by speed, angle and surface with no draw. The leave test below is the approved rule.

**Where I disagree or add:**
1. **Rims (revised after Game Design's wider-lip request, section 3 has the numbers).** Today's rims are 0.33 to 0.83 of the depth with a lip 0.3 R wide, and the big ones are walls (inner slope 0.77 to 1.13). With the lip widened to 0.5 R the crest can be taller and still be a ramp: **lip 0.5 R, crest 0.40 d** (inner slope 0.57, 1D rim-and-apron volume 0.53 of the bowl), with 0.45 d the most that holds 0.6. The 0.5 d crest Game Design asked for gives 0.63, over the limit, unless the lip is 0.6 R. I first proposed a 0.12 R rim (0.55 d, slope 0.8) and a 0.33 d cap at the old lip; both are superseded.
2. **New hashed fighter fields.** Section 20's journey bounds, the tumble, and the early recovery need state: `jContacts` (contacts so far), `jT` (seconds since the first contact), `jV0` (the journey's starting normalised speed, for the one-impact wear budget), `tumbleT` (seconds rolled), `contactT` (seconds since the last contact, for the 8-tick recovery window), `launchN` (the launch number, so every event pairs to its launch). `bounces` exists. These are granted lines in `state.gd` and `hash.gd` (Simulation).
3. **The tumble is a mode of the skid, not a separate system:** braking doubled, no trench, `rot` free, ends at 1.2 s or at a stop. Contact on rubble is always a tumble (a surface-class flag).
4. **Today's slide runs from 350 to 60 (`STOP`);** under section 20 a contact at 350 to 900 is a tumble and a skid under 600 becomes one. That shortens slides at low power and gives them the "rolls to a hard stop" look. It is a behaviour change QA should expect in slide length and trench counts.
5. **The leave test has one tolerance,** `LEAVE_CLEAR` (about 1.5 units: the ballistic step must end that far above the ground). It is not a speed threshold; it only keeps column-level noise from making a slow fighter hop.
6. **Wear** (one impact per journey) is Combat's and Simulation's code (`SimDamage`); I supply the contact record (speed in, speed out, kind) and the journey function reports the budget. The numbers are Game Design's.

## 2. The ground model: leave, land, bounce, tumble

One pure function shared by the runtime and Encounter's launch predictor (the B2 pattern, so plan equals outcome): `WorldSlide.advance(S, st, dt) -> st`, with `st` a small record `{x, y, z, vx, vy, mode, slide, bounces, contacts, t, launchT, tier}` and nothing else changed. `stepLaunched` and the journey function both call it; events are emitted by the runtime from the record's flags, never by `advance`. Arithmetic is float64 with `SimDetMath` roots, no trigonometry (an angle is a ratio), `x` wrapped with `SimWrap.wrap`; slopes from `groundY` at `x +- COL`.

**The leave test (replaces `CLIFF`).** In a skid or a tumble, let `s` be the slope of the segment just travelled (rise over run, in the direction of travel) and `vy_t = s x vN` the tangent's vertical rate. Take the next ballistic step exactly as `stepLaunched` integrates it: `vy' = vy_t - 1000 dt`, `y_b = y + vy' dt`. If `y_b - groundY(S, x2) > LEAVE_CLEAR` he leaves: `slide = 0`, `vx` kept, **`vy = vy_t`**, mode airborne, a `left_ground` event. It is equivalent to "the ground's radius of curvature at the crest is smaller than `v^2 / g`": at 2,000 units a second any crest tighter than 4,000 units lets go, at 500 any under 250. A hill (radius in the hundreds of thousands) never does; a heap crest (about 75) does from 270 upward; a crater lip, a cliff and a ridge do.
- The vertical rate uses the normalised speed (`vy = s x vN`), with the horizontal part carrying the launch's traversal factor as every launch does, so arcs stay readable. Alternative (Game Design): the tangent in raw space, arcs `launchT` times higher.
- The wall rule (`WALL` 0.8) stays: a rise steeper than a skid can climb stops him.

**Landing.** With the ground slope `s` at the contact (secant over `+- COL`), tangent `t = (1, s)/q` and normal `n = (-s, 1)/q`, `q = sqrt(1 + s^2)`, normalised velocity `(vxn, vy)`: `vn = (vy - s vxn)/q` (negative into the ground), `vt = (vxn + s vy)/q`, speed `sp = hypot(vxn, vy)`, contact `sin^2 a = vn^2/sp^2` compared as squares with 0.25 (30 degrees) and 0.94^2 (70). Then section 20's table applies as written: skid (over 900), bounce (30 to 70 degrees, over 900, with a bounce left: `vn' = -e_k vn` with `e` = 0.45, 0.35, 0.25 by bounce number, `vt' = 0.8 vt`, lifted off at once), slam (a crater, a hop at 2,000 or more), tumble (350 to 900, or rubble, or no bounce left and too slow to skid), water (the skim, unchanged: its keep and limits move into the surface table). A skid starts with the tangent speed (`vt / q` horizontal): the normal part is what the ground took.
- **Spin.** At a bounce `spin = dir x vt / BODY_R`, decaying in the air (a formula, no draw); `rot` free in a tumble, 0 in a skid. Animation reads `spin`, `bounces`, `mode` events.
- **Depth.** With lanes `groundY` takes the fighter's `z`; nothing in `advance` changes.

**The surface class per column** (braking). `WorldTerrain.surfaceAt(S, x)` is a pure, derived function (nothing new hashed): water where `S.water` is at least `MIN_DEPTH`; rubble where `S.rubble` is above a threshold; paving inside a settlement's platform (the span and platform the generator already has, not the coarse biome test `_paved` uses today); otherwise by biome from data: desert sand, mountains and highlands rock, plains and forest soil. `data/biomes/contact.json` (`biomes.contact/1`) holds the table: braking multiplier (paving and rock 0.8, sand and soil 1.3, per section 20), the tumble flag (rubble), and the water row (skip limits). A dug column is soil, its paving gone: a trench in a street leaves the class as paving until the cracks are the pavement's record (`S.crack`), a decision for Game Design.

**The journey function.** `WorldSlide.journey(S, st0, tier) -> {contacts: [{t, x, y, kind, speed, left}...], end: {x, y, t, kind}, n, lips, tumble, speedLoss, area: [{x, power}...]}`. It runs `advance` from the first contact (or from a launch) until the stop, 8 contacts or 4 s, then closes the tail as a tumble to a stop (closed form, no more steps), and reports each contact's area-damage power so Encounter can check the collateral budget (section 20: the planner declines an over-budget journey). Pure, no draw, same `advance` as the runtime. Cost: a journey is at most 240 ticks of `advance` (about 0.5 to 1 us a tick); with up to 16 predicted flights per decision that is 2 to 4 ms on that one tick: Encounter's budget (a candidate cap or a coarser candidate screen first); the plan equals the outcome because the step is the same.

## 3. Raised crater rims and lips on ridges and heaps

- **Craters: lip 0.5 R, crest at most 0.40 of the depth** (`RIM_IN` 0.3 to 0.5, `RIM_DEPTH_MAX` 0.40). Numbers, for a straight-down bowl (depth 0.22 R), steepest slope on the way up to the crest, bowl wall and rim together:

  | Rim, lip | Inner slope | Rim+apron area / bowl area (the sim's 1D profile) | Crest at E = 0.5, 1, 4, 16 (units) |
  | :--- | ---: | ---: | :--- |
  | today: 0.33 to 0.83 d, 0.3 R | 0.58 to 1.13 | 0.39 (E <= 2) to 1.02 (E = 16) | 8, 12, 27, 110 |
  | 0.33 d, 0.5 R | 0.52 | 0.43 | 8, 12, 23, 44 |
  | **0.40 d, 0.5 R (recommended)** | **0.57** | **0.53** | **10, 14, 28, 53** |
  | 0.45 d, 0.5 R (the most that holds 0.6) | 0.60 | 0.60 | 11, 16, 32, 59 |
  | 0.50 d, 0.5 R | 0.63 (fails) | 0.68 | 12, 18, 35, 66 |
  | 0.50 d, 0.6 R | 0.60 | 0.72 | 12, 18, 35, 66 |

  The slope and the ratios do not depend on the size. Game Design's estimate of 0.53 holds for a crest of about 0.35 d; at 0.5 d it is 0.63. **Volume:** the doc's convention is the 1D profile (the sim's crater is a trench across the band), where rim and apron hold 0.53 of the bowl at the recommended setting, inside "no more than the bowl". By a revolved 3D measure (a ring at a larger radius carries more) the ratio is above 1 already today (1.6) and would be about 2.3; the sim does not use that measure, and Rendering draws the bowl from the same profile, so I read the rule as the 1D one.
- **Does the lip launch?** The crest's radius of curvature is `(lip x R)^2 / (6 rim)`; a skid leaves when `v^2 / g` exceeds it. At the recommended setting: E = 1 leaves above about 275 units a second, E = 4 above 390, E = 16 above 530 (today, with the 0.3 R lip: 180, 260, 350). A skid is over 900 by section 20, so every skid leaves every crater lip; a tumble (350 to 900) leaves the big ones only above about 530. The wider lip is a gentler ramp, so the launch reads as an arc and not a pop.
- **T1 to T4 limits.** The relaxation's limit is 1.25 (40 units a column): a 0.57 slope (18 units a column) is untouched, so rims stay crisp. The crest never meets `DEFORM_CEIL` (960): a special crater of R 8,320 had a rim of 0.83 d = 1,520, so it was clipped flat-topped; at 0.40 d it is about 730. The relief cap (`RELIEF_MAX_RATIO`), the ordinary bowl cap and `DEFORM_FLOOR` are untouched. The ring the next dig samples at 1.2 R sits on the apron (0.9 of the crest), so a second dig on a lip is held back slightly more, which is right. The audit's steps stay under 0.6 bh a column, a smooth crest does not trip the spike metric, and shafts are unaffected.
- **Footings.** The apron reaches 2 R and the lip starts at 0.5 R, so more columns are in it than before. A rim lands on the columns of standing buildings in its apron. The T4 rule extends to digs: the rim's positive writes skip the columns under standing footings (`WorldStructures.pinned`), as heaps do.
- **Probe and audit.** The audit tool adds a "lip slope" metric (the steepest rise into any rim) and the probe a hard check: over a sweep of energies and grazes, the steepest inner slope is at most 0.6 and the 1D rim-and-apron area at most the bowl's.
- **Rubble heaps** get the same ramp rule. T1's crest cap (4 bh, slope at most 1.0) becomes **slope at most 0.6** (`RUBBLE_SLOPE` 0.6) with a wider spill (`RUBBLE_SPILL` 1.2 widths): a heap at most about 2.5 bh, a ramp a skid can climb and leave from the crest, not a wall that stops him. The footing taper stays.
- **Ridges and hills.** Slopes in the fighter plane are set by the generator: the highlands relief (about 8 bh at most, `districts-plan.md` section 14) is built with `HIGHLAND_SLOPE_MAX` 0.6 on the flanks and a crest tight enough to launch a fast skid; the formations (N1) stand on top. Today's mountain flanks reach 1.15 (37 units a 32 unit column) and would stop a skid as a wall; they become the far ridge row (not reachable) or the highlands.
- **Cliffs.** The relaxation allows up to 1.25: a step steeper than a skid can climb stops him (wall), a drop leaves by the test. Nothing else is needed.
- **Buildings, formations, props:** unchanged (a body that meets a footprint stops or is hit, L3). **Water's edge:** the skim.

## 4. Events (Camera, VFX, Animation, Audio)

New events (`docs/architecture/fx-events.md` gets them in the same slice). **Every one carries `x`, `y`, `z` (the body's depth) and `speed` (normalised), and `n`, the launch number** that pairs it to its launch: a per-fighter counter `launchN`, set when `doLaunch` arms a launch and hashed (one more fighter field), copied onto every event of that journey and onto the `launch` event itself.

| Event | Fields (besides actor, x, y, z, speed, n) | When |
| :--- | :--- | :--- |
| `left_ground` | vx, vy, cause (`lip`, `crest`, `heap`, `cliff`, `ridge`, `bounce`), contacts | the leave test fires, or a bounce lifts off |
| `bounce` | k (the bounce number, 1 for the first), vn, vt, keep, surface | a ground bounce; a water skim keeps its `skim` event and also emits this, with `surface` `water` |
| `land` | kind (`skid`, `tumble`, `slam`, `stop`), sin_a, surface, contacts, t | a contact that is not a bounce; `contacts` and `t` are the journey's counts so far |
| `tumble_end` | how (`stop`, `recover`, `air`), contacts, t | a tumble ends |
| **`journey_end`** | contacts (all kinds, at most 8), lips (flights off a lip), bounces, t (seconds from the first contact, at most 4), end (`stop`, `tumble`, `slam`, `water`, `recover`, `capped`) | once per journey, when it ends for any reason, including the 8-contact and 4 s caps (`capped`); the pairing event QA counts |
| existing `skim` | gains `z`, `speed`, `n` | each water skip |
| existing water events (`splash`, the water `ring`) | gain `z` (the body's depth, for a body at another lane), so VFX draws them at the right depth | as before |
| existing slide events | unchanged, plus `n` | the trench, dust and record |

**Why the journey counters come from state, not from the events:** `contacts` and `t` are the fighter's `jContacts` and `jT` (section 1, point 2), so the numbers on the events are exactly the ones the caps use and the planner's `journey` function predicts; QA can compare a predicted journey to the played one field by field. `launchN` is the only new field the events add. Nothing here draws a random number.

Camera takes `left_ground` to `land` as an airborne phase with a known arc; VFX hangs dust, tumble blur and the contact flash on `bounce` and `land` by speed and surface; Animation picks skid, tumble, bounce and air from the events and from `mode`, `spin`, `bounces`; Audio takes surface and speed. The early recovery (a dodge tap in a tumble or within 8 ticks of a bounce) is Controls' and Combat's; the window is readable from `contactT` and the mode.

## 5. Slices and goldens

| # | Slice | Owner | Behaviour | Goldens |
| :--- | :--- | :--- | :--- | :--- |
| G1 | Rims capped at 0.33 d, the dig's footing skip, the heap ramp (`RUBBLE_SLOPE` 0.6, spill 1.2), the lip-slope probe check and audit metric, the doc table | World | Changes (terrain: smaller big rims, gentler heaps) | Regenerated |
| G2 | The ground model: `WorldSlide.advance`, the leave test, the landing table, tumble, `surfaceAt`, `contact.json`, the new fighter fields; `fighter.gd` (`impact` and the launched branch) calls it, by grant. **Lands off by a data flag** (`enabled`), so it is neutral and provable on the light digests | World, with granted lines in `fighter.gd`, `state.gd`, `hash.gd` | Neutral | Hash-only |
| G3 | The events and their consumers: `fx.gd`, `view/fx.gd`, FX_FIELDS (granted); Camera, VFX, Animation, Audio read them | World, with Rendering and the others | Neutral | Hash-only |
| G4 | `WorldSlide.journey`, and Encounter's planner calls it; the probe of plan against outcome over 300 seeded launches across craters, heaps and cliffs | World writes it; Encounter calls it | Neutral until switched on | None |
| G5 | **The switch-on** (`enabled`) with Game Design's numbers; the early recovery with Controls; QA re-baselines | World, Combat, QA | Changes (landings, wear, slide length, collateral from slides, where launches end) | Regenerated once |

G1 can land first and alone (terrain only). G2 to G4 follow the lanes order (they touch the launched branch of `fighter.gd`): after L0 and L2. G5 lands with or just before L4's switch-on so QA re-baselines once. **QA bands that move:** slides, bounces, slams and caught-in-the-air shares (section 20's table), craters per match (down), time to a stop, airborne time after a landing, wear per journey, flights off a lip per minute, and collateral from slides.

## 6. Game Design's rulings (balance-targets section 20) and what is left

**Applied:** a trench in paving becomes soil for braking (the surface class reads the trench: a column whose `S.deform` is below its settlement platform's paving level counts as soil); heaps at slope 0.6 (`RUBBLE_SLOPE`); highlands flanks 0.35 to 0.6 (`HIGHLAND_SLOPE_MIN`, `HIGHLAND_SLOPE_MAX`); the leave uses the normalised tangent, with an optional lip-lift factor (`LIP_LIFT`, 1 to 2, data in `contact.json`, default 1) that multiplies the vertical rate at the leave; no personality difference; no random draw anywhere.

**Answered (balance-targets section 20, end):** spin is my formula, halving every 0.5 s in the air, capped at 3 turns a second (1.5 at tier 1); a tumble leaves one scuff and one dust puff per contact, at most 3 a second, and no trench; wear is 30% at the first touch-down and 70% in proportion to the speed each contact removes, a slam pays all, a lip flight pays nothing; `LEAVE_CLEAR` about 1.5 accepted. **Rim ruling (EP):** lip 0.5 R and crest 0.40 d as data (`RIM_IN`, `RIM_DEPTH_MAX`), with the pair 0.6 R and 0.5 d as the switch if Orb wants a taller lip after seeing it. Nothing is open on the plan.

## 7. Risks

- **Plan and outcome** are the main one (as for B2): the planner must call `journey`, which calls `advance`; the probe covers it, and the cost of a decision grows with journeys (cap candidates first).
- **Jitter:** `LEAVE_CLEAR` and the surface noise; the probe checks that a skid across 1,000 seeded plains leaves nowhere.
- **Slide length:** tumbles replace slow slides, so trenches and dust at low power shorten; Art and VFX want to see it.
- **Collateral:** longer flights and bounces move where launches end; slides near towns are watched by QA.
- **Replays:** `contact.json` joins the replay data hash (`dataHash()`).

## 8. Scratch build: status and measurements (2026-10-02)

Built against local HEAD 08f5cd0 in a scratch copy, so each slice is ready to apply the moment its slot opens. Everything is in `docs/world/scratch-build/` (a `build.py` that applies it to a fresh export; its README says how). The tree's sim files are untouched.

**G1 and reach** (`g1_reach.py`, `g1_freeze.py`): lip 0.5 R and crest 0.40 d with footings skipped; heaps at slope 0.6 (spill 1.0: above about 1.1 a low chain flight lands on the heap and plan and outcome differ); structure reach by tier with the scaled falloff, data in each `ladder.json` (`reach.structure` [1, 1, 1.6, 2.8], `reach.ringCap` -1) with the schema, `fighter_data.gd`'s parse and `beam.gd`'s explicit 1.0; and a slide's trench no longer relaxes the ground he stands on or the ground ahead (it dropped away beneath him and read as a lip of his own making). Probe: 0 failures, with the new section (rim slope at most 0.6 at every energy, largest 0.56; crest at most 0.40 d; rim and apron area at most the bowl's; heap slope at most 0.6; reach out to exactly the tier's factor and no further; the beam's path sample not widened). 100 default-arm matches, HEAD against G1 and reach:

| | HEAD | G1 and reach |
| :--- | ---: | ---: |
| Civilians lost at the KO | 17% | 20% |
| Structures lost | 45.8 | 55.1 |
| Craters | 48 | 46 |
| Length | 468 s | 475 s |
| KAI | 45 | 52 |
| BUILDING SMASH | 7% | 6% |
| Structures per minute at tier 3 (all rows / front row) | 4.15 / 5.53 | 3.91 / 5.49 |
| at tier 4 | 4.41 / 5.57 | **7.68 / 9.81** (band 6 to 20) |
| KO structures, all rows / front row | 24.9 / 32.4 | 31.2 / 41.0 (bands 15 to 40 and 25 to 50) |
| 60 second tier-4 windows over 20% of the front row | 7 of 40 matches | 13 of 40 (worst 47.5 to 61.3%) |

Tier 4 is now in its band; tier 3 was already in band on the retuned HEAD. The sim runs at 55 matches a minute against 58.

**G2 and G3** (`g2_contact.py`, `contact.gd`, `contact.json`; the model switched off by `enabled` in the data, copied into `S.contactOn` by `newMatch`): the pure `moveAir`, `groundPhase`, `stepContact` shared by the runtime (`stepFighter`) and the predictor; surface classes (`surfaceAt`, a column table built once); the landing table; bounces, skids, tumbles; the leave test; the 8-contact and 4 s bounds (past them he tumbles to a stop and cannot leave the ground again); one impact of wear per journey; spin and rot through `spinStep` (one function, only integrated or eased, never assigned); six hashed fighter fields (`jContacts`, `jV0`, `launchN` and, as integer ticks per Simulation's conditions, `jT`, `tumbleT`, `contactT` saturating at 8); the events `left_ground`, `bounce`, `land`, `tumble_end` and `journey_end`, with x, y, z, speed, the launch number, contacts and t, the slope, and `vx`, `vy` on `left_ground`; `launch` gains `ux`, `uy` and `n` (set in `WorldBrunt.arm` in the scratch; Simulation adds them in L0). Proofs:
- **Off is neutral:** per-tick light digests of 9 seeds over 12,000 ticks are identical to HEAD with the slice applied and the flag off.
- **On is deterministic:** two runs of the same 9 seeds give identical digests, and the render determinism check passes with the flag on.
- **Journey function:** over 240 seeded launches, on open ground the predicted end is within 60 units of the played one in 108 of 112 (96%); near a town it is 99 of 128, because a skid's own area damage collapses buildings and their heaps rise ahead of him, which a pre-computed journey cannot know. No NaN, no journey over 8 contacts, the same contact count in 212 of 240.
- **With the golden regenerated in the scratch (flag off):** parity passes (hash only); the validator reports only the missing `contact.json` schema (Tools).

**Flag on: what the model does** (100 default-arm matches; 20 matches for the landing classes): length 511 s (475), collateral 24% (20), structures lost 70.6 (55.1), craters 47 (46), KAI 48. Journeys per launch about 0.75; bounces per bounced journey 1.5 (band 1.3 to 2.2); the journey's end: stop 33%, wall 33% (the MOUNTAINSIDE launches landing on steep slopes), slam 31%, water 4%. **First-contact class of all launches against section 20's bands:** skid 19% and tumble 5% (slide band 40 to 55%), bounce 36% (8 to 15%), slam 21% (8 to 15%), water 3% (5 to 15%), caught in the air 16% (10 to 25%). The old model's slides were 56% of launches; the 30 to 70 degree landings it counted as slides are now bounces, and the planner's mix puts about a fifth of launches steeper than 70 degrees. Moving the skid/bounce boundary to 40 or 45 degrees gives skid 27% and bounce 27 or 22%. The bands are Game Design's call to re-base, or the angle bands' to move; the physics and the planner mix are what produce the numbers. **Cost:** about 17% more sim time per tick with the flag on (24,300 ticks a second against 28,600 in G1 and reach alone); trims: precomputed drag factors, fewer ground reads per tick.

**Order, per the EP and Simulation:** G1 and reach, then Simulation's L0 and L2 (both rewrite the launched branch), then G2 to G5 rebased onto them.

## 9. Physics constants for feel (proposed as data), for Animation's active ragdoll

Animation relies on: gravity 1000 u/s2 (unchanged), a spin cap of about 18 rad/s (mine is 3 turns a second, 18.85, and 1.5 at tier 1; halving every 0.5 s in the air, which is new: launch spin used to be constant), flights of 0.3 to 2 s. What the data gives, with the effect on a body:

| Constant | Value | Effect |
| :--- | :--- | :--- |
| Bounce keep (normal) | 0.45, 0.35, 0.25 | A 1,500 u/s landing rebounds 675 up (228 units, about 3 bh) for 1.35 s; a 900 landing 405 (82 units) for 0.8 s; the second bounce about a third of the first. Flights past 2 s only above about 2,200 into the ground: I propose `bounce.vyMax` 1,600 (a cap on the rebound's vertical speed, so a flight never exceeds 1.6 s) |
| Bounce keep (along the ground) | 0.8 | He keeps most of his run, so bounces travel |
| By surface (proposed, not built) | normal x paving 1.1, rock 1.15, soil 1.0, sand 0.75, rubble 0.8; along x paving 0.9, rock 0.9, soil 0.8, sand 0.65 | Streets and rock are lively, sand and rubble deaden: two extra data maps `bounceMul` and `tangentMul`, a few lines |
| Spin at a bounce | `vt / bodyR` (bodyR 60), capped 1.5 (tier 1) or 3 turns a second | A 1,000 u/s tangent gives 17 rad/s: a fast tumble; slower bounces roll gently |
| Tumble braking | double the skid's (section 20) for at most 1.2 s | At the tumble's entry speed (600) it stops in 0.13 to 0.3 s and 40 to 250 units: a short roll, as section 20 wants. If Animation wants a visible roll of 0.5 s or more, `tumble.brakeMul` 0.6 gives about 0.5 s; it is one number |
| Skid braking | 1,200 x surface + 1.2 v | Paving and rock 0.8, soil and sand 1.3: a 1,500 skid goes 700 units (times the launch's travel factor) on paving, 450 on soil |
| Water | skim at over 500 and under about 31 degrees, up to 6 skips, keep 0.85, lift 0.65 | Unchanged from today (the look Orb likes) |
| Slope | a skid gains or loses speed by `GRAV` x slope; a leave test per tick | Uphill a ramp slows him; a lip lets him go along the ramp; a straight downhill slope never lets go. I propose a `skid.vMax` (twice his entering speed) so a steep downhill cannot accelerate him without limit (not built) |
| `LEAVE_CLEAR`, `LIP_LIFT` | 1.5 units, 1.0 | A small tolerance; a lift above 1 raises the arc off a lip (data, at most 2) |

Animation's asks, from the EP's message: (1) the event fields are in (left_ground: vx, vy, cause, slope; bounce: k, vn, vt, keep, surface, slope; land: kind, sin_a, surface, slope; tumble_end: kind; plus z, n, contacts and t). (2) The ground slope is on each event as rise over run; the normal is `(-slope, 1)` over its length. (3) rot and spin are one function's, integrated or eased, never assigned (a skid eases upright with a 0.2 s time constant, so nothing snaps). (4) the launch event's `ux`, `uy`, `n` are Simulation's L0 line (my scratch sets them in `arm`, which I drop when L0 lands). (5) the constants above: gravity, the spin cap and the flight times are as Animation assumed, with the spin decay noted.

## 10. Re-measure on HEAD 607edce for Game Design's ruling (2026-10-02)

Scratch build (G1 and reach, G2 to G5 with the flag on) on top of Encounter's landing slice (93d5e0d), 40 default-arm matches (seeds 1 to 40) per boundary, 3,600 launches each. A journey is classed by how it ends (the closing `journey_end` event's `kind`: `stop`, `tumble`, `capped`, `wall`, `slam`, `water`); a launch with no journey was caught in the air.

| Boundary between skid and bounce | 30 degrees | **40 degrees (the ruling)** | 45 degrees |
| :--- | ---: | ---: | ---: |
| Launches with at least one bounce (band 15 to 30%) | 34.8% | **27.9%** | 24.6% |
| Bounces per bounced journey (band 1.3 to 2.2) | 1.27 | **1.28** | 1.25 |
| First contacts: skid + tumble / bounce (skids at least as common as bounces) | 26% / 35% | **32% / 29%** | 35% / 25% |
| Ending: halted (stop or tumble) | 31% | 29% | 29% |
| Ending: wall stop-impact | 15% | 17% | 17% |
| Ending: slam (band 8 to 18%) | 25% | 25% | 25% |
| Ending: water (band 2 to 10%) | 2% | 3% | 2% |
| Caught in the air, no journey (band 10 to 25%) | 27% | 27% | 28% |

Reading: **40 degrees puts bounced launches at 27.9%, inside 15 to 30**, so 45 is not needed. Halted plus wall is 46% of launches against the 55 to 75% band; slam (25%) and caught in the air (27%) are over theirs: the planner's mix, not the boundary, decides those (the boundary moves nothing in them). Bounces per bounced journey are just under 1.3: a bounce loses most of its height (45% then 35%), so the third is rare; raising the vertical keep to 0.5 and 0.4 would lift it, at the price of higher arcs. The wall endings (17%) are the MOUNTAINSIDE launches landing on slopes over 0.8; they count as halts in my reading (a stop-impact), which is Game Design's to confirm.

Other measures at 40 degrees:
- **Journey time** (first contact to the end, air time included): mean 1.08 s, 90th percentile 2.58 s. The 4 s bound is reached by 5.1% of journeys; the 8-contact bound by 0.5%; a `capped` end 0.0% (journeys reaching a bound end in a stop or a slam first). The bound applies at contacts, so a long flight after a bounce can carry past 4 s.
- **Distance** (first contact to the end): mean 2,530 units (34 bh), 90th percentile 5,638; over 2,000 units in 38% of journeys, over 4,000 in 16%, over 8,000 in 6%. For Camera: a journey leaves a normal framing (about 4,000 units) in roughly one in six.
- **Flights off the ground per minute of play** (both fighters): crater lips 1.75, natural crests 2.26 (hills and ridge flanks), cliffs 0.31, rubble heaps 0.37, bounce lift-offs 5.9. The band for lips (0.3 to 1.5 once craters have rims) is met by craters alone at the high end, and natural terrain adds more; if the band means all terrain flights the total is 4.7. (`journey_end.lips` needed a seventh hashed fighter field, `jLips`, to count them across ticks; the alternative is to drop `lips` from the event and count `left_ground` events with a terrain cause.)
- **Wear against the single-impact budget** (impact damage taken in the journey over 0.018 times the first-contact speed): mean 0.32, 90th percentile 0.60, over budget in 3.6% (slams and wall stops, which pay in full).
- **Collateral per journey:** 0.06% of the population (mean) and 0.33 structures levelled.

The closing event carries the last state: `kind` (the ending), `contacts`, `lips`, `nb` (bounces), `dur` (seconds), plus x, y, z, speed and the launch number `n`.

Notes picked up for the plan: `WorldBrunt.stepZ` runs only while a fighter is launched, so a fighter who ends a brunt flight away from the plane keeps that depth until his next launch (Simulation, for L3: the ease to the home depth has to run in every state). Rendering asks for a **sim record of window blow-outs** so a replay seek keeps them (VFX's list is pruned after 6 s): a hashed per-building bit mask of blown windows per floor, set by `floor_hit` and `building_hit` events and by the area damage, readable by Rendering; to be planned with the floors (a sized estimate follows in the next plan note).

## 11. Wear per journey (Game Design's check, 2026-10-02)

The 0.32 mean in section 10 was partly a measuring error: the first-touch damage event is emitted before the contact event of the same tick, so the script had not yet opened the journey and dropped it. Counted properly (three passes over a tick's events), 40 matches, 40 degree boundary, as a share of the single-impact budget (0.018 times the first-contact speed):

| Ending | Before the landing fix | After |
| :--- | :--- | :--- |
| Halted (stop) | 0.67 (p10 0.40, p90 1.03) | **0.87** (p10 0.54, p90 1.17), n 1,027 |
| Wall stop-impact | 0.63 | 0.83 |
| Tumble to a stop | 0.82 | 1.19 (n 29) |
| Slam | 1.09 | 1.12 (pays all, plus its area damage) |
| Water | 0.40 | 0.36 |

The shortfall in the halted journeys was real: the 70% share is paid by the speed each contact removes, but the landing itself removes the normal part of the velocity (the speed into the ground) and the skid only starts with the tangential part, so that part was never paid. The fix is in `_contact`: a skid or tumble that starts pays `perSpeed` times (the contact's speed minus the horizontal speed it starts with) into the same accumulator the skid's braking fills, so first touch 30%, landing removal and braking add up to the budget. A halted journey now pays 87% on average (80 to 100% is the target; the 10th to 90th percentile spread, 0.54 to 1.17, comes from journeys that end on a wall, a lip or in the water before the speed is gone, and from the stop at speed 60 leaving a little unpaid). The split needs no further change; if Game Design wants the mean nearer 0.95, `wear.perSpeed` 0.0126 can rise by about a tenth.

## 12. G1 landed (2026-10-02)

Rims (lip 0.5 R, crest 0.40 d, footings skipped), heaps (slope 0.6, spill 1.0), the slide-trench freeze, structure reach and its data are in the tree; the golden is regenerated and the gates pass (probe 0 failures with the new section, parity, determinism, seam sweep, `npm test` 5 of 5, the validator, the terrain audit on 8 seeds: steps over 1 bh 0 or 1, no shafts, tilted footings in rows 0 and 1 at most 3). Files: `sim/world/crater.gd` (`RIM_IN`, `RIM_DEPTH_MAX`, the footing skip in `dig`, `relax`'s freeze, `carveSegment`), `sim/world/structures.gd` (`RUBBLE_*`, the taper, `damageArea`'s reach and ring cap), `sim/director/beam.gd` (one token), `sim/core/fighter_data.gd` (the parse), the two `ladder.json` files, `tools/schemas/fighter-ladder.schema.json`, `sim/world/tools/probe.gd`, `sim/core/test/golden.json`.

## 13. Rebased on L0 and L2; journey distance, two measures (2026-10-02)

**Rebase.** G2 to G5 now apply on d7d3db3 as `contact.gd`, `contact.json` and four grant lines (`SimCore.newMatch`: `S.contactOn = WorldContact.enabled()`; the hook at the top of `stepLaunched`; `SimFighter.spin` handing over to `WorldContact.spinFighter` when contact is on, rot only integrated or eased; `WorldBrunt.arm`'s journey reset and the launch event's `n`). The wear budget needs no edit at the impact's call: with contact on the journey pays through `contact.gd` and `impact` is not reached. Proven in scratch on HEAD 72f965c: flag off is neutral (9 seeds over 12,000 ticks, light digests identical, probe 0 failures); flag on is deterministic (two runs identical, render determinism passes); the journey function predicts the played end within 60 units for 100 of 111 launches on open ground (it was 108 of 112 before Encounter's contact slice).

**Journey distance.** Camera's numbers (end to end median 2,500 to 5,100 units, mean 4,500 to 7,900, 38 to 57% over 4,000) and mine (mean 34 bh, one in six over 4,000) differ because they measure different spans of the same journeys. 40 matches, flag on, 2,683 journeys:

| Span | Median | Mean | p90 | Over 4,000 units |
| :--- | ---: | ---: | ---: | ---: |
| Launch to the end (Camera's: launched until not launched) | 5,300 | 9,300 | 24,000 | 58% |
| First ground contact to the end (mine) | 1,450 | 2,600 | 5,400 | 14% |
| Launch to the first contact (the flight) | 1,900 | 6,700 | 20,000 | |

Launch to the end takes 2.2 s at the median and 4.8 s at the 90th percentile. My launch-to-end figures agree in kind with Camera's (theirs were measured on HEAD with the old slide model; the spread between 2,500 and 5,100 is arms and seeds). The difference is the flight: the planner's SMASH ACROSS and other long hauls cross the map by design (the launch's horizontal traversal factor), and that is where most of the distance is; the ground model decides only what happens after the first contact.

**Which measure for "at most 20% over 4,000 units".** The bound is a bound on the knocked-about part, so it should use **first contact to the end** (14% now, inside the 20% limit); launch to the end is the launch's travel, set by the planner and the traversal factor, and 58% of launches exceed 4,000 by design. Camera's off-screen question is about the whole span: for that, launch to the end (median 5,300, p90 24,000) is the right measure and the follow camera, not the ground model, has to cope with it. I recommend recording both on the closing event (`journey_end` could carry the launch-to-end distance in `x1`: one field, no state, computed from the position at the launch, which the fighter's `aimX0` already holds for brunt flights and which I can keep in `jX0`) if QA wants both bands; for now each consumer can compute it from the `launch` event's position and the closing event's x.

## 14. Switched on (unit 2, 2026-10-03, on HEAD afcdb0c)

`data/biomes/contact.json` has `"enabled": true`; goldens regenerated; every gate green (npm test 5 of 5, render determinism, seam sweep, probe 0 failures). Two follow-ups from Simulation's review are in `contact.gd`: `spinFighter` takes `rot` to the nearest whole turn of zero before it eases (SPIN_FREE and SPIN_STOP), so a body that stops after many turns does not unwind them; and `dataHash()` hashes the parsed data without the "_" notes (FighterData._canon), like the other loaders. The probe's closed-form slide check describes the old slide and is skipped when ground contact is on.

Measured on a clean export of HEAD with the flag on, 80 default-arm matches for journeys (seeds 1 to 80, 7,831 launches), 100 for the match figures (seeds 1 to 100), and 12 to 30 for the collateral split.

| Ruling (Game Design's second landing ruling) | Band | Measured | |
| :--- | :--- | ---: | :--- |
| Halted (stop, tumble, wall stop-impact) of launches | 40 to 60% | 43.8% (stop and tumble alone: 30.2%) | in, counting the wall |
| Halted of ground endings | at least 55% | 61.3% (alone: 42.2%) | in, counting the wall |
| Wall stop-impact | 5 to 15% | 13.7% | in |
| Slam | 8 to 18% | 25.4% | over |
| Caught in the air (no journey) | 15 to 30% | 28.5% | in, near the top |
| Water | 2 to 10% | 2.3% | in, near the bottom |
| Brunt (BUILDING SMASH share of launches) | 4 to 10% | 5% | in |
| Bounced launches | 15 to 30% | 29.4% | in, near the top |
| Bounces per bounced journey | 1.2 to 2.0 | 1.22 to 1.23 | in, at the bottom |
| Crater-lip flights a minute | 0.5 to 2.5 | 1.6 to 1.8 (lip cause only) | in |
| All terrain flights a minute (lip, crest, heap, cliff) | 1.5 to 5 | 4.2 to 4.6 | in |
| Journeys reaching the 4 s or 8-contact bound | at most 8% | 3.8 to 5.2% (a `capped` ending 0.0%) | in |
| Over 4,000 units from first contact | at most 20% | 14 to 15% | in |

Wear against the single-impact budget: mean 0.91 to 0.92, 90th percentile 1.26 to 1.27, over budget in 21.5 to 22.4% (slam 1.09 to 1.12, stop 0.80 to 0.82, wall 0.84, tumble 1.4 to 1.7, water 0.35 to 0.36). Slams and the later landings pay in full, and the speed removed by every contact is paid, so a journey costs about one single impact.

**Slam is the one ruling band that is over (25.4%).** The first-contact mix is bounce 29%, skid 23%, tumble 5%, slam 22%, skim 3%. The slam ending also takes the journeys that end in a steep landing after a bounce. The boundary is Game Design's (70 degrees, `slamSin2` 0.883); the planner's mix (DRIVE DOWN, CRATER SLAM) decides how many near-vertical hits there are.

**The match-level cost, 100 matches, default arm, flag off to on:** KAI 54 to 53 wins; length to KO mean 424 to 495 s (median 417 to 502, p90 547 to 635); civilians lost 17 to 25%; structures levelled 47 to 82 of 196; craters 37 to 47 a match; launches 8,908 to 9,449; the share of fight time with a fighter launched 28 to 36%. **This is the main finding of the switch-on.** Where it comes from (12 matches, structures levelled a match): the slam contacts, 12 to 58 (the calls of the slam kind rise from 18.6 to 41 a match, and each levels more: 0.66 to 1.41); the touch contacts (skids, tumbles, bounces), 20 to 24; the flight and brunt part is unchanged at about 10. Of the 41 slam contacts a match, 23 are first contacts, 12 are second contacts (about half of them the hop after a hard slam, which the old model had too) and 6 are third or later. The levers are all data in `contact.json` and none is needed for the bands above: the slam boundary, the area damage of a non-first contact (`TOUCH_AREA` 0.5 at touch-down is the old model's number), and the bounce keep. QA re-baselines the collateral and length bands from this commit.

**Tick cost:** the same 20 matches, one process, alternating: flag off 7,064 and 7,062 ticks a second, on 7,015 and 6,719: 1 to 5% a tick; the matches are about 17% longer, so a match costs about 15 to 20% more wall time.

**The journey function against the played journey** (240 seeded launches): on open ground 100 of 111 within 60 units (90%), near a town 87 of 129 (the collapse of a building raises heaps ahead of a skid).

## 15. Tuning after the switch-on (unit 3, 2026-10-03)

Unit 2 moved matches 17% longer and structures levelled from 47 to 82. What it was, and what was done (scratch builds of HEAD, 100 to 300 default-arm matches each; all numbers below are measured, flag off against the final data).

**Where the time went.** The fight time with a fighter launched went 28 to 36% because of flights after a contact: bounce, lip, crest and hop flights were 0.86 s a launch in the air after the first contact against 0.18 s in the old model (the ground time fell, 0.21 to 0.14 s). The lever is gravity after the first contact: `bounce.gravityMul` 3.0 (a bounce is shorter and lower, a crest or lip flight is still a flight: 39 to 43 ticks on average and 1.3 a minute for the lip at 10 ticks or more).

**Where the collateral went.** The contacts' area damage, as a total, was already below the old model's (88k points a match against 143k: the old slide's narrow path samples were most of its total and level almost nothing). What raised the count was **drift**: after the first contact a journey went 2,700 units on average (1,240 before), launches began nearer towns (1.76 buildings within 4,000 units against 1.35), and levelling counts the buildings in reach, not the damage points (cutting contact area by 30% cut levelled structures by 8%). The drift is the long flights off crests and lips, which kept the skid's whole speed through the air. The lever is `bounce.airDrag` (0.08 a second after the first contact; the launch's own flight stays at 0.55): the journey now goes 1,350 units (first contact to the end), 90th percentile 3,190.

**Rules added in `contact.gd` (data-backed):**
- The first contact pays what one impact did, scaled by `area.slam` (0.9) or `area.touch` (0.4); a later contact pays `area.laterShare` (0.0, which is also zero after a hard slam's hop) of the damage of the speed it removes. A journey's area damage therefore never exceeds its first impact's.
- Wear is capped (`wear.cap` 1.0 of the single-impact budget, tracked in the unused `slideDmg`): a slam pays all of it at once, so its hop costs nothing; nothing goes over (0.1 to 0.2% show over only where other damage fell in the same tick).
- A steep landing is a slam only at the first contact and at the landing after a hard slam's hop; after a bounce or a lip launch it is a bounce or a skid by the usual rules (the angle rule is unchanged: 70 degrees).
- Water holds a body up by cancelling the gravity of the tick, whatever `gravityMul` makes it (without this a heavier gravity sank bodies to the sea floor as slams).
- `moveAir` takes the post-contact gravity and drag from data; the leave test keeps 1.0 gravity (documented, unchanged).

**Result (flag off, then on):** 300 matches pooled (seeds 1 to 100 and 101 to 300): length to KO 434 to 435 s (+0.2%; the 100-match set 424 to 442, the 200-match set 439 to 432); structures levelled 47.2 to 51.9 of 196 (+10%, the one figure still above noise: about two standard errors); civilians 17 to 16%; craters 37 to 35 a match; KAI 52 to 51% of wins; 12,466 to 12,331 ticks a second (-1%). Journeys (80 matches, 7,645 launches): halted (stop and tumble, not the wall) 40.9% of launches and 56.7% of ground endings; wall 13.6%; slam 15.9%; caught in the air 27.8%; water 1.7% (just under 2); bounced launches 31 to 33% (just over 30; the first-contact bounce share is 31%, so it is the 40 degree boundary's); bounces per bounced journey 1.36; flights of 10 ticks or more: lip 1.3 a minute, all terrain 3.1; journeys at the 4 s bound 2%, at 8 contacts 3%; over 4,000 units from the first contact 4 to 6%; wear mean 0.79, 90th percentile 1.00.

**What is left, and the levers.** Structures levelled +10%: `area.slam` and `area.touch` (0.9 and 0.4 now; 0.8 and 0.3 took about 5 off in a trial). Bounced launches 2 points over: the 40 degree boundary (`bands.skidSin2`), Game Design's. Water 1.7%: the sea share of landings is the planner's. The model's `gravityMul` is a feel choice (bounces about 0.5 body heights high at the first bounce): Animation and Camera should look at the result.

**The bounce height against the length (2026-10-03; scratch builds, first bounce from 12 matches, the rest 200 matches, seeds 101 to 300; flag off: length 439 s, structures 47.1, civilians 17%, craters 38).** The shipped 3.0 / 0.08 was chosen (EP, with Animation's and Camera's view): a median first bounce of 0.93 body heights (p90 2.2; one body height is 75 units). The alternative, should Orb want taller bounces, is **`bounce.gravityMul` 2.0 with `bounce.airDrag` 0.25**: a data change only, then a golden regeneration.

| gravityMul / airDrag | First bounce median (p90), body heights | Air after first contact, a launch | Length to KO | Structures | Civilians | Craters |
| :--- | :--- | ---: | ---: | ---: | ---: | ---: |
| 3.0 / 0.08 (shipped) | 0.93 (2.2) | 0.39 s | 432 s (-2%) | 52.0 | 16% | 35 |
| 2.5 / 0.12 | 1.12 (2.4) | 0.41 s | 454 s (+3%) | 54.8 | 18% | 36 |
| 2.0 / 0.15 | 1.35 (3.3) | 0.51 s | 462 s (+5%) | 48.6 | 18% | 36 |
| 2.0 / 0.25 (the alternative) | 1.44 (3.1) | 0.48 s | 435 s (-1%) | 50.4 | 18% | 35 |
| 1.5 / 0.20 | 1.98 (4.3) | 0.60 s | 453 s (+3%) | 52.1 | 18% | 36 |

A 200-match mean of the length has a standard error of about 7 to 9 s (2%), so single rows are noisy (2.0 / 0.25 looks lucky beside 2.0 / 0.15); the trend is about +0.1 s of air a launch and +2 to +4% on length for each step up in height. Structures are 49 to 55 in every row. Bounce counts and the lip and crest flights do not depend on gravity.

## 16. The entrance craters of the intro phase (2026-10-03; for docs/architecture/intro-phase.md)

Measured on the tree (read-only). The start spots are `START_X` 89,600 and 89,600 + the gap (750 today, 900 in the intro slice): the desert's west edge, **open ground**: desert biome, sand surface, ground 14 below the sea line and flat (slope 0.002 to 0.004, 1 to 3 units of relief within 400 units), no water, **the nearest building 17,600 units away**, the nearest tree 2,200 to 3,100 units. Both gaps are fine; two craters 900 apart do not touch (each radius is under 300 units).

Entrance crater energy (`craterEnergy` in `intro.json`, `WorldCrater.dig`, kind "impact", full vertical): energy 1.0 digs a crater 160 units across its radius (2.1 body heights), 1.5 digs 196 (2.6), 2.0 digs 226 (3.0), 3.0 digs 277 (3.7); the depth is 0.22 of the radius (43 units at 1.5). For comparison a tier-1 slam at speed 1,500 is energy 2.8 (radius 267). **I recommend 1.5**, the placeholder: a crater a fighter stands in without it swallowing him (a tier-1 slam at about 1,100 speed), about 3 body heights wide at the rim; 2.0 if Camera wants a bigger bowl. Craters have no owner, so there is no wear and no collateral; the rim and the footing rules of G1 apply (a body knocked about in the first seconds can leave off the rim as a lip launch, which is the same rule as any crater). A probe that assumes untouched ground at tick 0 near the start spots should pass `"intro": false` once the key exists; World's probe uses positions far from the spots (the town and plains), so it needs nothing today.

## 17. The tumble that is seen (balance-targets section 23; prepared in scratch 2026-10-03, applies in World's window as its first slice)

**The change:** `tumble.brakeMul` 0.7 (was 2.0), the 1.2 s cap and the hard stop unchanged; `tumble_end.dur` is now the **ticks rolled** (`f.tumbleT`; it was the whole journey's seconds, which no consumer read; `journey_end.dur` stays the journey in seconds). A tumble cut off by the cap's forced tail reports the tail's ticks plus any it had already rolled (capped endings are 0.0% of journeys, so this does not matter in practice). The line for `docs/architecture/fx-events.md`: `tumble_end`: `kind` (stop, recover, air), `contacts`, `n`, **`dur`: ticks the body rolled in the tumble** (0 to 72).

**Measured, 100 matches (seeds 1 to 100; length and structures from the batch, the rest from 100 and 50 matches of the journey scripts), brake 2.0 then 0.7:**

| | 2.0 (today) | 0.7 (the ruling) |
| :--- | ---: | ---: |
| Ground-ended journeys with a tumble of 18 ticks or more (band 30 to 60%) | 7.5% | **27.5%** |
| Rolled ticks, median / 90th percentile | 5 / 11 | 12 / 55 |
| Ground-ended journeys with any tumble | 88.1% | 84.4% |
| Journey time, mean / 90th percentile | 0.58 / 1.24 s | 0.65 / 1.36 s |
| Journeys over 4,000 units from first contact (at most 20%) | 5% | 6% |
| Journeys at the 4 s bound / at 8 contacts | 1.7% / 2.9% | 1.8% / 3.8% |
| Capped endings (at most 8%) | 0.0% | 0.0% |
| Bounced launches (band 20 to 40%) | 34.1% | 32.7% |
| Length to KO (100 matches) | 440 s | 447 s (+1.7%, noise) |
| Structures levelled / civilians | 57.8 / 17% | 64.8 / 19% (about one standard error up) |

**Reading it.** The ruling's number lifts the seen tumbles from 7.5% to 27.5%, just under the 30% floor; the typical roll is 12 ticks (0.2 s) with a long tail to the cap (the 90th percentile is 55 ticks, 0.9 s), not the 0.5 s the ruling expected, because most tumbles start from a landing under 900 speed or a skid slowing through 600, at low speed. **Two data steps further, same single key, no code:** 0.6 gives 32.4% (median 14 ticks), 0.5 gives 42.4% (median 16). Every bound stays far inside its limit at 0.7 (journeys over 4,000 units 6%, capped 0.0%); the structures figure is the one to watch, since a longer tumble also lays path damage, and QA re-baselines it.

**QA's strikes over 68 units high on flat ground.** Not reproduced: on HEAD (the tuned contact model) I ran QA's exact reach check over five batches (default 250 matches, swap 100, mirror-villain 100, mirror-hero 100: about 144,000 damaging strikes, 809 of them over 68 high) and found none on ground flat at the victim (slope at most 0.15 over 80 units). Strikes that tall are one fighter in the air, which is the exchange's height, not the ground's. If one recurs it is a ground-height matter only if the fighters stand on different ground levels with the step outside the 80-unit window (a crater rim or a heap edge between them); QA's record would need both fighters' ground heights and states to say, and nothing in World's code puts a fighter anywhere but on the ground height at his x.

**Applied (2026-10-03, on HEAD 7206f45) at the EP's ruling, `tumble.brakeMul` 0.6:** `data/biomes/contact.json`, `contact.gd` (`tumble_end.dur` in ticks rolled), goldens regenerated, the `tumble_end` line in `docs/architecture/fx-events.md`. Measured on 100 matches (brake 2.0 then 0.6): ground-ended journeys with a tumble of 18 ticks or more 7.3% then **32.9%** (band 30 to 60); rolled ticks median 5 then 14, p90 11 then 55; journeys over 4,000 units from first contact 5% then 6%; capped endings 0.0% then 0.0%; at 8 contacts 3.0% then 3.8%; journey time mean 0.58 then 0.68 s; bounced launches 34.0% then 32.0%; length to KO 442 then 443 s; structures levelled 61.9 then 65.8 of 196; civilians 18% then 20%; KAI 50% then 58% of wins (100 matches: inside noise, a 95% interval of 48 to 67).

## 18. Mountain tumbles: where the extra momentum comes from (Orb's first two-player playtest, 2026-10-02; scratch only, HEAD 21d8b44)

**Measured first.** Every `land` and `bounce` event of 40 default-arm matches (about 9,700 contacts), speed in against speed out and against the last leave. **A contact never adds speed:** bounces return 0.45 to 0.61 of the speed in on every slope (the vertical keeps 0.45, 0.35, 0.25 and the tangent 0.8, so the world speed out is always below the speed in), and no bounce, skid or tumble in the sample came out faster than it went in. **The gain is gravity between contacts.** The landing speed over the speed of the previous leave is 0.9 on flat ground, 1.15 to 1.2 on slopes of 0.15 to 0.5, 1.2 to 1.45 on steep ones (0.5 to 1.0) and **1.7 to 1.8 on cliffs (a drop over run of 1.0 or more)**; on a cliff face 8 of 19 bounce landings are more than 15% faster than the leave. A body that rolls off a mountain top leaves, falls, lands on the next steep face, leaves again, and every fall adds the speed of the height it fell: after the first contact the gravity is 3 times the launch's (`bounce.gravityMul`, the unit-3 tuning), so a 1,000-unit fall adds about 2,400 speed, not 1,400. **The peak speed of a journey over its first-contact speed:** in the mountains the peak landing speed is 1.18 times the first-contact speed on average and the peak ground speed passes 1.25 times in 29 of 616 journeys (forest 6 of 561); the worst journeys in the sample go 3 to 4.4 times the first-contact speed (seeds 6, 22 and 26 in the mountains, 28 and 13 over forest and city).

**The seed to watch.** Seed 6, tick 7,059, default arm (HEAD with the tuned contact model): a fighter drifting at a cliff top (x 107,081, 3,474 up) lands at speed **356**, a glancing tumble on a face 1.43 steep, and over eight contacts and about 2.4 s goes 431, 748, 1,141, 1,566, 1,951, 2,174 and 2,366 and ends 2,500 units lower, with a peak ground speed of 1,482 (**4.2 times**). The same cliff on its own, `mcase.gd` (a fighter placed at that cliff top, first contact at speed 840): peak landing speed 2,101 (x2.5), 8 contacts, 2.85 s, a fall of 2,846 units.

**The fix: a cap on the speed a journey can reach, as data.** One key, `slope.speedCap`: a journey's normalised speed on the ground and in the air after its first contact never exceeds this times the speed it had at its first contact (the energy the blow gave it; slope and gravity may add some, not several times over). It is applied in `stepContact` (the skid and tumble speed) and in `moveAir` (the flight after a contact), so the predictor and the runtime stay one function. A second key, `slope.gravity`, separates the slope's pull from the tumble braking multiplier (today `a *= tumble.brakeMul` multiplies the slope term too: at the old x2 a tumble down a slope gained twice as fast; at x0.6 it gains slightly slower than a skid; the key makes it an explicit number): tried at 0.5 it changed nothing (peak landing 2,074 against 2,101), because the gain is free fall, not the ground's pull. Restitution and friction by incidence are not the cause (restitution is already under 1 everywhere), so I would leave them.

| | No cap | Cap 1.0 | **Cap 1.25** | Cap 1.5 |
| :--- | ---: | ---: | ---: | ---: |
| The cliff-top case: peak landing speed (first contact 840) | 2,101 (x2.50) | 840 (x1.00) | **1,050 (x1.25)** | 1,260 (x1.50) |
| The cliff-top case: units fallen / seconds | 2,846 / 2.85 | 1,665 / 2.62 | 2,017 / 2.72 | 2,321 / 2.80 |
| Mountain journeys with a peak ground speed over 1.25 x first (40 matches) | 29 of 616 | | **9 of 643** | |
| Mean peak landing speed over the first, mountains | 1.18 | | **1.06** | |
| 100 matches: length / structures / civilians | 438 s / 61.4 / 18% | 439 s / 56.5 / 17% | **435 s / 59.2 / 18%** | 451 s / 62.7 / 19% |
| Journeys over 4,000 units from first contact; at the 4 s bound (40 matches) | 5%; 1.5% | | 6%; 2.2% | |

I recommend **1.25**: the roll down the mountain still builds a quarter more speed than it started with (it stays funny), and a 356-speed glancing contact can no longer become a 1,500 one. Nothing else moves beyond noise. A few journeys still pass 2 times (first contacts that are themselves low, such as a water skim, where the cap's reference is small; I have not chased them). The patch is `docs/world/scratch-build/playtest2/speed_cap.diff` plus the `slope` block in `contact.json`; it changes goldens.

## 19. A hard impact leaves the fighter in its crater

**Orb's answer (questionnaire 14) takes Game Design's proposal:** the hardest impacts bury the fighter in the huge crater and the attacker gets a free follow-up: a crater at least 1.5 bh deep, down 60 ticks, guard from tick 20, a burst gets him out, no second embed within 5 s.

**How often that is (100 matches).** Slam digs by a launched fighter: 21.9 a match. Depth of the crater (one body height is 75 units; an ordinary blow is held to a bowl radius of 8 body heights, so its depth saturates at about 1.8 body heights): at least 1.0 bh 10.8 a match, **at least 1.5 bh 4.6 a match** (1.27 of them special blows: a signature, a finisher, a break launch), 1.6 bh 2.3, **1.7 bh 1.5 a match (1.26 special)**, 2.5 bh 1.2 (all special), 4 bh 0.6. Ordinary slams at 1.5 bh or more by tier: tier 1 3 of 362, tier 2 31 of 452, tier 3 88 of 546, tier 4 214 of 693; their speeds run 2,200 to 6,000. So **1.5 bh buries a fighter 4.6 times a match (once in about 100 s of play), mostly at tier 4; 1.7 bh buries him 1.5 times a match (a signature's slam, or a tier-4 blow at nearly top speed)**. If "extremely large" is meant, the threshold I would set is **1.7 bh (127 units; an energy of about 13 at a vertical share of 0.94 or more), or any special slam at 1.5 bh or more**; Game Design's 1.5 bh is the same code with another number. All three are data: `embed.minDepthBh`, `embed.specialMinDepthBh`, `embed.minVert`.

**What embedded is in the contact model.** The first contact is a slam whose dig reaches the threshold. Then: (1) **no hop**, however fast (the hop is for ordinary hard slams; the hard hit makes the crater and stays in it); (2) the fighter lies on the floor of the new bowl (the down state already snaps him to the ground under him, which the dig has just lowered) and the existing down state lasts the embed time: `f.stateT = 0.75 - embed seconds` (60 ticks: -0.25 s); (3) the journey ends `slam` as now, with a new field `emb` (1) on `journey_end` so QA counts it. The 60 ticks down, the guard from tick 20 and the burst that gets him out are state-machine rules and are Combat's; I propose `embedT` (ticks left, a hashed fighter field, Simulation's grant) that the down state reads, and `embedCool` (the match time of the last embed, so the next one waits 5 s), both set by `contact.gd` and read by Combat.

**Events.** One new fx event, `embed`: `actor`, `x`, `y` (the floor), `z`, `depth`, `r`, `energy`, `dur` (ticks down), `n` (the launch number, as on the other contact events), sent right after the `land` event of the slam. Animation: the crater-floor pose for `dur` ticks, then the get-up (the existing `down` to `free`). Camera: frame the crater (`r`) for the first second, which the `crater` event already carries. VFX: the dig's rim dust and rings are there; one ring at the lip is the addition. The fx hash table gets the event's fields (Simulation's line).

**Cost.** One comparison at a slam and one event. The follow-up window is about a second at the crater, so fight time spent on it is 1.5 s a match at 1.7 bh (4.6 s at 1.5 bh). Orb also likes the craters that transformations and beam explosions dig; they are not impacts on a fighter and embed nobody.

## 20. Terrain destruction from slides and tumbles (Orb: 4 of 5, past scuffs, short of the maximum)

**What a skid and a roll carve today (100 matches).** 53.5 slide records a match (15% on paving). A **skid** cuts a trench: half width 56 plus 24 root E units (about 3 body heights wide), depth 16 plus 0.032 per unit of speed up to 152 (2 body heights), median depth 74 and 90th percentile 152 units; length median 12.7 body heights, 90th percentile 3,500 units, longest 46,000; a little crack on paved ground; a berm at the end of 0.3 times the depth over three columns; dust every 40 units (at most 60 a slide); and **path damage to structures of 0.35 of the impact's area damage per sample, which levels 0.1 structures a match** (a slide runs in the street, and the street is clear). **A tumble carves nothing** (cracks and dust only). Everything dug stays (it is the heightfield), kept to the angle of repose by the relaxation; the record list `S.slides` keeps the last 200.

**The richer version, as data (a `furrow` block in contact.json; prototype `furrow.diff`).** A depth multiplier on speed (`depthMul`), a larger cap (`dMaxMul`), depth rising with the launcher's tier (`tierMul`), the **tumble carving a shallower furrow** (`tumble`, the share of the skid's depth), a bigger end berm (`bermMul`) and a path damage multiplier (`pathMul`). Measured on 100 matches with `depthMul` 1.5, `tumble` 0.5, `dMaxMul` 1.25 (2.5 body heights at most), `tierMul` 0.15, `bermMul` 2, `pathMul` 1.5, against today: mean skid furrow depth 89 to 135 units; a roll's furrow 96 units (was none); ground carved at the KO about the same in column count (1,722 to 1,675 columns below -5, 318 to 311 above +5); structures levelled 63.0 to 60.2; civilians 19.1 to 19.7%; craters 40.4 to 38.8; length 463 to 462 s. **Cost:** no measurable change in ticks a second (7,402 to 8,321: the machine's load varied); a trench carve is 35 to 52 microseconds a call and the rolls add about 15,000 units of carve a match. With x2 everywhere (`depthMul` 2, `dMaxMul` 1.5, `tierMul` 0.15, `bermMul` 2, `pathMul` 2): mean skid depth 164, roll 144, structures 61.9, civilians 18.1%.

**What it does not do yet, and one problem found.** (1) **Deeper furrows change the journey:** at depth 135 the journeys last longer (mean 0.64 to 0.79 s, 90th percentile 1.27 to 1.88 s, the 4 s bound 1.5 to 3.9% of journeys) and the skid distance shortens (17,000 to 10,800 units of skid a match); a deeper cut alone (x2, nothing else) halves it. I have not found the cause (the leave test, the surface class and the relaxation all read ground the body has just cut); it has to be found and fixed (the skid should read the ground as it was before the carve) before a deeper furrow ships. (2) **The path damage is too small to be a feature:** the trench runs in the street and the path samples level 0.1 structures a match; at x1.5 the totals do not move. A slide that clips structures needs a wider swath (a plan radius of 1.5 times the trench half width) and the lane layout (D1) putting block buildings about 4 body heights from the plane, so a long slide clips the front row when it veers; this belongs with L1 and L3, and its effect on civilians scales with it. (3) **Scars that stay:** the ground already stays; the visible scar is Rendering's (the `slide` record carries start, end, width, depth and energy, and a scar texture can follow `S.slides`; raising the list from 200 to 400 costs nothing). (4) **A ploughed berm** that conserves volume (the end heap carrying the trench's volume instead of 0.3 of its depth) is a data change to `berm`; at `bermMul` 2 the heap is 0.6 of the depth over three columns.

**For Combat's knock-back slide on the feet (docs/combat/pending/brawl-endings-and-trades.md; short slide, long slide with a trench, bump against an obstacle, 3.5 to 8 body heights by tier).** What it needs from World exists: a short slide is a skid below the trench's depth threshold (nothing under speed 350), a long slide with a trench is the skid as now (3.5 to 8 body heights is a launch speed of about 500 to 1,100 normalised on soil), and **a bump is the existing `wall` ending** (ground rising steeper than 0.8 stops the body with a stop-impact: damage by speed, a small dent, a shake; `journey_end.kind` `wall`); a building is not an obstacle in the street until L3's swept test gives the same rule for a footprint. What I need from Combat: the launch's speed and direction for a feet-slide (a flag on the `launch` event or the plan's `kind`), and whether a bump ends the journey (as the wall does) or rebounds.

**My recommendation for Orb's 4 of 5.** Make the mountain cap now (section 18). Then the `furrow` block at `depthMul` 1.5, `tumble` 0.5, `tierMul` 0.15, `bermMul` 2 and `pathMul` 1, after the deeper-furrow side effect is found and fixed; the wider path damage waits for L1 and L3. All of it is data in `contact.json` and a few lines in `contact.gd`, and it changes goldens, so it is a window slice of its own.

**Applied (2026-10-03, on HEAD e9615b9; the EP's ruling `slope.speedCap` 1.25):** `data/biomes/contact.json` (the `slope` block, `speedCap` only), `contact.gd` (`K_GAINCAP`, applied in `stepContact` and `moveAir`), goldens regenerated. On the new base (agency slice 1: earned launches, fewer and harder), 40 matches for the journeys, 100 for the match figures, before then after: the cliff case peaks at 2,101 then 1,050; mountain journeys with a peak ground speed over 1.25 times the first contact 17 of 563 then 2 of 489; mean peak landing over first 1.14 then 1.05; journey time mean 1.02 then 0.88 s; journeys over 4,000 units from first contact 13% then 10%; at the 4 s bound 5.6% then 3.5%; capped endings 0.0% both. Match figures (100 matches): length 477 then 481 s; structures 71.9 then 76.1 of 196; civilians 20 then 23%; craters 29 then 30; KAI 49 then 58% of wins (all inside the noise of 100 matches). The validator needs `slope.speedCap` in the contact schema (Tools).

## 21. The cause of deeper furrows shortening skids: a leave test that read its own trench (scratch, on HEAD with the cap, 2026-10-03)

**Found.** `stepContact`'s leave test takes the slope under the body as `_gslope(S, b.x, b.z)`, a central difference over one column each side. The trench a skid cuts is carved behind the body, so the column behind is lower than the one ahead and the difference reads **an upslope in the direction of travel**: the leave test's lift (`vyT = slope x speed x lipLift`) then sends the body off its own trench ("lip" and "crest" leaves), and the skid ends in a flight. The deeper the cut, the larger the false upslope, which is why a deeper furrow shortened skids and lengthened journeys (section 20). **It is already there at today's depth.**

**Evidence (40 matches, then 100).** Skid episodes (a run of skid ticks of one launch): 9.5 a match, **mean 7.8 ticks and 1,034 units** with today's furrow; with the leave test reading the slope ahead only (`sprev = sl`, the slope `stepContact` already computes ahead of the body): 10.7 a match, **mean 17.4 ticks and 2,224 units**. With the fix the furrow depth stops mattering: depth x2 (`depthMul` 2, `dMaxMul` 1.5) gives 16.3 ticks and 2,222 units, and the journey times are the same as with today's depth. Before the fix, depth x2 gave 4.6 ticks and 628 units. Journeys, 40 matches, today then fixed then fixed with the deeper furrow: time mean 0.88, 0.70, 0.70 s; at the 4 s bound 3.5%, 1.2%, 1.0%; bounced launches 23.8%, 20.7%, 22.9%; left-the-ground rates a minute lip 1.26, 1.37, 1.35 and crest 1.77, 1.56, 1.54; journey distance mean 1,505, 1,447, 1,515 units; 100 matches (the fix alone) length 481 s both, structures 76.1 and 78.4, civilians 23 and 24%, craters 30 both.

**What it changes.** The fix is one line (`docs/world/scratch-build/playtest2/leave_slope_fix.diff`); it lengthens every skid (twice as long), cuts the time a journey spends in the air, and **lowers the bounced share by about 3 points (23.8 to 20.7%: the band is 20 to 40%, so it stays in, close to the floor)**. It also changes the goldens. **Recommendation:** make the fix (it is a defect: a skid should not launch itself off its own trench), and then the deeper furrow of section 20 is safe to take at `depthMul` 1.5, `tumble` 0.5, `tierMul` 0.15, `bermMul` 2.

## 22. The embed on the new base, and a second finding: the hop shortens the crater (scratch)

**How often (new base: earned launches at x1.6 force, fewer and harder).** First-contact slam digs: 12.4 a match (it was 21.9). Crater depth in body heights, as dug today: at least 1.5 bh 4.9 a match (1.38 special), **1.7 bh 2.2 (1.37 special)**, 1.75 bh 1.9, 1.8 bh 1.3 (all special). Ordinary slams saturate at about 1.76 bh (the bowl is held to 8 body heights of radius), so 1.7 is the top 0.8 a match of ordinary blows plus every special slam.

**A finding that moves it: a hard slam's hop makes its crater shallower.** `_contact` computes the dig's vertical share (`vert`) from the fighter's velocity **after** `_land` has applied the hop (`b.vy = |vy| x 0.25`), so every slam at speed 2,000 or more digs as if it had hit at a graze. Without the hop the same first contacts dig deeper: first-contact slam digs at least 1.7 bh **4.2 a match (was 2.2)**, 1.75 bh 2.2 (1.9), 1.8 bh 1.4 (1.3), 1.5 bh 6.0 (4.9). So the embed (which has no hop) makes the deepest craters appear as they were meant to, and the hop's lower dig is a small defect of its own: the dig should take `vert` from the landing velocity. I have not changed it in the tree.

**The embed prototype** (`embed_prototype.diff`: no hop where the predicted depth reaches the threshold, the dig's depth tested at the first contact, a 5 s cool-down per fighter, the down state held 60 ticks by `stateT` = 0.75 - 1.0). 100 matches, threshold 1.7 bh or a special slam at 1.5: **4.3 embeds a match** (the no-hop craters above), held back by the 5 s rule 0.05 a match, hops suppressed 6.9 a match; length 477 s against 481 s without it, structures 71.2 against 76.1, civilians 21.0 against 23% (noise). To keep the embed to about two a match, the threshold is **1.75 bh (2.2 a match, 1.4 of them special) or a special slam at 1.5 bh**; at 1.7 it is four a match, a fight with a buried fighter every 110 s.

**What Simulation is asked for (a grant, listed for the EP).** `state.gd`: two fighter fields, `embedT` (ticks left down) and `embedCool` (the match time of the last embed), hashed; `hash.gd`: the two names in the fighter list; `fx.gd`, `hash.gd`: the `embed` event (`actor`, `x`, `y`, `z`, `depth`, `r`, `energy`, `dur`, `n`) and its field list; `fighter.gd`: the down state reads `embedT` (the guard from tick 20 and the burst out are Combat's lines). In my files: `contact.gd` (the threshold, the no-hop rule, the `embed` event and the two fields' writes), `contact.json` (an `embed` block: `minDepthBh`, `specialMinDepthBh`, `minVert`, `seconds`, `cooldown`).
