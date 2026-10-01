# Contact: full contact on every hit, and no passing through

Owner: Encounter Systems Director. Date: 2026-10-01. Status: in the tree on HEAD `607edce` (after the landing mix, `93d5e0d`), with Combat's contact data, goldens regenerated.

**Why.** Orb wants full contact on every hit and no passing through. Animation measured 41% of hits beyond a hand's reach (68 u) and 45 side swaps in 4 seeds. Combat's data closes the strings (`docs/combat/contact-spacing.md`, the parked contact files). This is the sim side, section 5 of that note, plus the dodge as a physical move and the parry fix of section 7.

**The rule.** On every damaging strike's contact tick the two fighters are within 68 u, at the same height, on known sides.

## What the director does

Everything below runs only in a profile with a `contact` block (`dynamic`). The old profiles keep facing-based offsets and the blink, so `parity` stays bit-identical.

| # | Rule | How | Where |
| ---: | :--- | :--- | :--- |
| 1 | **Offsets by side, not by facing** | A `rush` or `finRush` ends on the mover's own side of its target, along the shortest arc. Only `"side": "cross"` changes sides. A target that is in a move of its own is read at that move's end, so a re-close during a dodge takes the side the pair will end on | `melee.gd` `sideOff`; the `rush` and `finRush` ops |
| 2 | **The strike places the striker** | A closing move ends on the strike's tick, but the target steps after the mover, and a launched body flies 130 to 500 u in a tick. So a damaging strike puts its striker at the contact offset (58 u), on its own side, at the target's height. The limit is `contact.placementReaches` (3 reaches) plus two ticks of the target's flight. Past it nothing moves and the feed says OUT OF REACH | `melee.gd` `_contact`, called by `strike` |
| 3 | **No overlap** | No move ends inside `minSeparation` (45 u). Two bodies at rest closer than that, at the same height, are moved apart evenly, each on its own side. A body in an authored move or in flight is left alone | `sideOff`; `melee.gd` `contactTick` |
| 4 | **Facing follows the opponent** | Every tick of a melee exchange each fighter faces the other | `contactTick` |
| 5 | **The reach check** | The feed line OUT OF REACH names any strike that could not be placed. QA's probe can read the distance and the height difference at each `damage` event; mine is `reach.gd` (numbers below) | `_contact` |
| 6 | **A parry ends the string** | When a parry lands, every pending beat is dropped and the chain window is closed, so the exchange ends that tick. Only in profiles with a `parry` block | `melee.gd` `strike` |
| 7 | **The dodge is a step-around** | Teleporting is on hold, so the `dodge` beat with `"side": "cross"` is two short moves: over the attacker (1.3 body heights above it; under it at the flight ceiling) and down behind it at its height. The beat gives the length (`dur`, 8 ticks), the rise (98 u) and the end distance (`off`, 74 u). No draw | `melee.gd` `opDodge`, `opDodgeLand` |
| 8 | **No launch goes back through the launcher** | The planner offers a building or a mountainside only on the far side of the rival. Before, a MOUNTAINSIDE or BUILDING SMASH behind the launcher sent the body through it | `launch.gd` `chooseLaunch` |

**Also in this slice: the transformation push comes at the break** (Game Design). `SimFighter.formBreak` calls `DirExchange.formBreak`, which pushes a rival within 700 u back at 900 u/s if it is free or charging. It draws nothing and starts nothing. The push is gone from the request. This is not gated by profile; only the live version changes in sim terms, because in a full or short version the sim is paused between the request and the break.

## Results

12 AI matches, seeds 1 to 12, every damaging melee strike. Before is HEAD `607edce` (the landing mix, on the live data).

| Measure | Before | After |
| :--- | ---: | ---: |
| Strikes beyond 68 u | 40.1% of 3,493 | **0 of 3,129** |
| Strikes at another height (over 17 u) | 16.7% | 1.4% |
| Strikes with the bodies overlapping (under 45 u) | 2.1% | 0 |
| Farthest strike | 6,871 u | 68 u |
| Side swaps inside exchanges | 1,237 | 447 |
| ... in the three DODGE branches (the authored cross) | 861 | 437 |
| ... anywhere else | **376** | **10** |
| Time an exchange stays open after a parry | 1.68 s | 0 |
| OUT OF REACH lines | | 0 |

- **The 1.4% at another height** are all terrain (43 strikes): the higher fighter is standing on ground that is higher than its rival (a slope or a crater's edge). The striker is never in the air above or below its target.
- **The placement is a real move on 5% of strikes.** The striker travels over 100 u on its contact tick in 167 strikes, and over 250 u in 69 (2.2%). These are catches of launched bodies, where the chase is already that fast. Before, 4 strikes did.
- **The 10 other swaps** are exchanges that start with the pair stacked almost on one x, and one launched body.

| Match level (200 matches, seeds 1 to 100 per arm; before is the landing mix, `93d5e0d`) | Before | After |
| :--- | ---: | ---: |
| Match median, default / swap | 7:24 / 7:14 | 7:07 / 7:00 |
| KAI, default / swap arm | 64% / 50% | 56% / 51% |
| Chain links per match | 59 to 61 | 53 to 56 |
| Melee exchanges per minute | 19.7 | 20.2 |
| Beam outcomes, CLASH / HIT | 33% / 39 to 47% | 37 to 40% / 36 to 45% |
| Structures lost at the KO | 18 to 19% | 18 to 23% |
| MOUNTAINSIDE, share of launches (forward only now) | 23.4% | 14.5% |
| Landings: slide / slam / caught / brunt / water | 59.0 / 13.2 / 17.7 / 3.8 / 2.6% | 56.0 / 14.0 / 19.6 / 4.1 / 2.7% |

The melee mix is unchanged (every branch within 1.0 point).

## What this needs from others

- **Combat:** done. The step-around's length, rise and end distance are on the `dodge` beat (`dur` from `tempo.stepAround` 8, `rise` 98, `off` 74), and the placement limit is `contact.placementReaches` (3). The director reads all four from the data. `stepAround` must stay at 9 ticks or under, because DODGE & COUNTER's step-in starts 9 ticks after the dodge. The two ticks of the target's flight added to the placement limit stay in code.
- **Combat and Game Design:** with forward-only launches a building or a slope behind the launcher needs a throw that turns first. Until then brunt launches are rarer.
- **Animation:** the step-around is a `rush` event for the defender over the attacker, then a second move down. The parried string now ends on the parry's tick, so no phantom blows remain.
- **QA:** the reach check as a band: 100% within 68 u; another height only on sloped ground.

## The wound region, picked at plan time (for M0)

Today the region is drawn after the hit, by the attack's weight, and the animator picks its key set separately. A jab can show a hit to the head while the wear goes to the arms.

**How it would work**
1. When an exchange is planned, each strike beat gets a region: a keyed draw, `SimRng.keyed(seed, "region", ex.n × 16 + strike index)`, over the same weights the damage code uses today (weight class, the "go for the wound" bias, the crippling rule). It never touches `S.rng`, so no other draw moves.
2. The region rides the strike as `o.region`, next to `o.class`. Chain links and finisher strikes get theirs when they are planned.
3. `SimDamage.hit` uses `o.region` when it is present and draws as today when it isn't (impacts, beams, old profiles).
4. The `strike` beat and the `damage` event already reach the animator, which picks the key set by region: head is jab, hook or upper; core is cross, kick or round.

**What it needs:** Simulation's lines in `damage.gd` and `wounds.gd` (accept `o.region`; expose the weights as a function the planner can call), and Game Design's word that "go for the wound" becomes a weight at plan time. When Combat's composer picks pieces (limb and target), the region follows the piece's target and the keyed draw goes away.
