# Shots: energy blasts in flight

Owner: Simulation and Engine. Status: in the tree since 2026-10-02 (section 11), neutral: nothing fires a shot until Encounter's slice 3a. It is what Encounter's slice 3a needs first (`docs/director/agency-plan.md` section 3; rules in `docs/design/agency-pass.md` section 5 and `moveset-rules.md` section 11 i).

## 1. What a shot is

A shot is sim state: a record in `S.shots`, hashed, in the order it was fired. The director fires shots and decides what a hit means. The core moves them and finds what they meet.

| Field | Meaning |
| :--- | :--- |
| `id` | Unique in the match, in firing order (`S.shotSeq`) |
| `owner` | The slot whose shot it is. A deflect changes it |
| `kind` | A kind in `data/fight/shots.json` (`bolt`, `charged`, `lob` to start) |
| `mode` | How it travels: `LINE`, `SEEK` or `LOB` |
| `x`, `y`, `z` | Position. `x` wraps with the planet. `z` is the depth: the owner's at the fire, 0 until the depth switch-on |
| `vx`, `vy` | Units a second |
| `tgt`, `left`, `total` | A seeking shot's target slot; ticks left to its arrival (or of life, for a straight one), of how many |
| `x0`, `y0`, `px`, `py` | A lob's start and landing point |
| `power` | What it trades with |
| `dmg` | What a plain hit does |
| `group` | Shared by the shots of one volley, so a volley counts as one landed strike |
| `deflected`, `fresh`, `dead` | Times sent back; fired this tick; ended this tick |

**The cap is 32 live shots** (data). Two nine-piece spreads and two barrages fit. Past it `fire` returns null and the press is spent without a shot.

## 2. How a shot travels

| Mode | Rule |
| :--- | :--- |
| `LINE` | A straight line at the kind's speed until something stops it or its life runs out (120 ticks) |
| `SEEK` | Toward a fighter, arriving on a set tick whatever he does: each tick it covers `1 / left` of what remains, the rush's rule. The time is the distance over the kind's speed, at most `arriveTicks` (45), so "a blast always arrives within 45 ticks" and "energy reaches at any range" hold exactly. A seeking shot is not stopped by the ground or the water on the way |
| `LOB` | A fixed-time arc (36 ticks) to a point: a straight line plus a parabola of the kind's height |

- A shot fired this tick sits at its start and moves from the next tick, so a volley's pieces leave together and an arrival is exactly its tick count after the fire.
- Timers are whole live ticks. Shots do not move during a pause, a hit-stop or the intro, because their step does not run.
- Speeds are Game Design's, in units a tick: bolt 60, charged 90.

## 3. What a shot meets

Every test is swept over the tick's movement, so a fast shot never passes through anything. The order each tick: all shots move; trades; then each shot, in firing order, against the fighters, then the ground, the water and its life.

| Against | Rule | Who decides the result |
| :--- | :--- | :--- |
| **Another shot** | Shots of different owners whose paths come within their two radii trade: each loses the other's power, and one with none left ends. Bolts (power 1) cancel in pairs and what is left of the bigger volley lands. A charged shot (power 3) eats three bolts | The core |
| **A fighter** | The shot's path against his body (a circle of `bodyR` at `chest`), or a seeking shot's arrival at its target. Never its owner. Not after a KO, not a fighter still in the intro | `SimShots.hitFighter(S, shot, f)`: the plain rule is the shot's damage and its end. **Encounter replaces this function's body** with the blast's rules (guard, the perfect block's deflect, the dodge, the walk-through) |
| **The ground** | A straight shot at or under `groundY`, or a lob's landing | `SimShots.hitWorld(S, shot, cause)`: nothing by default. **World adds** what a blast does to the ground and to the structures around the point (with the beam's tier factor) |
| **The water** | A straight shot under the surface | The same hook, cause `water` |
| **A structure** | Not as an obstacle yet. A shot flies in the fighter plane, where no footprint stands; a footprint its path really crosses stops it when World's swept test lands with the lanes (L3). Until then structures are reached by the end's blast, through `hitWorld` | World |

`SimShots.deflect(S, shot, newOwner)` turns a shot round: it becomes the new owner's and seeks the old one. `SimShots.end(S, shot, cause)` ends one.

## 4. Events and the view

| Event | Fields | When |
| :--- | :--- | :--- |
| `shot_fire` | actor, kind, id, x, y, z, target, spd, amount (power), link (group), ux, uy | a shot is fired |
| `shot_hit` | actor (owner), victim, kind, id, x, y, z, amount (damage), outcome, link | it met a fighter. The plain rule sends `hit`; the director's blasts send their own outcomes (guard, deflect and the rest) |
| `shot_clash` | id, b (the other id), x, y, z, amount (power traded) | two opposing shots traded |
| `shot_end` | id, kind, x, y, z, cause (hit, clash, ground, water, life) | it is gone |

**The view.** A renderer draws the shots in flight from `S.shots` (position, velocity, kind, owner, power), as it reads `S.beams`. The four events carry positions for the muzzle flash, the impact and the clash. The reference consumer lists them; VFX and Audio build on them.

## 5. Determinism, the hash, replays

- No random number is drawn. Everything is float64 under the sim's rules; the only root is in the fire (the distance) and the fire's unit direction.
- All of `S.shots` and `S.shotSeq` are hashed; the events join the event table.
- `data/fight/shots.json` joins the fight data hash and the replay header, so a replay refuses other shot data.
- Order is fixed: firing order everywhere; trades walk slot 0's shots against slot 1's.

## 6. Cost (measured on Orb's PC)

| In flight | The shots' step |
| :--- | :--- |
| None | 0.2 µs a tick |
| 9 against 9 | 75 µs |
| 16 against 16 (the cap) | 171 µs |
| 32 of one owner | 104 µs |

About 3.2 µs a shot a tick, and 0.3 µs a pair of opposing shots. The whole tick today is about 100 µs, so a full barrage exchange roughly doubles it while it lasts. On a machine 5 to 10 times slower that is 1 to 2 ms. The lever is the cap.

## 7. Proofs (scratch copy of 541f7de)

1. **The code is neutral:** nothing fires a shot yet, and parity passes on the untouched goldens (9 matches, 179,088 ticks).
2. **Hashed:** every light digest and tick count is identical; only the full-state checkpoints move.
3. **The parity check "shots"** holds: none in a default match; a straight shot's speed, life, the ground and the seam; a seeking shot landing on its tick, near and far, at a target that moves; the fire tick's rest; three bolts against two (two clashes, one lands); a charged shot against two bolts; a deflect; the cap; a lob's arc and landing.
4. Also green there: determinism, `npm test`, the validator (0 errors) and its self-test (2,305 of 2,305) with the schema.

## 8. What Encounter and the others do with it

- **Encounter (3a):** `SimShots.fire(S, slot, kind, {...})` from its blast code; the body of `hitFighter`; `deflect` on a perfect block. Its damage and outcomes go on `shot_hit`. A volley passes one `group` to its pieces.
- **World:** the body of `hitWorld`.
- **Combat, Game Design:** the kinds and their numbers in `shots.json` (the damage there is a placeholder).
- **Tools:** the schema, parked as `shots_schema.cjs` (needs the grant).
- **VFX, Audio, Camera:** the four events and `S.shots`.

## 9. Open points

1. **A seeking shot ignores the ground.** That keeps "energy reaches at any range" true over a planet with hills between the fighters. It will be drawn passing through a ridge unless VFX arcs it. The alternative, the ground stopping it, makes long shots whiff. Encounter's and Game Design's call; it is one condition in the step.
2. **The short beam** (3b) is a beam, not a shot: it stays the director's `S.beams`.
3. **Shots against a fighter in a transformation's hold or a pause:** the step does not run in a pause; in a live hold the director's `hitFighter` decides.

## 10. What else the agency pass needs from the core

| Ask | From | What it is in the core | Size |
| :--- | :--- | :--- | :--- |
| The `knockback` event | Combat (`brawl-endings-and-trades.md`) | An emitter, its fields (who was sent, by whom, the kind, the distance, the start and end ticks) in the event table and the view's list. Encounter's op sends it | Small, about 10 lines. Neutral |
| `exchange_end {actor, kind}` | QA (`timing-edge-plan.md`), Encounter | An emitter and its fields. Encounter sends it from `endEx` | Small, about 8 lines. Neutral |
| A flow value per fighter | QA, Encounter (2c) | `ActState.flow` (an int, hashed), with a `flow` event when it changes. Encounter owns the count's rule | Small, about 10 lines. Neutral until Encounter writes it |
| The press log, if it moves to core | Encounter (slice 1), QA | A ring of the last presses per fighter in `ActState` (tick, kind, grade), hashed, with `SimAct` to push and read it | Small to medium, about 40 lines and a parity check. Neutral |
| Controls' `intent-hash.patch` | Controls | One line: the agency fields join `INTENT` in `hash.gd`. It moves the goldens (hash only), so it goes with the first slice that reads those fields | One line and a regeneration |
| World's embed | World (`ground-contact.md`) | `Fighter.embedT` (ticks) and `embedCool`, hashed; the `embed` event (actor, x, y, z, depth, r, energy, dur, n) | Small, about 12 lines. Neutral |
| `autoCharge` | Controls | One more name in `SimAct.ASSISTS` | One line. Neutral |

All but the press log and the intent hash are prepared as one neutral slice (`pending/agency.py`), proven with the shots on b8ea622, and ride with them (EP, 2026-10-02). The press log stays in Encounter's state; the intent hash goes with Encounter's charge slice. As built: `knockback {victim, attacker, kind, amount, dur, n, x, y, z}` (`amount` the distance, `n` the end tick), `exchange_end {actor, kind: continue, knockback or launch}`, `flow {actor, n}` sent by `SimAct.setFlow` when the count changes, `embed` as World listed it, `Fighter.embedT` and `embedCool`, `autoCharge` as the fourth assist.

## 11. As built (2026-10-02, on aee2c6b)

`sim/core/shots.gd` (`SimShots`), `S.shots` and `S.shotSeq`, the step after the beams in `SimCore.step`, `data/fight/shots.json` with Tools' schema, the four shot events, and the agency lines of section 10 (the `knockback`, `exchange_end`, `flow` and `embed` events, `ActState.flow` with `SimAct.setFlow`, `Fighter.embedT` and `embedCool`, `autoCharge`).

**Proofs, in the tree:** the code passes parity on the untouched goldens (9 matches, 184,273 ticks) with the checks "shots" and "agency lines"; with the new state and events hashed, every light digest and tick count is identical, so the one golden file that comes out differs in its full-state checkpoints only. Parity, determinism, the seam sweep, `npm test`, the validator (0 errors), its self-test (2,358 of 2,358), the touch test and the loader check pass.

