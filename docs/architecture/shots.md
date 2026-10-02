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

## 12. Game Design's first numbers, and a shot that is let pass (in the tree since 2026-10-02, on aea5e4f)

Applied in the tree. The light digests, tick counts and full-state checkpoints did not move (no match has a shot); only the fight data hash in the goldens changed. All gates pass.

**The numbers** (`agency-pass.md` section 11, item 6b), in `data/fight/shots.json` with no schema change:

| Kind | Speed (units a tick) | Trade power | Plain damage | Flight |
| :--- | ---: | ---: | ---: | :--- |
| `bolt` | 60 | 1 | 8.67 (a third of a light) | 120 ticks |
| `shard` | 50 | 1 | 5.2 (a fifth of a light) | 24 ticks: 1,200 units |
| `arc` | 45 | 2 | 52.8 (0.8 of a heavy) | 120 ticks |
| `charged` | 90 | 3 | 66 (a full heavy, its value at 30 ticks of charge; the director passes 0.6 of it for a tap) | 120 ticks |
| `lob` | a 36-tick arc | 3 | 66 (a heavy) | 36 ticks |

- The damage column is the plain rule's stand-in. "A shape carries its strike's damage": the director's blasts pass their own at the fire (a volley's total is one light; a charged shot rises to a full heavy at 30 ticks of charge).
- Not in this file, because they are the director's: the ki costs, the counts (a volley of 3, a spread of 5), and the burst, which has no travel and is an area hit, not a shot.
- The radii and the lob's height are my placeholders.

**A shot that is let pass** (ruling 6a). When `hitFighter` returns false (a dodge), or a seeking shot arrives at a target that cannot be hit, the shot flies on as a straight shot at its last velocity for the kind's life, and the ground and the water then stop it. `Shot.passed` remembers whom it has passed, so it is not offered to him again every tick. `SimShots.release(S, shot)` does the same on the director's call. Before this, a let-pass seeking shot stayed on its target and met him again each tick.

**A kind with no blast entry.** World's `WorldBlast.shotHit` (called from `SimShots.hitWorld`) does nothing for a kind that `data/biomes/blast.json` does not list: no crater, no structure damage, no water effect. The shot still ends and `shot_end` is sent. Today that is `shard` and `arc`; the validator warns about both (`xref:blast-kind`) until World adds them.

**The charged shot's plain damage is the full heavy,** not the tap's 0.6. Tools' check (`xref:shots-order`) wants a kind with more trade power to do no less damage than one with less, and the arc does 52.8.

## 13. The second round: buildings, wild deflects, the spray, mines (parked, 2026-10-02, on 2c91129)

Orb's direction is in `docs/ep/vision.md` ("Orb on the energy blasts"), Game Design's rules in `agency-pass.md` section 15, Legal's screen in RL-060 and RL-061, and World's side in `docs/world/ground-contact.md` sections 27 and 28. This is the core's part of it. It is built and proven in a scratch copy of 2c91129 (after Encounter's slice 7) and parked as `docs/architecture/pending/shots2.py` with Tools' `shots2_schema.cjs`. Nothing is in the tree.

| Piece | What it adds to the core | Does it change today's matches? |
| :--- | :--- | :--- |
| Shots meet buildings (14) | A swept test in the step and the hook `hitStructure` | Only with the data switch `structures` on |
| The wild deflect (15) | What `SimShots.deflect` does, and a shot that can hit anyone | Only with `deflect.scatter` on |
| The spray cone (16) | Two options of `fire`: `aim` and `spread` | No: nothing passes them yet |
| Mines (17) | A fourth way of travelling (`MINE`), `trip`, `tripNear`, the kind `mine` | No: nothing lays one yet |

Both switches ship off, so the code part is neutral. Each switch is its own part of the script and its own golden regeneration.

## 14. Shots meet buildings in flight

- **Which shots.** Straight and lobbed ones, a wild shot included. A seeking shot is not stopped, by the same rule that lets it ignore the ground: it arrives.
- **Which buildings.** A standing building whose nearest face is within `WorldStructures.Z_REACH` in depth of the shot. That is World's rule for every blast and the filter of World's own prototype. It reads the shot's depth, so it holds with depth on or off.
- **The test.** Each tick, after the fighters: the tick's movement as a segment against the building's box, widened by the shot's radius (its width in x, its ground to its current top in y, so a shot passes over a building that has lost floors). It is exact, with no samples, so a fast shot can't skip a narrow building or a corner. The earliest crossing wins and the lower index breaks a tie. The shot is moved to the crossing.
- **The hand-over.** `SimShots.hitStructure(S, shot, building) -> bool`. True ends the shot with cause `building`. False lets it through, and `Shot.lastB` keeps it from being offered to that building again. The rule in the parked build ends the shot and does nothing to the building. World's body goes there: `WorldBlast.shotBuilding(...)` from its prototype. "One shot levels at most one building" is World's to count.
- **Only entering counts.** A building the tick's movement starts inside is not met. So a shot fired from inside a footprint (fighters can stand in one today), or a seeking shot released there, flies out of it. Buildings of different rows overlap in x, and this rule covers that too.
- **Lines.** 7 in the step and one function of about 60 (`_building`). World sized my side at 8 with the test in its own file. The brief put the swept test in the core, so the 60 are the test.
- **Against World's prototype.** `WorldBlast.shotMeetsBuilding` samples the path every 24 units and tests straight shots only. This test replaces it and keeps World's `shotBuilding` as the hit. It also covers lobs, which a wild shot is. The EP picks one test, not both.
- **Don't switch it on alone.** Today a shot flies through a building and its blast on the ground reaches it. With `structures` on and no World body, a building takes nothing from the shot it stops. So the switch goes on in World's window, with its `shotBuilding`.

## 15. A deflect sends the shot wild

`SimShots.deflect(S, shot, slot)` keeps its name and its caller. With `deflect.scatter` on it does this:

| Game Design's rule (15.2) | In the core |
| :--- | :--- |
| A seeded direction | Three stateless draws from the match seed, the shot's id and its deflect count (`SimRng.keyed`): the band, the distance, the side. `S.rng` is not read, so nothing else in the match shifts |
| 85% land 4 to 20 bh away, 15% arc to 20 to 40 | `nearMin` to `nearMax` (300 to 1,500 units) or, with `farChance` 0.15, `farMin` to `farMax` (1,500 to 3,000) |
| Biased down and away | It becomes an arc (a lob) to that spot on the ground, or on the water over it. With `awayChance` 0.75 the spot is on the side away from the shooter |
| Never within 30 degrees of the line back to the shooter | The launch direction is checked (`backCos` 0.866). If it fails, the other side is tried, then each side with a flat arc; the first that passes is used |
| It can hit either fighter or a building on the way | `Shot.wild`: a wild shot is offered to every fighter, its owner too. Buildings stop it by section 14. It also lands early on ground or water that rises into its path |
| Not the deflector for its first 10 ticks | `Shot.safe` and `safeT` (`safeTicks` 10) |
| The shooter answers for the damage | The owner does not change. `hitWorld` and `hitFighter` see the shooter as its owner |
| Where it lands, it explodes | `hitWorld` with cause `ground` or `water`, as for any landing |

- The new event `shot_deflect {id, actor, kind, x, y, z, x1, y1, dur}` says who deflected it, where it is bound and when. The caller still sends its own `shot_hit` with the outcome `deflect`.
- **One line of Encounter's changes.** The step's "he let it pass" branch tested `sh.owner != k`, which relied on the deflect changing the owner. It now tests that this call did not deflect the shot (`sh.deflected` unchanged). The result is the same with scatter off.
- **The flight's shape is my placeholder:** `speed` 50 units a tick, at least `minTicks` 12, an arc `arcPer` 0.25 of the distance high. Game Design gave the distances and the angle, not the shape.
- **A shot that hits its own shooter takes the plain rule:** its damage, and it ends. It is not handed to `DirBlast.hit`, because that rule reads the shot's owner as the attacker: a full charged shot would knock him back with himself as the attacker and could start a finisher on himself. Encounter can take the case over by widening the one condition in `hitFighter`.
- **Still Encounter's from 15.2:** the +8 ki and the free approach, the context deflect, and the feed line (it still says the shot "goes back").

## 16. The spray cone

Game Design's rule (15.4) keeps the spread's build-up, the recovery and the seek-or-miss draw with the director. The core gives it two options of `fire`:

- **`"aim": slot`** fires a straight shot at where that fighter's centre is now. It does not follow him.
- **`"spread": slope`** turns the aim by a seeded draw of up to that slope either side: 0.105 is 6 degrees and 0.325 is 18. The draw is `SimRng.keyed` on the match seed and the shot's id.

So the rule's "the rest fly straight inside the cone and explode around the rival" is `fire(S, slot, "bolt", {"aim": rival, "spread": slope})`, and a bolt that still seeks is today's `{"target": rival}`.

`spread` also works with `target`, for a shot that seeks loosely: it aims beside him by the distance times the draw (`Shot.ax`, `ay`), lands only if that point is within reach of him, and otherwise passes him and flies on as a straight shot. Game Design's rule does not need it. It is there if "seeks loosely" reads better than a straight miss.

The director's own seek-or-miss draw should be a keyed draw too (`SimRng.keyed(seed, its own key, the shot's id)`), so a replay matches and no stream shifts.

## 17. Mines

A mine is a shot that does not travel: mode `MINE`, in `S.shots`, hashed, laid with `SimShots.fire(S, slot, "mine", {"ground": true or false})`. A kind is a mine when its data has a `mine` block.

| Game Design's rule (15.5) | In the core |
| :--- | :--- |
| Hovering where he laid it, or resting on the ground | It sits at the fire's position. With `ground` it sits on the ground, and follows the ground if a crater or a heap moves it |
| Up to 6 a fighter; a seventh fizzles the oldest | `mineCap` 6. The oldest ends with cause `life` |
| At least 2 bh apart | `mineGap` 150: `fire` returns null within that of any mine, and the press is spent |
| 20 s, then it fizzles | `lifeTicks` 1,200, cause `life`, no hit and no blast |
| Arming, 30 ticks | `Shot.arm`. Until it is armed only another mine's blast sets it off |
| The rival's body within 1.5 bh, never its owner | His centre within `trigR` 112.5 |
| Power 3, a 2 bh blast, 0.8 of a heavy, the owner takes 30% | Every fighter within `blastR` 150 is offered to `hitFighter`: the rival through the director's rule (which adds the knock-back), the owner by the plain rule at `ownShare` 0.3. The radii grow by `tierR` (1, 1, 1.25, 1.5) with the owner's tier |
| Any shot that hits a mine sets it off | A swept test of every flying shot, either fighter's, against the mine's own radius. The shot ends there with cause `clash` |
| A blow on a mine sets it off | `SimShots.trip(S, mine, "blow", slot)`, or `tripNear(S, x, y, r, "blow", slot)` for a contact point. The director calls it |
| Chains, 6 ticks apart, whoever owns them | Mines within `chainR` of a blast follow, nearest first, `chainTicks` 6 apart; ties go to the one laid first |
| Mines count toward the 32 | They do |
| Buildings, craters | `hitWorld(S, mine, "mine")`: World's `mineBlast` goes there |
| Mines never close in on command (Legal) | A mine has no velocity and no target |

- `Shot.fuse` is -1 until the mine is set off, then the ticks to its blast. `fuseTicks` is 0: a mine set off by a rival blows on that tick. A chain's delay goes in the same field.
- The new event `mine_trip {id, actor, kind, x, y, z, dur}`: `kind` is `fighter`, `shot`, `blow` or `chain`, and `dur` is the time to the blast. The blast is `shot_end` with cause `mine`.
- A mine does not trade with shots, and two mines never meet.

**One conflict in the rule.** Mines must be 2 bh apart and a blast reaches 2 bh, so below tier 3 a chain only happens between mines laid at exactly the minimum gap. `chainR` is its own number, so Game Design can set it wider than the blast (3 bh would chain a field laid at up to 3 bh spacing) or lower the gap.

**A minefield and the cap.** 6 a fighter is 12 mines at most, which leaves 20 of the 32 for shots in flight. `fire` refuses a mine at the cap as it refuses a shot. A field of mines costs little while it waits (section 18). The cost is the shots that fly through it.

## 18. State, the view, cost, proofs, open points

**New state on a shot** (all hashed): `ax`, `ay` (the spray's offset), `arc` (a lob's height, now per shot), `lastB`, `wild`, `safe`, `safeT`, `arm`, `fuse`, `ground`. Timers are whole ticks. Nothing is added to a fighter.

**New data** in `data/fight/shots.json`: `structures`, `deflect {...}`, `mineCap`, `mineGap`, and the kind `mine` with its `mine {...}` block. Tools' schema needs these keys, and `speed` may be 0 (a mine's). The script is `shots2_schema.cjs`.

**What the view needs to draw mines.** Nothing new from the core:
- Each mine is an entry of `S.shots` with `mode == SimShots.MINE`: `x`, `y`, `z`, `owner`, `ground`, `arm` (above 0: dim; 0: bright), `fuse` (0 or more: about to blow), and `left` over `total` for a fade near the end of its life.
- The radii are in `SimShots.kinds[kind].mine`: `trigR` and `blastR`, with `tierR` for the owner's tier.
- Events: `shot_fire` when it is laid, `mine_trip` when it is set off, `shot_end` with cause `mine` (the blast) or `life` (the fizzle).
- Legal's look rules (RL-061) are the view's: a hexagonal plate or a faceted caltrop, never a glowing sphere, never numbered or shown as a set.
- Both players always see every mine. Nothing about a mine is hidden state.

**Cost** (Orb's PC, the shots' step alone; the section 6 figures still hold for shots in flight).

| Case | A tick |
| :--- | ---: |
| 12 mines waiting (the most there can be), no shots | 23 µs, about 2 µs a mine |
| 12 mines with a rival hovering just outside a trigger | 24 µs |
| 12 mines and 20 bolts flying through the field | 109 µs |
| 64 mines, with the caps lifted for scale | 124 µs waiting; 431 µs with 16 against 16 flying through |
| A chain of 12 going off | 14 µs a tick over its 80 ticks, without World's blasts |
| A straight shot over the densest street, `structures` on | About 8 µs more a tick for each straight or lobbed shot (32 of them: 389 µs against 130). Seeking shots pay nothing |

- **The cap of 32 holds.** A full minefield costs about a quarter of one 16 against 16 exchange while it waits. The new cost is each shot against each mine, which the 12 and the 20 bound.
- **A blast's cost is World's.** World measured a mine's crater at 170 to 250 µs and 12 in one tick at 1.9 ms. The chain's 6 ticks between mines spread that out; two chains can still put two blasts on one tick.
- **The building test's lever** is the list `WorldStructures.near` returns: its buckets are 1,200 units wide, so about 12 buildings come back for every shot and most are rejected one by one. A narrower index from World would halve the 8 µs. It is not needed at the usual 1 to 4 straight shots.

**Proofs** (scratch copy of 2c91129; the script applied to 7c300a2 gives the same nine files byte for byte).

1. **`code` is neutral.** Parity passes on HEAD's goldens but for the fight data hash. Regenerated: all 9 matches (173,526 ticks) and both replays are equal at every checkpoint, light and full.
2. **`hash`.** Every light digest and tick count is identical. Only full-state checkpoints with a shot in flight move.
3. **Gates at that state:** parity (34 checks, with the new "shots: buildings, wild deflects, the spray, mines"), determinism, the loader check, the touch test, the seam sweep, `npm test` (5 stages), the validator (0 errors; one warning, the mine has no entry in World's `blast.json`) and its self-test (2,808 of 2,808).
4. **The new check** forces each rule whatever the data says: a bolt stops on a building's face and on its roof, flies over the roofs, leaves a building it was fired inside, and a seeking bolt is not stopped; 60 wild deflects match their seeded draws, stay in the bands, favour the away side and never leave within 30 degrees of the shooter; a wild shot lands, hits its own shooter in its way, and hits its deflector only after the 10 ticks; 40 sprayed bolts match their draws and fill the cone; a loosely seeking bolt lands or flies on by its offset; mines are laid, refused inside the gap, armed, set off by a rival, a shot of either fighter and a blow, chain in order 6 ticks apart, fizzle at the end of their life, replace the oldest past 6, and count toward the cap.
5. **`scatter` on:** 7 of 9 golden matches move. Parity, determinism and the loader check pass on the regenerated goldens.
6. **`structures` on, after it:** 4 of 9 move. Parity and determinism pass.

**100 matches, seeds 1 to 100, default arm.**

| | As HEAD | `scatter` on | `scatter` and `structures` on, no World body |
| :--- | ---: | ---: | ---: |
| KAI wins | 60% | 55% | 55% |
| Length, mean | 493 s | 500 s | 499 s |
| Civilians lost | 26% | 26% | 24% |
| Structures lost, of 196 | 89.9 | 87.7 | 81.8 |
| Craters | 30 | 36 | 34 |
| Limb breaks a match | 0.34 | 0.27 | 0.27 |

KAI's share drops 5 points with `scatter` on. The interval on 100 matches is about 10 points either way, so that is not yet a finding; QA should measure it, since a deflect no longer sends the shot back at the shooter. The third column shows why `structures` waits for World: buildings stop shots and take nothing, so fewer fall.

**Open points.**

1. **One test for buildings, mine or World's** (section 14). The EP's call.
2. **Who a wild shot answers to.** The shooter, by Game Design's ruling. World's note asked which; the owner stays the shooter, so `hitWorld` passes him.
3. **A shot hitting its own shooter** takes the plain rule (section 15) until Encounter's rule handles it.
4. **The chain radius against the gap** (section 17). Game Design's.
5. **A seeking shot through a building.** It is not stopped, as with the ground (section 9, point 1). With buildings now solid to other shots this shows more. The same one condition changes both.
6. **A shot that runs out of life in the air** still ends with no blast. World asked for a call there; "every shot ends in an explosion" (15.1) says so too. It is one line (`hitWorld(S, shot, "air")` at the life's end) once World's blast fades with height, and it changes matches, so it goes in World's window.
7. **My placeholders, for Game Design:** the wild flight's shape (`speed`, `minTicks`, `arcPer`), `awayChance` 0.75, a mine's radius 20, `fuseTicks` 0, `chainR`.
8. **Mines and the shot kinds beyond these** (splitting, rain, curving, ricochet) are not designed here.

