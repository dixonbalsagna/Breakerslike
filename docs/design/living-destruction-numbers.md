# Living destruction: the numbers

Owner: Game Design. Status: starting values for World's build (LD1 to LD3). Date: 2026-09-29.

Game Design's numbers for World's living destruction (`docs/world/living-destruction.md`). Orb picked:
- fire, plus smoke and dust cover, with cover made and taken;
- landslides;
- lava, quakes and rifts, at tier 4.

Orb's framing: "as the fighters power up, the destructiveness should keep scaling… not 'map painting' but interfering and actively engaging with a real landscape."

Every value is a named constant in data or in `sim/world/`, and a starting value that QA tunes against the bands in `balance-targets.md` §11. Distances are world units, times are seconds, and "tier" is the higher tier of the fighter who caused the event.

## 1. Rules that hold for every effect

1. **The land wounds; only a rival breaks.** Hazard wear follows the Wounds rules, but hazards alone can never take a region past battered (89). This matches the chain rule in `balance-targets.md` §5b. Breaks, the brink and the finisher stay in the fighters' hands.
2. **Cause is inherited.**
   - Every effect is credited to the fighter whose event started it: the igniting blow, the crater that opened a slope, the breach that exposed lava, or the blow that tipped a quake's stress.
   - Spread and knock-on effects keep the original cause. Fire that spreads from lava is credited to whoever breached the lava.
   - Casualties then feed menace and anguish through the standing per-casualty rule, and the roster's meters later.
3. **Collateral always counts.** Casualties and structure losses from these effects count toward every band in `balance-targets.md` §4, fall under World's tier-scaled caps and casualty ramp, and are never exempt.
4. **The low-tier bleed stays intact.**
   - At tier 1 every effect is decoration or cover only: no casualties.
   - At tier 2, fire burns trees only; roofs catch from tier 3. A tier-2 slide has a budget of 2% of the population. Both fit inside the 4%-per-minute low-tier cap.
5. **The readability cap.** Effects never bury the fight:
   - At most **3 active hazard fronts** (fires, slide fronts, lava flows) inside the camera's framing at once. Further ones wait, or merge into the nearest front.
   - **Fighters and their auras always draw above clouds, smoke and dust,** with an outline. Clouds block line of sight for lock-on, never from the players' eyes.
   - No new hazard starts during a finisher or a respected cinematic; it waits until the cinematic ends.
   - Camera shake from quakes stays within Camera's cap. Effects stay within VFX's budgets.
   - Hazards cause at most **15% of all wear** in a match. The fighters decide the fight.

## 2. Fire (LD1)

| Tier | What happens |
| :--- | :--- |
| 1 | Sparks. A hit tree may burn out on its own, with no spread |
| 2 | Spreading fire through trees. Roofs do not catch |
| 3 | Faster spread, and village roofs catch |
| 4 | Firestorm: a larger ignition reach and its own wind |

| Constant | Value | Notes |
| :--- | :--- | :--- |
| Ignition | Fire-capable damage at a tree of at least its resistance, which runs from 0.6 to 1.4 × base and is fixed by the world seed. The base is set so that a tier-2 beam path, a tier-2 blast or a ground tier-up ignites, and a tier-1 event only sparks | Sources: beam paths (FIRESTORM most), blasts, ground tier-ups, clash shockwaves, lava |
| Tree burn time | 6 s, then ash. Ash is never canopy cover again | "Cover taken" |
| Spread (tier 2) | A neighbour within 60 units catches after 1.5 s, or 1.0 s downwind and 2.2 s upwind | About 40 units per second downwind |
| Spread (tier 3) | Catches after 1.0 s | Roofs catch from burning trees or houses within 60 units |
| Spread (tier 4, firestorm) | Within 90 units, after 0.7 s | About 130 units per second |
| Wind | One seeded direction per match, drifting slowly; 30 units per second for cloud drift | Deterministic |
| House fire | 10 s; 5% of max HP per second; casualties by the standing damage rule | From tier 3 only |
| Simultaneous burning trees | At most 24 on screen (readability) | Further ignitions queue |
| Hazard wear | 2 per second to the legs and 1 to the core while in fire at low altitude. A launch through fire adds 6 to the region hit | Stops at once on leaving |

## 3. Smoke and dust, and line-of-sight blockers made and taken (LD1)

Hiding is removed (Orb). Every "cover" in this section now means a **line-of-sight blocker** for lock-on (`spec-wounds.md` §1c): bowls, rubble, canopy, clouds and terrain. Burnt canopy and slid ridges stop blocking sight.

| Tier | Cloud radius | Life | Cover? |
| :--- | :--- | :--- | :--- |
| 1 | 40 | 2 s | No (too small) |
| 2 | 90 | 5 s | Yes |
| 3 | 180 | 8 s | Yes |
| 4 | 320 | 12 s | Yes, a bank you can lose a fight in |

- **Spawns:** craters (radius scales with the crater), building collapses, and fire (one smoke cloud per burning cluster, renewed while it burns). There are at most 16 clouds, of which at most 6 are big enough to block line of sight.
- **Life:** each cloud drifts downwind at 30 units per second, and shrinks over the last 40% of its life.
- **Line of sight** (hiding is removed; `spec-wounds.md` §1c):
  - *Blocking:* a fighter at least 30 units inside a blocking cloud blocks the opponent's line of sight.
  - *Breaking lock:* an ESCAPE fighter breaks lock after 0.9 s without line of sight, for up to 4 s.
  - *Inside a cloud:* the hunter regains lock within 120 units instead of 240.
  - *No recovery bonus and no ambush.*
- **Cover made:**
  - *Bowls* from tier 2: crater relief of at least 1.5 bh, where bh is World's building-height unit.
  - *Rubble heaps:* a heap at least 1 bh high (bh is one fighter's height) blocks line of sight for a fighter low beside it, at any tier. With World's implosion heaps (`docs/world/buildings-in-depth.md` §4c), house heaps (0.5 to 0.6 bh) never qualify, and tower heaps (about 2.7 bh, up to 6 bh) do. The height rule does the gating, so there is no separate tier gate.
  - *Slide debris* where a slide piles up (§4).
  - `nearestCover` reads the live state.
- **Cover taken:**
  - Burnt canopy is gone for the match.
  - A slid ridge loses its ridge cover where it fell.

## 4. Landslides (LD2)

| Tier | What happens |
| :--- | :--- |
| 1 | Scree: a cosmetic slip with no push, no damage and no casualties |
| 2 | Real slides. The front moves at 300 units per second. Houses at the foot can be flattened; towers are only damaged. A budget of 2% of the population per slide |
| 3 | The front moves at 450 units per second. The toe can bury a fighter. A budget of 5% per slide |
| 4 | A peak collapses. The front moves at 600 units per second and destroys everything in its path for up to 800 units. A budget of 10%, and at most one per match |

- **Trigger:** a hit, a crater or a beam trench that leaves a slope steeper than the angle of repose (World's `REPOSE`). Mountain slopes are generated just under it, so a tier-2 blow there can set one off.
- **Carry:** a fighter caught in the front is pushed along the slope at 0.8 × the front's speed. Dashing out works.
- **Hazard wear:**
  - In the front: legs 6 and core 3 per second (a carry usually lasts 2 s or less).
  - Buried at the toe (tier 3 and up): core 12, once, and stuck for 1 s.
- **Buildings in the path:** they take the front's mass flux (World's formula), within the tier budget above. A slide that would exceed its budget stops at the budget line.

## 5. Quakes and rifts (LD3, tier 4)

- **Stress** builds in coarse cells of about 600 units on today's planet (World's grid, scaled to the planet):
  - each ground crater adds (radius × depth) / 1,000;
  - a ground tier-up adds 10;
  - a slide adds 5;
  - it decays at 1% per second.
- **Cracks** show at stress 30 or more, at any tier. They are the visible warning.
- **A quake** needs stress of 100 or more in a cell **and** a fighter at tier 4. Then:
  - a 3 s rumble countdown (the warning the AI and the player can use);
  - the fault steps 1 to 3 bh along a line placed by the cell's hash;
  - buildings take shaking damage of 30% of max HP for towers and 10% for houses;
  - fighters on the ground in the cell stagger for 0.5 s, with no wear;
  - the cell's stress resets to 20.
- **A rift** needs stress of 150 or more and a fighter at tier 4. A chasm opens across the cell. A fighter launched into a rift takes 10 wear to the core, once, and climbs out.
- **Limits:** at most 2 quakes and 1 rift per match. None during a finisher or a respected cinematic.

## 6. Lava (LD3, tier 4)

- **Onset:** a tier-4 crater deeper than the column's crust.
  - *Crust:* thick in mountains, thin in plains, desert and on the ocean floor.
  - *Plains, desert and the ocean floor:* a tier-4 beam impact or a tier-4 launch impact at 2,500 units per second or more breaches them.
  - *Mountains:* only a finisher-class blow breaches them.
- **Flow:**
  - It starts at 60 units per second and slows as it cools.
  - It hardens to rock in 20 s. Cooled lava raises ground and can seal a valley ("cover made").
  - It ignites trees and houses it touches, under the fire rules.
- **Hazard wear:**
  - In lava: legs 4, core 2 and arms 1 per second.
  - Landing in lava: core 15, once, and the fighter is thrown clear.
- **Limit:** at most 3 lava events per match.

## 7. How often each effect should trigger

These are game-scale bands per 1v1 match, and QA checks them in `balance-targets.md` §11:

| Effect | Band |
| :--- | :--- |
| Spreading fires (tier 2 and up) | 0.5 to 3 per match, in matches with at least 5% of fight time in forest or villages |
| Forest burnt by the end, among matches that reach tier 3 | 15 to 60% of the forest's trees |
| Clouds that block sight | 3 to 10 per match |
| Real slides (tier 2 and up) | 0.5 to 2 per match, in matches with at least 10% of fight time in mountains. At most 1 peak collapse |
| Quakes | In 30 to 70% of the matches that reach tier 4; at most 2 per match. Rifts at most 1 |
| Lava events | 1 to 3 in the matches that reach tier 4 |
| Hazard wear | At most 15% of all wear in a match |
