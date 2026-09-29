# Exchange templates

Owner: Combat and Choreography. Status: P0 wave 1. This is the catalogue of every exchange the prototype's director can compose: trigger, beats, outcomes and windows. It also covers which matchups fall short of the P2 exit criterion "every stance pairing has at least two authored outcomes", with proposals for the missing ones. Atoms are defined in `move-grammar.md`; the signature's variants are in `signature-variants.md`.

**Source.** `index.html:NNN` is a line of `prototype/index.html` at commit `7233c96`. Observed frequencies come from QA's baseline (`qa/baseline-p0.md`, section 7, default arm, 1,000 seeded matches) unless marked otherwise. Nothing here changes the prototype.

**Notation.** A attacker, D defender. `rt = clamp(dist/2600, 0.18, 0.65)` s is the rush time (`index.html:420`). Beat times are on the exchange clock, measured from the request. `base` is 26 for a light and 66 for a heavy (`index.html:432`). Damage figures are before the damage model's multipliers (`move-grammar.md`, `strike`). "Stance applies" means the struck fighter's stance multiplier is used: AGGRESSIVE 1.12, DEFENSIVE 0.38, EVASIVE 1.0, ESCAPE 1.25.

---

## 1. How a template is chosen

The director picks a template from two inputs only, the defender's state and the attack kind (`index.html:421, 435-507, 582-590`):

| Defender state | Light | Heavy | Signature |
| :--- | :--- | :--- | :--- |
| AGGRESSIVE | TRADE BLOWS | HEAVY CLASH | beam CLASH, or HIT |
| DEFENSIVE | PRESSURE | GUARD BREAK | GUARD |
| EVASIVE | DODGE (read or counter) | DODGE (read or counter) | DODGE, or HIT |
| ESCAPE | PURSUIT (slips away or caught) | PURSUIT (slips away or caught) | HIT, or ESCAPE |
| CHARGING (holding charge when attacked) | CHARGE INTERRUPT | CHARGE INTERRUPT | HIT |

The attacker's stance is not an input. It reaches an exchange in only two ways:
1. An AGGRESSIVE attacker gets +0.08 on the DODGE & READ chance (`index.html:458`).
2. When the defender strikes back without ignoring stance, the attacker's own stance sets the damage the attacker takes. That happens in TRADE BLOWS' two exchanged blows and the defender's winning blow (`index.html:498, 500`), and in DODGE & COUNTER (`index.html:468`).

A DEFENSIVE attacker therefore takes 0.38× from those counters. Everything else in an exchange is the same whichever stance the attacker chose.

Every branch is rolled once, when the exchange is planned, before any beat plays (`index.html:413`). Nothing either player does during the exchange changes the branch, except the defender's parry (four templates) and the attacker's chain.

---

## 2. Template catalogue

Each template lists its trigger, the rule that picks its branch, its beats, its outcomes, its windows, and when it ends. "Ends" is the exchange clock at which both fighters are released if the attacker does not chain; hitstop comes on top in real time.

### 2.1 TRADE BLOWS
- **Trigger.** Light against an AGGRESSIVE defender (`index.html:493-500`).
- **Branch rule.** Each side scores `tier + ki/70 + R(0, 1.6) + 0.3·[its hp is higher]`; the attacker wins if its score is higher (`index.html:495-496`). Two RNG draws, the attacker's first. Both feed lines read TRADE BLOWS: the winner is not shown (QA-004).

| Time | Atom | Who | Values |
| :--- | :--- | :--- | :--- |
| 0 | `rush` | A to D | 58 u, rt |
| rt − 0.1 | `windup` | | parry window opens |
| rt | `strike` | A on D | 24, parryable, stance applies (1.12) |
| rt + 0.17 | `counter` | D on A | 20, A's stance applies |
| rt + 0.34 | `strike` | A on D | 24 |
| rt + 0.51 | `counter` | D on A | 20, A's stance applies |
| **Attacker wins** | | | |
| rt + 0.72 | `strike` | A on D | 34, hitstop 0.1 |
| rt + 0.76 | `launch` | A launches D | force 1,000 |
| rt + 0.98 | `chain-window` | A | 0.6 s; ends rt + 1.58 |
| **Defender wins** | | | |
| rt + 0.72 | `counter` | D on A | 32, A's stance applies, hitstop 0.1 |
| rt + 0.76 | `launch` | D launches A | force 1,000 |
| rt + 1.0 | `hold` | | ends rt + 1.0 |

- **Observed.** 25.9% of all melee exchanges (4,142 of 16,022), the most common template.
- **Note.** The four exchanged blows are identical in both branches, so the trade looks even until the last beat decides it. That is good staging. But the decision was made before the first blow, so no timing can win it.

### 2.2 HEAVY CLASH
- **Trigger.** Heavy against an AGGRESSIVE defender (`index.html:501-506`).
- **Branch rule.** `p = clamp(0.5 + 0.09·(A.tier − D.tier) + (A.ki > D.ki ? 0.05 : −0.05), 0.2, 0.8)`, then one draw r. WON when r < p − 0.12, COUNTERED when r > p + 0.12, SHOCKWAVE otherwise. So SHOCKWAVE is always 24%, WON is p − 0.12, and COUNTERED is 0.88 − p.

| Time | Atom | Who | Values |
| :--- | :--- | :--- | :--- |
| 0 | `rush` | A to D | 58 u, rt |
| rt − 0.05 | `windup` | | parry window opens |
| **HEAVY CLASH — WON** | | | |
| rt + 0.28 | `strike` | A on D | 74 (base + 8), stance ignored, **parryable**, hitstop 0.12 |
| rt + 0.32 | `launch` | A launches D | force 1,800 |
| rt + 0.58 | `chain-window` | A | 0.6 s; ends rt + 1.18 |
| **HEAVY CLASH — COUNTERED** | | | |
| rt + 0.28 | `counter` | D on A | 66, stance ignored, hitstop 0.12 |
| rt + 0.32 | `launch` | D launches A | force 1,600 |
| rt + 0.6 | `hold` | | ends rt + 0.6 |
| **CLASH SHOCKWAVE** | | | |
| rt + 0.28 | `clash.shockwave` | both | pushed apart at 900 u/s, 18 damage each, crater and area damage at the midpoint |
| rt + 0.7 | `hold` | | ends rt + 0.7 |

- **Observed.** COUNTERED 39%, WON 37%, SHOCKWAVE 24%, as the formula predicts when tiers are level.
- **Note.** WON has the widest parry window in the game, 0.33 s: an AGGRESSIVE defender who parries turns a lost clash into a stagger.

### 2.3 PRESSURE
- **Trigger.** Light against a DEFENSIVE defender (`index.html:475-480`).
- **Branch rule.** If the defender has more than 25 ki at plan time, a 40% roll adds a counter (`index.html:479`). The defender does nothing to earn it.

| Time | Atom | Who | Values |
| :--- | :--- | :--- | :--- |
| 0 | `rush` | A to D | 58 u, rt |
| rt − 0.1 | `windup` | | parry window opens |
| rt | `strike` | A on D | 26, knockback 120, parryable, stance applies (0.38), D loses ki |
| rt + 0.16 | `strike` | A on D | 26, knockback 120 |
| rt + 0.32 | `strike` | A on D | 26, knockback 120 |
| **PRESSURE — GUARD HOLDS** | | | |
| rt + 0.42 | `chain-window` | A | 0.6 s; ends rt + 1.02 |
| **PRESSURE — GUARD HOLDS → COUNTER** | | | |
| rt + 0.55 | `counter` | D on A | 24, stance ignored, no launch |
| rt + 0.8 | `hold` | | ends rt + 0.8 |

- **Observed.** 12.7% of melee exchanges (2,041). QA counts the counter under the base tag, so the split is in section 3.
- **Defect CC-002.** GUARD HOLDS hands the attacker a chain window, and the chain link ignores stance. The guard "holds" and is then bypassed by one more press.

### 2.4 GUARD BREAK
- **Trigger.** Heavy against a DEFENSIVE defender (`index.html:481-487`).
- **Branch rule.** None: one outcome.

| Time | Atom | Who | Values |
| :--- | :--- | :--- | :--- |
| 0 | `rush` | A to D | 58 u, rt |
| rt − 0.1 | `windup` | | parry window opens |
| rt | `strike` | A on D | 45, knockback 150, parryable, stance applies |
| rt + 0.2 | `strike` | A on D | 45, knockback 150 |
| rt + 0.4 | `guard.drain` | on D | −25 ki, GUARD BREAK banner |
| rt + 0.42 | `strike` | A on D | 75.9 (base × 1.15), stance ignored, hitstop 0.12 |
| rt + 0.46 | `launch` | A launches D | force 1,700 |
| rt + 0.72 | `chain-window` | A | 0.6 s; ends rt + 1.32 |

- **Observed.** 8.1% of melee exchanges (1,297). The only defence is the 0.10 s parry.

### 2.5 DODGE (read or counter)
- **Trigger.** Light or heavy against an EVASIVE defender (`index.html:456-471`).
- **Branch rule.** `pRead` is 1 under an ambush. Otherwise it is `clamp(0.42 + 0.08·(A.tier − D.tier) + 0.08·[A is AGGRESSIVE] − 0.12·[A.ki < 12] − 0.05·[heavy], 0.15, 0.8)`, using the attacker's ki after paying for a heavy (`index.html:458`). One draw (`index.html:459`), then one more for the dodge height.

| Time | Atom | Who | Values |
| :--- | :--- | :--- | :--- |
| 0 | `rush` | A to D | 58 u, rt |
| rt − 0.12 | `windup` | | a parry window that can never parry (CC-009) |
| rt | `dodge.warp` | D | teleports 74 u behind A |
| **DODGE & READ** | | | |
| rt + 0.22 | `strike` | A on D | base, not parryable, stance applies (1.0) |
| rt + 0.27 | `launch` | A launches D | heavy only, force 1,400 |
| rt + 0.5 | `chain-window` | A | 0.6 s; ends rt + 1.1 |
| **DODGE & COUNTER** | | | |
| rt + 0.24 | `counter` | D on A | base × 0.9, A's stance applies |
| rt + 0.3 | `launch` | D launches A | force 900 |
| rt + 0.6 | `hold` | | ends rt + 0.6 |

- **Observed.** Light: COUNTER 54%, READ 46%. Heavy: COUNTER 60%, READ 40%.
- **Note.** A light READ does not launch. Both fighters then stand locked side by side for 0.28 s before the window and up to 0.6 s during it (section 7).

### 2.6 PURSUIT (slips away or caught)
- **Trigger.** Light or heavy against an ESCAPE defender (`index.html:440-454`).
- **Branch rule.** `pEsc = clamp(0.5 + 0.07·(D.tier − A.tier) + 0.12·[dist > 800] − 1·[ambush], 0.05, 0.88)`, one draw (`index.html:441-442`). Light and heavy have the same escape chance; a heavy only hits harder when it catches.

| Time | Atom | Who | Values |
| :--- | :--- | :--- | :--- |
| **PURSUIT — TARGET SLIPS AWAY** | | | |
| 0 | `rush.far` | A after D | 260 u short, 0.8·rt, tracking the fleeing target |
| 0.55·rt | `slip` | D | freed, bursts away at 1,500 + 200·D.tier u/s; A loses 3 ki |
| rt + 0.5 | `hold` | | A stands locked from 0.8·rt; ends rt + 0.5 |
| **PURSUIT — CAUGHT** | | | |
| 0 | `rush` | A to D | 58 u, rt |
| rt | `strike` | A on D | base × 1.2, not parryable, stance applies (1.25) |
| rt + 0.05 | `launch` | A launches D | force 800 light, 1,500 heavy |
| rt + 0.3 | `chain-window` | A | 0.6 s; ends rt + 0.9 |

- **Observed.** About 50/50 for both kinds.
- **Note.** This is the one template where distance matters (+0.12 to escape beyond 800 u). That is a gamble with odds, which is what pillar 3 asks of the escape stance, not a range check.

### 2.7 CHARGE INTERRUPT
- **Trigger.** Light or heavy against a defender who was holding charge (`index.html:435-439`).
- **Branch rule.** None: one outcome.

| Time | Atom | Who | Values |
| :--- | :--- | :--- | :--- |
| 0 | `rush` | A to D | 58 u, rt |
| rt | `strike` | A on D | base × 1.4 (36.4 light, 92.4 heavy), stance ignored, not parryable |
| rt + 0.05 | `launch` | A launches D | force 900 light, 1,500 heavy |
| rt + 0.32 | `chain-window` | A | 0.6 s; ends rt + 0.92 |

- **Observed.** 0.4% of melee exchanges (62): the AI rarely charges within reach and is rarely attacked while charging.

### 2.8 Chain link (extension)
- **Trigger.** The attacker presses light or heavy during an open chain window, with fewer than 5 linked hits and at least 6 ki (`index.html:572-575`).
- **Beats.** From the press `tc`, with `combo` counting this link:

| Time | Atom | Who | Values |
| :--- | :--- | :--- | :--- |
| tc | `rush.chain` | A to D | 60 u short, 0.24 s, catches a body in flight |
| tc + 0.26 | `strike` | A on D | 52 + 7·combo, stance ignored, not parryable, hitstop 0.08 |
| tc + 0.3 | `launch` | A launches D | force 1,500 |
| tc + 0.55 | `chain-window` | A | 0.6 s |

- **Observed.** 24% of melee exchanges chain; mean length 2.4; 13 five-hit chains in 1,000 matches.
- **Note.** A chain link is identical whichever template it extends, whichever key was pressed and whatever the defender's stance. It is the same move up to four times, with no choice in it except whether to press.

### 2.9 Signature exchange
The outcome is picked by defender state when the signature is requested (`index.html:586-590`). The variant name comes from the biome under the defender and does not change the outcome (`signature-variants.md`).

| Defender state | Outcome rule | RNG at plan time |
| :--- | :--- | :--- |
| AGGRESSIVE | CLASH if D has 40 ki or more and A is not ambushing; otherwise HIT. The clash winner is decided later, at the struggle | none |
| DEFENSIVE | GUARD | none |
| EVASIVE | DODGE with probability `clamp(0.55 − 0.06·(A.tier − D.tier), 0.2, 0.8)`, never under an ambush; otherwise HIT | one draw, taken even under an ambush |
| ESCAPE | HIT with probability `clamp(0.5 − 0.05·(A.tier − D.tier) + 0.3·[dist < 500], 0.15, 0.9)`; otherwise ESCAPE. The tier term has the wrong sign (CC-004) | one draw |
| CHARGING | HIT | none |

| Time | Atom | What happens |
| :--- | :--- | :--- |
| 0 | `beam.charge` | A moves vertically to above D over 0.55 s, then holds, charging |
| 0.8 | `beam.fire` | the beam fires down at D; carving runs along its length over 0.22 s |
| 0.8 + reach (at most 0.2) | `beam.connect` | **HIT**: 230, stance ignored, explosion, launch at 2,600. **GUARD**: 200, stance applies (0.38), explosion, launch at 1,300 |
| 0.82 | `beam.dodge` | **DODGE**: D teleports 300 u up and hangs, locked (CC-005) |
| 0.82 | `beam.escape` | **ESCAPE**: D is freed and bursts away at 1,600 u/s |
| 1.7 | `hold` | end, for every outcome except CLASH |
| 0.8 to 2.4 | `clash.beam` | **CLASH**: D pays 40 ki; the struggle is drawn for 1.6 s. The winner scores higher on `10·tier + 0.35·ki + R(0, 16)` (+ `0.08·menace` for a villain) |
| 2.4 | clash resolution | the winner fires a full beam at the loser: 260, stance ignored, explosion, launch at 2,600 |
| 3.4 | `hold` | end of a CLASH |

- **Observed** (share of signatures by defender state):
  - AGGRESSIVE: CLASH 95%, HIT 5%.
  - DEFENSIVE: GUARD 100%.
  - EVASIVE: DODGE 54%, HIT 46%.
  - ESCAPE: HIT 72%, ESCAPE 28%.
  - CHARGING: HIT 100%.
  - Over all signatures: CLASH 40.4%, HIT 23.3%, GUARD 20.0%, DODGE 12.5%, ESCAPE 3.8%.
- **Windows.** None. A signature cannot be parried, has no chain window, and nothing either player does after the request changes its outcome.

---

## 3. Coverage against the P2 criterion

### 3.1 The counting rule this document uses
- **Unit.** A cell is attacker stance × defender state × attack kind: 4 × 5 × 3 = 60 cells. Counting per stance pairing with the attack kinds pooled hides the problem. A player who picks heavy against a DEFENSIVE defender always gets the same result, even though the pairing as a whole has several outcomes.
- **Distinct outcome.** Two outcomes are distinct when both of these hold:
  1. They end with a different fighter ahead: who was launched, who took the larger damage, who holds the initiative.
  2. A spectator can tell them apart from what they see or from the debug feed.
  Differences in damage alone do not count. The parry is a defender interrupt available in some templates, and it is counted separately rather than as an outcome of any cell.
- **Pass.** A cell passes with at least two distinct outcomes that are each reachable in normal play.

### 3.2 Defender state × attack kind (what the director actually selects on)

| Defender | Light | Heavy | Signature |
| :--- | :--- | :--- | :--- |
| AGGRESSIVE | 2, but **hidden**: TRADE BLOWS attacker wins, defender wins (one feed tag) | **3**: WON, COUNTERED, SHOCKWAVE | 3, **one hidden**: CLASH won, CLASH lost, HIT (HIT only when D is below 40 ki or A ambushes) |
| DEFENSIVE | 2, **weak**: GUARD HOLDS, → COUNTER (24 damage, no launch, a roll D does not earn) | **1: FAIL** (GUARD BREAK) | **1: FAIL** (GUARD) |
| EVASIVE | **2**: READ, COUNTER | **2**: READ, COUNTER | **2**: DODGE, HIT |
| ESCAPE | **2**: SLIPS AWAY, CAUGHT | **2**: SLIPS AWAY, CAUGHT | **2**: HIT, ESCAPE |
| CHARGING | **1: FAIL** (CHARGE INTERRUPT) | **1: FAIL** | **1: FAIL** (HIT) |

Five cells fail outright, one is weak, and two have a branch the feed never names.

### 3.3 Across the attacker's stance

The attacker's stance is not a selector, so every attacker row copies the table above:
- **20 of 60 cells have one outcome**: DEFENSIVE heavy, DEFENSIVE signature, CHARGING light, heavy and signature, each under all four attacker stances.
- **4 cells are weak**: DEFENSIVE light under each attacker stance.
- **8 cells hide a branch from the feed**: AGGRESSIVE light and AGGRESSIVE signature, under each attacker stance.
- **15 cells are never played by the AI**: every ESCAPE-attacker cell, because the AI never attacks from ESCAPE (`index.html:841`). A human can attack from ESCAPE and gets exactly the templates of any other stance.

Nothing about the attacker's stance creates a distinct outcome in any cell. The only differences are the +0.08 read chance and the damage the attacker takes from counters (section 1). By the reading in 3.1, the 16 stance pairings are really 4 defender columns played four times over.

## 4. Measured: the hidden branches and who ends ahead

**Method.** A headless census of 1,000 seeded AI-vs-AI matches (default arm, seeds 100001 to 101000), about 19,700 exchanges. It used a copy of the prototype instrumented with read-only hooks, proven identical to the pinned file: 0 differences in 4,052,564 steps and 44,249 feed lines. Its cell counts match QA's section 7 exactly. The scripts are not committed; they can be handed to QA.

| Finding | Measured |
| :--- | :--- |
| TRADE BLOWS winner (hidden from the feed) | attacker 50.2%, defender 49.8%. The fighter ahead on hp wins about 70% (the +0.3 hp term, `index.html:495`): trades work *against* comebacks |
| PRESSURE → COUNTER | 38.7% of PRESSURE exchanges |
| Beam CLASH winner (hidden from the feed) | attacker 47.7%, defender 52.3%. VORR wins 61.8% of all beam clashes, through the villain-only menace term (`index.html:625`) |
| Attacker stance | Changes no outcome except the AGGRESSIVE read bonus (+9.6 points). In a scenario that lets the AI attack from ESCAPE (300 matches), ESCAPE attackers get the same outcome split as DEFENSIVE and EVASIVE attackers |
| Damage taken when countered, by the attacker's own stance | light DODGE & COUNTER: 17.6 hp as DEFENSIVE against 36.2 as AGGRESSIVE. TRADE BLOWS lost: 39.9 against 95.5. This is the free protection Game Design's R1 removes |
| Parry | 35.9% of AI parry presses succeed: 41% in the 0.10 s windows, 100% in HEAVY CLASH — WON's 0.33 s window. 22% of presses fall in templates with nothing parryable |
| Phantom chains (CC-001) | 13.4% of chain links follow a parry and deal nothing; 13.1% of "CHAIN xN ended" feed lines come from parried exchanges |
| Chain windows | 59.3% close unused; each one is 0.6 s with both fighters held |
| Downed targets | 15.4% of exchanges target a defender who is down. They get their full stance options (CC-014) |
| Rush time | on its 0.18 s floor in 70.8% of exchanges: most fights happen within 468 u |

**Who ends ahead** (mean net hp swing per exchange, attacker minus defender):
- **Attacker-favoured:**
  - TRADE BLOWS attacker wins, +143
  - GUARD BREAK, +220
  - HEAVY CLASH — WON, +189
  - DODGE & READ, +101 light and +168 heavy
  - PURSUIT — CAUGHT and CHARGE INTERRUPT
  - beam HIT, +284
  - beam CLASH won by the attacker, +329
- **Defender-favoured:**
  - TRADE BLOWS defender wins, −30
  - DODGE & COUNTER, −39 light and −76 heavy
  - HEAVY CLASH — COUNTERED, −101
  - beam CLASH won by the defender, −304
  - any parried exchange, about −20
- **About even:** CLASH SHOCKWAVE, PRESSURE → COUNTER, and the slips, dodges and escapes.
- **By this measure, DEFENSIVE as a defender has no defender-favoured outcome at all:** the guard only reduces the attacker's gain. It is still the best stance to be in, because of the 0.38× multiplier.

---

## 5. How the gaps close

### 5.1 Outcomes and stance rules
Game Design's stance rules (`docs/design/stance-matrix.md`, section 5) are adopted as the target for P2. Combat authors the beats for them:
- **Second outcomes (R3).**
  - DEFENSIVE against a heavy: BRACE or GUARD BREAK, by ki.
  - DEFENSIVE against a signature: DEFLECT or GUARD.
  - CHARGING against a light or heavy: INTERRUPT, or BURST after 1.0 s of charge.
  - CHARGING against a signature: OVERCHARGE CLASH or HIT.
  - AGGRESSIVE against a light: the TRADE BLOWS winner named in the feed as TRADE BLOWS — WON or LOST.
  - Beam CLASH: the clash winner named the same way.
- **The earned counter (R4).** PRESSURE's counter comes from a defender press during the string, not a roll.
- **Attacking profiles (R1, R2).** Attacking drops your guard. Each attacking stance has its own damage and perk; the ESCAPE attack is hit and run.
- **Chain rules (R6).** No chain window after a parry (CC-001) or after GUARD HOLDS (CC-002).
- **The procedural move system gives every branch its look** (`procedural-moves.md`). The template fixes who wins and when contacts land; the composer picks the parts. So the same outcome never looks the same twice, and different outcomes stay distinct (test T1).

### 5.2 Which templates have windows (Combat's call)

| Template | Parry window | Chain window | Change from today |
| :--- | :--- | :--- | :--- |
| TRADE BLOWS, PRESSURE, GUARD BREAK | on the first attacker strike | after an attacker win only | PRESSURE: no chain after GUARD HOLDS (R6); a counter window for the defender instead (R4) |
| HEAVY CLASH — WON | on the deciding strike | yes | none |
| DODGE (both branches) | **none: remove the dead wind-up** (CC-009) after the port proves parity | after DODGE & READ | the attacker's read chance comes from stance (R2), not from a window |
| PURSUIT, CHARGE INTERRUPT, CLASH SHOCKWAVE, HEAVY CLASH — COUNTERED | none | CAUGHT and INTERRUPT only | CHARGING gains BURST (R3) |
| BRACE, DEFLECT, BURST (new) | none | none: the defender won | new |
| Signature | none | none | the defender's choice is DEFLECT by ki (R3) |
| Chain link | none | yes, with light (extend), heavy (cash out) and a direction (aim) (`procedural-moves.md` section 7) | a defender break-out window from link 3 |

**Surfacing** (the look is for UI/UX and VFX; the events are ours). Every window atom emits render-only cue events on open and close:
- **The parry window** gets a wind-up tell on the attacker: an anticipation pose plus a short flash and sound. It is visible for the whole window, so a new player can see it and an expert can read it.
- **The chain window** gets a follow-up prompt on the attacker: a pursuit pose with a pulse, shown for the window's length.
- **The feed** stops announcing the outcome at the moment of the request (`index.html:415`), so the exchange is not spoiled before it plays.

**Widths: proposals for Controls and Game Feel**, who decide them:
- light-strike parry windows from 0.10 s (6 ticks) to about 0.20 s (12 ticks), with Game Design's R5 whiff cost (5 ki, 0.5 s lockout) making it a read rather than a mash;
- the heavy clash window stays at about 0.33 s (20 ticks);
- the chain window stays at 0.6 s, with a 4-tick press buffer.

Accessibility derives its assists from Controls' final numbers.

### 5.3 Timing
Orb found the greybox too fast. Two held stretches in today's templates read as stalls:
- the chain window, which holds both fighters for up to 0.6 s even when unused, as 59% are;
- the beam-dodge hang (CC-005).

Phrases composed by `procedural-moves.md` fill the chain window with a follow-up pose and pursuit. Readability minimums (anticipation per weight class, at most three contacts between holds) are part of every phrase class. A global beat-spacing scale is an open question for Game Design with Controls and Game Feel.

---

## 6. Proposed names (pending Legal and Orb)
From Narrative's glossary (`docs/narrative/glossary.md`, sections 8 and 9). The current tags stay in the code and in these documents until Legal and Orb rule. Internal atom and template ids (`move-grammar.md`) do not change with display names.

| Current | Proposed display text |
| :--- | :--- |
| DODGE & READ | DODGE — SEEN THROUGH |
| DODGE & COUNTER | DODGE — COUNTER |
| PURSUIT — TARGET SLIPS AWAY | PURSUIT — SLIPPED AWAY |
| N HIT CHAIN (banner), N CHAIN (HUD) | CHAIN ×N, one label |
| SMASH ACROSS (launch) | HURL ACROSS |
| BUILDING SMASH (launch) | THROUGH THE WALL |
| MOUNTAINSIDE (launch) | INTO THE MOUNTAIN |
