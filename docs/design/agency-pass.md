# The agency pass: rules from Orb's first two-player playtest

Owner: Game Design. Orb played two local matches with a second player on 2026-10-02 and then answered questionnaire 14 (`docs/ep/vision.md`, last section). This page turns those answers into rules. Two items are still pitches, because Orb asked for them: the ranged press (§1) and how the alchemist reads timing (§2). Every number is a proposal for data.

**Where the pillars bend.**
- *Pillar 2 (stances, not combos)* bends toward the player. The director still choreographs, but the player sets the recipe (§2).
- *Pillar 3 (never out of range)* holds, with one change of meaning: an attack always **arrives**, but the defender is no longer frozen while it comes (§1).

## 1. The ranged press (a pitch: Orb picks)

**The problem, in Orb's words:** "pressing a single attack key at any distance essentially locks both fighters from performing actions as the attacker flies in and performs the attack."

**Orb's brief for the fix:** give control to the players, but never allow "two fighters standing in opposite corners whiffing jabs in the air with zero purpose". Standing far apart and trading taunts is the acceptable floor, especially with reactive lines that stay fresh.

### Two rules under every option

1. **A physical press at range never throws a strike at nothing.** Beyond about 6 bh it is either a call or a way of closing in. That rules out whiffed jabs by construction.
2. **The exchange starts at contact.** Nothing is decided until the first blow's wind-up, at any range. The defender moves, guards, dodges, fires or leaves until then.

### The call (Orb's pick for the ranged taunt)

- A call is a **voice line with a face cut-in,** and nothing else. Orb picked only that.
- **It does not feed meters.** The earlier ruling, "taunts should just feed meters", stays for the close taunt, which takes a second and can be hit (`control-rules.md` §4). A call is safe and free, so if it paid meter, two players at range would farm it. Meter comes from the taunt that carries a risk.
- It can't be punished and it doesn't root him. He keeps flying while he talks.
- **Keeping it fresh** (Narrative's dialogue director picks the line):
  - it reads the fight: the last exchange, who is ahead, wounds, forms, the place and the distance;
  - a call made within 4 s of the rival's call is a **reply** to it, so two players calling make a conversation;
  - no line repeats inside a match, and the pool rotates from day to day;
  - after three calls in 10 s he stops talking and only gestures, until 10 s pass. That keeps the cut-ins rare (at most 6 a minute, `rule-of-cool.md`).

### Three hybrids for getting from the call to the attack

| | **A. Call, then charge** | **B. The stick decides** (recommended) | **C. Mark and close** |
| :--- | :--- | :--- | :--- |
| **A press with no direction** | The call. Holding the button through it launches him at top speed | The call | The call, and it marks the rival for 2 s |
| **A press with the stick toward** | The same as above | **A charge:** he rushes at once, with no call first | While the mark lasts, flying toward the rival is boosted for free, and the attack fires when he is in reach |
| **A press with the stick away** | The call | A backstep, or a retreating blast with RB held | The call |
| **Who flies the approach** | The director, in a straight line | The director, in a straight line | The player, steering all the way |
| **Speed into the fight** | About a second for the call, then the charge | Immediate | As fast as the player flies |
| **Control** | Commit or don't | Direction is the intent, as it already is up close (ADR 0008) | The most: he can peel off at any moment |
| **Risk** | Every attack from range starts a second late | A player who never touches the stick only ever talks | The most to build, and a charge with no clear start for the defender to read |

**Recommendation: B.** It needs no new input, it is instant, and it uses the rule players already learn up close: the stick is the intent. A press alone is banter, and a press toward is an attack. Option A's held launch can be added on top as a second way to charge without changing B.

**Energy needs none of this.** With RB held, a press fires a blast at any range (§5), which is the purposeful thing to do from far away.

## 2. The fight alchemist

Presses are ingredients in the ongoing string, not a queue.

### Rules Orb has set

- **The window is each fighter's last 5 presses.** A press expires after 90 ticks.
- **The recipe display is a setting.** When it is on, a small strip shows the current recipe's name.
- **The stick picks the launch's direction, and the director snaps it to the most dramatic nearby target.** The tilt at the moment of the blow sets the direction on the screen. The director then picks the best target within about 45 degrees of it (a building, water, a crater), inside the collateral budgets. With no tilt the director picks freely. In a juggle each return blow reads the tilt again. Depth stays the choreographer's (ADR 0009).

### What a press carries

| Property | Values | Set by |
| :--- | :--- | :--- |
| Weight | Light or heavy | The button |
| Family | Physical or energy | Whether RB is held (§5) |
| Direction | Toward, level or away, and the stick's tilt | The stick |
| Rhythm | Held, mashed or timed | How it was pressed |

### The recipes

The number of heavies in the last five sets the kind of string, and the last press sets how it ends.

| Heavies in the last five | What plays | Feels like |
| :--- | :--- | :--- |
| None | **A flurry:** a rapid run of small strikes | Speed |
| One or two | **A blur combo:** the rapid blur Orb describes, with heavy accents that crack a guard | The standard combo |
| Three or four | **A bruiser string:** fewer, harder blows that push the rival back | Pressure |
| Five | **A power blow:** one big, slow strike | Commitment |

| The last press | The string's end |
| :--- | :--- |
| A light | It stays a brawl |
| A heavy | A knock-back, or a launch when one was earned (§3) |

**Direction.** Toward presses forward, and it prefers the close strikes: elbows, knees, the headbutt and the shoulder, so it reads as getting inside (Combat's proposal, confirmed). Level stands and trades. Away gives ground: dodges, a heavy to knock the rival off, and blasts from range.

### How timing is read (a pitch: Orb picks)

Orb asked for hybrids between "three clear styles" and "timing is the skill". In all three, a **held** press (12 ticks or more) charges the blow, and **mashing** (three presses inside 20 ticks, off the beat) gives speed, less damage and no launch.

| | **A. Styles first** | **B. Timing tops each style** (recommended) | **C. Timing wins trades** |
| :--- | :--- | :--- | :--- |
| **What picks the style** | The mix and the rhythm | The mix and the rhythm | The mix and the rhythm |
| **What a timed press does** (within 4 ticks of a blow landing) | A clean hit, for 10% more. Nothing else | It lifts the style to its top level: a timed flurry becomes more strikes, a timed blur combo earns its ender, and a charge released on the flash is a full charge | It does nothing in a string of your own. When both fighters attack, the timed press wins that beat |
| **For a beginner** | Everything is available by feel | The three styles work by feel, at their base level | The same as A until someone trades with him |
| **For an expert** | A small edge | A real ceiling in every style | The edge shows only in trades |
| **Risk** | Timing barely matters | Two levels per style to teach and to show | Solo strings have no skill in them |

**Recommendation: B, with C's rule added.** The styles stay clear and standard, timing is what lifts each one, and Combat's proposal that **a timed press wins its trade beat** is confirmed, so timing also shows when both fighters attack.

### The running mix

The game keeps each player's mix over their last 20 presses and compares it with their latest five.
- **A change-up** breaks his habit. Its first blow has a wind-up 3 ticks shorter.
- **A repeat** matches it. Wind-ups grow by 2 ticks for each repeat, up to 6 (`control-rules.md` §6).

### When both fighters attack

| | He plays a flurry or a blur | He plays a bruiser string or a power blow |
| :--- | :--- | :--- |
| **I play a flurry or a blur** | A blur exchange: traded strikes, decided on the pulse | My lights land first. Three clean ones before his blow lands stop it; otherwise it comes through |
| **I play a bruiser string or a power blow** | The mirror of that | A fist clash, decided on the pulse |

**A cross-counter on the last beat is a double slide** (Combat's proposal, confirmed). Both blows land on the same tick, both fighters slide apart for half the knock-back distance each, and nobody wins the exchange.

### What a player can always predict

1. The weight of my next blow is the weight I pressed.
2. More presses give more strikes.
3. Ending on a heavy sends him away. Ending on a light keeps him close.
4. Holding is bigger and slower. Mashing is faster and weaker. Timing is cleaner.
5. The stick decides which way he flies.
6. What I don't choose is the limb, the exact strike and the camera.

## 3. Brawls against launches

**Orb's rule: 30% of brawls end in a launch.** The band is 25 to 35% of exchanges, against 64.6% today.

| How an exchange ends | Target |
| :--- | :--- |
| The brawl continues, with both fighters in reach | 40 to 50% |
| A knock-back | 20 to 30% |
| A launch | 25 to 35% |

**A launch is earned by four things only** (Orb):
1. a charged, held heavy that lands;
2. the ender of a full string, which is a heavy after four or more of the string's strikes landed;
3. a heavy pressed with a stick direction, landing clean;
4. winning a clash.

- **Not a guard break and not a riposte.** Both now end in a knock-back. Meter never buys a launch.
- Signatures, finishers, crippling blows and throws are set pieces with their own rules, and still launch.
- If the share misses the band, QA tunes the third earner first, by how clean the heavy has to land.

**Knock-backs** (Combat's distances, confirmed): 3.5, 5, 6.5 and 8 bh at tiers 1 to 4.
- Under 4 bh he slides upright. At 4 bh and over he drops low, brakes with a hand and cuts a trench.
- An obstacle stops a slide early, as a light brunt inside the collateral budgets.
- In the air he drifts back and rights himself.

**Launches pay more.** With about half as many, each launch's impact wear rises so launches keep their share of the damage. QA sizes the factor, at about ×1.6, and re-tunes match length.

**Slide and tumble destruction: 4 of 5** (Orb). Terrain destruction from slides and tumbles is a central feature.
- Every long slide cuts a trench, and World widens trenches by about a third.
- A tumble leaves a line of divots, where it left only scuffs before.
- Both damage what they cross, inside the tier's budget and the journey's one-impact cap (`balance-targets.md` §20).

## 4. Air recovery: hold to brake

**Orb's rule:** hold to brake, it costs ki, and harder hits take longer. It is not a dodge tap.

- **The input:** hold LT during a launch flight. It is the boost (§6) turned against his own flight.
- **The cost:** 20 ki for each second it is held.
- **Harder hits take longer.** The brake slows him at a fixed rate, so the time and the ki follow the launch's speed: about 0.35 s and 7 ki for a light launch, and about 1 s and 20 ki for a hard one.
- **He has control again** when his speed drops under a third of the launch's speed. He can also let go early and fly on.
- **An earned launch can't be braked for its first 12 ticks,** so the hit reads.
- **It never works** on a crippling blow's launch, a finisher's launch or a hard impact (§7).
- **With no ki he can't brake.**
- **Counterplay:** the brake shows as a flare against his direction of flight, so the attacker sees it. A follow-up can arrive before he stops, and he stops in a place the attacker can read.
- A small steer is free: the stick bends his path by up to 15 degrees.
- The ground recovery stays as it is: a dodge tap on a bounce or in a tumble, for 15 ki (`balance-targets.md` §20).
- The AI brakes on 20%, 50% or 80% of chances by difficulty.

## 5. Energy play

### Hold RB (Orb's rule)

While RB is held, the attack buttons are blasts and beams. Released, they are physical. This replaces the toggle. The Simple layout and touch keep choosing by range.

### Signatures: 45 ki and 15 s (Orb's number)

- **A signature costs 45 ki and has a 15 s cooldown per fighter,** down from 120 s. Orb left the kind of limit open, so this reads the answer as the ki cost plus the shorter cooldown.
- **What that means in numbers.** Ki returns at 5 a second without charging, which is 75 ki every 15 s. So the cooldown is the real limit, not the ki. A fighter who wants to can fire about every 15 to 20 s: **12 to 20 signatures a match, against 2 to 5 today.**
- **Two things have to follow,** or beams decide every match:
  - a signature's damage drops by about 40%, and QA re-tunes it against match length;
  - the pause budget doesn't grow. The rival's absorbed signature and other beam set pieces play live once the bank is spent (`spec-wounds.md` §8b).
- **What a gauge would add.** A gauge filled by fighting (blows landed and taken, clashes, perfect blocks) ties beams to the brawl. It would give about one signature per 45 to 60 s of real fighting, which is 4 to 7 a match, and a fighter who only stands back and charges would get none. If the 15 s rule makes fights too beam-heavy, the gauge is the fix that keeps beams frequent without making them free.

### All eight beam plays (Orb wants every one)

| # | Play | How |
| ---: | :--- | :--- |
| 1 | Both fire at once | A signature answered by a signature in its wind-up: a full struggle on the pulse |
| 2 | Fire late into an incoming beam | An answer in the first 20 ticks after the beam fires: the struggle starts at −10 for the late fighter |
| 3 | Block, then push back | While a held guard is taking a beam, a heavy energy press turns it into a struggle that starts at −15 |
| 4 | Walk through on guard | Holding guard and the stick toward wades through the beam at guard damage. With a perfect block it is clean |
| 5 | Split the beam | A perfect block with the stick level |
| 6 | Swat it away | A perfect block with the stick away. The director picks where it lands |
| 7 | Blast volleys that trade | Light blasts that cross cancel each other in pairs, and what is left of the bigger volley lands |
| 8 | Feed a struggle with a second charge | Once per struggle, holding Power between pulses pours in 10 ki for +5. His beam visibly swells |

A sustained **stream** (the heavy button held with RB, about 15 ki a second) is a lesser beam. It can struggle with another stream, or with a signature at −10.

Plays 4, 5 and 6 are the answers in `rule-of-cool.md` §2, and they move to the first energy slice.

### Beam defence: 3 of 5

Orb set the forgiveness in the middle, not generous.

| Answer | Today | Now |
| :--- | :--- | :--- |
| **Dodge** | A roll, about 55% | **No roll.** A dodge tap in the last 14 ticks of the wind-up or the first 6 ticks of the beam avoids it |
| **Perfect block** | The last 10 ticks of the wind-up | The last **12** ticks, for beams only |
| **Held guard** | Reduced damage | Unchanged |

## 6. The left trigger and flight

**Orb's rule:** hold LT to boost in any direction, draining ki.

- **A tap is the dodge. A hold is the boost,** at about 2.2 times normal flight, in any direction.
- **It drains 12 ki a second,** and ki doesn't return while boosting. There is no separate gauge.
- He can't guard, charge or fire while boosting.
- **Empty ki leaves him exhausted** for 2 s: no boost, no dodge, and three quarters speed.
- "Escape" isn't a stance any more. It is what happens when an attack arrives while he is boosting away, and the pursuit roll is retired.

**The four ways to stop an escape** (Orb's picks):

| Tool | How | Result |
| :--- | :--- | :--- |
| **Chase and catch** | Boost after him and attack when in reach | The strike lands. A catch is decided by reach, not by a roll |
| **A blast from behind** | A blast that hits a boosting fighter | It knocks him out of the boost and down |
| **The intercept** | A fast, curved flight that arrives ahead of him. It costs 20 ki, and can be used once every 5 s. It is a flight, not a teleport | He meets the rival coming |
| **Exhaustion** | Outlast him | He runs dry first and is stuck |

**Not in the rules,** because Orb didn't pick them: extra damage for a hit from behind, and a new price to break out of a brawl. A fighter who is free simply boosts away. The burst and the dodge-cancel stay as the answers to being hit.

## 7. Hard impacts: buried in the crater

**Orb's rule:** yes, the fighter is buried, and the attacker gets a free follow-up.

| Question | Rule |
| :--- | :--- |
| **The threshold** | By the crater. An impact that digs a crater at least 1.5 bh deep buries him: a slam at about tier 3 or above, or any CRATER SLAM. Smaller impacts keep the bounce, the skid and the tumble |
| **What happens** | No hop, no bounce and no skid. He stops at the bottom |
| **The free follow-up** | The attacker gets **one blow that can't be answered,** if he strikes within 40 ticks: a heavy or a blast into the crater. It lands clean, deepens the crater and doesn't launch |
| **How long he is down** | 60 ticks. After the follow-up, or from tick 40 without one, he can guard |
| **How he gets out** | He rises by himself at 60 ticks. A burst throws him out earlier, but not before the follow-up's 40 ticks are over. He comes out with 10 ticks of safety |
| **Limits** | One follow-up per burial. The same fighter can't be buried twice inside 5 s. The brake (§4) can't stop a hard impact |

This replaces the single small hop after a very hard slam (`balance-targets.md` §20).

## 8. Speed at the top tier (a proposal)

**Orb's note:** "fighters almost get a little too fast when max transformation is reached".

Today each tier adds 10% speed, so tier 4 is +30%, and the surge and other bonuses stack on top.

| | Today | Proposal |
| :--- | :--- | :--- |
| Speed at tiers 2, 3 and 4 | +10%, +20%, +30% | **+8%, +14%, +18%:** each step adds less |
| The most any stack of bonuses can reach | No cap | **×1.25** of base speed, for flight and for strike cadence |
| Damage and launch force by tier | +9% and +16% a tier | Unchanged |

Power should read as weight, which is pillar 4: bigger craters and longer launches, with the fight still readable. The boost (§6) is a multiple of this capped speed, so it is bounded too.

## 9. What this changes elsewhere

| Rule today | Becomes |
| :--- | :--- |
| The exchange is fixed at the press (`stance-matrix.md` R8) | It is fixed at the first blow's wind-up (§1) |
| A queue of up to 3 presses (`control-rules.md` §6) | The alchemist's window of 5 and its recipes (§2) |
| 40 to 65% of exchanges end in a launch, and a guard break or riposte launches (`balance-targets.md` §10) | 25 to 35%, earned four ways (§3) |
| Recovery only on the ground (`balance-targets.md` §20) | Hold to brake in the air as well (§4) |
| A 120 s signature cooldown, and 2 to 5 signatures a match (`balance-targets.md` §13) | 15 s, and about 12 to 20 a match, with damage re-tuned (§5) |
| RB toggles energy (ADR 0008) | RB is held (§5) |
| A dodge against a beam is a roll | A timed dodge always works (§5) |
| The escape stance and its slip roll (`balance-targets.md` §13) | Boost on ki, and four ways to stop it (§6) |
| One hop after a hard slam | Buried, with a free follow-up (§7) |
| +10% speed a tier, uncapped (`ladder.json`) | A flattening curve and a ×1.25 cap, if Orb agrees (§8) |

**Not in this page:** a glancing bounce on a mountain gaining too much momentum is World's to tune (a bounce must never add speed), and the split-screen camera is Camera's.
