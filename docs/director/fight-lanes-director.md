# Fight lanes: the director's part (ADR 0009)

Owner: Encounter Systems Director. Status: plan only, no edits. It answers the six asks in Simulation's `docs/architecture/fight-lanes.md` §8, and it is the plan for slice L4 (the switch-on) and L5 (beams in depth).

**Orb's rules.**
- Every smash, launch and throw gets a slight variation of angle, so fights zigzag a little.
- Larger deviations happen only when a building or another dynamic blocker is targeted.
- The player never steers depth.

Units: 1 bh is 75 units. The band is 32 bh deep, +5 to -27 bh.

## 1. The default deviation

**What it is.** A target depth for the end of the flight: Simulation's waypoint `aimZ1`. It is never an angle, so no trigonometry enters the sim.

**Size, by kind of blow**

| Blow | Deviation, bh | Why |
| :--- | :--- | :--- |
| A shove or knockback (no launch), a burst's push | 0.3 to 1.0 | The fight shuffles |
| SLAM DOWN and UPPERCUT (mostly vertical) | 0.3 to 1.2 | Short flights |
| SMASH ACROSS, MOUNTAINSIDE, a throw, a break or finisher launch | 0.6 to 2.5 | Long flights carry more |

A front street is 9 bh wide and a back street 6 bh, so a few blows in a row cross it without leaving it.

**Distribution.** `min + (max - min) × u²`, with `u` a keyed draw. Most deviations are small, and a few are near the top of the range.

**Sign: the zigzag.** The second keyed draw picks the side. It leans back toward the lane's centre line as the fighter nears an edge:

`P(toward the centre) = 0.5 + centrePull × |offset| ÷ half-width`, with `centrePull` 0.4.

So a fight wanders across the street and comes back, and doesn't hug a kerb.

**Bounds.** The result is clamped inside the lane the flight started in, less a 0.5 bh margin: a small deviation never leaves the street. In open country it is clamped to the band.

**Draws.** `SimRng.keyed(seed, "depth.mag", ex.n)` and `"depth.side"`, plus `ex.combo` for chain links. They never touch `S.rng`, so switching depth on doesn't reorder any other draw.

**Hero and villain.** No difference in the small deviation: it is texture. Personality shows in the targeted ones.

**Targeted deviations.** Only a BUILDING SMASH (B2's aim, any row), or a throw or launch aimed at a formation or a prop (P1), leaves the lane. The launch planner scores them as today. The depth is the target's footprint, from `WorldBrunt.aim`.

## 2. Alignment before an exchange

- **Who moves:** the attacker. Attacks close the gap (pillar 3), in depth as in x. At `requestAttack`, `ex.z` is the defender's depth.
- **How fast:** inside the approach, the 0.25 to 0.65 s rush or the 0.8 to 2.0 s pursuit flight. The rush homes in `z` as it does in `x` and `y`. No extra time, no extra beat.
- **Where:** wherever the defender is. That is usually a street, because small deviations stay in the lane. After a targeted smash it can be inside a block row, in the wreck. The exchange is fought there. Pulling the defender out first would be the "invisible hand" the ADR removes.
- The defender doesn't move to align. Counters and clashes happen at `ex.z`.

## 3. A rush with a footprint in the way

- **Default: plough through** (the prototype Orb liked; the EP's ruling 2). The rush takes its straight line, and each footprint it crosses takes a brunt hit (`WorldBrunt.hit`) at the attacker's tier, paid from the collateral budget like any brunt.
- **The protector goes over when it can.** A fighter with care above 0 arcs the rush over a building whose roof is within `overMaxBh` (6 bh) of the path. It uses the `rush` `arc` argument Combat's variety pass already asks for. Otherwise it ploughs, and its anguish pays.
- **Cost:** one swept test along the rush line at the request. In a city the streets are clear, so this only happens when the defender rests inside a block row.

## 4. Where a fighter stays after a flight

- **Where it landed.** `zT` is the landing depth. Nothing eases it back to the centre line or any other line.
- **Inside a block row,** after a targeted smash: it stays in the wreck while it is down or locked. When it is next free and moves, `zT` becomes the nearest point of the adjacent street, 1 bh in from the kerb, eased at the free rate: it steps out of the rubble into the street. That is an exit to the nearest open ground, not a return to a line. Without it, a free fighter would slide along walls inside the row (ruling 2), with no way for the player to leave.
- **Open country:** it stays where it landed, anywhere in the band.

## 5. The data file and the debug feed

**File:** `data/director/depth.json` (my path, beside `location.json`), with Tools' schema `director-depth.schema.json` in the same commit. Simulation suggested `data/combat/`. These are director policy, not Combat's choreography, so I would keep them with the director's data.

| Key | Value | Meaning |
| :--- | :--- | :--- |
| `enabled` | false until L4 | The switch: with it off the director passes zero everywhere |
| `deviation.shove`, `.vertical`, `.long` | [min, max] in bh | Section 1's table |
| `deviation.power` | 2 | The exponent on the draw |
| `deviation.centrePull` | 0.4 | The lean back toward the centre |
| `deviation.laneMarginBh` | 0.5 | Kept clear of the lane's edge |
| `rush.plough` | true | Section 3's default |
| `rush.overMaxBh` | 6 | The protector's arc limit |
| `rest.blockExit`, `rest.exitMarginBh` | true, 1 | Section 4 |
| `predictor.maxFlights`, `.maxAims`, `.maxSteps` | 12, 16, 3000 | Section 6 |

**Feed lines** (the debug overlay; one per decision):
- `DEPTH small -1.4 bh (toward centre, lane front street)`
- `DEPTH target building 212 in block row 1 (-8.0 bh)`
- `ALIGN to -2.1 bh (the defender)`
- `RUSH ploughs building 77`, or `RUSH over building 77 (+3.2 bh)`
- `REST exits to the back street (-12.9 bh)`

`launch_plan` lists each candidate's end depth after its score.

## 6. The predictor's cost budget

Per launch decision:
- at most **12** predicted flights and **16** aim solves (B2's brunt candidates);
- at most **3,000** predictor steps in all;
- **one** gather of the footprints near the launch point, sorted along the flight and reused by every candidate (the pointer walk the predictor had before B2).

Target: 0.3 ms typical and 1 ms worst on the reference laptop. Today's sim tick is about 0.08 ms on average and 0.3 ms at p99, and a decision comes about ten times a minute.

**What keeps it cheap.** A small deviation stays in its street, and World guarantees streets are clear. So a non-targeted flight in a city needs no footprint test at all. The swept test runs only for targeted candidates, and in open country where formations or props stand. If a decision would exceed the budget, the lowest-scoring brunt candidates are dropped first. That is logged, not silent.

## 7. What changes in the control-scheme steps 2 to 5

| Step | Change |
| :--- | :--- |
| 2: request-only counters, the queue | `requestAttack` sets `ex.z`. Queued requests carry no depth. No rule changes |
| 3: interrupts | A dodge cancel and a burst separate the fighters in x and keep `z`. The burst's shove takes the small "shove" deviation. A reversal is a throw: the small "long" deviation, or a targeted one |
| 4: entry, mode, the AI, the Simple assists | Entries act in x: a rush homes in `z`; stand and retreat keep `z`. Blink slots stay in the x-y plane at `ex.z`. Context actions: a throw takes a throw's deviation, or targets a building or prop. Picking up a prop aligns the fighter to the prop's depth, done by the director and never by the player. The AI never plans depth, and `DirLocation.roam` stays one-dimensional |
| 5: variety | Volleys and beams travel in depth to the target (L5): the beam plan sets `oz` and `zs` from both fighters' depths, and a beam clash meets at the interpolated depth |
| The launch planner | Every candidate gains an end depth. SMASH ACROSS runs the length of its street. BUILDING SMASH is the only launch that leaves the lane |
| Location variety | Unchanged: the biome record and the roam work in x |

## Needs from the EP
1. **Simulation:**
   - the waypoint on every flight (L2);
   - a `zT` the director may set (the block exit);
   - `ex.z`;
   - the keyed draws, which exist.
2. **World:**
   - a lane lookup, `WorldLanes.at(x, z)`, returning the lane, its bounds and whether it is a street;
   - the nearest street from a block row;
   - the swept test for the rush line and the predictor.
3. **Tools:** `director-depth.schema.json`.
4. **Combat:** the `rush` `arc` argument (variety pass, row 2) before L4, for the protector's rush over a roof.
5. **Game Design:** confirm three choices:
   - the protector going over and the feeder ploughing (section 3);
   - exchanges fought inside a block row (section 2);
   - the sizes in section 1.
