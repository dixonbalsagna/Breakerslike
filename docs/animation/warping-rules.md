# Warping rules

Owner: Animation. Status: rules plus what A1 runs, 2026-09-30. How one key set serves many contexts without changing a timing: the approach at any duration and distance, a blow at any standoff, a launch in any direction, and a planted foot on any slope, across the seam. **Every constant is the prototype's (`move-grammar.md`, `prototype/index.html` at 7233c96) and provisional until Combat's live data and moveset system settle it; the rules are written on phase and duration, not on those constants, so they survive a change.** The plan is `pose-pipeline.md` §4; the atoms are `clip-list.md`.

The rule that governs all of it: **the sim moves fighters; animation moves the skeleton under them.** Warping here means fitting a pose to a time or a place the sim already fixed. It never moves a fighter, an anchor tick or a contact time.

---

## 1. The approach: one entry, any duration, any distance

The sim's `rush` covers `dist` in `rt = clamp(dist/2600, 0.18, 0.65)` s (11 to 39 ticks), stopping 58 u short of the target, and tracks it live. Animation sees a duration `d` (ticks) and a phase `p = elapsed / d`. It never sees the distance, so any distance works.

| Phase | Range of `p` | Pose | Curve |
| :--- | :--- | :--- | :--- |
| Launch-off | `0` to `min(4 ticks, 25% of d) / d` | `approach.launch` (a coil), fading out | linear out |
| Flight | the middle | `move.dash`, pitched to the velocity (`atan2(vy, max(abs(vx), 60))`, clamped ±0.9 rad, times 0.7) | eased in over `0.18`, out from `0.78` |
| Arrival | `0.78` to `1.0` | blends toward the base, where the next strike's load takes over | ease out, complete on the arrival tick |

| Case | `d` | Launch-off | Flight | Arrival | What holds |
| :--- | ---: | ---: | ---: | ---: | :--- |
| Minimum (`dist` under 468 u) | 11 ticks | 3 ticks | 5 | 3 | The load of the first strike may overlap the arrival: the fit shortens the load, never the contact |
| Typical | 24 ticks | 4 | 15 | 5 | |
| Maximum (`dist` over 1,690 u) | 39 ticks | 4 | 27 | 8 | The flight pose holds longer; nothing stretches |
| Chain link (`rush.chain`) | 14 ticks | 3 | 7 | 4 | Followed by one heavy strike |
| Pursuit (`rush.far`, `0.8 rt`) | 9 to 31 ticks | as above | | no brace | Ends open-handed |

**Any distance.** At 7,400 u/s across half the planet the fighter is a streak; the pose is unchanged, the afterimage and camera do the speed (VFX, Camera). A speed above a threshold may add the stream pose's lean (planned).

**The arrival tick is the sim's.** The `rush` event carries it (`n`); the arrival pose is complete on it, and the first strike's load begins from the arrival pose.

## 2. A blow at any standoff: the reach fit

The sim places the attacker 58 u short of the defender (60 u for a chain link, 74 u behind the attacker after a dodge warp) and every blow connects on its beat: the prototype has no hit volumes. So the fist must meet the defender's body wherever the fighters stand.

| Layer | What it does | A1 |
| :--- | :--- | :--- |
| Authored lunge | The contact pose puts the pelvis forward and leans, so the striking end lands at about 51 to 59 u from the attacker's root | **Built** (contact poses' hips and hand targets) |
| IK to the socket | The striking hand or foot is solved to the defender's `hit_*` socket for the part's region, at full weight on the contact tick | A2 |
| Reach fudge | A target within 15% of the pose's reach is absorbed by pelvis and spine lunge (a cosmetic root offset of at most 0.3 body height, back to zero by the part's end); beyond 15% the validator rejects the pairing at data time | A2 |
| Runtime fallback | A clamped reach: the hand goes as far as it can and the blow still counts | A2 |

| Standoff | Where it occurs | Fit |
| :--- | :--- | :--- |
| 58 u | every melee template's `rush` | the authored lunge (A1) |
| 60 u | chain links | the same, at the higher lunge weight |
| 74 u behind | the defender after a dodge warp | the attacker turns first (`cue.turn_read`); the counter is the defender's strike at the same 58 to 74 u |
| 180 to 400 u | pursuit and volley approaches | no contact; the pose never reaches a contact key |

The hit height comes from the region (head, core, arms, legs): the key set's height band (three IK heights, ±0.25 body height) picks the target socket.

## 3. Launches: five types, seven vectors

`chooseLaunch` offers UPPERCUT `(0.25 f, 1.0)`, SLAM DOWN `(0.2 f, -1.25)`, SMASH ACROSS `(f, 0.18)`, and BUILDING SMASH and MOUNTAINSIDE, each to either side `(±1, 0.12)` and `(±1, 0.05)`: up to seven candidate vectors. Force is 800 to 2600 times `(1 + 0.16 (tier - 1))`, so speed runs from about 800 u/s to about 4,000 u/s. Spin is the sim's `rot` (`R(8,16)` rad/s), so **animation never adds tumble**: it picks the shape the tumbling body holds.

**The struck body.** One pose family, `tumble`, blended by speed:

| Speed | Blend | Why |
| :--- | :--- | :--- |
| under about 600 u/s | `launch.tuck` weighted 0.7 | a slow launch curls |
| 700 to 2,200 u/s | `launch.spread` into `launch.stream` | faster reads as a stiff streak |
| over 2,200 u/s | `launch.stream` | the maximum case: a rigid line, arms and legs together |

**The striker's follow-through** is what sells the send-off, and it is chosen by the vector (planned; A1 plays the strike's own follow key for all):

| Vector | Striker's follow key | Landing pose |
| :--- | :--- | :--- |
| UPPERCUT `(0.25 f, 1.0)` | rising follow, chest lifting, head up | crumple or slide brake |
| SLAM DOWN `(0.2 f, -1.25)` | overhead hammer, weight dropping (a new key set) | head-down fold into the ground: crater, embed |
| SMASH ACROSS `(f, 0.18)` | a horizontal follow, torso turned through | slide brake |
| BUILDING SMASH `(±1, 0.12)` | horizontal follow toward the building | embed: limbs splayed to the wall normal |
| MOUNTAINSIDE `(±1, 0.05)` | as smash across | embed against the slope |

**SLAM DOWN is the most-played launch** (46.4% of launches at the P0 baseline, `qa/baseline-p0.md`; Combat's composer is meant to cut that), so it needs the most variants: hammer, dive-kick, double-fist, and a body-slam tuck, each with a crater embed and a slide-out landing.

**Minimum and maximum cases.**
- **Minimum:** a launch at 800 u/s into water slows to under 200 u/s and is freed within 0.3 s (`water-catch`): the body enters as `launch.tuck`, the water layer damps it, and it breaches into the base pose.
- **Maximum:** a tier-4 launch at about 4,000 u/s across the map: `launch.stream`, the camera follows (Camera), and the landing pose is chosen from the landing signal (`slide`, `crater`, `building_hit`), not from the launch.

## 4. Feet on the ground: slopes and the seam

The rule is `pose-pipeline.md` §4.8, restated:
- A grounded foot is a **pin in the fighter's local frame, an offset from the root along the shortest arc**, never an absolute x. A fighter crossing the seam changes absolute x by the planet's circumference; an offset does not care, so nothing slides.
- The ground under a foot is the sim's ground height read through the shortest-arc helpers, piecewise linear between terrain columns (32 u at the current world scale, a foot about 19 u wide). The foot's normal is the straddled columns' slope; the pelvis reads a two-column average.
- A pin holds until the pose lifts the foot or the leg would stretch past 100%; then the foot **re-plants** (a step). Ankle limit 35 degrees; pelvis drop at most 0.15 body height; beyond that the foot re-plants on the nearest supporting point (crater rims are the steep case).
- **Allowed slide:** `slide_brake` and a broken leg's drag let the foot travel on purpose.
- **Test A3:** planted-foot drift while pinned at most 0.02 body height, on slopes to 45 degrees and across the seam.

A1 has no foot plant (fighters mostly fly, and the poses set their own feet); it lands in A2 with the ground query.

## 5. Beams

| Beat | Sim time | Animation |
| :--- | :--- | :--- |
| Charge and rise | 0 to 0.8 s (48 ticks); the rise 0.55 s (33) | `beam.charge` weight 0 to 1 over the first 0.35 of it, then held with a tremble |
| Fire | 0.8 s; the front sweeps in 0.22 s; life 0.95 s | `beam.fire` on the beat, held to 0.55 of the beam's life, then relaxed |
| Clash | 1.6 s | Both hold `beam.fire` braced; the loser's pose fails in the last third (planned) |

Both poses are original (RL-038): a closed fist along the shoulder line, the rear forearm braced under the lead elbow; no open palm, no wrist grip.

---

## 6. What these rules fix in the tests

| Rule | Test (`pose-pipeline.md` §10) |
| :--- | :--- |
| Contact on the beat, load and recovery in the gaps | A7 timing fidelity (A1: 164 and 128 contact frames a match, worst error 0.0014 rad) |
| The reach fit | A2 contact accuracy (A2) |
| Feet on slopes and across the seam | A3 (A2) |
| The pose depends on phase and duration only | A8 no pops, and the min and max cases above rendered as filmstrips |
