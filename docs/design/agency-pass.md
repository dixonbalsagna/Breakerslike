# The agency pass: rules from Orb's first two-player playtest

Owner: Game Design. Orb played two local matches with a second player on 2026-10-02, answered questionnaire 14, and then picked from the pitches (`docs/ep/vision.md`, "Orb's picks after the pitches"). This page is the rules that follow. Three parts are **provisional** because Orb wants to feel them in play first: the signature limit (§5), the escape (§6) and top-tier speed (§8). Every number is a starting value for data.

**Where the pillars bend.**
- *Pillar 2 (stances, not combos)* bends toward the player. The director still choreographs, but the player sets the recipe and earns the ending (§2).
- *Pillar 3 (never out of range)* holds, with one change of meaning: an attack always **arrives**, but the defender is no longer frozen while it comes (§1).

## 1. The ranged press: three bands

**The problem, in Orb's words:** "pressing a single attack key at any distance essentially locks both fighters from performing actions as the attacker flies in and performs the attack."

**Two rules under everything here.**
1. **A strike never exists at range.** No strike is thrown at a rival who is out of reach. QA tests it as a hard rule.
2. **The exchange starts at the wind-up.** Nothing is decided until the first blow's wind-up, in every band. Until then the defender is free.

### The bands

An icon by the fighter shows which band he is in, so a press never surprises.

| Band | Distance | A physical press does |
| :--- | :--- | :--- |
| **Close** | Within 3 bh | Strikes at once, as today |
| **Mid** | 3 to 12.5 bh | **A short lunge:** about a third of a second of travel (20 ticks at most), then the wind-up. The stick picks the entry, as it does up close: toward rushes, level steps in, away backsteps |
| **Far** | Beyond 12.5 bh | **Tap to taunt, hold to charge** |

With RB held, a press fires a blast in any band (§5).

### The far taunt is a challenge

- A tap plays his taunt: a voice line with a face cut-in, over 45 ticks. He keeps flying while he talks.
- **If the opponent presses attack during it, the challenge is answered.** Both rush and meet in the middle: a fist clash if either pressed heavy, and otherwise a blur exchange, decided on the pulse.
- **If it is ignored, the taunter keeps the line:** he gets the taunt's credit (§3).
- It can't be punished. That is why its meter is rationed (§3).

### The button picks the charge

Holding the attack button in the far band charges.

| | **A held light** | **A held heavy** |
| :--- | :--- | :--- |
| **Before he goes** | 8 ticks (12 before §12) | 16 ticks (24 before §12) |
| **The flight** | Fast: about 0.3 to 1.0 s by distance | Slower: about 0.5 to 1.4 s |
| **Changing his mind** | Releasing the button stops the charge at no cost. That is the feint | Committed once he goes. Only a dodge-cancel (15 ki) stops it |
| **Blasts on the way** | Any blast that lands stops him | He shrugs off light blasts and volleys, taking half their damage. A charged shot or a beam still stops him |
| **On arrival** | A light opener, into a brawl | A charged heavy. If it lands clean it **earns a launch** (§3) |
| **Cost** | None | 4 ki, a heavy's cost |

**The defender is free during any charge.** He can guard, dodge, press attack to meet it (a trade or a clash at contact), fire, or boost away (§6).

**Pillar 3 holds:** a charge always reaches a rival who doesn't answer.

## 2. Reading presses: the fight alchemist

Presses are ingredients in the ongoing string, not a queue.

### The frame

- **The window is each fighter's last 5 presses.** A press expires after 90 ticks.
- **The recipe display is a setting.** When on, a small strip names the current recipe and shows the flow count.
- **The stick picks the launch's direction, and the director snaps it to the most dramatic nearby target** within about 45 degrees: a building, water or a crater, inside the collateral budgets. With no tilt the director picks freely. In a juggle each return blow reads the tilt again. Depth stays the choreographer's (ADR 0009).

### The three styles

The number of heavies in the last five presses sets the style, and the last press sets the ending.

| Heavies in the last five | Style | What plays |
| :--- | :--- | :--- |
| None | **Blur** | A rapid run of light strikes |
| One to three | **Combo** | Lights with heavy accents that crack a guard and push the rival back |
| Four or five | **Power** | Big, slow blows, charged by holding |

| The last press | The ending |
| :--- | :--- |
| A light | It stays a brawl |
| A heavy | A knock-back, or a launch when one was earned (§3) |

**Direction.** Toward presses forward and prefers the close strikes: elbows, knees, the headbutt and the shoulder. Level stands and trades. Away gives ground: dodges, a heavy to knock the rival off, and blasts.

### Timing upgrades each style (Orb's pick)

Each style works by feel at its base level. Timing lifts it.

| Style | Base | With timing | The upgrade |
| :--- | :--- | :--- | :--- |
| **Blur** | Mashing: more strikes, less damage each, no ender | A **steady** mash, with presses evenly spaced within 3 ticks of the beat | **A perfect blur:** every strike lands clean, and it closes with its own ender, a burst that knocks the rival back. The player doesn't press for that ender: the blur plays it, and it is a knock-back, never a launch |
| **Power** | A held blow: more damage and a longer wind-up | **Released on the flash,** within 6 ticks of the flash at full charge | **A guard-breaking blow.** Against a guard it breaks it. Unguarded, it earns a launch |
| **Combo** | Presses in any rhythm | **Taps in time,** each within 4 ticks of a blow landing | **Clean and hard:** each timed strike does 15% more |

### Timing earns the ending: the flow count

- Each timed press adds 1 to the fighter's **flow,** up to 5.
- A press off the beat sets it back to 0, and so do 90 ticks without a press.
- **A heavy ender launches only at flow 3 or more,** in the direction the stick picks. Below that it is a knock-back.
- **At flow 5 the ender is a showcase ender,** with the panel and 20% more impact wear (Combat's proposal, confirmed).

### The running mix

The game keeps each player's mix over their last 20 presses and compares it with their latest five.
- **A change-up** breaks his habit. Its first blow has a wind-up 3 ticks shorter.
- **A repeat** matches it. Wind-ups grow by 2 ticks for each repeat, up to 6 (`control-rules.md` §6).

### When both fighters attack

| | He plays blur or combo | He plays power |
| :--- | :--- | :--- |
| **I play blur or combo** | A blur exchange: traded strikes, decided on the pulse | My lights land first. Three clean ones before his blow lands stop it; otherwise it comes through |
| **I play power** | The mirror of that | A fist clash on the pulse, or **Blow for Blow** when both are in time (below) |

- **A timed press wins its trade beat** (Combat's proposal, confirmed).
- **A cross-counter on the last beat is a double slide:** both blows land together, both fighters slide apart for half the knock-back distance, and nobody wins the exchange.

### Blow for Blow (the named set piece Orb asked for)

Two fighters trade heavy blows in turn, driving each other back and forth across the ground, neither giving way, until one misses the beat. "Blow for Blow" is an in-house label only; Narrative picks the player-facing name. Legal's twelve staging rules apply (`docs/legal/agency-pass-screen.md`), and Combat's content is in `docs/combat/alchemist-recipes.md` §2.

| Part | Rule |
| :--- | :--- |
| **Trigger** | Both fighters release a power blow on the flash in the same exchange |
| **The turns** | They take turns. On his turn a fighter presses heavy on the beat, inside an 8-tick window |
| **A blow on the beat** | One of his own heavies at ×0.7 of a heavy. **Each turn uses a different strike and a different place,** and the wear goes to that place's region: the ribs, flank and chest to the core; the shoulder plate to the arms; the hip and thigh to the legs. The other fighter takes it in his own brace and stays on his feet. Then it is his turn |
| **They travel** | Each blow drives both fighters along the ground, and the answer drives them back the other way, further each time: 40 units on the first turn, rising by 8 a turn to 96 on the eighth (Combat's numbers, confirmed) |
| **The beat** | 40 ticks between blows at first, 4 ticks shorter each turn, and never under 24 |
| **The end** | The first to miss the beat, or to guard or dodge, gives way. The other lands the last blow as an earned launch, with the panel and 25% more impact wear |
| **Limits** | At most 8 turns, then both slide apart with no winner. It counts as a big set piece, so at most one per 20 s (`rule-of-cool.md` §1) |
| **A region breaking** | A blow that breaks a region ends it at once, and the striker has won the exchange. In the turns that can only be the core, which puts him on the brink: limb wear stops at battered and spills into the core, as always. The last blow is the only one that can be a crippling blow |
| **Mood** | +8 at the start and +3 for each blow |
| **The AI** | It hits 40%, 65% or 85% of beats by difficulty |

Legal screens the staging before it is built. It must be ours and not a known scene's.

### What a player can always predict

1. The weight of my next blow is the weight I pressed.
2. More presses give more strikes.
3. Ending on a heavy sends him away. Ending on a light keeps him close.
4. Holding is bigger and slower. Mashing is faster and weaker. Timing makes each of them better.
5. Staying in time earns the big ending.
6. The stick decides which way he flies.
7. What I don't choose is the limb, the exact strike and the camera.

### What QA measures: "consistent timing should give the fighter a substantial edge"

Scripted players in a mirror match, with everything else equal.

| Match | Target |
| :--- | :--- |
| A timed player (hits 80% of beats) against a masher | The timed player wins **72 to 82%** |
| A timed player against a style-only player (holds and mixes sensibly, never on the beat) | The timed player wins **62 to 70%** |
| A style-only player against a masher | The style-only player wins 55 to 62% |

The masher bands against the AI stay as they are (`control-rules.md` §6).

## 3. Brawls, launches and taunts

### Launches

**Orb's rule: 30% of brawls end in a launch.** The band is 25 to 35% of exchanges, against 64.6% today.

| How an exchange ends | Target |
| :--- | :--- |
| The brawl continues, with both fighters in reach | 40 to 50% |
| A knock-back | 20 to 30% |
| A launch | 25 to 35% |

**A launch is earned by four things only:**
1. a charged, held heavy that lands, including a heavy charge from the far band (§1);
2. the ender of a full string, which is a heavy ender at flow 3 or more (§2);
3. a heavy pressed with a stick direction, landing clean;
4. winning a clash, Blow for Blow included.

- A guard break and a riposte now end in a knock-back. Meter never buys a launch.
- Signatures, finishers, crippling blows and throws are set pieces with their own rules, and still launch.
- If the share misses the band, QA tunes the third earner first, by how clean the heavy has to land.

**Knock-backs** (Combat's distances, confirmed): 3.5, 5, 6.5 and 8 bh at tiers 1 to 4.
- Under 4 bh he slides upright. At 4 bh and over he drops low, brakes with a hand and cuts a trench.
- An obstacle stops a slide early, as a light brunt inside the collateral budgets.
- In the air he drifts back and rights himself.

**Launches pay more.** With about half as many, each launch's impact wear rises so launches keep their share of the damage. QA sizes the factor, at about ×1.6, and re-tunes match length.

**Slide and tumble destruction: 4 of 5** (Orb). It is a central feature.
- Every long slide cuts a trench, and World widens trenches by about a third.
- A tumble leaves a line of divots, where it left only scuffs before.
- Both damage what they cross, inside the tier's budget and the journey's one-impact cap (`balance-targets.md` §20).

### Taunts feed meters, with a guard against farming

Orb leans yes, and will revisit it in play.

| Taunt | What it pays |
| :--- | :--- |
| **The close taunt** (1 s, and it can be hit) | In full, as ruled: Pride +6, heat +10, Wrath +8 or Hunger +5, once per 15 s (`control-rules.md` §4) |
| **A far taunt that is answered** | The same full value, to the taunter, whoever wins the clash. **Only an attack press during the taunt answers it** (the EP's ruling). Taunting back is a reply in the dialogue, but for meter each of those taunts counts as ignored |
| **A far taunt that is ignored** | Half the value for the first, a quarter for the second and an eighth for the third. **Nothing after the third,** until the two fighters have traded blows |

The line and the face cut-in always play, whatever the meter does. Narrative's dialogue director keeps them fresh: a call within 4 s of the rival's is a reply to it, no line repeats inside a match, and after three calls in 10 s he only gestures for a while.

## 4. Air recovery: hold to brake

**Orb's rule:** hold to brake, it costs ki, and harder hits take longer.

- **The input:** hold the boost (§6) during a launch flight. It is the boost turned against his own flight.
- **The cost:** 20 ki for each second it is held.
- **Harder hits take longer.** The brake slows him at a fixed rate, so the time and the ki follow the launch's speed: about 0.35 s and 7 ki for a light launch, and about 1 s and 20 ki for a hard one.
- **He has control again** when his speed drops under a third of the launch's speed. He can also let go early and fly on.
- **An earned launch can't be braked for its first 12 ticks,** so the hit reads.
- **It never works** on a crippling blow's launch, a finisher's launch or a hard impact (§7).
- **With no ki he can't brake.**
- **Counterplay:** the brake shows as a flare against his direction of flight. A follow-up can arrive before he stops, and he stops in a place the attacker can read.
- A small steer is free: the stick bends his path by up to 15 degrees.
- The ground recovery stays: a dodge tap on a bounce or in a tumble, for 15 ki (`balance-targets.md` §20).
- The AI brakes on 20%, 50% or 80% of chances by difficulty.

## 5. Energy: the first slice

Orb will make no final calls on beams until the energy system can be played: "I want to personally experience how the expansion of ranged blasts change the gameplay." So this section specifies the first slice to build, and marks what is provisional.

### What the first slice contains

| Input | What it does |
| :--- | :--- |
| **Hold RB** | The attack buttons become energy. Released, they are physical. This replaces the toggle |
| **RB and light** | **Blast volleys.** A tap is a bolt, and repeated taps are a volley. Volleys that cross **trade:** they cancel in pairs, and what is left of the bigger one lands |
| **RB and heavy** | **A charged blast.** Holding charges it for up to 30 ticks. Held on past the full charge, it becomes **a short beam** of about half a second, for 20 ki |
| **The signature** | As now: the power trigger and its button, for 45 ki |

Blast speeds and ranges are in `moveset-rules.md` §11, and blasts use the tier factor on structures (`balance-targets.md` §15).

### Which beam plays come first

| Order | Play | How |
| :--- | :--- | :--- |
| **First slice** | Blast volleys that trade | As above |
| | Both fire at once | A signature or short beam answered by one in its wind-up: a struggle on the pulse |
| | Walk through on guard | Guard held with the stick toward wades through at guard damage. With a perfect block it is clean |
| | Split the beam | A perfect block with the stick level |
| | Swat it away | A perfect block with the stick away. The director picks where it lands |
| **Second slice** | Fire late into an incoming beam | An answer in the first 20 ticks after the beam fires. The struggle starts at −10 for the late fighter |
| **Later** | Block, then push back | A heavy energy press while a held guard is taking a beam: a struggle that starts at −15 |
| | Feed a struggle with a second charge | Once per struggle, 10 ki between pulses for +5 |

### Beam defence: 3 of 5

| Answer | Today | Now |
| :--- | :--- | :--- |
| **Dodge** | A roll, about 55% | **No roll.** A dodge tap in the last 14 ticks of the wind-up or the first 6 ticks of the beam avoids it |
| **Perfect block** | The last 10 ticks of the wind-up | The last **12** ticks, for beams only |
| **Held guard** | Reduced damage | Unchanged |

### The signature limit (provisional: Orb's to revisit)

Orb disliked the 120 s cooldown and set the slider to 15 s. The mildest limit that should still keep fights from being led by beams is:

- **45 ki and a 15 s cooldown per fighter;**
- **a signature's damage cut by about 40%,** because there will be several times as many;
- **one band for QA to watch:** signatures deal at most 30% of a match's damage.

Ki is now spent on much more than beams (the boost, the brake, bursts, specials and short beams), so the true rate should sit well under the ceiling of one every 15 s. QA reports signatures per match from the first slice.

**If fights still become beam-led,** the next lever is a rising cost and not a longer timer: each signature fired in the last 45 s adds 15 ki to the next. A gauge filled by fighting is the stronger alternative, and it stays on the table for when Orb has played the slice.

The pause budget doesn't grow: beam set pieces play live once the bank is spent (`spec-wounds.md` §8b).

## 6. Flight and escape (provisional)

Orb: "I need to feel how this works in game... lets get something that works now and then work on it when we have more combat systems in place." This is the simple version to build now. Every number sits in one data block so it can change.

- **One dedicated control boosts,** as Controls proposes. Held, he flies at about 2.2 times normal speed in any direction. The dodge stays a separate tap.
- **It drains 12 ki a second,** and ki doesn't return while boosting.
- He can't guard, charge or fire while boosting.
- **Empty ki leaves him exhausted** for 2 s: no boost, no dodge, and three quarters speed.
- "Escape" isn't a stance any more, and the pursuit roll is switched off.

**Two ways to stop an escape, in this version:**

| Tool | How | Result |
| :--- | :--- | :--- |
| **Chase and catch** | Boost after him and attack when in reach | The strike lands. A catch is decided by reach, not by a roll |
| **A blast from behind** | A blast that hits a boosting fighter | It knocks him out of the boost and down |

Exhaustion is the third, and it comes free with the drain. **The intercept** (a fast curved flight that arrives ahead of him, for 20 ki) waits for a later slice.

A charge from the far band (§1) catches a fighter who isn't boosting. Against one who is, it becomes the chase.

## 7. Hard impacts: buried in the crater

**Orb's rule:** the fighter is buried, and the attacker gets a free follow-up.

| Question | Rule |
| :--- | :--- |
| **The threshold** | By the crater. An impact that digs a crater at least **1.75 bh** deep buries him, or 1.5 bh for a special's impact (World's build: about two burials a match). Smaller impacts keep the bounce, the skid and the tumble |
| **What happens** | No hop, no bounce and no skid. He stops at the bottom |
| **The free follow-up** | The attacker gets **one blow that can't be answered,** if he strikes within 40 ticks: a heavy or a blast into the crater. It lands clean, deepens the crater and doesn't launch |
| **How long he is down** | 60 ticks. After the follow-up, or from tick 40 without one, he can guard |
| **How he gets out** | He rises by himself at 60 ticks. A burst throws him out earlier, but not before the follow-up's 40 ticks are over. He comes out with 10 ticks of safety |
| **Limits** | One follow-up per burial. The same fighter can't be buried twice inside 5 s. The brake (§4) can't stop a hard impact |

This replaces the single small hop after a very hard slam (`balance-targets.md` §20).

## 8. Showing power without more speed

Orb noted that fighters "almost get a little too fast when max transformation is reached", and gave no yes or no on a speed curve. **The curve is held: nothing changes in the speed numbers for now.** Orb asked instead for more ways to show power: "rocks levitating around a powered-up individual look cool". VFX leads that list. This is the rules-side view of what each tier should read as.

**The principle:** each tier adds a new **kind** of evidence, not more of the same. Power is weight (pillar 4).

| Tier | What it should read as | What the rules already give it |
| :--- | :--- | :--- |
| **1** | A strong fighter. The world doesn't react to him | Knock-backs of 3.5 bh; small craters; a beam that wounds a house and doesn't level it |
| **2** | The ground notices | Knock-backs of 5 bh; the first trenches; two bounces; small formations can be broken through |
| **3** | The surroundings move | The world reacts: rubble lifts when he charges, windows blow out, clouds part. Impacts reach 1.6 times as far. Burying impacts begin. Orbit launches |
| **4** | The sky and the horizon answer | Reach 2.8 times as far; the sky pales; cracks spread under him when he stands; the round-the-world hit; a finisher that wrecks a district |

**More rules-side signals that cost no speed,** for VFX and Camera to draw from:
- a longer hit-stop on his heavy blows, by a tick or two a tier;
- a guarding rival slides further back from each blocked blow;
- his charge lifts rubble over a wider radius. Legal's rule holds: a gentle lift with weight, never a ring of rocks;
- a wider camera at tiers 3 and 4, so the scale shows;
- deeper sound, with delayed booms from far impacts.

If the top tier still reads as too fast once these are in, the curve is ready: +8%, +14% and +18% by tier in place of +10%, +20% and +30%, with a ×1.25 cap.

## 9. The build order

Each slice is playable by itself. Energy comes early, as Orb asked.

| # | Slice | What the player gets | Who builds it |
| ---: | :--- | :--- | :--- |
| 1 | **The free approach** | The exchange starts at the wind-up. Three bands with the icon, the mid lunge, tap to taunt and hold to charge, and the answered challenge | Encounter (the director's read, bands and charges); Controls (tap and hold at range); Simulation (the charge state); Combat (lunge, charge and taunt pieces) |
| 2 | **Energy, first slice** | Hold RB, volleys that trade, the charged blast and short beam, the provisional signature limit, the first five beam plays and the new defence windows | Controls (RB held); Combat (the energy pieces); Encounter (blast exchanges and the struggle on the pulse); Simulation (blasts in flight, ki); World (blast damage to structures) |
| 3 | **Boost, escape and the brake** | The boost control with its ki drain and exhaustion, the two ways to stop an escape, and hold to brake | Controls; Simulation; Encounter (the AI's use of them) |
| 4 | **The alchemist** | The window of 5, the three styles, the timing upgrades, the flow count, the endings and the four earners, the stick's launch direction, and the recipe display | Encounter (the reader and composer); Combat (endings and trade beats); Controls (reading rhythm); Simulation (state); World (the slide on the feet and its trench) |
| 5 | **Clashes and Blow for Blow** | The fist clash and blur exchange on the pulse, and the named set piece | Combat; Encounter; Simulation |
| 6 | **Buried, and destruction at 4 of 5** | Burying impacts with the free follow-up, wider trenches and tumble divots | World; Simulation; Encounter |
| 7 | **Energy, second slice** | The late answer, block then push back, feeding a struggle, and the intercept | Encounter; Combat; Controls |

QA baselines after each slice. The timing bands in §2 are measured from slice 4.

## 10. What this changes elsewhere

| Rule today | Becomes |
| :--- | :--- |
| The exchange is fixed at the press (`stance-matrix.md` R8) | It is fixed at the first blow's wind-up (§1) |
| A press at any range rushes | Three bands; a strike never exists at range (§1) |
| A queue of up to 3 presses (`control-rules.md` §6) | The window of 5, three styles, timing upgrades and the flow count (§2) |
| 40 to 65% of exchanges end in a launch, and a guard break or riposte launches (`balance-targets.md` §10) | 25 to 35%, earned four ways (§3) |
| Taunts feed meters, close only (`control-rules.md` §4) | The far taunt feeds too, rationed (§3) |
| Recovery only on the ground (`balance-targets.md` §20) | Hold to brake in the air as well (§4) |
| A 120 s signature cooldown (`balance-targets.md` §13) | 45 ki and 15 s, provisional (§5) |
| RB toggles energy (ADR 0008) | RB is held (§5) |
| A dodge against a beam is a roll | A timed dodge always works (§5) |
| The escape stance and its slip roll (`balance-targets.md` §13) | A boost on ki, provisional (§6) |
| One hop after a hard slam | Buried, with a free follow-up (§7) |

**Not in this page:** a glancing bounce on a mountain gaining too much momentum is World's to tune (a bounce must never add speed), and the split-screen camera is Camera's.

## 11. Rulings on the first live build (`654acff`, 2026-10-02)

The build has earned launches at ×1.6 force (about 28% of decided exchanges), knock-backs, the exchange starting at the wind-up with the range bands, a slope speed cap of 1.25, and World's skid fix: skids run twice as long and cut deeper furrows.

| # | Question | Ruling |
| ---: | :--- | :--- |
| 1 | **Walls end 21.5% of launches,** against a band of 5 to 15%. Longer skids reach more walls | **The band stays, and World pulls two levers.** The wall slope rises from 0.8 to **1.0**, so a skid rides up slopes of up to 45 degrees and can fly off the crest. And a skid that meets a wall at a speed under **600** just halts, with no stop-impact: it counts as halted, not as a wall. World re-measures. If walls are still over 15% after both, the band moves to 8 to 18% |
| 2 | **Speed lines** fell from 17 to 7.8 a minute with the new rhythm. The EP let a follow-up heavy after a launch keep its own streak, which gives 10.9 | **Confirmed.** The rule is one streak per exchange, plus one for a follow-up heavy after a launch. The band is 8 to 14 a minute |
| 3a | **The interim far tap** flies in at about the old speed until the taunt and the held charges exist | **Confirmed as interim.** It is the old rush with the exchange starting at the wind-up. Slice 1's taunt and charges replace it (§1) |
| 3b | **A guard press during a rival's approach** starts the 20-tick perfect-block lockout today | **It shouldn't.** Raising a guard as someone flies in is the natural thing to do, and it must not cost the perfect block. The lockout starts only when a guard press lands during a visible wind-up and misses the window, or when two guard presses come within 20 ticks of each other. A single press with no wind-up showing starts nothing |
| 4 | **A patient player starts 22 to 30% of exchanges** against a fast masher, down from 33 to 42% | **A small floor until the alchemist lands.** When both fighters have a press waiting at an exchange boundary, the one who didn't start the last exchange starts this one. Controls' measure should return to 35 to 50% for a patient player who has pressed. The alchemist's trades replace this rule, because there both presses play |
| 5 | **The embed threshold** | **Recorded as World built it:** a crater 1.75 bh deep, or 1.5 bh for a special's impact. That is about two burials a match. It replaces the single 1.5 bh in §7 |
| 6a | **A seeking shot is not stopped by ground** between the fighters | **Confirmed.** It keeps "energy reaches at any range" true on a planet with hills. VFX arcs it over the terrain. A shot that is dodged or loses its target carries on as a straight shot, and that one does hit the ground and structures, with the tier factor |

**6b. The first numbers for shots** (`data/fight/shots.json`), with Combat's rule that a shape carries its strike's damage and never adds to it.

| Kind | Speed (units a tick) | Trade power | Damage | Ki |
| :--- | ---: | ---: | :--- | ---: |
| Bolt | 60 | 1 | Half a light strike (§14; it was a third) | 1 |
| Volley (3 bolts) | 60 | 1 each | One and a half lights in all (§14) | 3 |
| Shard spread (5) | 50, up to 1,200 units | 1 each | A light strike, split in five | 3 |
| Arc | 45 | 2 | ×0.8 of a heavy | 8 |
| Burst | None, within 150 units | 3 | ×0.8 of a heavy | 8 |
| Lob | A fixed 36-tick arc | 3 | A heavy, over an area | 8 |
| Charged shot | 90 | 3 | ×0.6 of a heavy on a tap, rising to ×1.25 of a heavy at 30 ticks of charge, which knocks back (§14) | 8 |

- Every seeking shot arrives within 45 ticks.
- **Trades:** shots of opposing fighters cancel power for power. Bolts cancel in pairs, and a charged shot eats three bolts and ends.
- A held guard takes a blast at the guard's rate, like a strike.
- A heavy charge from the far band (§1) shrugs off shots of power 1 at half damage. Power 2 and above stop it.
- These are first values. QA reports blast damage as a share of match damage from the first energy slice, and the band to start from is 15 to 30%.

## 12. Rulings on Encounter's slice 3 (the challenge and the charges, 2026-10-02)

The starts floor works: a patient player now starts 44 to 49% of exchanges, inside the band.

| # | Question | Ruling |
| ---: | :--- | :--- |
| a | **Matches run 80 s longer** (a median of 9:56, from 8:35). The AI charges 76 times a match, because launches leave the pair far apart about 40% of the time, and each charge is slower than the fly-in it replaced | **Both: the charges shorten, and then QA re-tunes.** A held light goes after 8 ticks and flies 0.3 to 1.0 s. A held heavy goes after 16 ticks and flies 0.5 to 1.4 s. That gives back about half the 80 s. QA then raises k to bring the median to between 7:00 and 7:30. The band stays 6 to 8 minutes: Orb asked for five minutes or more, and nearly ten is too long. The 4 points of extra collateral are inside the bands and need no change |
| b | **The band edge.** A match opens exactly 12 bh apart, so the opening press read as far and played a taunt. Encounter added 0.1 bh of slack | **Move the edge, and keep the opening distance.** The far band starts beyond **12.5 bh**, so the opening press is a lunge. Each band edge also gets **0.5 bh of hysteresis,** so the icon doesn't flicker when the fighters hover on a line. The entrance still needs its 12 bh |
| c | **A rival's press during a held heavy's hold** turns it into a meeting | **Intended.** The defender is free during any charge, and pressing attack is one of his answers. Both rush and meet in a fist clash. The fighter who was already charging enters it at **+5,** for the charge he had built. Winning a clash earns a launch, so he doesn't lose his reward by being met |

## 13. A light-only player can always finish a fight (urgent ruling, 2026-10-02)

**What QA found** on the first agency build (`docs/qa/baseline-agency1.md`). The endings are in band (launch 28.6%, knock-back 20.4%, stay 51.0%), but:
- a masher wins 0 of 100 against the easy, medium and hard AI, where the bands are at least 60% against easy and 35 to 50% against medium;
- two lights-only players never finish: 0 of 40 matches were decided before the 15:00 cap;
- brink to KO is 128 s against 45 to 90.

**The cause is one rule.** A finisher needs decisive exchanges, and a decisive exchange has meant a launch, a clash won or a guard break. Launches now need a heavy. So a player who only presses light can wear the rival down but can never open him up or finish him.

**The fix keeps Orb's four earners and keeps "mash is a blur, weaker".** A light never launches. It doesn't need to.

| # | Rule | Data |
| ---: | :--- | :--- |
| 1 | **A knock-back is a decisive exchange.** Being driven back means that fighter lost the exchange. It counts for the brink's set-up, for the finisher and for the mood, exactly as a launch does | The decisive list gains `knockback` |
| 2 | **A blur always closes.** When four or more lights of a string have landed, the blur plays its own ender, a knock-back the player doesn't press. This holds for plain mashing too. It is not a launch | `blur.enderAfter` 4 |
| 3 | **The plain blur's ender is the weak one.** It drives the rival back 0.6 of the tier's knock-back distance: 2.1, 3, 3.9 and 4.8 bh. The perfect blur, once timing is built, gets the full distance and its clean hits | `blur.enderDist` 0.6 |
| 4 | **A knock-back hurts.** Its skid costs half of a launch's impact wear | `knockback.wear` 0.5 |
| 5 | **Mashed lights do ×0.8 of a light each,** and no less. More strikes at 0.8 is still a weaker string than a combo | `blur.strikeMul` 0.8 |
| 6 | **A light ender never launches.** Earner 2 is still a heavy ender after four landed strikes, and with the alchemist, at flow 3 or more | No change |
| 7 | **The easy AI earns far fewer launches.** It earned 17 to 35 a match against the masher's 2. The AI's use of the four earners scales by difficulty: ×0.25 on easy, ×0.6 on medium and ×1.0 on hard. The target is at most 6 earned launches a match for the easy AI | `ai.earnerUse` 0.25, 0.6, 1.0 |

**What a light-only player can now always do:** land four lights, drive the rival back, and repeat. Each knock-back wears him, and at the brink it opens him and then finishes him.

**The other rows.**
- **Brink to KO.** With knock-backs counted, decisive exchanges go from about 29% to about 49% of the total, so the brink should fall to around 75 s. If it is still over 90 s, `brinkSetups` goes from 2 to 1.
- **Length.** QA's k +8% is accepted, for a median of about 454 s. Re-measure after rules 1 to 5, because knock-back wear shortens matches again.
- **Mood** (Calm 22.1%, Tense 61.0%). Re-measure after these rules. If Calm is still under 30%, the decay goes from 4 to 5.
- **The timing baseline** (timed against a masher 67.5%, style-only against a masher 75.0%, timed against style-only 45.0%) is recorded as the starting point. §2's bands apply once the timing rules are built.

**The bands to hit after this ruling:**
- a masher wins at least 60% against the easy AI and 35 to 50% against medium, with forms taken;
- two lights-only players finish at least 95% of matches before the time cap;
- brink to KO is 45 to 90 s.

**A met charge, until the fist clash exists.** Encounter's interim rule is confirmed: the meeting is settled by the old roll, with 10 points off the charger's chance. With no pulses yet, that stands in for the defender's timing in answering. When the fist clash is built, the pulses decide and the charger enters at +5 (§12).

## 14. Rulings on the slice 4 baseline (QA's `docs/qa/baseline-agency4.md`, 2026-10-02)

The §13 targets are met: the masher wins 99%, 37% and 0% against the easy, medium and hard AI; the lights-only mirror finishes 60 of 60; brink to KO is 65.7 s; the median is 7:21; and KAI is at 51.4%. 83 bands pass and 15 fail.

### 1. How exchanges end: the bands move, and Orb's 30 is measured where it belongs

**Measured:** launch 21.0%, knock-back 31.9%, stay 47.1%.

- **QA's bands are accepted:** launch 18 to 30%, knock-back 25 to 35%, stay 40 to 50% of decided exchanges.
- **Orb's "30% of brawls end in a launch" is a share of the endings, not of every exchange.** A brawl is a run of exchanges in reach, and it ends when the fighters are separated, by a knock-back or by a launch. Nearly half of all exchanges don't end the brawl at all. So the measure is: **of the exchanges that separate the fighters, 25 to 40% are launches.** Today that is 21.0 out of 52.9, which is 39.7%, at the top of the band.
- **The AI's earner use stays** at 0.25, 0.6 and 1.0. Raising it would push launches past Orb's number, and it would take the masher under his band against the medium AI.

### 2. Chains, exchanges and gaps

| Row | Measured | Ruling |
| :--- | :--- | :--- |
| Chains per 100 exchanges | 14.0 against 15 to 35 | **10 to 30,** as QA suggests. Strings now come from the player's presses, so the old chain count runs lower. It is replaced by a strikes-per-string measure when the timing rules land |
| Exchanges started | 26.55 a minute against a limit of 26 | **15 to 28.** Knock-backs make exchanges shorter and more frequent |
| Matches with no gap over 10 s | 92.3% against 95% | **The band stays, and the measure changes.** A gap is 10 s with no strike, blast, charge or taunt from either fighter. Blasts and far taunts are play, and they weren't being counted. If it still misses, Encounter has the AI close or fire within 6 s of a launch |

### 3. A timed player against the AI

**Measured:** 85% against the medium AI, against a band of 60 to 80%, before any timing rule exists.

**The band moves to 70 to 90%,** and a band against the hard AI is added at **40 to 60%.** The timed script stands in for a skilled player, and a skilled player should beat the default opponent most of the time. The medium AI can't be made stronger without taking the masher under 35%. When the timing rules land, QA re-measures both rows.

### 4. Lights-only fights end too fast at the brink

**Measured:** brink to KO is 26 s in the lights-only mirror, against a floor of 45 s.

**A plain blur's ender counts as half a set-up.** Opening a fighter on the brink needs two set-ups. A launch, a clash won, a guard break, a heavy's knock-back or a perfect blur's ender is worth one each. The plain blur's ender, from untimed mashing, is worth half. So a masher needs twice as many to open the rival, which keeps "mash is weaker" true at the brink as well. It is still decisive for wear and for the mood.
- Data: `setup.weight`, with 1 for everything except `blurPlain` at 0.5.
- Expected: about 45 to 55 s for a lights-only brink. The overall 65.7 s is unaffected.

### 5. The buried fighter's free follow-up

**What is live:** the free blow reaches from any distance, the buried fighter is held until the attacker arrives, and the AI never bursts out.

- **The follow-up is a dive, with a time limit and no distance limit.** The attacker presses within 40 ticks, and the director flies him to the crater at charge speed. The blow must land **within 100 ticks of the burial.** At that speed it reaches about as far as a long launch throws, so nearly every burial can be followed. If he can't arrive in time, there is no follow-up.
- **A blast is the other free blow.** With RB held, the press sends a charged shot into the crater. It arrives within 45 ticks from any distance, and it is the weaker choice.
- **The buried fighter is held until the blow lands, and never beyond tick 100.** Without a follow-up he rises at 60, as before.
- **The AI bursts out only when no follow-up is coming.** From tick 40, if the attacker hasn't pressed and is within 12 bh, the AI bursts on 20%, 50% or 80% of chances by difficulty. A burst can't escape a dive that is already on its way.

### 6. Energy

**Measured:** blasts are 4.4% of match damage against a band of 15 to 30%. With the AI firing more they reach 13.9%, but matches run a minute longer and structures lost rise to 45%, because dodged shots hit the ground with the tier factor.

Three changes, together:

| Change | Rule |
| :--- | :--- |
| **Bolts hit harder** | A bolt does **half** a light, up from a third, so a volley of three is one and a half lights. A fully charged shot does ×1.25 of a heavy, and a clean hit from one is a knock-back, so it is decisive and keeps the fight moving. Blasts were too slow a way to win, which is why firing more made matches longer |
| **A missed bolt doesn't wreck buildings** | A shot of power 1 that misses leaves a scorch and does no structure damage. Only shots of power 2 and above damage structures, with the tier factor. Bolts can wound a building they hit directly, but never level one |
| **The band** | **10 to 25%** of match damage, until Orb has played it. The AI's firing rate goes to the level that reached 13.9% |

- These replace the bolt and charged rows in §11's table.
- **The provisional signature limit** gives 5.6 signatures a match between AIs, well under the ceiling. No change. KAI at 42% with it on is the floor, so QA re-centres with the placeholder `dmgMul` values.
- **Re-measure after the three changes:** match length (the minute should come back), structures lost (back toward 35 to 40%), and the blast share.
