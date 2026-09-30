# Stance matrix

Owner: Game Design. Status: P0, draft for EP review. Date: 2026-09-29.

This page says what each stance is for, what beats it and what it costs. For every stance against every attack kind it gives the intended outcomes, lists the gaps against the P2 exit criterion, flags the dominance risks, and sets the stance rules for P2.

**Division of labour.**
- **Combat's `docs/combat/exchange-templates.md` is the canonical inventory** of templates, beats, branches and outcome counts per pairing. This page does not repeat it. It states the design intent each template must serve and the rules the P2 director must follow.
- **Observed frequencies come from QA** (`qa/baseline-p0.md` §7, default arm, 1,000 matches).
- **Code references** (`index.html:L123`) are lines of `prototype/index.html` at commit `7233c96`.

**Orb's ruling (docs/ep/vision.md):** keep stances and the fight director. Transformations, minions, Tandem and the other per-fighter systems (`systems-sketch.md`) change numbers and add moves. They never change this grammar.

## 1. The four stances and the charging state

| Stance | Its job | What beats it | What it costs | Today (`index.html`) |
| :--- | :--- | :--- | :--- | :--- |
| **AGGRESSIVE** | Press and trade. Meet force with force. | Being read by an EVASIVE defender. A parry timed in the wind-up. | Takes ×1.12 damage (`L326`). A signature against it becomes a beam clash that costs the defender 40 ki (`L586`, `L603`). | The AI's favourite while healthy. Weight 2.4 above 35% HP (`L815`). |
| **DEFENSIVE** | Absorb and punish. | Heavy: GUARD BREAK drains 25 ki and lands a strike that ignores the guard, then a launch (`L481-488`). | Moves at ×0.8 (`L771`). Every hit taken drains ki worth 8% of the damage (`L329`). | Takes ×0.38 damage (`L326`). The AI stands still and charges (`L832-833`). |
| **EVASIVE** | Read and slip: dodge behind the attacker, then counter. | Being read: a light from an AGGRESSIVE attacker, a tier advantage, or an ambush (`L458`). | When read, it eats the full hit. Takes ×1.0 damage. | Moves at ×1.25 (`L771`). Counters 54 to 60% of melee (QA §7). |
| **ESCAPE** | Disengage, break lock through line of sight, and reposition (hiding is removed; `spec-wounds.md` §1c). | Being caught: a pursuit that is not slipped, or a signature at close range (`L441`, `L589`). | Takes ×1.25 damage (`L326`). A caught pursuit hits at base ×1.2 with a launch (`L452-453`). | Moves at ×1.35 (`L771`). The only stance that can break lock through line of sight (`spec-wounds.md` §1c). The AI never attacks from it (`L841`). |
| CHARGING (a state, not a stance) | Build ki (+30/s) and power (+9/s) in the open (`L783`). | Any attack: CHARGE INTERRUPT ignores stance and launches (`L435-438`). | Total exposure, and the charge ends. | Rarely attacked: 73 of 19,670 exchanges (QA finding 6). |

## 2. Defender state × attack kind: intent, counter, cost

**What the director selects on.** The defender's state and the attack kind choose the template (Combat §1). Today the attacker's stance is not a selector; section 3 changes that for P2.

**Outcome counts.** Today's counts follow Combat §3.2 and QA §7. The last column is the P2 target, and section 4 gives the rules behind it.

| Defender | Attack | Intent: what this cell is about | Counter (who should win it) | Cost (what the winner risks) | Outcomes today | P2 target |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| AGGRESSIVE | Light | Force meets force. A trade that the stronger fighter, or the one with more ki, tends to win (`L495`). | The better-resourced fighter. The defender can parry the opening strike. | Both take damage, and the loser is launched. | 2, but the feed never names the winner | 2, both named in the feed (TRADE BLOWS — WON / LOST) |
| AGGRESSIVE | Heavy | A heavy clash with three endings, weighted by tier and ki (`L502-506`). | The attacker if ahead on tier or ki. The defender can parry during the 0.33 s window. | The loser eats a heavy and a launch. A shockwave costs both sides and the world. | 3 | 3 |
| AGGRESSIVE | Signature | Beam meets beam. A defender with 40 ki or more answers with a clash (`L586`). | The clash roll: tier, ki, randomness, and today menace (`L625`). A defender below 40 ki is simply hit. | The defender pays 40 ki to clash. The loser takes 260 and a launch (`L636-638`). | 3 (Combat §3.2). A clash in 95% of these exchanges (QA §7) | 3 |
| DEFENSIVE | Light | The guard holds. A light is the wrong tool against a guard. | The defender. | The defender loses a little ki per hit. The attacker risks a counter. | 2, weak: the counter is a 40% roll the defender never earns (`L479`) | 2: GUARD HOLDS, or a counter the defender earns by input (R4) |
| DEFENSIVE | Heavy | A heavy breaks a guard. This is the answer to turtling. | The attacker. | The defender loses 25 ki, takes a strike that ignores the guard, and is launched. The attacker spends 4 ki. | **1: FAIL** (GUARD BREAK) | 2: GUARD BREAK, or BRACE when the defender has ki to spare (R3) |
| DEFENSIVE | Signature | A guarded beam hurts less, but it still hurts. | The defender, mostly. | The defender takes 200 × 0.38 plus a launch (`L611-613`). The attacker spends 45 ki for little. | **1: FAIL** (GUARD) | 2: GUARD, or DEFLECT; Interpose for protectors (R3) |
| EVASIVE | Light | The read game. A light from AGGRESSIVE is the tool that pins an evader. | The attacker's read against the defender's slip (`L458`). | A wrong read gives the defender a counter and a launch. | 2 | 2, with the AGGRESSIVE read bonus raised (R2) |
| EVASIVE | Heavy | Commitment gets punished. A heavy is the wrong tool against an evader. | The defender (a heavy's read chance is 0.05 lower). | The attacker eats a counter of base × 0.9 and a launch (`L468-469`). | 2 | 2 |
| EVASIVE | Signature | Dodge the beam. | The defender, about 55% of the time (`L588`). | The attacker spends 45 ki. | 2 | 2 |
| ESCAPE | Light or heavy | The chase: a real gamble, never a range check (pillar 3). | A coin flip moved by tier and distance (`L441`). An ambush always catches. | If caught, the defender takes base × 1.2 × 1.25 and a launch. If it slips, the attacker loses 3 ki. | 2 | 2, and an EVASIVE attacker is better at running the defender down (R2) |
| ESCAPE | Signature | Outrun the beam, unless it is fired from close. | The attacker when close (+0.3 inside 500 units, `L589`). | An escape wastes 45 ki. | 2 (the tier term has the wrong sign: GD-B01) | 2, with the tier term fixed |
| CHARGING | Any | Charging in the open is a gamble. Early in a charge you are exposed. A charge you finished earns you a defence. | Today, always the attacker. | The charger is launched and loses the charge. | **1: FAIL** in all three cells | 2: INTERRUPT, or BURST or OVERCHARGE CLASH after a full charge (R3) |

**Parry.** The parry is a defender interrupt, not a cell outcome (Combat §3.1). It exists in four templates: TRADE BLOWS, PRESSURE, GUARD BREAK and HEAVY CLASH — WON. Its windows are 0.10 s, and 0.33 s on HEAVY CLASH — WON. Nothing on screen shows them (Combat CC-011). QA measures 9.1 parries per 100 melee exchanges (QA §8).

## 3. The attacker's stance: today a pairing in name only

Today the attacker's stance changes two things inside an exchange:
- the EVASIVE read chance: +0.08 when attacking from AGGRESSIVE (`L458`);
- the multiplier the attacker takes when the defender strikes back, because `hit()` uses the victim's stance (`L326`).

So the 16 stance pairings are four defender columns played four times (Combat §3.3). Every ESCAPE-attacker cell goes unplayed by the AI, because it never attacks from ESCAPE (`L841`).

## 4. Dominance risks

Reasoned from the rules and QA's data. None of these was tested with new batches (ADR 0005). Each is marked for QA's probe (section 6).

1. **DEFENSIVE is the stance a rules-reader would live in.** High risk.
   - The rules put no cost on attacking from DEFENSIVE. Outgoing damage ignores the attacker's stance, and nothing limits the rate of attacks (`L319-338`, `L390-416`).
   - Its ×0.38 applies to the counters it receives as an attacker: the defender's blows in TRADE BLOWS (`L498`, `L500`) and DODGE & COUNTER (`L468`).
   - Its ×0.8 speed costs nothing, because every attack closes the gap by itself (pillar 3, `L420`).
   - Its only answer is the heavy, and heavies cost 4 ki.
   - The AI hides all this because it attacks about 2 to 2.5 times less often in DEFENSIVE (`L844`). A human has no such limit.
2. **EVASIVE wins most exchanges as a defender.** Medium risk.
   - DODGE & COUNTER is 54% of light attacks into EVASIVE and 60% of heavies; the signature is dodged 54% of the time (QA §7).
   - The attacker's tools against it are weak: +0.08 for AGGRESSIVE, and the tier term (`L458`).
3. **"Winners spend 55% of the match in AGGRESSIVE" is not evidence that AGGRESSIVE dominates** (QA §9). The AI picks its stance from HP (`L815`): AGGRESSIVE above 35% HP, DEFENSIVE below 55%, ESCAPE below 30%. So losing fighters drift into DEFENSIVE and ESCAPE because they are losing. Use the fixed-stance probe instead (section 6).
4. **Parry mashing.** Medium risk. A mistimed parry press costs nothing (Combat CC-008), so the parry is not yet a read.
5. **Guard bypass through a chain.** Medium risk. After PRESSURE — GUARD HOLDS, a chain opens. The chain's strike ignores stance, so the guard stops mattering (Combat CC-002, GD-B04).

## 4b. Who controls what (Orb, questionnaire 4)

| The player controls | The director controls |
| :--- | :--- |
| Stance (intent); movement and positioning; attack **weight** (light, heavy, signature); charging and power-ups; **when to transform**; fighter specials (the heat track, Drop the Act, Press, the fold, the Encore call) | **When** to attack; combos and chain continuation; parries; the finisher struggle; voice and barks |

Skill balance is 2 out of 10: strategy far outweighs execution.

- **R9. Attacks are timed by the director; the player sets their weight.**
  - *Weight is a sticky setting.* Pressing light or heavy sets the weight of every strike from then on, until the player changes it. It shows on the stance ring.
  - *Signature is a one-shot intent.* It fires at the director's next opening, once the fighter has 45 ki.
  - *The player shapes when through stance.* Each stance sets the director's attack cadence for the player's own fighter:
    - AGGRESSIVE: the director's fastest tempo, and it chains most readily;
    - DEFENSIVE: it attacks mostly as a punish (the R2 punish window) after absorbing an exchange;
    - EVASIVE: it attacks after dodges and reads, plus the occasional poke;
    - ESCAPE: it only hits and runs when the opponent has committed, and otherwise disengages and breaks lock.
  - *Charging and specials* pause the director's attacks until they end.
  - *Chains:* whether to continue is the director's call. It reads stance (AGGRESSIVE chains most), ki, heat and the fight's mood (`spec-wounds.md` §9).
  - *Controls' intent queue* (`docs/controls/intent-queue-plan.md`), answered:
    1. Light and heavy latch as the weight mode. The match starts in light. Signature is a one-shot in the queue slot, and returns to the latched weight after it fires.
    2. No timing press remains anywhere. Chain follow-ups are the director's call. The beam clash is resolved by state: AGGRESSIVE with 40 ki or more meets the beam, and the winner is decided by tier, ki and meters.
    3. The player's lever over parry and the struggle is stance plus a ki reserve (R5, the finisher row in `spec-wounds.md`). There is no new input.
    4. A funded, queued signature fires within **180 ticks** (3 s), overriding the stance's cadence if it must, at the next exchange boundary.
    5. The special and transform holds stay (stoke, Press, the fold trigger, Drop the Act, taking a filled transformation), and so does the Encore's contextual prompt.
- **Where skill lives now:**
  - *reads:* hold the stance that beats the opponent's likely weight, and set the weight that beats the opponent's stance (heavy into DEFENSIVE, light from AGGRESSIVE into EVASIVE);
  - *spacing and position:* which biome, near people or away from them, line-of-sight blockers, the city's edge;
  - *resource timing:* ki for a signature or held back for a clash; when to charge; the heat stages; spending Pride; when to Press;
  - *transform and special timing:* when to take a filled transformation or fire the fold, Drop the Act or the Encore.

  There is no execution test anywhere in the base game.

## 5. Stance rules for P2 (Game Design decisions)

The director implements these rules through Encounter Systems. Combat authors the beats.

- **R1. Attacking drops your guard.** During your own exchange, a counter hits you at ×1.0 whatever your stance. Stance multipliers protect only the fighter being attacked. This removes risk 1's free protection.
- **R2. Each stance has an attacking profile.** The attacker's stance becomes a real part of the pairing:

  | Attacking from | Damage dealt | Perk | In one line |
  | :--- | :--- | :--- | :--- |
  | AGGRESSIVE | ×1.15 | +0.15 read chance against EVASIVE (today +0.08). Wins tied trades | Presses, and pins evaders |
  | DEFENSIVE | ×0.85 | ×1.3 on a punish: an attack started within 0.6 s of your guard absorbing an exchange | Absorbs, then punishes |
  | EVASIVE | ×1.0 | The target's slip chance is 0.15 lower when pursuing ESCAPE | Runs down the fleeing |
  | ESCAPE | ×0.9 | Hit and run: the exchange ends after the first strike, with no counter and no chain | Strikes and vanishes |

  The result is a readable loop:
  - An AGGRESSIVE attacker pins EVASIVE.
  - An EVASIVE attacker runs down ESCAPE.
  - DEFENSIVE punishes AGGRESSIVE pressure.
  - ESCAPE breaks lock through line of sight to buy room (never healing, never an ambush).
  - On defence: DEFENSIVE absorbs lights, EVASIVE punishes heavies, AGGRESSIVE meets force, and ESCAPE leaves.
- **R3. Every cell gets a second outcome, decided by a state the player can see** rather than by a hidden roll where possible:
  - *DEFENSIVE against a heavy:* at 50 ki or more, the defender BRACES. The guard holds, it costs 30 ki, and there is no launch. Below 50 ki, GUARD BREAK.
  - *DEFENSIVE against a signature:* the defender DEFLECTS the beam upward when it has 40 ki or more and its tier is at least the attacker's. That costs 30 ki and deals no damage, and the beam carves nothing further. Otherwise it is GUARD. Protector fighters also get INTERPOSE (`economy.md`, section 4.3).
  - *CHARGING, light or heavy:* INTERRUPT if the charge has run under 1.0 s. After that, BURST: the aura throws both fighters apart, with no damage to the charger.
  - *CHARGING against a signature:* an OVERCHARGE CLASH after 1.0 s of charge with 40 ki or more, otherwise HIT.
  - *AGGRESSIVE against a light:* the feed names the winner.
- **R4. The counter against a light is earned by patience** (questionnaire 4: no timing presses). PRESSURE's counter is decided by state: **50%** if the defender has held DEFENSIVE for 2 s or more before the attack and has more than 25 ki, **20%** otherwise. Holding a guard is the read; the director times the counter.
- **R5. The parry is a director outcome, resolved by state** (questionnaire 4). There is no parry button.
  - *Base chance,* in the four parryable templates: DEFENSIVE **25%**, AGGRESSIVE **15%**, EVASIVE and ESCAPE 0% (they dodge or leave instead).
  - *Modifiers:*
    - the attack is a heavy: +10, because a heavy wind-up is easier to read;
    - the defender's head is battered: −10;
    - ±5 per tier of difference;
    - the defender has 50 ki or more: +5;
    - the attacker is Boiling on the heat track: +5, because a reckless attacker is easier to catch.
  - *The drama stays.* The parry ring still shows as a tell, and the parry is still a visible counter beat.
  - The Controls anti-mash lockout (the previous amendment) is **moot** and withdrawn.
  - QA band unchanged: 5 to 15 parries per 100 melee exchanges.
- **R6. Chains follow the exchange's result.** No chain window opens after a parry (CC-001) or after GUARD HOLDS (CC-002).
- **R7. A tier advantage always helps its owner.** Every roll moves in the direction of whoever is ahead on tier (fixes GD-B01).
- **R8. Switching stance stays free and instant.** The template is fixed when the attack starts (`L410-421`), so a defender must predict, not react. Revisit if P2 playtests find stance-flicking tells.
  - *Stance snapshot* (co-signed with Controls and Combat): both fighters' stance multipliers are frozen when the attack starts (at `requestAttack`), and `hit()` reads the snapshot for the whole exchange. A late switch to DEFENSIVE mid-exchange no longer gives ×0.38. Under R1 the attacker's snapshot is ×1.0.

These rules are starting values. QA re-tests them in the probe below before they are locked.

## 6. How we test the matrix (P2 acceptance)

1. **Coverage.**
   - Every cell of attacker stance × defender state × attack kind has at least two outcomes that are reachable in normal play, using Combat's counting rule (§3.1).
   - Each outcome has its own feed tag.
   - QA's §7 table shows every outcome.
2. **Fixed-stance probe.** Requested from QA.
   - *Setup:* two identical, role-neutral fighters. One fighter's stance is forced. It attacks at a uniform cadence (the AGGRESSIVE interval in every stance, and attacks are allowed from ESCAPE). Its opponent plays the standard AI.
   - *Arms:* each stance is run once in each slot, 1,000 matches per slot.
   - *Pass:* no forced stance wins more than 55%. Each stance loses at below 45% to at least one other forced stance in the round robin. Bands are in `balance-targets.md`.
3. **The escape gamble.** Pursuit slip rate and beam escape rate stay inside the bands in `balance-targets.md`.
4. **Comprehension.** After two matches, a new player can say what each stance is for (charter).
5. **Multi-fighter.** In 2v2 and free-for-all, a third fighter attacking someone who is already in an exchange produces an authored CUT-IN, never a silent overlap (`modes.md`, `team-2v2`).
