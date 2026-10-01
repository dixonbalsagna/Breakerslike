# Control-scheme data plan (Encounter's step 2)

Owner: Combat and Choreography. Date: 2026-09-30. Status: plan; the data lands when the EP opens the window with Encounter's step 2 (`docs/director/control-scheme-plan.md`), in one commit with the parked Q4 batch (`pending/`) and Tools' schema changes.

**Rulings this follows:**
- ADR 0008;
- Game Design's `docs/design/stance-matrix.md` section 7 and `docs/design/control-rules.md` sections 1, 2 and 8 to 10;
- Combat's `moveset-system.md` section 9.

**What stays untouched:** the `parity` profile and its frozen copy. Every edit below is in the `dynamic` profile or in new templates.

---

## 1. One thing to settle first: plan-time or mid-exchange

Today every branch is chosen when the exchange is planned. Under ADR 0008 three decisions arrive **after** planning, inside the exchange:

| Decision | Arrives | So in data it is |
| :--- | :--- | :--- |
| A **perfect block** (`defPerfect`) | during the opener's wind-up | an **interrupt** on the branch, not a selector outcome |
| A **reversal** | after a normal block | an interrupt |
| An **answering beam** | during the attacker's beam tell | the beam's outcome moves from plan time to the **fire beat** |
| A dodge-cancel or a burst | in the gaps, or under pressure | interrupts (Encounter's step 4) |

So each branch gains an `interrupts` block naming what happens when one arrives. Encounter drops the branch's pending beats and schedules the interrupt's beats from that tick, as the finisher takeover does today. Plan-time selectors keep only what is known at the request: `defQueued`, `defMode`, the held state and the entries.

## 2. Defender states and the Neutral column

`trigger.defender` gains **NEUTRAL** (nothing held). The mapping is Game Design's: Press is AGGRESSIVE, Guard is DEFENSIVE, Dodge is EVASIVE, sprinting away is ESCAPE, Power held alone is CHARGING. The AGGRESSIVE column applies only when `defQueued` is set; otherwise the defender is NEUTRAL.

| New template | Trigger | Branches | Selector | Beats |
| :--- | :--- | :--- | :--- | :--- |
| `clean_hit` | light vs NEUTRAL | **CLEAN HIT:** the opener and every queued link land at ×1.0. **CLIPPED:** the opener lands, the string ends, no launch | condition on `defClipped` (the defender flying at more than half speed across or away); no draw | the approach, the opener with its wind-up, then the chain links from the queue, then the ender |
| `clean_hit_heavy` | heavy vs NEUTRAL | **CLEAN HIT:** the heavy lands and launches. **CLIPPED:** it lands with a short knockback, no launch | as above | the approach (20 ticks or more), the heavy, the launch or the knockback |
| (signature vs NEUTRAL) | sig vs NEUTRAL | HIT | none | the beam, section 5 |

**No wind beat's parry roll, no counter, no trade.** The defender's outs are inputs:
- a Guard press in the tell is the perfect-block interrupt, or a normal block that moves the cell to the Guard column's first outcome (GUARD HOLDS, or GUARD BREAK against a heavy);
- a dodge-cancel in a gap, or a burst.

Encounter re-plans the remainder in those cases.

## 3. Selector edits on today's templates

| Template | Today | Step 2 (`dynamic`) |
| :--- | :--- | :--- |
| `trade_blows`, `heavy_clash` | fire for any AGGRESSIVE defender | fire only for Press (`defQueued`); otherwise the NEUTRAL templates. The **retreat entry** adds a term to the defender's side: about +15 points on the trade (a +0.24 score term) and +10 against a heavy rush (−0.10 on the attacker's `p`) |
| `dodge` | read, or counter | three branches. The read roll is unchanged. If not read: **counter** when `defQueued` is set, else a new **clean** branch (the dodge succeeds, nobody is hit, the attacker recovers) |
| `pressure` | a gated 40% roll for the counter | **no roll.** The branch is GUARD HOLDS. Its interrupts are the perfect block and the reversal (section 4). This replaces parked edit 3 |
| `guard_break` | one outcome | GUARD BREAK, or **BRACE** by state (guard held with the ki to spare, R3). The interrupt is the perfect block |
| `pursuit`, `charge_interrupt` | unchanged | unchanged. A tackle against a sprinter uses the pursuit's gamble with +0.10 (section 6) |

## 4. Strike classes, windows and the interrupt branches

**Strike classes** replace `noParry` in the `dynamic` profile (`moveset-system.md` section 9.7). Each strike carries `class` and, where it has one, its window in ticks relative to contact.

| Class | Wind-up | Perfect-block window | Strikes |
| :--- | ---: | :--- | :--- |
| `opener` | 15 light, 20 heavy | the last 10 ticks | the first attacker strike of TRADE BLOWS, PRESSURE, GUARD BREAK, the NEUTRAL templates, a DODGE read, a caught pursuit, a thrown prop |
| `heavy` | 20 | the last 10 | HEAVY CLASH's deciding blow, GUARD BREAK's breaking strike, heavy counters |
| `ender` | 18 | the last 10 | TRADE BLOWS' deciding blow, the chain ender |
| `blast` | 15, or 20 charged | the last 10 (a perfect block deflects it) | ordinary energy blasts |
| `mid` | 6 | none (a held guard blocks normally) | PRESSURE's second and third strikes, TRADE BLOWS' exchanged blows, chain links |
| `none` | as its weight | none | CHARGE INTERRUPT, strikes on a launched or downed body, grabs |

**Timing edits these force in `dynamic`:**
- heavy exchanges approach in at least 20 ticks (15 today);
- TRADE BLOWS' deciding blow gets a 15-tick wind-up after the circle;
- the chain ender's wind-up goes from 12 to 18 ticks.

**The interrupt branches,** shared by every template that has a window:

| Interrupt | When | Beats (from the interrupt's tick) | Then |
| :--- | :--- | :--- | :--- |
| `perfect_block` | a Guard press in an opener's, heavy's or ender's window | cue `perfect_block`; the attacker's string ends and it staggers 24 ticks; the defender keeps its momentum | the defender's press within 30 ticks starts the **`riposte`** template |
| `reversal` | the context button after a normal block, close | an 8-tick turn and counter-strike; the attacker's string ends | the defender's own exchange starts with a throw or a sweep |
| `dodge_cancel`, `burst` | Encounter's step 4 | Combat supplies the beats then | |

**New template `riposte`:** the defender's attack after a perfect block. It can't be blocked or dodged; it launches when the blocked strike was a heavy or an ender. One branch, no draw.

**Retired:** the clean parry. Game Design withdrew it, so the `parry.cleanTicks` and `parry.cleanReward` fields leave the profile.

## 5. The answered-beam rule

`beam.outcome` in `dynamic` is decided at the **fire beat**, from what the defender did during the tell:

| The defender, during the tell | Outcome |
| :--- | :--- |
| fires its own signature (45 ki, off cooldown) | **CLASH:** a full struggle, with the six shapes |
| requests a heavy energy attack with 40 ki or more | **CLASH**, with −10 on the defender's clash score |
| a Guard press in the perfect window | **DEFLECT** |
| holds Guard | GUARD |
| Dodge | DODGE or HIT, by today's roll |
| sprinting away | the ESCAPE gamble, as today |
| Press with a light blast or a physical attack, or NEUTRAL | HIT (the beam goes through) |

The automatic rule (AGGRESSIVE with 40 ki or more) leaves the `dynamic` profile. The AI answers by Game Design's difficulty numbers, which are Encounter's to apply.

## 6. Context templates

A new family with `trigger.kind` of `grab`, `tackle`, `dive_grab`, `throw_object` or `shove`. Each has one fixed outcome per held state (Game Design's table, `control-rules.md` section 9). There are no draws, except the tackle's chase. The beats are in `moveset-system.md` section 9.9.

| Action | Neutral | Press | Guard | Dodge | Sprint | Power |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| `grab` | thrown (a launch at ×0.8 of a heavy) | stuffed | thrown | whiff (20 ticks open) | whiff | thrown, charge interrupted |
| `tackle` | carried (long haul) | stuffed; the tackler takes the opener at ×1.2 | carried | whiff (30 ticks) | the pursuit gamble, +0.10 for the tackler | carried, charge interrupted |
| `dive_grab` | slammed | stuffed | slammed | whiff (30 ticks) | whiff | slammed, charge interrupted |
| `throw_object` | hit | a trade: the object hits and the rival's attack continues | blocked at the guard's rate; tier 3 or above also staggers | dodged | misses beyond 4 bh | hit, charge interrupted |
| `shove` | pushed about 6 bh | pushed if the tell hasn't started; otherwise the attack lands | stopped | avoided | no effect | pushed, charge interrupted |

**The guard actions** read the attacker, not a held state:
- `reversal` lands on an attacker with links still queued. It whiffs against a dodge-cancel. A bait (an attacker who stopped and guards) blocks it, leaving the reverser 12 ticks behind.
- `deflect` turns a light blast or volley aside. Against a heavy charged shot it turns it aside and the defender is pushed back. It has no effect on a signature.

**Staging.** `grab`, `shove`, `reversal` and `deflect` need no World work and can land with step 2 or 4. `tackle` and `dive_grab` reuse the launch planner. `throw_object` waits for World's V1 props.

## 7. Chains
Queued presses become the links, and an empty queue plays the ender (Encounter's step 3). The link and ender beats come from `styles.json` `chains`. `chainP` remains only as the AI's and the Simple layout's policy.

## 8. What Encounter supplies, and what Tools changes

**Plan-context flags and requests (Encounter):**
- `defQueued`, `defMode`, `defPerfect` (already planned);
- `defClipped`: the defender moving at more than half speed across or away;
- the entries of both fighters (rush, stand, retreat);
- the queue length at plan time (for CLEAN HIT's string);
- the reversal request;
- the defender's answer at the fire beat (none, signature, or heavy blast).

**Schema changes (Tools), in the same commit:**
1. `trigger.defender` gains `NEUTRAL`; `trigger.kinds` gains the context kinds.
2. A strike's `class` and `window`, in non-parity profiles.
3. A branch's `interrupts` block.
4. A selector of kind `condition` (no draw); the beam outcome's `decideAt` and answer rules.
5. The `riposte` and context templates.
6. The `parry` block loses its clean-parry fields.
7. The parked batch: the finisher `kind`, and `contest.struggle.byState`.

**Checks:**
- the loader regression still passes on the untouched parity copy;
- `node tools/validate.js`: 0 errors;
- QA's feel probe after the timing edits: the wind-ups add about 0.1 to 0.2 s to heavy exchanges and chains.
