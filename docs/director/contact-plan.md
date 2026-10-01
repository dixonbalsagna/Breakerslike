# Contact: full contact on every hit, and no passing through

Owner: Encounter Systems Director. Date: 2026-10-01. Status: built and measured on a scratch copy (HEAD `13540bf` plus step 2b and the landing mix); applied to the tree when the EP opens the slot.

**Why.** Orb wants full contact on every hit and no passing through. Animation measured 41% of hits beyond a hand's reach (68 u) and 45 side swaps in 4 seeds. Combat's data closes the strings (`docs/combat/contact-spacing.md`, the parked contact files). This is the sim side, section 5 of that note, plus the dodge as a physical move and the parry fix of section 7.

**The rule.** On every damaging strike's contact tick the two fighters are within 68 u, at the same height, on known sides.

## What the director does

Everything below runs only in a profile with a `contact` block (`dynamic`). The old profiles keep facing-based offsets and the blink, so `parity` stays bit-identical.

| # | Rule | How | Where |
| ---: | :--- | :--- | :--- |
| 1 | **Offsets by side, not by facing** | A `rush` or `finRush` ends on the mover's own side of its target, along the shortest arc. Only `"side": "cross"` changes sides. A target that is in a move of its own is read at that move's end, so a re-close during a dodge takes the side the pair will end on | `melee.gd` `sideOff`; the `rush` and `finRush` ops |
| 2 | **The strike places the striker** | A closing move ends on the strike's tick, but the target steps after the mover, and a launched body flies 130 to 500 u in a tick. So a damaging strike puts its striker at the contact offset (58 u), on its own side, at the target's height. The limit is 3 reaches plus two ticks of the target's flight. Past it nothing moves and the feed says OUT OF REACH | `melee.gd` `_contact`, called by `strike` |
| 3 | **No overlap** | No move ends inside `minSeparation` (45 u). Two bodies at rest closer than that, at the same height, are moved apart evenly, each on its own side. A body in an authored move or in flight is left alone | `sideOff`; `melee.gd` `contactTick` |
| 4 | **Facing follows the opponent** | Every tick of a melee exchange each fighter faces the other | `contactTick` |
| 5 | **The reach check** | The feed line OUT OF REACH names any strike that could not be placed. QA's probe can read the distance and the height difference at each `damage` event; mine is `reach.gd` (numbers below) | `_contact` |
| 6 | **A parry ends the string** | When a parry lands, every pending beat is dropped and the chain window is closed, so the exchange ends that tick. Only in profiles with a `parry` block | `melee.gd` `strike` |
| 7 | **The dodge is a step-around** | Teleporting is on hold, so the `dodge` beat with `"side": "cross"` is two short moves: over the attacker (1.3 body heights above it; under it at the flight ceiling) and down behind it, 74 u away at its height. 8 ticks in all, unless the beat gives `dur`. No draw | `melee.gd` `opDodge`, `opDodgeLand` |
| 8 | **No launch goes back through the launcher** | The planner offers a building or a mountainside only on the far side of the rival. Before, a MOUNTAINSIDE or BUILDING SMASH behind the launcher sent the body through it | `launch.gd` `chooseLaunch` |

## Results

12 AI matches, seeds 1 to 12, every damaging melee strike. Before is step 2b plus the landing mix on the live data.

| Measure | Before | After |
| :--- | ---: | ---: |
| Strikes beyond 68 u | 38.7% of 4,452 | **0 of 4,561** |
| Strikes at another height (over 17 u) | 16.1% | 1.1% |
| Strikes with the bodies overlapping (under 45 u) | 1.1% | 0 |
| Farthest strike | 6,082 u | 68 u |
| Side swaps inside exchanges | 1,590 | 627 |
| ... in the three DODGE branches (the authored cross) | 1,109 | 622 |
| ... anywhere else | **481** | **5** |
| Time an exchange stays open after a parry | 1.78 s | 0 |
| OUT OF REACH lines | | 0 |

- **The 1.1% at another height** are all terrain: the higher fighter is standing on ground that is higher than its rival (a slope or a crater's edge). The striker is never in the air above or below its target.
- **The placement is a real move on 5% of strikes.** The striker travels over 100 u on its contact tick in 225 strikes, and over 250 u in 108 (2.4%). These are catches of launched bodies, where the chase is already that fast. Before, 9 strikes did.
- **The 5 other swaps** are exchanges that start with the pair stacked almost on one x.

| Match level (200 matches, seeds 1 to 100 per arm; before is the landing mix) | Before | After |
| :--- | ---: | ---: |
| Match median, default / swap | 9:22 / 9:35 | 9:30 / 9:22 |
| KAI, default / swap arm | 66% / 58% | 57% / 59% |
| Chain links per match | 78 | 75 |
| Melee exchanges per minute | 20.1 | 20.7 |
| MOUNTAINSIDE, share of launches (forward only now) | 24.3% | 14.6% |
| Landings: slide / slam / caught / brunt / water | 60.3 / 13.3 / 14.8 / 2.9 / 3.8% | 56.4 / 14.5 / 18.1 / 4.0 / 3.4% |

The melee mix is unchanged (every branch within 0.6 points).

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
