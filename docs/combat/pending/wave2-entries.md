# Wave 2: the Anti-hero's entries, as specs to pose from

Owner: Combat and Choreography. Date: 2026-10-01. Status: parked specs for Animation. Nothing here is loaded or hashed, and no live data changed. The data is `entries.antihero.wave2.json` in this folder; this sheet is the same content for reading. Plan: `../m0-rich.md` (wave 2 of ten). Wave 1 is `wave1-strikes.md`.

**What is here.** 15 entries: how he gets to the blow, by the direction held. Rush 6, stand 5, retreat 4. They need 12 new poses; the rest derive from poses Animation has. Counts are authored sketches: Animation generates the wind-ups, follow-throughs and derived poses (wave 1: 23 authored, 117 in the pack). Eleven work on today's sim. Four wait: three need a path on the rush (the arc dive, the skid, the spiral) and one needs fight lanes (the lane step).

## 1. How to read a row
- **Path.** The line he travels. The sim owns his position, so a path that is not straight needs Encounter (section 4).
- **When.** The situation that offers the entry. The composer picks among those on offer.
- **Ticks.** For a rush, `c` is the template's approach time: the distance over 2,600 u a second, between 15 and 39 ticks, at least 20 for a heavy; beyond 2,500 u it is the pursuit flight of 48 to 120 ticks. "Start" and "arrive" are how long the start and arrival poses hold inside `c`. Stand and retreat entries are short fixed moves.
- **Where.** Air or ground, and whether a grounded use needs both legs (the broken-leg filter, section 5).
- **New poses / derives from.** What Animation authors, and what it already has.
- **Favours.** The wave 1 strikes that join best out of this entry: the composer weights them up, and they tell Animation what the arrival pose must flow into.

## 2. Shape language and limits
- **Blades.** In flight he is one narrow line, led by a shoulder or a forearm guard. Turns are banked like a blade on edge. The crouch is a coiled line with one hand down.
- **No look depends on the tail.** If the tail stays, it trails as one line.
- **The attack's tell rides on every entry.** The light or heavy tell (`moveset-system.md` section 7.3) plays through the approach, so an entry never hides the weight.
- **Legal's stacking rule:** the three crouch entries keep the hands open and forward, or one on the ground. Legal screened this sheet and it is GO (`docs/legal/rule-of-cool-screen.md`, the wave 2 section); its conditions are the Legal lines in the rows.
- **No teleports** (`docs/design/rule-of-cool.md` section 1, rule 8): he is drawn the whole way on every path.

## 3. Where an entry ends, and out of reach
- **Every entry ends at the contact distance of the strike that follows it** (wave 1: 58 u for a long blow, 50 to 54 for a mid one, 32 to 38 for a close one), on his own side, at the rival's height.
- **A rush** always closes, from any distance.
- **A stand out of reach** closes by plain flight, 12 ticks later than a rush, then plays its entry (Game Design, `control-rules.md` section 8).
- **A retreat out of reach** is the counter stance: the back move, then a hold of up to 45 ticks. If the rival's rush arrives, the counter meets it. If nobody comes, it ends with 10 ticks of recovery.

## 4. The entries

### Rush (toward): 6

| Entry | Path | When | Ticks | Where | New poses | Derives from | Favours | Look |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `dash` | straight | any distance; the default | c; start 3, arrive 3 | air and ground | none | approach.launch, move.dash, move.brake | jab, cross, haymaker, front_kick, shoulder_check, driving_knee | One narrow blade: a shoulder and its forearm guard lead, the other arm folded to the chest, legs together behind. **Legal:** not both arms trailed straight back, and not one fist punched ahead. |
| `arc_dive` | an arc: up by a quarter of the distance (4 bh at most), then down onto the rival **(needs a path on the rush)** | in the air, 600 u or more away, or 2 bh or more above the rival | c; start 4, arrive 5 | air only | start: a kick upward off nothing, back arched; arrive: head down over the rival, the striking limb already raised | move.ascend, move.descend | hammer, dropping_elbow, axe_kick, stomp, double_hammer, tail_spike | He climbs first, then folds at the top and comes down on the rival like a dropped blade, level with him on the last tick. |
| `rising` | straight, from below | the rival is 1.5 bh or more above him, or he is on the ground and the rival is in the air | c; start 3, arrive 4 | air and ground | arrive: under the rival, body a vertical line, the striking limb low and loaded | move.ascend, approach.launch | uppercut, rising_elbow, rising_knee, spear_hand, headbutt | Straight up from below, the body one vertical line, open hands flat along his thighs until the last moment. |
| `skid` | along the ground; the last 30% is a slide **(needs a path on the rush)** | both on the ground, 200 to 1,500 u apart | c; start 4, arrive 6 | ground only; needs both legs | start: the drop onto one hip and one hand; arrive: braking on the hand and the outside foot, the other leg free | move.sprint | sweep, low_kick, spear_hand, rising_knee, tail_sweep | He runs, drops and slides the last stretch on a hip and a hand, arriving under the rival's guard. |
| `spiral` | the golden spiral: 11% longer than the straight line, 0.2 of the distance off it at its widest **(needs a path on the rush)** | in the air, 800 u or more away; always the ping-pong's intercept | c; start 4, arrive 6 | air only | start: a banked turn away from the rival, one arm leading the curve | move.dash, move.burst | hook, backfist, snap_round, side_kick, spinning_heel, tail_whip | He leaves at an angle and curves back in, banked like a blade on edge, arriving from the side. **Legal:** flight only: he is drawn the whole way, with no vanish and no afterimage that hides him. |
| `coil_spring` (his own) | straight, flat and low | from the ground or a wall, within 900 u; needs both legs | c; start 6, arrive 3 | ground only; needs both legs | start: the deepest crouch, one hand on the ground, hips above the head | move.burst, move.brake | spear_hand, twin_spear, shoulder_check, body_ram, driving_knee, cross_arm_ram | He sinks, holds for a beat, and uncoils flat and low at the rival's middle. **Legal:** hands open and forward, or one on the ground: never clenched fists at his sides; no scream, ground-crack or rising-rubble effect on the crouch. |

**In energy mode:** advancing fire. `dash`: bolts from the folded arm's hand every 6 ticks; a burst on arrival. `arc_dive`: a volley fanned downward at the top of the arc. `rising`: bolts straight up from one hand; a burst under the rival on arrival. `skid`: none: his hands are on the ground. `spiral`: a volley thrown across the inside of the curve. `coil_spring`: none in the spring; a point-blank burst on arrival.

### Stand (neutral): 5

| Entry | Path | When | Ticks | Where | New poses | Derives from | Favours | Look |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `step_in` | a step | in reach | 6 | air and ground; grounded needs both legs | none | move.step_f | jab, cross, palm_heel, front_kick, short_elbow, short_knee | One short, flat step, the head level, the hands already where the strike starts. |
| `pivot` | a step with a turn | in reach | 9 | air and ground; grounded needs both legs | the pivot: weight on the lead foot, the rear hip swinging round, shoulders a beat behind the hips | move.step_f | hook, backfist, snap_round, roundhouse, spinning_elbow, spinning_heel | He turns on the lead foot and lets the turn become the blow. |
| `plant_coil` (his own) | a step, dropping low | in reach | 9 | air and ground; grounded needs both legs | the plant: a drop into the crouch on the spot, spine curled, eyes up | none | uppercut, rising_elbow, spear_hand, rising_knee, headbutt | He drops into the crouch where he stands and strikes up out of it. **Legal:** hands open and forward, or one on the ground: never clenched fists at his sides; no scream, ground-crack or rising-rubble effect on the crouch. |
| `lane_step` | a step, in depth **(needs fight lanes)** | in reach; only once fight lanes land | 9 | air and ground; grounded needs both legs | the lane step: a sidestep toward or away from the camera, body turned a quarter | none | side_kick, hook, low_kick, short_elbow | A sidestep off the line, so the blow comes from beside the rival's guard. |
| `rooted` | no travel | in reach; the only stand entry with a broken leg on the ground | 0 | air and ground | none | stance.aggressive, stance.air | jab, cross, palm_heel, headbutt, tail_jab, hammer | He does not move his feet at all: the blow comes out of the stance. **Legal:** hands low and open while he waits; no beckoning and no arms-crossed pose. |

**In energy mode:** the turret. `step_in`: planted volleys from both hands in turn. `pivot`: an arc thrown off the turn. `plant_coil`: a charged shot from the crouch, one hand braced on the ground. `lane_step`: bolts from the new angle. `rooted`: the turret: charged shots and volleys from where he stands.

### Retreat (away): 4

| Entry | Path | When | Ticks | Where | New poses | Derives from | Favours | Look |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `backstep_counter` | back to 150 u | in reach, or as the counter stance out of reach | 9; counter step 6 | air and ground; grounded needs both legs | none | move.step_b, move.retreat | cross, front_kick, side_kick, overhand | One step back with the weight on the rear leg, then straight back in as the rival follows. |
| `fade` | no travel: a lean | in reach; the only retreat entry with a broken leg on the ground | 6; counter step 0 | air and ground | none | the dodge lean (Animation's unit K) | uppercut, hook, rising_elbow, short_knee, headbutt | His feet stay; the head and chest slip back out of range and come forward again with the counter. **Legal:** a lean from the hips of about 30 degrees at most, feet planted: not a backbend. |
| `hop_back` | back to 150 u, rising 40 u | in reach | 9; counter step 6 | air and ground; grounded needs both legs | the hop: both knees drawn up, body leaning in toward the rival | move.retreat | front_kick, side_kick, tail_jab, axe_kick | A short hop back and up, so the counter comes down from a little above. |
| `drop_back` (his own) | back to 110 u, dropping low | in reach, on the ground | 9; counter step 6 | air and ground; grounded needs both legs | the drop: back and down into the crouch, under the line of the blow | none | sweep, spear_hand, rising_knee, uppercut | He gives ground downward: back into the crouch under the blow, then up through the rival's middle. **Legal:** hands open and forward, or one on the ground: never clenched fists at his sides; no scream, ground-crack or rising-rubble effect on the crouch. |

**In energy mode:** kiting. `backstep_counter`: kiting bolts while he backs away. `fade`: a point-blank burst as he comes forward. `hop_back`: a volley fired down the line he left. `drop_back`: a low arc along the ground.

## 5. The filter
- **A broken leg, on the ground:** drop every entry that needs both legs. What stays: dash (after the 20-tick slower take-off) and rising; rooted; fade. One of each direction.
- **A broken leg, in the air:** nothing is dropped.
- **A broken arm:** nothing is dropped. The skid and the coil spring put the good hand on the ground.

## 6. What this needs
| For | What |
| :--- | :--- |
| **Animation** | the new poses in the rows; arrival poses that flow into the favoured strikes' chambers |
| **Encounter** | a `path` on the `rush` op: `arc` (apex a quarter of the distance, 4 bh at most), `ground` (the last 30% a slide) and `spiral` (`blitz.md` section 1). Today every rush is a straight line, so those three entries cannot play yet. The composer's entry choice by the "when" column, and the favoured joins as weights |
| **Fight lanes** | the lane step |
| **Legal** | done: GO, with the lines now in the rows |
| **VFX** | the fire that rides each entry in energy mode; no afterimage that hides him on the spiral |
