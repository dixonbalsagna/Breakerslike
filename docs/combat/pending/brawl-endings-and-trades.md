# Brawls that end without a launch, and the trade beats

Owner: Combat and Choreography. Date: 2026-10-02. Status: parked data. Nothing here is loaded or hashed, and no live data changed. The data is `templates.brawl.json` in this folder; the tags are in `moveset.antihero.m0.json`. Plan: `../alchemist-content.md` sections 3 and 4.

**Against HEAD `a56187a` (2026-10-03).** The knock-back has landed in the director: its numbers are in `data/director/launch.json` (`knockBack`), the `knockBack` op (args `w`) and the `stagger` op (args `w`, `ticks`) are in `sim/director/exchange.gd`, and the `knockback` event names the four kinds. The data file is updated to match: the four knock endings are one live beat each and keep their looks, and the slide and drift ticks are the director's (18 and 20; the long slide is the skid). The level endings, the trade beats and the double slide are still new. Section 2 below stays as the description of the look. The file's target is a new `data/combat/brawl.json` (`apply-order.md`).

**Why now.** Orb: "every brawl seems to end in a launch", and trades should be flashier. These pieces hold whatever questionnaire 14 answers. **Which one plays when is left out on purpose:** that is Game Design's recipe table. The recipe mapping, the charge, mash and the steered juggle wait for the questionnaire.

## 1. The two tags, on every existing piece
In `moveset.antihero.m0.json`, on all 38 strikes and the 7 throws.

- **`sends`**: where the piece sends the rival, relative to the striker, first choice first. `across` is level and away from him; `up`; `down`; `turned` is away, swung about 70 degrees off his line; `behind` is for the two throws that turn. The stick picks the piece whose direction is nearest the tilt.
- **`ends`**: how a string may end on the piece. `level` for a light: the brawl continues. `knock-back` and `launch` for a heavy: a knock-back by default, a launch when one was earned. A throw is always a launch.

| First direction | Lights | Heavies |
| :--- | ---: | ---: |
| Across | 9 | 11 |
| Turned | 4 | 0 (5 as a second choice) |
| Up | 2 | 2 |
| Down | 3 | 7 |

A ground knock-back needs a piece that sends across: 12 of the 20 heavies can.

## 2. The knock-back vector
A flat, short send: the body slides on the ground or drifts in the air and stops on its feet. Not a launch: no planner candidates, no bounce, no journey.

| | |
| :--- | :--- |
| **Direction, on the ground** | along the ground, away from the striker; the piece must send across |
| **Direction, in the air** | the piece's first direction: across is level, up is 20 degrees above level, down is 20 degrees below |
| **Distance** | 3.5, 5, 6.5 and 8 body heights at tiers 1 to 4. **A proposal for Game Design,** inside its "under about 8 bh". A double slide gives each fighter half |
| **Kinds** | a short slide (under 4 bh, upright); a long slide (4 bh and over: he drops low, a hand on the ground, and World cuts a trench by tier); a bump (an obstacle stops it early: a light brunt, inside the collateral budgets); a drift (in the air: carried back, then upright) |
| **Ticks** | a short slide 18, a long slide 30, a drift 20 |
| **Who is free when** | the one sent is free when it ends; the striker 6 ticks before |
| **The stick** | it cannot turn a ground slide; in the air it picks among the piece's directions |
| **Limits** | never through the striker; no launch's wear; QA counts it apart from launches; it opens no chain window by itself |
| **Event** | `knockback`: who was sent, by whom, the kind, the distance, the start and end ticks |

## 3. The eight endings
Each list starts on the string's last contact tick. Ticks are from that tick.

| Ending | Kind | After | Look | Beats | New poses |
| :--- | :--- | :--- | :--- | :--- | :--- |
| `level.shove_off` | level | a string that ended on a light | The last light is a push: a palm heel or a shoulder check that sets the rival back a step, and both settle at fighting distance. | 0: A strikes D (link, a push); 3: A moves to 150 u over 9; 3: cue reset (both) | none |
| `level.hop_back` | level | a string that ended on a light | Both hop back a step at the same moment and land facing, still in reach. | 3: A moves to 150 u over 9; 3: D moves to 150 u over 9; 3: cue reset (both) | none |
| `level.break_and_circle` | level | a string that ended on a light | Both give a half step and drift a quarter step round each other, eyes locked: the brawl is still on. | 3: A moves to 110 u over 9; 3: D moves to 110 u over 9; 3: cue circle (both) | none |
| `knock.slide_short` | knock-back | a string that ended on a heavy, with no launch earned; on the ground; under 4 bh | The loser is driven straight back on both feet, leaning into it; the winner holds the end of the blow. | 3: D is knocked back (slideShort); 3: cue slide_brace (D); 15: the striker is free | `slide.feet_high` |
| `knock.slide_long` | knock-back | the same, 4 bh and over | The loser slides a long way, drops low and brakes with a hand on the ground, cutting a furrow. | 3: D is knocked back (slideLong); 3: cue slide_brace (D); 27: the striker is free | `slide.feet_high`, `slide.feet_low` |
| `knock.bump` | knock-back | the same, with an obstacle inside the slide's length | The slide ends early against a wall, a formation or a crater's edge: a bump, not a smash. | 3: D is knocked back (bump); 3: cue slide_brace (D); 15: the striker is free | `slide.feet_high` |
| `knock.drift` | knock-back | a string that ended on a heavy, with no launch earned; in the air | The loser is carried back a few body heights, arms out, and rights himself; nobody falls. | 3: D is knocked back (drift); 17: the striker is free | none |
| `knock.double_slide` | double slide | a cross-counter on a string's last beat (PROPOSAL for Game Design) | Both blows land and both fighters slide apart, each braking the same way. | 3: D is knocked back (slideShort, half the distance); 3: A is knocked back (slideShort, half the distance); 3: cue slide_brace (both); 21: the striker is free | `slide.feet_high` |

- **Level endings leave both in reach,** at 110 to 150 u, facing, with nobody ahead.
- **None is a still hold.** Each has a move on every tick it runs, as the live templates do.
- **The slide on the feet** needs 2 poses: high (upright, both feet wide, leaning into the slide) and low (the front leg bent deep, one hand trailing on the ground behind). It is not the skid on the back that follows a launch.

## 4. The six trade beats
One beat in which both fighters act. A is the fighter whose press came first. Strikes are mid-string hits: no perfect-block window. Traded lights do half a light, as Game Design ruled for the blur exchange.

| Trade beat | Ticks | Look | Needs | Beats | New poses |
| :--- | ---: | :--- | :--- | :--- | :--- |
| `trade.exchange` | 16 | One lands, and the other lands back half a beat later. | both in reach | 6: A strikes D (link at x0.5); 13: D strikes A (link at x0.5) | none |
| `trade.cross_counter` | 14 | Both blows land on the same tick and both heads snap. | both in reach; two strikes may land on one tick | 6: A strikes D (link at x0.5, both land); 6: D strikes A (link at x0.5, both land) | none |
| `trade.check_and_reply` | 16 | The blow is stopped on a forearm or a shin, and the checker answers at once. | the checked blow is an arm or a leg strike: an arm strike is checked on the forearm, a leg strike on the shin | 6: A strikes D (link, checked); 6: cue check (D); 13: D strikes A (link at x0.5) | `check.forearm`, `check.shin` |
| `trade.light_clash` | 14 | The two limbs meet between them and both recoil. | both blows from the same limb family (two hands, or two feet); each limb is solved onto the other | 6: A strikes D (link, clash); 6: D strikes A (link, clash); 6: cue clash_light (both) | `clash.recoil` |
| `trade.slip_and_miss` | 14 | One sways off the line; the other hits air and leans too far. | the slipper is not staggered | 6: A strikes D (link, misses); 3: cue slip (D); 6: cue over_commit (A) | none |
| `trade.bind_and_shove` | 24 | A short tie-up, collar and elbow, then one shoves the other off. | both in reach; uses the tie-up of wave 5 and the hold of wave 4 | 0: both hold for 12; 12: A strikes D (link, a push); 15: D moves to 150 u over 6 | none |

## 5. Lights against a heavy
Game Design's rule for a flurry or a blur meeting a bruiser string or a power blow.

| Piece | Rule | Look | Beats |
| :--- | :--- | :--- | :--- |
| `lights_vs_heavy.stuffed` | Game Design (agency-pass.md section 2): three clean lights before the heavy lands stop it | The third clean light lands on the wind-up, and the heavy collapses into a stagger. | 6: A strikes D (link); 12: A strikes D (link); 18: A strikes D (link); 18: D loses its pending heavy; 18: D staggers |
| `lights_vs_heavy.comes_through` | the same rule's other side: fewer than three clean lights, and the heavy comes through | The lights land on a fighter who keeps winding up, and the heavy lands through them. | 6: A strikes D (link); 12: A strikes D (link); 12: A loses its third light; 20: D strikes A (heavy) |

Neither needs a pose. The second needs the reaction-strength input Animation offered: the struck fighter keeps his wind-up and only shudders.

## 6. What this needs
| For | What |
| :--- | :--- |
| **Game Design** | when each ending and each trade beat plays; the knock-back distances by tier; the double slide's trigger |
| **Encounter** | four ops (`knockBack`, `hold`, `stagger`, `drop`); seven strike arguments (`slot`, `o.trade`, `o.checked`, `o.clash`, `o.whiff`, `o.react`, `o.push`); two strikes landing on one tick; chain links that do not launch by themselves |
| **World** | the slide on the feet as a state, with its trench by tier; the bump against an obstacle |
| **Simulation** | the `knockback` event |
| **Animation** | 5 sketches: the forearm check, the shin check, the light-clash recoil, the slide on the feet (high and low). All inside `docs/animation/joint-limits.md`: the slide's width comes from the front leg, since a thigh goes at most 45 degrees back |
| **Tools** | a schema when this lands; 8 tempo names (`linkLoad` 6, `tradeHalf` 7, `checkHold` 4, `recoil` 6, `bind` 12, `shove` 6, `breakOff` 9, `advantage` 6); the slide and the drift are the director's numbers now |
| **Legal** | the slide on the feet is not a landing on one knee and one fist |
| **QA** | exchanges that end level, in a knock-back and in a launch, counted apart |
