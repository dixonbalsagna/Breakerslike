# Patch plan: VFX's shot event asks, and four more shot kinds

Owner: Simulation and Engine. Status: **a plan only** (2026-10-03, on 45a95b9). Nothing here is built or run. It is for my next window in the sim tree; Encounter holds the tree now.

Sources: VFX's asks in `docs/vfx/shots-plan.md` ("Needs from Simulation"); the kinds in `docs/design/agency-pass.md` section 15.5, `docs/design/launch-pair-plan.md` and `docs/combat/launch-pair-movesets.md` section 4; Legal's staging rules in RL-062. The shot model is `docs/architecture/shots.md`.

## Part A. VFX's event asks

All four are small and in `sim/core` only. One of World's lines in my file changes shape (item 3).

| # | VFX's ask | The change | Lines |
| :--- | :--- | :--- | ---: |
| 1 | `actor` and `amount` on `shot_end` | `SimFx.shotEnd` sets `actor` (the shot's owner) and `amount` (its damage). Exact for a shot that ends on the tick it was fired | 1 |
| 2 | `ux, uy` or a face normal on `shot_end` with cause `building` | `ux, uy`: the shot's unit direction, on **every** `shot_end` (it is free, and a ground burst can use it too). For cause `building` also `surface`: `side` or `roof`, from which slab of the swept test the shot entered. The normal follows: a side face is (-sign of `ux`, 0), a roof is (0, 1) | 8 |
| 3 | A paid flag for the wear pool | `outcome` on `shot_end` with cause `building`: World's own word from `WorldBlast.shotBuilding` (`chip` while the pool is filling and nothing shows; otherwise what the floors or the house did). Richer than a flag, and it is already returned. `SimShots.hitStructure` returns that word in place of true (an empty word lets the shot through), and `end` takes it | 6 |
| 4 | `r` on `mine_trip` | `r`: the blast radius at the owner's tier (`blastR` times `tierR`), worked out where the blast works it out | 2 |

**The hash and the goldens.**
- `shot_end` is sent in every match that has shots, and the light digest folds events. So adding `actor`, `amount`, `ux`, `uy`, `surface` and `outcome` to its hashed fields moves every light digest, by design. One regeneration.
- Proof, in two steps as before: the code with nothing new hashed passes parity on the untouched goldens; then the field list, where tick counts and every full-state checkpoint must not move (the state is unchanged) and only the light digests do.
- `mine_trip` is not sent in a match yet, so `r` moves nothing.

**Needs:** World's review of the one line in `hitStructure`; `docs/architecture/fx-events.md` rows (mine).

## Part B. The kinds

Game Design's list calls for three at launch and one later:

| Kind | Whose | When |
| :--- | :--- | :--- |
| Curving shot | The Protagonist | At launch |
| Rain | The Anti-hero | At launch |
| Splitting shot | The Anti-hero | At launch |
| Ricochet shot | The Protagonist | Later |

The burning wake and the shield orb are conditional with Legal and not on the launch list, so they are not planned here.

Common to all four:
- **Neutral until the director fires one.** Each lands with its rule unused, as mines did.
- **Seeded draws are keyed** on the match seed and the shot's id (`SimRng.keyed`); `S.rng` is not read.
- **The cap of 32 covers them.** Children of a split or a rain are shots and count.
- **Numbers are data,** and every number below is my placeholder until Game Design gives its own.

### B1. The splitting shot

Game Design: a charged shot that bursts into five bolts in a cone on a second press; the answer to a rival who dodges late.

- **The call.** `SimShots.split(S, shot, o = {}) -> Array` (the children). The director calls it on the second press. The shot's kind needs a `split` block in the data.
- **What it does.** The parent ends with cause `split` and no blast. `count` children leave from its position as straight shots, fanned evenly across the cone about the parent's direction: slopes from minus `spread` to plus `spread`. With `"target": slot` in `o` the middle child seeks that fighter.
- **The children** are of the block's `kind` (shards, by Combat's sheet), at that kind's speed, and share one `group` so the volley counts once. Their damage is the director's to pass, as with any blast. They do not rest a tick: they are born in flight and move on the tick of the split.
- **The cap.** A split is refused, and the parent flies on, unless the live shots plus `count` less one fit under the cap.
- **State.** None new.
- **Data.** `kinds.<kind>.split {count 5, spread 0.32, kind "shard"}`.
- **Events.** `shot_end` cause `split` for the parent, then a `shot_fire` for each child with the group in `link`.
- **Size.** About 30 lines.

### B2. Rain

Game Design: fired upward; a second later a spread of bolts falls over a patch 6 bh wide, marked on the ground before it lands. Legal: it falls from above and never encloses the rival.

- **The call.** `SimShots.fire(S, slot, "rain", {"px": x})`: `px` is the patch's centre, which the director picks (the rival's position at the throw, or the stick).
- **The carrier.** One shot in a new mode `RISE`: it climbs from the thrower to a point `height` above the patch in `riseTicks`, drawn as a lob. It meets nothing on the way, neither fighters nor buildings nor shots: it is the upward throw, not a shot at someone.
- **The fall.** When it arrives it ends with cause `rain` and `count` children appear above the patch: straight shots falling at their kind's speed, spread evenly over `width` with a small keyed jitter, each a little higher than the last so they land one after another. From there they are ordinary straight shots: a fighter under one is hit, a roof stops one, the ground ends one, and each bursts by World's rule.
- **The mark.** A new event at the throw, `rain_mark {id, actor, x, y, z, r, dur}`: the patch's centre on the ground, its half width and the time to the first landing. Both players see it; that is the rule's warning.
- **State.** None new on a shot beyond the mode.
- **Data.** `kinds.rain {speed, r, power, dmg, lifeTicks, rain {count 6, width 450, riseTicks 60, height 1500, kind "bolt", gap 40}}`.
- **Size.** About 45 lines.

### B3. The curving shot

Game Design: a heavy shot that bends round cover or round the front of a guard, with the stick setting the side; slower than a straight one. Legal: steered by the stick only; nothing surrounds the rival or closes in on command.

- **The call.** `SimShots.fire(S, slot, "curve", {"target": slot, "side": 1 or -1})`. The side is fixed at the fire, from the stick. Nothing steers it afterwards, which keeps Legal's line.
- **How it travels.** A new mode `CURVE`. A base point pursues the target and arrives on a set tick, exactly as a seeking shot does. The shot is drawn off that base, across the line of fire, by a bow that is zero at both ends and widest half way. In the side-on plane that is over the top (side 1) or underneath (side -1).
- **What stops it.** Unlike a seeking shot, a curving shot **is** stopped by buildings and by the ground. That is what makes the bend mean something: bowed over a tower it clears the roof, and bowed too low it hits the wall.
- **The hit.** It arrives on its target like a seeking shot, but from above or below. The director's guard rule reads the shot's velocity at the hit to decide whether the guard faced it; "round the front of a guard" is Encounter's rule, on a direction the core supplies.
- **Let pass.** A dodge releases it as a straight shot along its last direction, as today.
- **State.** No new field: the base point reuses `x0, y0` and the bow reuses `arc` (both are a lob's fields, and a shot is never both).
- **Data.** `kinds.curve {speed 35, r 20, power 2, dmg, lifeTicks, curve {bow 0.35, bowMax 900}}`: the bow as a share of the distance at the fire, with a ceiling in units so a far shot does not bow off the screen.
- **Events.** None new: the view draws it from its position in `S.shots`.
- **Size.** About 45 lines.

### B4. The ricochet shot (later)

Game Design: it bounces once off the ground or a wall before it seeks; a bank shot round a building.

- **The call.** `SimShots.fire(S, slot, kind, {"ux", "uy", "bank": slot})`: a straight shot toward the bank point, which will seek that fighter after its bounce.
- **The bounce.** Where a straight shot would end on the ground or on a building's face, a shot with a bounce left does not end. It sends `shot_bounce {id, x, y, z, surface}`, World leaves its small mark, and the shot turns into a seeking shot at its target. From there a building does not stop it, by the seeking rule.
- **State.** Two new hashed fields: `bank` (bounces left) and `bankTgt` (the slot it will seek).
- **Size.** About 30 lines. Not for the launch window.

## Order, size and proof

| Step | What | Goldens |
| :--- | :--- | :--- |
| 1 | Part A, code | None: parity passes on the untouched goldens |
| 2 | Part A, the `shot_end` fields hashed | One regeneration: light digests move by design; tick counts and full-state checkpoints must not |
| 3 | Split, rain and curve, code and data, unused | The fight data hash only |
| 4 | The two new modes' hashing, if any state turns out to be needed | Light digests identical |
| Later | Ricochet | The two new fields hashed: light identical |

Steps 1 to 3 can be one commit with one regeneration. About 135 lines in `sim/core/shots.gd` and `fx.gd`, and about 150 of forced checks in `parity.gd`: each kind's path, its hits, the cap, the seam, and that a default match has none.

**Cost.** A curving shot costs what a straight shot over a city does (it is tested against buildings). A rain adds up to `count` straight shots for under a second. Nothing here changes the cost of the kinds that exist.

## Needs, when it is built

1. **Game Design:** the numbers. Rain: how many bolts, from how high, which kind, the damage of each. Split: the child kind and how the parent's damage is shared. Curve: its speed, bow, power and damage. Whether a rain's bolts can hit its thrower (today a shot never hits its owner unless it is wild).
2. **Encounter:** the presses (the second press for the split; the stick's side for the curve; the patch for the rain), the ki costs, the guard rule against a curving shot, and what the AI does about a marked patch.
3. **Tools:** schema keys `kinds.*.split`, `kinds.*.rain`, `kinds.*.curve`, later `bank`.
4. **World:** the review of `hitStructure`'s line (Part A, item 3); blast rows for the new kinds `rain` and `curve` in `blast.json`.
5. **VFX, Audio:** the new events `rain_mark` and, later, `shot_bounce`; the new end causes `split` and `rain`.

## Open points

1. **A rain over a tower** lands on the roof, not the street. That follows from shots meeting buildings. If Game Design wants the patch always on the ground, the children would have to ignore buildings, which reads wrong.
2. **The curve's bow near the ground.** Side -1 with both fighters standing puts the bow underground, so the shot ends at once. The director should not offer that side there, or the core clamps the bow to stay above the ground; I would leave it to the director.
3. **A split with no room under the cap** leaves the parent flying. The alternative, fewer children, makes the cone lopsided.
