# Pitches for Orb: wear readout, Rally, downtime, fragments

Owner: Game Design. Status: pitches for Orb to react to. Date: 2026-09-29.

Orb picked Variant A, "Wounds" (`damage-model.md`). Orb asked for pitches on three follow-ups:
- the readout (N2);
- a Rally per fighter (N3);
- the downtime between exchanges, which the player fills (N4).

The last section brings the orbs (N5) in line with Legal's screen (`docs/legal/q3-screen.md` §a). Everything here is a mechanic that survives a re-skin, and names are working names.

---

## 1. Showing wear without numbers or bars (N2)

Every option shows the same state: four regions, each fresh, bruised, battered or broken, plus the brink (`damage-model.md` §2). They differ in where the eye finds it.

| # | Readout | What it looks like | Sell | Accessibility note |
| :--- | :--- | :--- | :--- | :--- |
| R1 | **Silhouette** | A small body figure by the fighter's name. Each region is shaded by stage. On the brink the outline pulses | Exact and glanceable. Best for learning, and it already backs the `training` mode | Stages differ by fill pattern (clean, hatched, cracked, shattered) as well as colour. Size is scalable. It is the easiest option for colour-blind and low-vision players |
| R2 | **Wound glyphs** | Four small region icons on the nameplate (head, core, arms, legs). Each one cracks as its region wears: hairline, split, shattered | Reads like scars, not stats. Compact enough for a four-player `team-2v2` HUD | Shape-coded, so it needs no colour. A high-contrast mode and larger icons are options. A screen reader can speak glyph changes |
| R3 | **Aura crown** | No HUD at all. The fighter's aura carries four arcs around the body, one per region. An arc flickers when battered and gaps when broken. On the brink the whole aura gutters | Keeps the player's eyes on the fight and is fully in-world. It fits "no meters" best | The weakest at long zoom and for low vision. It needs an arc-thickness option and pairs with R5 audio. It should never be the only channel |
| R4 | **Wound cards** | No persistent readout. When a stage changes, a picture-in-picture card of about 1.5 s shows the damaged region with a stamp, for example "ARMS: BROKEN". The pause menu shows the full body chart | Cinematic, uncluttered, and every change is announced | Cards are transient, so pair them with a persistent option. Captions on. With reduced motion, the card is a still. It adds a readable event for deaf players |
| R5 | **Audio and haptics** (accessibility add-on) | A heartbeat and breathing layer per stage. A distinct rumble pattern for each break and for the brink | Tension without anything on screen | For low-vision and blind-leaning players. Volume and rumble strength are adjustable. Never the only channel |

**Recommendation.**
- **Default:** R3, the aura crown, plus R4, wound cards. The fight shows its state in-world, and every change is announced.
- **Options:** R2 (wound glyphs) as a single HUD toggle. R1 (silhouette) on by default in `training` and as the accessibility default. R5 layers on top of any choice.

## 2. Rally per fighter (N3)

**Shared rule.** A Rally takes a fighter out of the brink and mends one broken region by one stage, so it comes back battered, one good hit from breaking again. Each fighter reaches it differently.

| Fighter | Rally (working name) | Trigger | What it does | Why it is him |
| :--- | :--- | :--- | :--- | :--- |
| Protagonist | **Second Wind** | While on the brink, he survives the opponent's finisher attempt by winning its contested clash or escape roll (`damage-model.md` §5) | Mends a region and gives a short Respect surge: his next track step is free | He gets stronger when his rival gives everything. Surviving their best shot is his fuel |
| Anti-hero | **Spite** | While on the brink, he wins a decisive exchange with his own hands (melee, no signature) and has refused help (no fusion this match) | Mends his arms first, and his next finisher must be by hand | Pride before everything. He comes back only on his own strength. Accepting fusion gives up Spite for the match, which is the cost of taking help |
| Tyrant | **Emergency revision** | While on the brink, press to force an unscheduled revision. It is instant and safe, like his other revisions (Orb) | Mends his most-worn region, but **skips a rung**: he loses the next scheduled refit, and the new revision shows a visible flaw (a crack or a patch) | Vain and quick to anger. He would rather "upgrade" than admit he is losing, and each patch job makes him worse |
| Cyborg | **Reboot** | While on the brink, he docks his backup drive, if it is still loose, or finishes a consume beat within reach of civilians. Consuming stays interruptible, like charging | Mends one chip break (`damage-model.md` §4), and his regrowth doubles for 5 s | He runs on spare parts and people. Protect the civilians, or catch the drive first, to deny him |

**Orb approved these Rallies with looser limits.** The binding limits are in `spec-wounds.md` §2:
- each region can be rallied once;
- a 15 s cooldown;
- the finisher-contest tilt replaces the final-act lock.

The original pitch follows for the record.

**Limits, so finales don't loop (original pitch):**
1. **Once per fighter per match.** The Tyrant may use Emergency revision twice, but never in his full-power form, and each use costs a refit.
2. **Cooldown.** No Rally within 30 s of leaving the brink.
3. **Rallies wear off.** The mended region comes back battered, not bruised. A second brink after a Rally puts the finisher's roll in the opponent's favour.
4. **Final-act lock.** Once both fighters have been on the brink, or after 8:00 of match time, Rallies are off and the next decisive exchange ends the match.
5. **Visible.** Every Rally is a feed line, a bark and a camera beat, so the comeback always reads as earned.

## 3. Downtime the player fills (N4)

Orb's pick: the player fills the 1.5 to 4 s gaps between exchanges (`balance-targets.md` §10) with free flight, taunts, charging and positioning, helped by dynamic set pieces and quick verbal exchanges. Each idea below says what the player actively does, and why it is a decision rather than something to watch.

| # | Idea | What the player does | The decision it creates |
| :--- | :--- | :--- | :--- |
| D1 | **Banter volley** | Tap taunt; the stick direction picks the tone (boast, jab or threat). The opponent has 1.5 s to tap a retort. On-screen lines are chosen by context (wear, biome, collateral, ego meters), voiced as grunts and laughs | An unanswered taunt gives the taunter a bigger ego-meter bump; answering splits it. But taunting spends your breathing room while the opponent could be charging |
| D2 | **Charge standoff** | If both fighters hold charge within sight of each other, their auras meet in a visible push. Release early to take the first strike of the next exchange; hold longer to build more power | Chicken. The one who holds longer gains more, but gives the other a free interrupt window. You read the opponent's aura to decide when to break |
| D3 | **Fragment scramble** | After a big impact, the planet sheds molten fragments at the site (section 4). Fly in and grab them | A fragment is a charge surge for anyone, and mass toward the fold for the Protagonist. Grab it, or stay out of the other fighter's reach; a heavy hit knocks held fragments loose |
| D4 | **Falling-set-piece play** | A tower tips, a crater vents magma, a dam or ice shelf gives way. Steer the opponent into its path, ride a magma plume up for an aerial start, or save the civilians under it | Use the world as a weapon, or protect it. It feeds each fighter's ego meter differently: catching civilians builds the Protagonist's Respect, the Cyborg can scoop them, and it costs the Tyrant nothing |
| D5 | **Stance feint** | Your stance shows on your aura. Flick stances in mid-range to bait the opponent into throwing the attack your real stance beats | The mind game "stances, not combos" promises. The template reads the stance at the moment the attack starts (`stance-matrix.md` R8), so feints are real |
| D6 | **Tumble recovery** | After a long launch, input a timed recovery mid-tumble to right yourself early and pick your landing. The chaser picks an intercept line | The launched fighter can turn a chase into an ambush angle. The chaser must choose between cutting off and hanging back |
| D7 | **Power-up gambit** | Start a long transformation in the open during downtime | The opponent must commit to interrupting it (a decisive exchange, `damage-model.md` §5) or answer with their own power-up. It is a bluff war, and the Tyrant's instant revisions change the maths |
| D8 | **Lock break** (replaces the hunt beat now that hiding is removed) | In ESCAPE, dive through smoke, dust or behind a ridge to break the opponent's lock for up to 4 s, and earn a second breath | The chaser picks a line to regain sight, or waits out the 4 s. Room to breathe, but no concealment and no ambush (`spec-wounds.md` §1c) |

**Guard rails.**
- No idea may pause control for more than the set-piece allowance. Banter never freezes play: lines appear over live action.
- The AI uses every idea too (Encounter Systems), so solo play has the same texture.
- QA's "no gap over 10 s" band still applies (`balance-targets.md` §8), and none of these may stall a fight.

**Recommendation for a first playable:**
- D1 banter;
- D2 standoff;
- D3 scramble;
- D5 feints.
All four need little new content and use systems already on the path.

## 4. Fragments, brought in line with Legal's screen (replaces N5)

Legal rated **Held fragments** CONDITIONAL. The conditions are binding (`docs/legal/q3-screen.md` §a). The design:

- **Source.** The planet itself. Big impacts (region-break launches, beam hits, ground tier-ups, clash shockwaves) shed **irregular molten or crystalline fragments** of different sizes where they land. How many exist depends on the damage and the planet seed. It is never a set, and never seven.
- **Anyone can grab one.** A fragment gives an instant charge surge (Legal's A1, GO). There is no hiding, searching, radar or sensor. They are in plain sight where the fight happened.
- **The Protagonist can hold them.** They orbit his body (Legal's A2 look and pose rule, with no raised-arms pose). The fold into the barren proving ground unlocks when the **total mass he holds** passes a threshold. Any mix of sizes works. There is no count to complete, no required order, no wish and no summoned being.
- **Contested.** A heavy hit knocks one held fragment loose, chosen by a seeded draw weighted toward the largest. The opponent can grab it for its surge, which also denies the mass.
- **Element variety.** Five element looks (molten, crystal, storm, tide, stone) follow the biome that shed them. They are a colour-and-effect variety, not a collection.
- **Pacing.** The threshold is tuned so that the fold typically becomes possible in act 3, and never before the 4:00 floor (`systems-sketch.md` §4).
- **Tripwires we will never cross:**
  - exactly seven of anything;
  - stars or numerals on fragments;
  - a sensor;
  - "wish" or "summon" language;
  - a required order;
  - identical smooth spheres.
- **Fallback.** If Art or Marketing cannot keep clear of the tripwires, drop holding and the fold. Keep shedding and surges (A1) and orbit charge (A2).

**Questions left for Orb:**
- Should the fold also need a time floor? Recommended: yes, 4:00.
- Should a rival's grab be only a denial, or also a small boost to their own meter? Recommended: a surge plus a denial, with no meter bonus.

## 5. Broken limbs: a dramatic swing, not a routine (questionnaire 5)

Orb: "a dramatic swing during the match, not especially common but a real consideration when playing." Today limbs break 3.75 times a match (arms first in 63%), so breaks are routine. Pitch: **limbs stop breaking from plain wear.**

**A. The crippling moment (recommended)**
- **How often:** about 1 match in 3 has one limb break (0.3 to 0.5 a match), and a fighter breaks at most one limb per match.
- **How it happens:**
  - Limbs still wear down to battered, but they stop there.
  - A limb breaks only in a *crippling moment*: a heavy-class blow (a heavy, a guard break, a signature or a chain ender) lands on a battered limb in a decisive exchange, and a roll succeeds.
  - The roll starts at 15%, rises by 10 if the attacker is a tier ahead, and by 10 in act 3 or later. It drops by 10 if the defender holds DEFENSIVE, bracing.
- **Why it's a real consideration:** you see your limb reach battered, so you guard it or keep it out of the fight. The attacker sees it too, and loads heavies to go for it.
- **The beat:** a respected 1.5 s set piece. The camera pushes in, the crack lands, both fighters get a line, and a long launch across the map follows.
- **What changes afterwards:**
  - *A broken arm* weakens heavies and signatures, but the fighter turns feral: lights hit 15% harder and chain more often.
  - *Broken legs* take away the dash, but the fighter plants: their guard gets stronger.
  - *For both sides:* the fighter who did it gets a meter surge and the fight's mood jumps. The broken fighter gets the trailing-fighter help (comeback ruling). The rival who fights on with a wrecked arm is the story.
- **Brink and finisher:** the brink becomes **the core broken**. Wear that would push a limb past battered spills into the core, so the fight still ends on time. The finisher rule is unchanged: a KO only comes through a finisher from the brink. Rally mends the core; a broken limb stays broken for the match, as its scar.
- **The break band:** "3 to 5 region breaks" is retired. The new bands are limb breaks 0.3 to 0.5 a match and one core break a match (the brink), plus any re-brinks after Rallies. Acts also advance when a core reaches battered, so chapters still come.

**B. A high threshold** (simpler, less dramatic). Limbs break only past 130 wear, the director spreads its hits, and the brink is the core broken, or the core battered plus one broken limb. Breaks become rarer, but they happen when the numbers say so, not in a moment.

**C. The price of survival.** Limbs break only when a fighter survives a finisher: they live, but lose an arm or a leg. The rate follows contest survival (about 1 match in 4). It is very dramatic, but it only matters at the end, so it is less of a consideration during play.

## 6. For Orb: the in-match upgrade draft (questionnaire 8)

The idea, from a friend: during a match, pick one of three upgrades. Most are stat and movement picks, a rarer one is a special, and the picks come at transformations or act changes, with short early phases building to a peak.

**The same in every option:**
- **Small numbers.** A pick is worth at most +10%, and a stat can't be raised past +25% in one match.
- **Fair and replayable.** Each fighter's three offers come from a seeded deck, so replays and online play match. Both players see what was picked, as icons under the portrait.
- **Nothing is locked.** Every card is in the deck from the start (questionnaire 3).
- **Optional.** A "Draft: on or off" switch at match setup. The 45 to 55% balance band must hold either way.

**Example cards.**
- *Stats:* Might (+8% damage); Reserve (+15 ki cap); Thick Skin (guard takes 10% less).
- *Movement:* Slip (dodge cooldown 1 s shorter); Afterburn (sprint 15% faster); Quick Break (burst cooldown 2 s shorter).
- *Special (rarer):* a fourth special for this match, or a signature variant.

| | **A. Form picks** (recommended) | **B. Act picks** | **C. The plan** |
| :--- | :--- | :--- | :--- |
| **When** | Each time a fighter transforms. The three cards appear **inside the transformation cinematic**, so the fight never stops for it | At each act change, about 2:00, 3:00 and 5:00. A 3 s beat where **both fighters pick at once** | **Before the match:** each player drafts three picks, one of three each time. They switch on in stages as the acts advance |
| **How many** | Up to 3 per fighter: the first, second and final form | 3 per fighter | 3 per fighter |
| **The special pick** | At the final form only | At the last act change only | The third draft |
| **Feels like** | Every transformation is also a build choice, and you earn it by getting there | A shared interval, like a round break, that both players read | A game plan chosen up front, with no interruption at all |
| **Good** | No added pause. It rewards transforming, and the rival can delay a pick by stopping the fill | Perfectly even: both get the same picks at the same time | The simplest to build, and the best for online play. Acts stay invisible |
| **Risk** | The leader may pick first, which can snowball. The trailing-fighter help offsets it, and QA checks | It pauses the fight three times, and it makes the invisible acts visible, which changes your questionnaire 4 pick | You can't adapt to how the fight is going, which is half the fun of a draft |
| **Phases building to a peak** | Early forms come quickly and the final form is the peak | Acts 2 and 3 are a minute apart, then the long final act | The picks arrive on the same act timing, but they were chosen earlier |

**Orb picked C** (questionnaire 10). The design is in `upgrade-plan.md`.

*The recommendation had been A.* The cinematic is already a respected pause where the rival waits, so the pick costs no extra downtime, and it gives the Transform hold a second reason to matter. If you want it perfectly even, B is the one. C is the fallback if pausing mid-match tests badly on phones or online.

**The next build** would not include the draft. The placeholder transform lands first (`control-rules.md` §7), and option A needs it.

## 7. For Orb: the rival's ego and the roster's biggest swing (2026-10-01)

Orb's picture: the Protagonist and the rival (the Anti-hero) are both solid all-rounders. The rival's final transformation is the largest swing in power in the roster, but his ego may cost him heavily, or hand the opponent a large buff, in the mid to late game.

**The same in every version.**
- **Three forms,** like a typical fighter. His five-form Pride ladder folds into three: Regalia at Pride 60, Sovereign at 80 and Apex at 95.
- **For scale,** a typical fighter gains +9% damage a step, so +27% at the top.
- **Pride** runs from 0 to 100 and is visible. Humblings (being perfect-blocked, guard-broken, thrown or crippled) cost 15 each, and the crash below 50 still takes a form away.
- **Even overall.** His win rate stays inside 45 to 55%. He wins under 45% of the matches that end before Apex and over 60% of those that reach it, which is the "situational" rule from questionnaire 5.
- **Abdicate** (Drop the Act) stays as his way out: he gives up the climb for unrestrained power now.

| | **A. The Indulgence** (the opponent's buff) | **B. The Heavy Crown** (his own debuff) | **C. The Wager** (a handicap he chooses) |
| :--- | :--- | :--- | :--- |
| **The idea** | The opponent talks him into letting them power up | His damage drops as his ego grows, because he toys with them | He takes each form by declaring a handicap, and must back it up |
| **What feeds the ego** | Winning exchanges (+3), completed taunts (+6), and granting a request (+20) | Styling: an exchange won (+3), a perfect block (+5), a taunt (+6), a string of three or more (+8) | A wager won (+25), plus exchanges won (+3) |
| **The cost** | At Pride 60 or more the opponent may **ask**, once a minute and twice a match. If he grants it, the opponent gains a whole ladder step at once and full ki, which is about +9% damage and +10% speed for the rest of the match | Above Pride 50 he loses 4% damage per 10 Pride, so he is at −18% just before Apex. That is his weak mid-game | Each wager is one of two handicaps for 20 s: no heavies, no guard, or the opponent charges untouched for 6 s |
| **If he refuses or fails** | Refusing costs 10 Pride: he looks afraid | A humbling drops his Pride and the climb, but his damage comes back | A lost wager costs 30 Pride and the form |
| **The payoff** | Each grant brings Apex a form closer and adds +6% to Apex's damage | Reaching Apex ends the restraint for good | Each wager won adds +8% damage for the match |
| **The final form's swing** | +25% damage, up to **+37%** with two grants | From −18% to **+40%**: a 58-point swing in one moment | +20%, up to **+44%** with three wagers won |
| **Fit with his Pride ladder** | The forms stay as they are. The ask is a new beat at Regalia and Sovereign | The ladder is the debuff: every form before Apex makes him showier and weaker | The wager is how each form is entered |
| **What it needs** | A prompt for both players (ask, then grant or refuse), and AI for both sides | Data only | A two-option prompt at each form, and rules for three handicaps |
| **Risk** | Both players may always say yes, so both just get stronger and the choice goes flat. A player-controlled rival may never grant | His mid-game may feel weak to play. If Apex comes in under a quarter of his matches, he is simply weak | The most rules and the most swing. One lost wager can decide the match |

**Recommendation: B first, then A on top.**
- B is your "damage drops as his ego grows" as written. It needs no new input, it tunes by data, and its one moment at Apex is the largest swing in the roster.
- A adds the talk, which is the part only he has. It stacks cleanly on B once B is proven: granting a request would be the fastest way through the weak middle.
- C is the showiest, and it is the fallback if B's mid-game reads as weakness rather than arrogance.

**"Playing along" pays** in every version: the player who leans into his ego (taunting, toying, granting, wagering) reaches a bigger Apex sooner, and the player who fights plainly gets an ordinary all-rounder.

The ego mechanic is scheduled after his first moveset (questionnaire 8), so nothing here is in the next build.

## 7b. For Orb: hybrids of A and B, with "take it on the chin" (2026-10-01)

Orb asked for hybrids of §7's A (the opponent's ask) and B (the Heavy Crown), leaning on B, built around Orb's own idea. Every number is a proposal for data. §7's win-rate rules stay: 45 to 55% overall, under 45% in matches that end before Apex, and over 60% in those that reach it.

### Take it on the chin (in all three hybrids)

The rival plants his feet, opens his arms and lets the opponent hit him. What he absorbs counts in full toward his ego, and only in part against his body.

| Question | Proposal |
| :--- | :--- |
| **When the prompt appears** | His Pride is 60 or more (he has taken his first form), he is free and not guarding, he is not on the brink or opened up, and the move is off cooldown. The context icon gains a "hold" mark |
| **The input** | **Hold** the context button for 12 ticks. A tap still does the usual context action, so ADR 0008's priority list is untouched. The stance lasts while held, for 4 s at most |
| **How many attacks** | Up to 3 ordinary hits, or 1 signature, which ends it |
| **The reduction** | Ordinary attacks hurt 17% less (Orb's figure; the tuning range is 15 to 25%). A signature hurts **70% less**. Nothing launches, staggers or moves him |
| **Against his body** | Only the reduced damage becomes wear, and it lands on the head and the core, half each. That is the real price: his core is his brink |
| **Toward his ego** | The move's **full** damage counts: +1 Pride per 12 damage. That is about +2 for a light, +5 for a heavy and +20 for a signature, the best rate in his kit. A completed absorb (3 hits, or a signature) also adds to Apex's size |
| **What he gives up** | Movement, guard, dodge, attacks and the burst. Releasing early ends it with 20 ticks of recovery |
| **How often** | A 25 s cooldown from the end of the stance |
| **A signature absorbed** | A set piece: a 1.5 s pause, a camera push and a line of bravado ("Was that supposed to hurt?"). It is the short version in the pause budget and draws on the bank. When the bank can't cover it, it plays live with a camera cut. Signatures come 2 to 4 times a match, so this costs 1.5 to 3 s in a match with a 17 s budget |
| **The opponent's counterplay** | **Throw him:** a grab or tackle beats the stance at full damage and humbles him (−15 Pride). **Don't attack:** he gains nothing, the cooldown starts, and the opponent has up to 4 s to charge untouched. **Hit him anyway** when ahead on wear: every hit goes to his head and core |
| **The AI rival** | It uses the stance when its core is below battered and it isn't within 15 Pride of a crash. It answers a signature tell on 20%, 45% or 70% of chances (easy, medium, hard), and otherwise uses it when the opponent has a string queued |
| **The AI opponent** | Easy attacks into it. Medium charges. Hard throws him |

**How it fits B.** In B his damage falls as his Pride rises, so the middle of the match is his weak stretch. The chin gives that stretch a job: he can't out-hit the opponent, so he banks their attacks to reach Apex sooner. It also fits the Proud front, which already hides his wear.

### Three hybrids

| | **1. On the Chin** (lead) | **2. The Open Invitation** | **3. The Slow Burn** |
| :--- | :--- | :--- | :--- |
| **How much of A** | A little. There is no ask. The opponent's choice is built into the stance: hit him and feed him, or charge for free | The most. The stance is an open offer, and the opponent can also ask once | None |
| **B's debuff** | Full: −4% damage per 10 Pride above 50, so −18% before Apex | Full, as in 1 | Half: −2% per 10 Pride, so −9% before Apex |
| **The opponent's buff** | None beyond the free charging time | While he holds the stance, an opponent who charges gains at double rate, and he gains +10 Pride for waiting. At Pride 80 or more the opponent may **ask** once a match: they gain a whole ladder step and he gains +20 Pride | None |
| **Apex** | +36% damage, +3% per completed absorb, up to **+45%** | +34%, +3% per completed absorb and +6% for granting the ask, up to **+49%** | +30%, +2% per completed absorb, up to **+36%** |
| **The swing at Apex** | 54 to 63 points | 52 to 67 points | 39 to 45 points |
| **What it needs** | One hold prompt, one short set piece, and data | Two more prompts (the offer and the ask), and AI for both | The same as 1 |
| **Risk** | His middle is weak if the opponent never attacks into the stance. The 25 s cooldown and the opponent's own need to deal damage limit that | Both players may take every offer, so both just get stronger and the choice goes flat | Safer, but less of an identity: his swing is still the roster's largest, by less |

**Orb picked 1, On the Chin** (2026-10-01). Its rules now live in `spec-wounds.md` §3, under the Anti-hero's kit, as proposals for data. It is built after his first moveset.

*The recommendation was 1:* It is B at full strength with Orb's move as the engine, and it needs only one new prompt. The piece of A it keeps costs nothing to build: every time he poses, the opponent chooses between feeding his ego and powering up. If playtests show that the talk between the two players is missing, 2's open invitation adds onto it without changing anything in 1. 3 is the fallback if his weak middle feels bad rather than arrogant.

## 8. For Orb: three rule-of-cool pitches (questionnaires 11 and 12)

Each pitch has options, a comparison and a recommendation. The numbers are proposals. The full feature plan is in `rule-of-cool.md`.

### 8a. Which hits earn the big impact treatment

Orb picked speed lines and panel cut-ins, with no impact frames and no slow motion, at a spectacle level of 4 out of 10. The question is which hits get them.

**How often the candidates happen** (QA's Q10 retune, 7:36 a match; the two marked "est." aren't measured yet):

| Candidate | Rate |
| :--- | :--- |
| A heavy that lands | 8.3 a minute (QA's first reading; the estimate was 6) |
| A launch | 11.8 a minute |
| A heavy clash won | 0.69 a minute (QA's first reading; the estimate was 1.5) |
| A signature | 3.0 a match |
| A finisher | About 1.5 a match |
| A crippling blow | 0.5 a match |

| | **A. Peaks only** | **B. Two levels** (recommended) | **C. Every big hit** |
| :--- | :--- | :--- | :--- |
| **Speed lines alone** | None | Every launch and every heavy that lands: a 6-tick streak with no cut | None |
| **Panel cut-in with speed lines** | Signatures, finishers, crippling blows and the KO | The peaks in A, plus hits the player earned: a clash won, a riposte that launches, and a ping-pong's ender | Every heavy that lands and every launch |
| **Rationing** | None needed | Earned hits share one panel every 12 s. Peaks always play | None |
| **Panels a minute** | About 0.8 | About 2.5 | About 15 |
| **On Orb's scale** | About 2 of 10 | About 4 of 10 | About 8 of 10 |
| **Risk** | Long stretches look plain | The ration needs tuning so panels don't cluster | The panel stops meaning anything, and it hides the fight |

**Orb picked B, two levels.** With QA's measured rates the panel count holds: about 0.8 a minute from the peaks, plus about 1.6 from earned hits under the 12 s ration, so about 2.4 a minute. Speed lines alone ride on about 15 to 20 hits a minute.

*The recommendation was B:* speed lines are cheap and never cover the screen, so they can ride on every launch. The panel stays rare enough to mean "that one mattered", and it lands at 4 of 10.

### 8b. A last stand at the brink

Orb didn't pick this as a story beat at first, then asked for a pitch. The wounds model already does part of it: a fighter near the brink hits up to 50% harder, the trailing fighter gets small bonuses, and each fighter has a Rally. Comebacks are meant to be common, at 30 to 45% of matches.

| | **A. The stance** | **B. One last signature** (recommended) | **C. Refuse to fall** |
| :--- | :--- | :--- | :--- |
| **What he gets** | Presentation only: a camera cut, his face cut-in and a line when he reaches the brink | A, plus his signature becomes free and ready at once, for 20 s, the first time he reaches the brink | A, plus he survives the first finisher automatically |
| **Fit with the wounds model** | No change. It shows the harder hits he already has | No change to wear. The rival still answers it as any signature: guard, a perfect block, or a beam of their own | It overrides the finisher's survival roll, which is now about 32% |
| **Fit with the brink chapter and Rally** | None | A signature that lands is a decisive win, so it closes his opening and can start a Rally where the fighter's Rally allows | It repeats what the Protagonist's Rally already does, and it stretches the brink chapter past its 45 to 90 s band |
| **Comebacks** | Unchanged | Up a little. QA holds them at 30 to 45% | Up a lot, and finishers stop being decisive |
| **How often** | Once per fighter per match | Once per fighter per match. A second brink after a Rally gives nothing | Once per fighter per match |
| **Risk** | It may feel like a promise with nothing behind it | One more signature a match, so the band becomes 2 to 5 | It undercuts the finisher, which Orb set at 7 of 10 |

**Orb picked B, one last signature.** The rule is in `spec-wounds.md` §1b. Legal's re-screen of it is pending.

*The recommendation was B:* it gives the fighter on the brink one clear, dramatic thing to do, the player chooses the moment, and the rival can answer it. It needs no new system.

### 8c. What a completed taunt does

Orb picked a mid-fight taunt that can be punished, with an effect that depends on the fighter.

**The same for every fighter.**
- *The input:* the context button's fallback in physical mode (`control-rules.md` §4).
- *The gesture* is each fighter's own, and never beckoning fingers (Legal).
- *It takes 1 s.* A dodge-cancel can end it in the first 20 ticks. After that he is committed.
- *Punished:* any hit that lands during it is a clean hit at ×1.2.
- *Completed:* mood +3, the face cut-in plays, and the fighter's own effect happens.
- *Cooldown:* 15 s.
- *The AI opponent is goaded:* for 4 s it attacks more, by 50% on easy and 25% on medium. The hard AI isn't baited.
- *Target:* 1 to 3 completed taunts per fighter per match, with 20 to 40% of attempts punished.

| | **A. Meter only** | **B. In character** (recommended) | **C. The dare** |
| :--- | :--- | :--- | :--- |
| **The rival** (Anti-hero) | Pride +6 | Pride +6, as already written | A dare, as for everyone |
| **The Protagonist** | Heat +10 | **A challenge.** If the opponent attacks him within 5 s, it counts as a full commitment: a Respect spark of +10 heat | A dare |
| **The Empress** | Wrath +8 | **A reprimand.** The opponent is riled for 6 s: they hit 5% harder, but their wind-ups are 2 ticks longer, so they are easier to perfect-block | A dare |
| **The Cyborg** | Hunger +5 | **Service.** A sandwich pickup appears beside him, worth Hunger +5 when he takes it. The opponent can knock it away | A dare |
| **How it works** | Every taunt feeds its fighter's own meter | Each taunt does a different kind of thing: meter, goading, angering, and a pickup | A completed taunt arms a dare for 8 s. His next decisive win pays double meter and mood +6. If he loses it, the opponent gets +10 on theirs |
| **Risk** | All four feel the same | Four small rules to tune. "Riled" must stay readable | High stakes on every taunt may make players stop taunting |

**Orb picked A, meter only** ("taunts should just feed meters"): Pride +6, heat +10, Wrath +8 and Hunger +5, with the shared rules above kept. The rule is in `control-rules.md` §4.

*The recommendation had been B.*
