# Agency: evidence and architecture for the director

Owner: Encounter Systems Director. Date: 2026-10-02. For Game Design's `docs/design/agency-pass.md` and Orb's questionnaire 14. Scratch and docs only: nothing in the tree's sim was edited.

Measured on a clean copy of HEAD `8fd6aba` (the sim and data are the same at `21d8b44`): 100 AI matches, seeds 1 to 100, 730 minutes, 17,349 exchanges; and 40 matches with a scripted human defender for the press test.

## 1. The numbers

### How a brawl ends

A brawl here is one melee exchange with its chain links (16,997 of them). Each is classed by what ended it.

| A melee exchange ends in | Share |
| :--- | ---: |
| **A launch** | **36.3%** |
| A shove with no launch (the planner chose to hold back) | 12.6% |
| A hit that leaves both in reach (a light CLEAN HIT or RIPOSTE with no follow-up, a CLIPPED blow) | 14.6% |
| A perfect block | 10.3% |
| A blocked string (PRESSURE — GUARD HOLDS, no interrupt) | 6.8% |
| A reversal or a burst | 7.0% |
| A whiff (DODGE — CLEAN, the target slips away) | 10.2% |
| A clash that throws both back (CLASH SHOCKWAVE) | 1.0% |
| A finisher or a limb break | 1.0% |

- **When the attack lands and runs its course, 73% end in a launch and 25% in a shove.** That is Orb's "every brawl seems to end in a launch": a fight that isn't blocked, dodged or cut short almost always ends by sending someone away.
- **No trade ends level.** TRADE BLOWS is 6.7% of exchanges; 54% of them end in a launch, 24% in a shove, and 21% are perfect-blocked at the opener.
- **Against QA's figure.** Game Design's page quotes 64.6% of exchanges ending in a launch. That is on another base. Per exchange started it is 36%; per exchange that landed, 73%.
- **Exchanges per launch: 1.8.** There are 13.0 launches a minute. 39.4% of exchanges hold at least one launch, and those hold 1.37 each (chain links are 0.28 per exchange).
- **How the launches' journeys end** (same build, by World's `journey_end`): halt 42%, caught in the air 25%, slam 16%, wall 14%.
- The planner's "no launch" wins 26% of its decisions (3,111 of 12,174). That shove is what a knockback slide could be.

| By exchange | Share of exchanges | Ends in a launch | In a shove | Chain links each |
| :--- | ---: | ---: | ---: | ---: |
| CLEAN HIT | 26.7% | 51% | 17% | 0.57 |
| PRESSURE — GUARD HOLDS | 12.9% | 0 | 0 | 0 |
| RIPOSTE | 10.2% | 48% | 15% | 0 |
| GUARD BREAK | 9.6% | 29% | 10% | 0.25 |
| DODGE & READ | 7.3% | 52% | 14% | 0.67 |
| TRADE BLOWS | 6.7% | 54% | 24% | 0.28 |
| PURSUIT — CAUGHT | 3.9% | 68% | 26% | 0.61 |
| DODGE & COUNTER | 3.5% | 66% | 32% | 0 |
| HEAVY CLASH (won or countered) | 3.7% | 73% | 19% | 0.22 |

### The lock during an approach

Both fighters are locked from the press until the exchange ends. The approach is the time from the press to the first blow.

| Distance at the press | Share of exchanges | Approach, median | p90 | Whole exchange, median | p90 |
| :--- | ---: | ---: | ---: | ---: | ---: |
| In reach (under 260 u) | 36% | 15 ticks | 15 | 56 ticks | 116 |
| 260 to 1,000 u | 25% | 15 | 22 | 65 | 126 |
| 1,000 to 4,000 u | 21% | 39 | 63 | 80 | 148 |
| **4,000 u and over** | **17%** | **120 (2.0 s)** | 120 | 162 (2.7 s) | 217 |
| All | 100% | 16 | 120 | 71 | 163 |

- **38% of exchanges start from 1,000 u or more:** 68 a match, 30 of them from 4,000 u or more with a full 2 s fly-in.
- **Both fighters are locked for 56% of the match.** 45% of that locked time is approach: **15 seconds of every minute** are spent with one fighter flown in by the director and the other frozen.
- The longest approach was 153 ticks (2.5 s).

### What a press does during an approach

A scripted human defender made one press at a random tick of each approach against him (40 matches, about 1,270 presses of each kind).

| Press | Did something | What |
| :--- | ---: | :--- |
| **Move** (stick, sprint away) | **0%** | A locked fighter ignores movement. He cannot leave |
| **Attack** | **0%** | The exchange was planned at the press. His own press waits in the queue, and expires after 36 ticks unless he is in a beam's tell |
| **Guard** | 21% | Only inside the perfect-block window, the last 12 to 14 ticks. A guard raised earlier does nothing: the blow uses the stance he held when the attack was pressed |
| **Dodge** | 98.5% | The dodge-cancel: the exchange ends with no winner. It costs 15 ki and has a 3 s cooldown, so it is not a free answer |
| Power tap (the burst) | not sampled | 30 ki, 8 s |

So during a 2 s fly-in the defender's stick and attack button are dead, his guard matters only at the very end, and his one real out costs ki. The attacker is in the same position: he cannot steer, and his only out is the same 15 ki dodge-cancel.

## 2. The ranged lockout: what makes it, and three sizes of fix

**What makes it** (`sim/director/exchange.gd` `_start`, `data.gd` `planMelee`):
1. **The whole exchange is planned at the press.** The template and its branch are chosen from the defender's state on that tick, and every beat is scheduled then.
2. **Both fighters are set to `locked` at the press,** and the stances are frozen for the exchange (`ex.sA`, `ex.sD`), so a guard raised later is not a guard.
3. **The approach is the first beat of every template:** a director-flown `rush` of 15 to 39 ticks inside 2,500 u, and a pursuit flight of 48 to 120 ticks beyond it. Every later beat is timed from its end.
4. **One exchange runs at a time,** so the defender's own attack cannot start.

| | (a) The defender acts during the approach | (b) The attacker cancels or steers | (c) A player-flown dash, handed over at contact |
| :--- | :--- | :--- | :--- |
| **What changes** | The exchange has two phases. At the press only the rush starts, and the defender stays free. At the wind-up (15 to 20 ticks before contact) the director locks him, reads his state and his press, and plans the rest | The attacker's dodge-cancel is free until his first wind-up starts. The stick during the rush picks his arrival side and height | A press beyond a set range starts no exchange. It arms the attack and the fighter flies in himself, at dash speed, steering. The director takes over inside contact range, with only the wind-up left |
| **In the code** | `_start` splits: an `engage` beat does today's lock, snapshot, `react` and plan. Templates are scheduled from the wind-up, not from the press | `DirInterrupt.dodgeCancel` skips the cost for the attacker before the first wind-up; `sideOff` reads the stick | The queue keeps an armed request while he charges; `_start` waits for range; the pursuit block of the approach goes away. The charge's movement is the fighter's own flight |
| **Size** | About 150 lines in the director | About 30 lines | About 200 lines in the director, plus the charge movement |
| **Needs from others** | A new event at the engage (the `attack` event's template and defender state are not known at the press any more): Simulation's lines, and every reader of `attack` (HUD, Camera, Animation, QA) | Nothing | Simulation: a charge flag in the fighter's movement. Camera: framing a charge. The AI flies its own approach (it already moves toward its rival) |
| **Fixes** | The defender can move, guard, dodge, attack back or leave until the wind-up. A rival who flies off turns it into a chase | The attacker's commitment only | Both. Nobody is flown or frozen before contact range |
| **Leaves** | The attacker is still flown in | The defender is still frozen | Nothing of the lock |
| **Risk** | Medium. A fleeing defender must become a pursuit and not a stretched rush. Two requests meeting mid-air need one rule (a trade) | Low. A free cancel is a free feint; the 0.5 s dodge gap limits it | The highest. Exchanges fall from 24.6 a minute toward the 15 to 24 band, matches lengthen, and every pacing band is re-measured. Pillar 3 holds only if the charge is faster than flight |

**How they map to Game Design's list.** (a) is its B ("the exchange starts at contact") for the defender, (b) is its E's free cancel, and (c) is B in full and the ground Orb's call-out (A) stands on: the taunt is a start-up in front of the charge.

**Order I would build.** (b) first: it is a day's slice and removes the attacker's half of the complaint. Then (a), which removes the defender's and is the base for (c). Then (c) with the call-out, once Orb has answered the questionnaire.

## 3. The fight alchemist: an architecture sketch

**What it replaces.** The request queue (3 presses, first in first out, each one an exchange or a chain link) and the fixed `chainLink`.

### The press log

Each fighter keeps his last presses as state (hashed, so replays and rollback hold).

| Field | Values | Where it comes from |
| :--- | :--- | :--- |
| Tick | | the press |
| Weight | light, heavy | the button |
| Family | physical, energy | RB held (the mode field today) |
| Direction | toward, level, away; and the tilt in 8 directions | the stick, relative to the rival along the shortest arc |
| Rhythm | plain, held, mashed, timed | **held:** the layout's hold edge (12 ticks). **mashed:** three presses inside 20 ticks. **timed:** within 4 ticks of one of his own blows landing; the director knows every blow's contact tick from the beat list |

- **The window** is the last three presses, each gone after 90 ticks.
- **The running mix** is counters over his last 20 presses (lights, heavies, energy, toward and away, each rhythm). The latest three against the mix gives *change-up* (wind-up 3 ticks shorter) or *repeat* (step 3's staleness).
- It fits in the director's per-fighter integers (`act.dirI`) or a small array of its own beside the queue. That is Simulation's choice.

### Choosing the string

- **A phrase at a time.** Today an exchange is planned whole at the press. With the alchemist it is planned one phrase at a time: one to three strikes, about 0.3 to 0.6 s. At each **decision tick** (a few ticks before the next wind-up starts) the director reads both windows again and schedules the next phrase: carry on, change kind, or end.
- **The recipe is a table, not a roll.** `recipe(my window, my mix, his window, his mix, his held state)` is a lookup in data: heavies in the last three (0 to 3) picks the kind (flurry, blur combo, bruiser string, power blow); the last press picks the ending (stay in reach, or knock away); direction picks press forward, stand and trade, or give ground; rhythm picks charged, fast and weak, or clean.
- **No draw decides an outcome.** What the player can predict (weight, count, ending, direction) comes only from presses and state. Keyed draws (`SimRng.keyed`) choose only among equal pieces: which limb, which strike.
- **Both attacking** is one more table (Game Design's two-by-two): blur exchange, fist clash, or lights racing a heavy. These need the pulse op and the clash score as state (M0).
- **The seed already exists.** A chain window is a decision tick, and a chain link is a phrase picked from the queue. The alchemist makes every string work that way and replaces "the next queued press" with "the recipe of the window".
- **The feed** prints each decision: both windows, the recipe, and why the ending was or was not a launch.

### The stick and the launch

- At a launch or knock-away beat the planner reads the attacker's tilt. Screen directions are world directions in this side-on view, in both split-screen panes.
- **With a tilt:** only candidates within 45 degrees of it compete. If none qualifies, the planner makes one along the tilt and scores its predicted flight like any other. The collateral budgets still apply.
- **No tilt:** today's planner.
- **Each return blow of a juggle** reads the tilt again; a launch beat already runs per link.
- A tilt back through the launcher is the turning throw (ruled, M0). Until then it is clamped to straight up or down.
- The AI's "tilt" is its personality term, as today.

### What the intent queue becomes

A three-press window that is read, not drained. The first press with no exchange running still starts one. Presses inside an exchange are ingredients for the next decision tick. Guard, dodge, power and context keep their step-3 handling.

### What Combat must supply

1. **Phrases:** beats for each string kind (flurry, blur combo, bruiser string, power blow, the kiting set), with strike classes, wind-ups and step-ins, and three endings each: stay, knock away, launch.
2. **The recipe table** as data, and the join rules between phrases (a phrase changes range band at most once).
3. **The both-attacking exchanges:** the blur exchange, the fist clash and the lights-against-a-heavy race, with their pulses.
4. **Rhythm variants:** the charged blow, the mashed flurry, the timed clean hit.
5. **Knock-back pieces:** the short skid and its reactions.
6. **Per-phrase damage,** so damage per minute holds when strings replace exchanges (QA sizes it).

### Stages

1. The press log, the mix and the feed line, with no change in behaviour. QA and Game Design can then read real play as recipes.
2. The stick-tilt launch (independent of the rest).
3. Recipes for the attacker's string against each held state, with today's templates cut into phrases.
4. The both-attacking table, with M0's pulse op.

## 4. Levers

| Aim | Lever | Where | Size |
| :--- | :--- | :--- | :--- |
| **Fewer launches** | The planner's "no launch" score (`NONE_BASE` 25) is a constant: move it to `launch.json` and raise it | Director data | Small. Today it wins 26% of decisions |
| | **An earned launch:** the `launch` beat launches only when earned (a heavy ender after three landed strikes, a guard break, a launching riposte, a clash won, a rival staggered); otherwise it is a knock-back | Director, with Combat marking the beats | Medium |
| **Knock-backs that skid** | Today's shove adds 700 to a locked body's speed and never enters World's skid. Make the knock-back a low, weak launch along the ground, so the contact model skids it 2 to 8 bh | Director (a planner candidate) | Small |
| **Bigger launches** | Impact wear per launch (about ×1.6, QA sizes it) | World and Simulation data | Data |
| **More traded strings** | A trade needs the defender's own press. The AI defender holding nothing has one in about a fifth of exchanges (Press 11.5% against Neutral 41.2%), although `pressReact` is 0.6: ripostes and punishes skip the reaction, and a staggered fighter has no press. Raise the rate, or let it react in more cases | Director data (`ai.json`) and a few lines | Small |
| | For humans, fix (a) above: a defender who can press during the approach makes it a trade | | |
| | With the earned launch, a trade ends level unless its ender lands after three strikes | | |
| **Air recovery** | Game Design's air brake: a dodge tap from 12 ticks after the launch until the first contact; 10 ticks to right himself, 40% of his speed kept; 15 ki on the dodge-cancel's cooldown | The flight is World's and Simulation's (it is the tech at another moment). The director's part: the AI's rate by level, and closing the chain window on a recovered body | Small for the director |
| **The signature cooldown** | `sigCooldown` 120 in each `fighter.json`. Set to 0 it is off with no code change: three checks in the director read it. The AI then needs its pick rate re-tuned (`sigPick`) | Simulation's data; my AI number | Data. Signatures are 3.5 a match today |
| | Game Design's beam gauge is a new meter: the state is Simulation's, the fill rules (blows landed and taken, clashes, perfect blocks) are the director's, as data | | Medium |
| **More beam struggles** | **A late answer:** accept the answering signature or heavy blast in the first 20 ticks after the beam fires, starting the struggle at -10 | Director (`beam.gd`) | Small |
| | The AI answers on 35% of chances at medium (`beamAnswer`); clashes are about a third of signatures, so about 1.2 struggles a match | Director data | Data |
| | Streams and blast clashes need the energy family (blasts and volleys), which is not built | Combat, World, VFX | Large |
| **Wider beam windows** | **Dodge with no roll:** a dodge tap in the last 20 ticks of the tell or the first 10 of the beam. The outcome is decided at fire today, so the 10 ticks after need the same late decision as the late answer | Director, and Combat's outcome rules | Small |
| | **Perfect block of a beam:** 10 ticks to 14 | `interrupts.json` (a `beam` window) | Data |
| **Walk through and split** | What exists: a perfect block of the fire beat is a DEFLECT (no damage, +8 ki). The beam still fires along its line and nothing changes by the direction held | | |
| | What is needed: the direction sampled at contact (Controls asked; Game Design to confirm), then three results. *Swat* (away): the beam is fired on from the defender at a new angle and carves there. *Split* (level): two thinner beams pass either side. *Walk through* (toward): the defender advances along the beam to contact and has an opening | Director (`beam.gd` fires any ray from any point already). The look is VFX's, the cue names Combat's. The kind goes out in `beam_outcome` | Medium, and it needs no core lines |

## 5. What I would do first

1. **(b):** the attacker's free cancel before his wind-up, and the stick choosing his arrival side.
2. **The knock-back as a skid, and "no launch" as data.** These two move the launch share without waiting for the alchemist.
3. **The press log, read-only.**
4. **(a):** the defender free until the wind-up. It needs the new event, so it needs Simulation and the readers of `attack`.
5. The beam items that are data or small: the cooldown off, the late answer, the dodge without a roll.
