# Wave 3: the ping-pong rally, its ender and the flight paths

Owner: Combat and Choreography. Date: 2026-10-01. Status: parked specs. Nothing here is loaded or hashed, and no live data changed. The data is `pingpong.antihero.wave3.json` in this folder. Plan: `../m0-rich.md` (wave 3 of ten). Rules: `docs/design/control-rules.md` section 11 and `moveset-rules.md` section 11(b). Choreography: `../blitz.md`.

**What is here.** The rally's beats in ticks; one definition of the three flight paths, for Encounter, Camera and VFX; the `return` strike class; the 7 return blows and 16 enders as they play in a rally; three knock patterns; what the defender's answers look like. One new pose: the intercept turn.

## 1. The rally in ticks
He knocks the rival away, leaves, arrives ahead on a spiral, and knocks the rival back. That repeats 1 to 4 times, and the last return blow is the ender.

| Ticks from the knock | Leaves | Arrives, loaded | Then | Contact |
| :--- | ---: | ---: | :--- | ---: |
| A middle return | 4 | 28 | 6 of anticipation | **34** |
| A middle return, Frenzied | 4 | 22 | 6 of anticipation | **28** |
| The ender | 4 | 28 | 18 of wind-up | **46** |
| The ender, Frenzied | 4 | 22 | 18 of wind-up | **40** |

- **Leaves at 4:** the hit-stop.
- **30 ticks from leaving to a middle contact** (24 in Frenzied), as Game Design set: 24 (18) of travel and the 6 of anticipation, standing loaded.
- **The ender's bounce is 12 ticks longer. This is a proposal for Game Design.** It keeps the same travel and adds its whole 18-tick wind-up in place. Squeezing the wind-up into the 30 would leave 12 ticks of travel, and 6 in Frenzied.
- **Where he arrives.** At the struck body's predicted position on the contact tick, pushed along its direction of travel by the return blow's own contact distance (wave 1). So he waits just beyond where the body arrives, facing it.
- **Speed.** He covers 1.109 times the chord in 24 ticks while the body covers about the chord in 34: about 1.6 times the body's speed, and 1.7 in Frenzied.
- **Costs and limits** (Game Design): 6 ki a bounce and 4 for the ender; a 10 s cooldown; one decisive exchange, decided at the ender; bounces stay in the lane and never pass through buildings; only the ender may be a targeted smash; the turning throw is never a return blow or the ender.

## 2. One definition of the flight paths
Orb asked early on for curving trails and arcing flight, so these shapes serve more than the entries. This section is the one definition: Encounter moves him along it, Camera frames it, VFX draws it. A path is **P(s)**, s from 0 to 1, from **S** (where he is) to **I** (where he must arrive). `d = I - S` by the shortest arc, and `D = |d|`. Nothing in it draws a random number.

**The ease (all shapes).** `s = 1 - (1 - t/T)^2`, with T the flight's ticks: a hard launch-off and a brake into the arrival.

**The spiral** (a quarter turn of a golden spiral, φ = 1.618):
```
pole:  C = S + (d + σ·φ·D·n) / (1 + φ²)
path:  P(s) = C + φ^s · Rot(σ·90°·s) · (S − C)
```
`n` is a unit vector perpendicular to `d` in the path's plane, and σ is +1 or −1. The pole is on `n`'s side for +1, and the curve bulges on the other side.

| Property (lengths in D) | Value |
| :--- | :--- |
| Length | 1.109 |
| Widest distance from the chord | 0.205, at s = 0.54 |
| Leaves S at | 48.7° off the chord |
| Arrives at I at | 41.2° off the chord, from the bulge side |
| The pole | 0.276 along the chord, 0.447 to the side |
| Angle between his heading and the line to the pole | 73° all the way (for the bank and the trail's taper) |
| Radius of the curve | 0.55 at the start, opening to 0.89 |
| Bounds | between the perpendiculars at S and at I, all of it on the side opposite the pole |
| Speed under the ease (D per flight) | 1.73 leaving, 1.24 at half time, 0 on arrival |

- **Which side it bulges.** Away from the struck body's path: the pole goes on the side of the body's mid-flight point. If the body flies within 0.05 D of the chord, flip the side from the last bounce; the first side is one keyed draw.
- **Which plane.** Up, down, or into a neighbouring depth lane (ADR 0009). A depth-lane bulge when the body's path is level; up when within 4 bh of the ground.
- **Clearance.** Sample 8 points: none under the ground plus 0.5 bh, none inside a structure. Otherwise try the other side, another plane, then a shallower turn of 60° (length 1.047, widest 0.133) and 30° (1.012, 0.066). Otherwise there is no intercept: an ordinary pursuit, and the blitz goes to its ender or ends. It never blinks.

**The arc** (the arc dive): `P(s) = S + s·d + 4·h·s·(1 − s)·w`, where `h` is the smaller of 0.25·D and 4 bh (300 u) and `w` is a unit vector perpendicular to `d` in the path's plane, up by default. At h = 0.25·D it is 1.148 D long and leaves at 45°. Past 1,200 u the apex stays 300 u, so the arc flattens.

**The ground path** (the skid): along the ground by the shortest arc, at the terrain's height, a run and then a slide from s = 0.7. It follows the heightfield, so it has no formula.

**The `path` event** (Simulation and Encounter), emitted when the move is planned, before the first tick of travel: actor; shape; S and I; σ; the plane; the turn (spiral) or h (arc); the start and end ticks.
- **Camera** frames the chord plus the widest offset on the bulge side before he leaves.
- **VFX** draws the trail by sampling P(s(t)) between ticks. Leaving over a 900 u chord he moves about 65 u a tick, so a line through his tick positions would show corners.
- **Animation** banks him by his heading, which the 73° gives without sampling.

## 3. The `return` class
A light at ×0.6 of a light's damage. Its whole 6-tick anticipation is the perfect-block window, with no early tolerance, and it works in the air. No return blow repeats inside one rally. In data: `strikeClass.classes` gains `return`, and the perfect-block window becomes per class (6 for a return, 10 for the others).

## 4. The pieces

**The one new pose: the intercept turn.** At the end of the curve he brakes side-on, already turned to face the body that is still coming, the striking limb loaded and his weight on the back leg. It derives from the spiral entry's start pose (wave 2) and the brake.

**The 7 return blows** (wave 1 strikes tagged `return`). The pattern sets the launch; the blow sets the pose. "Fits best" is a weight, not a rule.

| Return blow | Limb to target | Contact at | Sends the body | Fits best | As a return |
| :--- | :--- | ---: | :--- | :--- | :--- |
| `jab` | hand to head | **58** | straight back | rally | He is already there, side-on and still; the blade hand meets the body's own speed and he barely moves. |
| `hook` | hand to head | **58** | turned about 70 degrees | orbit | The flat arc catches the body as it passes his shoulder and swings it onto a new line. |
| `backfist` | hand to head | **58** | turned about 70 degrees | orbit | He arrives half turned away and unfolds the arm into the body's path. |
| `rising_elbow` | elbow to jaw | **38** | up and back | ladder | The body arrives almost on top of him; the elbow lifts it up the way it came. |
| `side_kick` | foot to chest | **50** | straight back | rally | The leg is a level line the body runs onto; his arms balance the other way. |
| `snap_round` | foot to chest | **50** | up and back, or turned | ladder, orbit | A whip of the shin across the body as it arrives, his hips barely turning. |
| `tail_jab` (held: the tail) | own to chest | **70** (est.) | straight back | rally | He does not turn at all: the tail meets the body behind his hip. |

**The enders** (16 heavies tagged `ender`), at their wave 1 contact distances, with the 18-tick wind-up and Animation's blow weight at its fullest.

| Launch hint | Count | Enders |
| :--- | ---: | :--- |
| Across | 6 | haymaker, spinning_elbow, double_palm, roundhouse, spinning_heel, tail_whip |
| Down | 7 | hammer, overhand, dropping_elbow, double_hammer, axe_kick, stomp, tail_spike |
| Up | 2 | uppercut, rising_knee |
| No hint | 1 | headbutt |

- An upward ender is a loft, not an orbit launch: orbit needs a break, a finisher or the crater set piece (`docs/design/rule-of-cool.md`, feature 19).
- At tier 4 in Frenzied an across ender may be the round-the-world hit (feature 22), in the shared budget. It keeps our own name, with no shouted name and no borrowed pose.

## 5. Three knock patterns
The director picks one from the room available, with no draw.

| Pattern | The knocks | Where | Its ender |
| :--- | :--- | :--- | :--- |
| **Rally** | back and forth along one line, 10 degrees off it into the lane each way | open air, long sight lines | across: a long launch, or the targeted smash at a brunt target |
| **Ladder** | a zigzag that climbs: each knock 30 degrees above the line back | near the ground or over a city: it clears the roofs | down: the drive, or the crater slam under its gates |
| **Orbit** | each knock turns about 70 degrees, so the body circles a point | over a landmark or a field of formations: the camera holds one frame | down onto the point, or across away from it |

## 6. The defender's answers, and what plays

| Answer | When | What plays |
| :--- | :--- | :--- |
| Burst (30 ki) | any time before the ender lands | both are pushed apart and tumble free; no winner |
| Perfect block on a return blow | a middle blow's 6 anticipation ticks; the last 10 of the ender's 18 | he staggers; the defender's riposte launches, and the defender may start a rally of his own at once |
| Dodge-cancel (15 ki) | between the knock's hit-stop and the next anticipation: ticks 4 to 28 | the body slips the intercept; he arrives, strikes air and over-commits (Animation's over-commit pose) |
| A held guard | any time | each return does guard damage only; the heavy ender is a GUARD BREAK |

The struck body is the ragdoll throughout: it flails off each knock and is caught mid-flail by the next.

## 7. The broken-limb filter
- A rally is in the air, so a broken leg drops nothing: kicks play on the good leg.
- A broken arm drops nothing either: every return is one-armed or uses no arm. Returns then alternate between the good arm (jab, hook, backfist, rising elbow) and the rest (side kick, snap round, tail jab), which covers the 4 middle blows a rally can have.
- Without a tail there are 6 returns, and 2 that use no arm.
- The ender is drawn from the heavies he can still throw: 14 with a broken arm, 16 with a broken leg in the air.

## 8. What this needs
| For | What |
| :--- | :--- |
| **Encounter** | the `path` on the `rush` op as section 2 defines it; the rally's beats from section 1; the intercept point from the return blow's contact distance; the `return` class; the three patterns |
| **Simulation** | the `path` event |
| **Camera** | frame the path from the event; hold one frame for the orbit pattern; the panel for a rally's ender (it is an earned hit, sharing one panel every 12 s) |
| **VFX** | the trail sampled from P(s); no afterimage that hides him |
| **Animation** | the intercept turn; the bank from his heading; the over-commit after a dodge-cancel |
| **Game Design** | the ender's longer bounce (section 1); the per-class perfect-block window |
| **Legal** | done: GO (`docs/legal/rule-of-cool-screen.md`, the waves 3 and 4 section). For the whole rally: he is drawn the whole way: no vanish, no blink cut and no afterimage that hides him; he is on screen at every contact for the 6 anticipation ticks and at least 4 after; no cut to a bystander who cannot follow, and no frozen shock-ring frame between knocks; no shout and no named technique on the rally or on the round-the-world ender |
| **Tools** | `return` in the strike-class enum; a per-class perfect-block window |
