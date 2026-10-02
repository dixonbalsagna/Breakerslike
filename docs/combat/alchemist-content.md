# The fight alchemist: the content it mixes

Owner: Combat and Choreography. Date: 2026-10-02. Status: a content plan. No live data and no code. The rules are Game Design's (`docs/design/agency-pass.md` sections 2 to 4 and 7) and the architecture is Encounter's. This note says which pieces each rule calls, how each piece is tagged, what exists and what is missing. Where it adds a rule of its own, it says "proposal".

**Why.** Orb's first two-player playtest (`docs/ep/vision.md`, last section): "every brawl seems to end in a launch"; combo trading should be "more represented and flashy"; juggles and pinballs slightly rarer, with higher payoff and spectacle; and a **fight alchemist** that reads the last few presses of both fighters and builds the string the player would expect.

**What the data says today.** Of the 19 branches in the live templates, 11 end in a launch: every won trade, every won clash, the guard break, the caught pursuit, both dodge answers, the riposte and the heavy clean hit. The other 8 are the ones where nothing decisive landed. Each chain link launches again. So Orb's reading is exact: a brawl that is won has no other way to end. QA measures 64.6% of exchanges ending in a launch; Game Design's target is 25 to 35%.

---

## 1. Game Design's recipes, and the pieces each calls

A press carries a weight, a family, a direction and a rhythm. The window is each fighter's last three presses.

| The last three presses | What plays (Game Design) | The pieces it calls |
| :--- | :--- | :--- |
| Three lights | **A flurry:** a rapid run of small strikes | links: the 18 lights, at the string's own spacing |
| Two lights and a heavy | **A blur combo:** a rapid blur with one heavy accent that cracks a guard | a blur pattern of lights at 6-tick spacing, then one heavy as the accent |
| One light and two heavies | **A bruiser string:** fewer, harder blows that push the rival back | heavies, favouring the 10 that send across |
| Three heavies | **A power blow:** one big, slow strike | one heavy at full blow weight, on its longest wind-up |

| The last press | How the string ends | The pieces it calls |
| :--- | :--- | :--- |
| A light | it stays a brawl: both remain in reach | a level ending (section 3.3) |
| A heavy | a knock-away; a launch only when one was earned | a knock-back ending, or one of the 16 enders as a launch |

| Rhythm | What it does (Game Design) | The pieces it calls |
| :--- | :--- | :--- |
| **Held** (12 ticks or more) | power: a charged blow | a heavy with the charge in front of it: 1 new pose |
| **Mashed** (three presses inside 20 ticks) | speed: more strikes, less damage, never a launch | extra links on the snappy profile. A rule, no poses |
| **Timed** (within 4 ticks of a blow landing) | precision: a clean hit; three in a row earn a launch | the same pieces at full blow weight; the showcases open on a clean hit |

| Direction | What it does | The pieces it calls |
| :--- | :--- | :--- |
| Toward | presses forward | rush entries. **Proposal:** toward also prefers the close band (elbows, knees, the headbutt, the shoulder), so pressing forward reads as getting inside |
| Level | stands and trades | stand entries; the long and mid bands |
| Away | gives ground: dodges, a heavy to knock the rival off, blasts from range | retreat entries, an across heavy at knock-back force, the energy strikes |
| The stick's tilt | where the rival is sent, on the screen | the ender or return blow whose direction is nearest the tilt |

So each piece carries three tags the alchemist reads:
- **`weight`** (it has this already) and **`classes`**: opener, mid, ender, return;
- **`ends`**: how a string may end on it: level, knock-back or launch;
- **`sends`**: the direction it sends the rival, relative to the striker: across, up, down or turned (and behind, for the two throws that turn). A return blow that sends the body back along its path is across.

The tags, the eight endings and the trade beats are now parked data: `pending/brawl-endings-and-trades.md`. After Orb's picks, the recipe mapping for five presses with a base and a timed version of each style, the traded-blows set piece and the charges at range are in `alchemist-recipes.md`; where it differs from the table above, it is the current one.

## 2. The shelf: what exists and what is missing

"Have" counts the live atoms and templates plus the seven parked waves (`pending/waves-index.md`). Strike counts are from `pending/strikes.antihero.wave1.json`.

| Piece class | What it is | Have | Missing |
| :--- | :--- | :--- | :--- |
| **Opener** | an entry and a first blow | 15 entries; 5 light and 11 heavy opener strikes | nothing |
| **Link** | one blow inside a string | 18 lights | 2 lights that send the rival down, for steered juggles (section 4) |
| **Blur** | a compressed run of lights with one accent | the two-sided blur exchange (wave 5); the live TRADE BLOWS alternation | the one-sided blur combo: 6 patterns, as data. No poses |
| **Heavy** | one big blow | 20 heavies: 10 send across, 7 down, 2 up | the charge for a held press: 1 pose |
| **Ender** | the blow a string closes on | 16 enders. **Every one launches today** | endings that are not a launch: 3 level, 4 knock-back slides, 1 double slide, as data; 2 poses for a slide on the feet |
| **Traded beat** | both fighters act in one beat | TRADE BLOWS (alternating), HEAVY CLASH, the 3 pulse clashes (wave 5) | 6 small trade beats and the "stuff or come through" pair, as data; 3 poses |
| **Mash** | extra strikes | none | a rule. No poses |
| **Timed** | the clean version | the perfect block, the pulse, the return blow's window; 16 showcases specified, 6 of them in wave 7 | "clean" as a rule: full blow weight, the showcase gates open |
| **Kiting** | dodge, knock away, fire | 4 retreat entries; 10 across heavies; 31 energy strikes; the dodge's lean | the knock-back launch vector (section 3.3) |
| **Launch pieces** | launchers, returns, enders | the launch planner; wave 3's rally; 7 return blows; 16 enders; the turn throw | direction tags; a pinball pattern; the stay-in-the-crater ending; 1 air-brake pose (section 4) |

**The gap is small in poses and mostly data:** 9 authored sketches (section 5), against 107 already specified. What is missing is the middle of the shelf: ways for a string to be traded, and to end without a launch.

## 3. Traded exchanges

### 3.1 What exists
| Piece | Two-sided? | Ends in |
| :--- | :--- | :--- |
| TRADE BLOWS (live) | four alternating blows, then a deciding blow | a launch, always |
| HEAVY CLASH (live) | one meeting of two heavies | a launch, or both thrown back |
| DODGE and counter, PRESSURE and counter, RIPOSTE (live) | one answer | a launch, except PRESSURE |
| Fist clash, blur exchange, grapple lock (wave 5, parked) | yes, on the pulse | a launch or a throw; a tie throws both back |

So the game has trades, but each is a fixed script with one ending.

### 3.2 What to author for Game Design's three cases
Game Design's table for both fighters attacking has three cases. Each needs content the alchemist can vary.

**Flurry or blur against flurry or blur: the blur exchange.** Wave 5 has it as nine alternating lights and three pulse blows. To make two of them look different, its bursts are built from small **trade beats** of 12 to 14 ticks, each filled from the 18 lights:

| Trade beat | What both do | New poses |
| :--- | :--- | ---: |
| **Exchange** | one lands, the other lands back half a beat later | 0 |
| **Cross-counter** | both blows land on the same tick; both heads snap | 0: the computed reaction plays over each strike |
| **Check and reply** | one blow is stopped on a forearm or a shin, and the checker replies at once | 2: the forearm check, the shin check |
| **Light clash** | the two limbs meet and both recoil | 1: the recoil |
| **Slip and miss** | one sways off the line, the other hits air and over-commits | 0: the dodge lean and the over-commit exist |
| **Bind and shove** | a short tie-up, then one shoves the other off | 0: wave 5's tie-up |

**Proposal:** a timed press wins its beat (the checker in a check and reply, the one who lands in a slip and miss), so timing shows inside the trade as well as on the pulses.

**Flurry or blur against a bruiser string or a power blow: lights first.** Game Design: three clean lights before the blow lands stop it; otherwise it comes through. As content that is a pair:
- **Stuffed:** the third clean light lands on the wind-up and the heavy collapses into a stagger. No new pose: the stagger exists.
- **Comes through:** the lights land on a fighter who keeps winding up, and the heavy lands through them. No new pose: the computed reactions play at low strength over the wind-up, which needs the reaction-strength input Animation already offered.

**Bruiser or power against the same: the fist clash.** Wave 5, as written.

### 3.3 Endings that are not a launch
| Ending | Game Design's rule | What it looks like | Pieces |
| :--- | :--- | :--- | :--- |
| **Level** (3) | the string ended on a light: the brawl continues | a shove-off; a mutual hop back; a held look across fighting distance | the palm heel as a push; the hop back entry; the reset cue in the live data |
| **Knock-back slide** (4) | the string ended on a heavy and no launch was earned: a shove of under about 8 bh, a short skid on the ground | the loser is driven back on their feet, braking with a hand, carving the ground; the winner holds the end of the blow | the across heavies at knock-back force; a slide on the feet (2 poses) |
| **Double slide** (1) | a cross-counter on the last beat (proposal) | both slide apart | the same slide, both sides |
| **Launch** | one of Game Design's nine earners | as today | the 16 enders |

- **A new launch vector: the knock-back.** Flat and short. On the ground it is the slide; in the air it is a drift of a few body heights that stops upright. It joins the vocabulary in `launch-vectors.md` (loft, drive, crater slam, across, brunt).
- **A slide on the feet is not the skid Animation has.** That one is on the back or the face, after a launch. This one is upright: both feet wide, one hand trailing on the ground behind.
- **Trenches from slides** are World's, and Orb wants them to be a central feature.

### 3.4 One traded brawl, beat by beat (an example, not a script)
Both players on two lights and a heavy, one of them timing the presses:
1. Exchange: a jab lands, a cross comes back.
2. Light clash: two hooks meet; both recoil.
3. Check and reply: the timed player stops a front kick on the shin and answers with a short elbow.
4. The pulse: both strike; the timed player's blow gets through.
5. The timed player's heavy closes it: a roundhouse at knock-back force. The other slides back several body heights on their feet, a hand on the ground, and both are free.

Five beats, about 70 ticks, nine blows shown, no launch.

## 4. Bigger, rarer launches

### 4.1 What earns one
Game Design's list (`agency-pass.md` section 3): a heavy ender after three or more strikes of the string landed; three timed presses in a row; a held, charged heavy that lands clean; a guard break; a riposte after a perfect block against a heavy or an ender; a clash won on the pulse; a throw; a signature, a crippling blow or a finisher; any heavy on a rival who is staggered or opened up. Everything else is a knock-back or a brawl that continues.

**What that changes in the content:** a chain link stops launching by itself. A link keeps the string going; only an earned ender launches.

### 4.2 The juggle, as content
| Beat | Piece | Have |
| :--- | :--- | :--- |
| **The launcher** | an earned ender, with a showcase when the gates allow: the rising spear up, the overhead hammer down | 16 enders: 6 across, 7 down, 2 up, 1 with no direction; 2 showcases in wave 7 |
| **The catch** | the intercept flight and the turn | wave 3 |
| **Steered returns** | each return blow reads the stick again | 7 returns, in three directions (below) |
| **The ender** | the stick picks it, and the planner picks the target within 45 degrees: down, a crater; across, a brunt or through a formation; up, the loft, or orbit at tier 3 | the 16 enders; the set pieces in `docs/design/rule-of-cool.md` |
| **The landing** | a hard impact leaves him in the crater (`agency-pass.md` section 7) | a stay-in-the-crater ending: the ragdoll held where it lands (World and Animation) |

**The stick needs direction coverage.** Today:

| Sends the body | Return blows | Enders |
| :--- | :--- | ---: |
| Back along its path | jab, side kick, tail jab | |
| Turned (about 70 degrees) | hook, backfist | |
| Up and back | rising elbow, snap round | 2 |
| Across | | 6 |
| **Down** | **none** | 7 |

Two light return blows that send the body down are missing: a short hammer-fist and a heel tap. With them every direction of the stick has at least two returns.

### 4.3 The pinball
The ping-pong (wave 3) bounces the body between two points in the air. A pinball adds the world: the knock sends the body into a formation, a building or the ground, it bounces (World's bounce), and he meets the rebound. As content it is a fourth knock pattern beside wave 3's rally, ladder and orbit. Each bounce off the world counts against the collateral budgets, and the ender is the only targeted smash.

### 4.4 What makes it read as a payoff
- **Rarer:** only the nine earners lead to one, and Game Design's target is about one juggle a minute, down from about three.
- **Longer and louder:** a juggle is three to five steered blows and an ender; a brawl's ending is one knock-back. Game Design gives the pinball's ender the panel every time.
- **The player steers it:** the stick picks each direction and the ender.
- **The defender has answers:** wave 3's burst, perfect block and dodge-cancel, plus the air brake Game Design recommends (a dodge tap; he rights himself over 10 ticks). As content that is 1 pose, the righting.

## 5. What to author

| Item | Data | Sketches |
| :--- | :--- | ---: |
| 6 blur patterns (the order of limbs and targets in a one-sided blur) | 6 | 0 |
| 6 trade beats, and the "stuffed" and "comes through" pair | 8 two-sided beat lists | 3: forearm check, shin check, light-clash recoil |
| 8 endings: 3 level, 4 knock-back slides, 1 double slide | 8 | 2: the slide on the feet, high and low |
| The knock-back launch vector | 1 vocabulary entry | 0 |
| The charged heavy | a rule | 1: the charge |
| Mash, and "clean" | 2 rules | 0 |
| 2 return blows that send down | 2 strike pieces | 2: the hammer-fist, the heel tap |
| The pinball pattern; `ends` and `sends` tags on the 38 strikes | 1 pattern; tags | 0 |
| The air brake | | 1: the righting |
| **Total** | | **9** |

**Order.** (1) The endings and the knock-back vector: with today's strings alone they stop every won brawl ending in a launch. (2) The trade beats, inside wave 5's blur exchange. (3) The blur patterns, the charge, mash and "clean", with the recipes. (4) The steered juggle and the pinball, after wave 3's curved flight.

## 6. Every new pose inside the joint limits
All nine sketches are authored inside `docs/animation/joint-limits.md`, and Animation's lint is the gate. What that means for these poses:
- **Knees and elbows fold one way,** to 155 and 160 degrees. The shin check raises a bent knee.
- **A thigh goes at most 45 degrees behind the hip.** The slide on the feet takes its width from the front leg, bent deep, not from a leg thrown far back.
- **No arm straight back along the body.** The charge draws the arm back at shoulder height with the elbow bent. The trailing hand of the slide is down and behind, elbow bent.
- **The spine turns about 70 degrees in all.** A check or a recoil that shows more of his back turns the whole body.
- **Hips open 105 degrees out and 60 in.** The heel tap comes down in front of him, not across his own standing leg.

## 7. What this needs from others

| For | What |
| :--- | :--- |
| **Game Design** | three proposals above: toward prefers the close band; a timed press wins its trade beat; a cross-counter on the last beat is a double slide |
| **Encounter** | pieces chosen by weight, class, `ends` and `sends`; two strikes landing on one tick; a check (a blow stopped on a limb, with no damage); the knock-back vector; chain links that do not launch |
| **World** | the slide on the feet as a state, with its trench by tier; the bounce off the world for the pinball; staying in a very large crater |
| **Animation** | the nine sketches; the reaction over a strike (the cross-counter) and over a wind-up (the heavy that comes through); the slide on the feet |
| **Controls** | hold, mash and timed taps told apart; the stick read during a string |
| **Legal** | the slide on the feet must not be a landing on one knee and one fist; the charge follows the rules already given for a charge (no cupped hands, nothing at a hip, no scream with a crouch and an aura) |
| **QA** | the share of exchanges that end level, in a knock-back and in a launch, against Game Design's targets; blows shown per traded brawl |
