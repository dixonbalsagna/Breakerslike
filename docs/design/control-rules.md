# Rules for the new control scheme (ADR 0008)

Owner: Game Design. Orb decided the scheme in `docs/decisions/0008-control-scheme.md` (questionnaire 8). This page sets the game rules it needs: windows, costs, cooldowns, priorities and automatic choices. Controls owns the bindings and layouts, and Encounter owns the director's use of them. Numbers are starting values in ticks (60 a second) and ki (cap 100), and QA tunes them.

**Build order** (Orb, questionnaire 10): the agency fixes first (counters on request, dodge-cancel, burst and the perfect block), then combat variety (blasts, teleports and beam struggles).

**What this replaces.** Stances are now held states, read at exchange start as before:

| Held state | Old stance |
| :--- | :--- |
| Press (attacking) | AGGRESSIVE |
| Guard held | DEFENSIVE |
| Dodge tapped | EVASIVE |
| Sprint away | ESCAPE |

`stance-matrix.md` R5 (the parry by state) and R9 (the weight latch and the signature queue) are superseded for human players. The R5 numbers stay as the AI's skill model.

## 1. The perfect block

- **The window is Controls'** (`docs/controls/input-scheme.md` §4.1). A fresh Guard press is a perfect block in the **last 8 ticks of a light wind-up, or the last 10 of a heavy one**. A press up to 4 ticks before the window opens also counts, and touch gets 2 more. The assist setting doubles the window and turns the lockout off.
- **A mistimed tap still blocks.** A press earlier in the wind-up, or a guard already held, is a normal block. Only a press after the strike lands is a hit.
- **Which strikes have a window.** Every strike with Combat's visible tell (15 ticks for a light, 20 for a heavy): an exchange's opening strike, every heavy, every ender, and ordinary energy blasts (a perfect block deflects them). Mid-string follow-ups have no fresh tell and no window. A perfect block against a signature beam is a **DEFLECT**: no damage and +8 ki, but no stagger and no riposte.
- **The reward:**
  - no damage, no guard wear and no ki loss;
  - +8 ki;
  - the attacker's string ends and they stagger for 24 ticks (0.4 s);
  - the defender keeps their momentum: an attack pressed within 30 ticks is a **riposte** that can't be blocked or dodged. Against a heavy or an ender, the riposte launches;
  - it counts as a parry for mood (+4) and as a humbling for Pride.
- **The risk.** Tapping without holding guard is the "moving parry": it works the same, but a late tap takes the full hit with no guard up.
- **Mashing Guard gives normal blocks only.** A Guard press outside a window locks the perfect block out for **20 ticks**, and each further press restarts the lockout. The guard itself still works. This value replaces the 18 ticks in Controls' spec.
- **Beam clash.** The director never fires a beam on its own, so the old "AGGRESSIVE with 40 ki meets the beam" rule goes. A clash now happens only when the defender answers during the incoming beam's tell, with their own signature (45 ki) or a heavy energy attack (40 ki). The selector conditions are in `stance-matrix.md` §7.2.
- **QA bands:** perfect blocks are 5 to 15 per 100 melee exchanges at mid skill, and at most 2 per 100 for a scripted Guard masher.

## 2. Dodge-cancel, burst and reversal

| Action | Cost | Cooldown | When it works | What it does |
| :--- | ---: | ---: | :--- | :--- |
| **Dodge-cancel** (Dodge tap mid-exchange) | 15 ki | 3 s | As the attacker: at any time, cancelling your own strike or recovery. As the defender: only in the gaps between strikes, never during hit-stun or a launch. This narrows the "any time, for either fighter" window in Encounter's plan: the burst is the tool for a fighter who is being hit | 12 ticks of invulnerability and a dash in the held direction. The exchange ends with no winner |
| **Burst** (Power tap) | 30 ki | 8 s | Also while being hit, including between the bounces of a ping-pong blitz (§11). Not during a launch, a cinematic or a finisher | A 360-degree shove that pushes the rival back about 8 bh and ends the exchange. No damage, and no winner |
| **Reversal** (context button in guard, close up) | 20 ki, or 10 ki after 2 s of continuous guard | 6 s | Only just after a normal block | A guard-cancel counter-strike that starts the defender's own exchange |

- **Burst bait.** If the rival is holding Guard when the burst fires, they absorb it and the burster staggers for 30 ticks. An expert pauses a string and guards to draw the burst out.
- **No fallback.** Without the ki, or on cooldown, the press does nothing except its acknowledgement. Two small pips by the ki bar show the dodge-cancel and burst cooldowns.
- **Dodges that cost nothing** (Controls' open point). The 15 ki is paid only for a dodge inside an exchange. These are free, with a 0.5 s cooldown between dodges:
  - a dash or a **lunge** outside an exchange, in any direction, including toward the rival. A lunge is only movement: it doesn't start an exchange until an attack is pressed;
  - a lunge that runs on into a sprint;
  - the Dodge state read at exchange start. It is the old EVASIVE stance, and the director resolves it with the dodge templates as before.
- **Two interrupts on the same tick** (Encounter's proposal, ruled by the EP). The order is perfect block, then reversal, then dodge-cancel, then burst, and the defender's interrupt goes before the attacker's. An interrupt that loses this way isn't charged: it costs no ki and starts no cooldown.
- **For scale:** a signature costs 45 ki, a clash 40 and a chain link 6. A burst therefore delays a signature, which is the trade.

## 3. The power layer and the transform hold

- **Power tap** (released within 12 ticks with no face button): a burst.
- **Power held** (12 ticks or more with no face button): the channel. It charges at +30 ki a second, and runs the fighter's own channel where they have one (the Protagonist's stoke). Guard is down while channelling, and CHARGE INTERRUPT applies as now.
- **Power plus a face button:** one of the three loadout specials, or the signature. Costs and cooldowns are unchanged: specials cost 15 to 30 ki with a 25 s cooldown, and the signature costs 45 ki with a 120 s cooldown per fighter. A special or signature fired this way never also bursts or charges.
- **Requests, not queues.** A funded press fires at the next exchange boundary. An unfunded press is refused with the "need ki" cue and doesn't wait: the same trigger, held, is how the player charges. This replaces the 180-tick and 600-tick queue rules, including the 600-tick wait that Controls' spec still keeps for an unfunded signature (§4 there). A beam that fires up to 10 s after the press would feel like the automatic beams Orb's friends objected to.
- **Transform: hold both triggers for 30 ticks (0.5 s).** This replaces the single Transform button in `moveset-rules.md` §10.1; the ready cues there are unchanged.
  - *The chord.* When the second trigger goes down within 6 ticks of the first, the two are read as the chord: no dodge, sprint, burst or charge fires, and releasing a chord never fires a tap.
  - *The fill.* A ring fills around the fighter over the 30 ticks. The fighter can move but can't attack. Taking a hit cancels the hold, and releasing early costs nothing.
  - *Not ready.* If no form is ready, the chord does nothing except a short "not ready" cue.
  - *Timing.* Mid-exchange, the transformation starts at the next exchange boundary.
  - *On touch,* the "ready" icon by the portrait is the button: hold it for 0.5 s.

## 4. The context button

**One rule:** the on-screen icon always shows what the press will do. The press does exactly that, or whiffs if the target has gone. There is no silent swap. The icon changes only after a new context has held for 10 ticks, so it doesn't flicker. Extra presses during recovery are ignored.

**Priority**, first match wins:

| # | Context | Action | Rule |
| ---: | :--- | :--- | :--- |
| 1 | Guard held | **Reversal** close up (§2), or a **deflect** beyond 1.5 bh | The deflect turns one ordinary blast aside for 10 ki |
| 2 | Sprinting | **Tackle** | A grab at speed: it carries the rival along the ground |
| 3 | Airborne, with the rival below and within 3 bh | **Dive grab** | A grab that ends in a slam |
| 4 | The rival within 1.5 bh | **Grab and throw** | A grab beats Guard, loses to an attack, and whiffs against a dodge. A whiff has a 1.5 s cooldown. No ki cost |
| 5 | A liftable object within 2 bh | **Pick it up** | The next attack press throws it (a heavy press slams it down). The power tier caps the object's size |
| 6 | Civilians within 3 bh | **The fighter's own action** | Set in fighter data, with a 10 s cooldown. None of them causes casualties (below) |
| 7 | Nothing else | **The fallback by mode** | Physical: a provoke (mood +3, and +5 to the fighter's ego meter if it finishes), or a feint when the rival is guarding in rush range. Energy: a short frontal shove for 5 ki, which a guard stops |

**Civilian actions** (working labels; Narrative names them):
- *Protagonist:* shelter. The group evacuates at once, and his anguish drops by 5.
- *Anti-hero:* witness. The crowd is made to watch, giving Pride +5 and mood +3.
- *Empress:* decree. The group relocates under guard, giving Wrath +5.
- *Cyborg:* take orders. A sandwich pickup spawns, giving Hunger +5.
- *The placeholders:* KAI shelters; VORR scatters the crowd for menace +2.

The grab completes the triangle the new scheme needs: **attack beats grab, grab beats guard, and guard (or a dodge) beats attack.**

## 5. The Simple layout's automatic choices

Simple produces the same actions as every layout, at the same costs and windows. The director chooses only what Simple has no button for.

| Choice | The rule |
| :--- | :--- |
| **Mode** (physical or energy) | Energy when the rival is beyond rush range or the player holds away; physical when close or holding toward. It switches only between exchanges, and holds for at least 1 s |
| **Burst** | A Guard or Dodge press during hit-stun counts as a burst request. If the player presses nothing, the director bursts for them at the fourth link of a chain. Both need the 30 ki and the cooldown |
| **Which special** (`special_auto`) | Power plus Attack fires one of the three loadout specials. Only specials that are funded and off cooldown are eligible. The director scores them by range fit, then by the rival's state (the guard-breaker against a guard, the anti-air against an airborne rival), minus a variety penalty for the last one used. Ties go to loadout slot order, so the pick is deterministic. If none is eligible, the press is refused with the "need ki" cue |
| **Signature** | Never automatic. Power plus Heavy on a controller, or a swipe up on Attack on touch |
| **Weight** | On touch, a tap is a light and a hold is a heavy |

- The automatic picks are sound but plain: mode follows range alone, and specials follow the obvious context. The full layouts add choice, such as picking the exact special, mixing modes at will, and timing or baiting a burst.
- The perfect-block window is the same on every layout (§1). Touch gets Controls' 2 extra ticks of early tolerance for screen latency.
- On touch, a Power tap does nothing, and the burst comes from the two rules above (Controls' `autoBurst` flag).

## 6. Mashing: fine for beginners, beatable by experts

**Why mashing works.**
- Every attack press is one exchange request, and extra presses queue a short combo up to **3 deep**. Presses beyond that are ignored, never punished.
- The director composes real strings from those presses, so a masher sees good-looking combat and beats the easy AI.

**Why an expert beats it.**
1. **A queue is a commitment.** Three queued presses commit about 1.5 to 2 s, and the string's ender has the 20-tick heavy tell with a perfect-block window. A perfect block gives the riposte.
2. **Repeats go stale.** The same weight in three exchanges running adds 2 ticks to its wind-ups for each further repeat (at most +6) and widens the rival's perfect-block window by 2 ticks (at most +4). Changing weight, mode or direction clears it.
3. **A blocked string is punishable.** A fully blocked string leaves the attacker 12 ticks behind, which is the guard's punish window.
4. **The triangle.** Attacks lose to guard and dodge, and a masher never grabs, so guarding a masher is safe.
5. **Defensive mashing fails too.** Mashed Guard gives normal blocks only (§1), and dodge-cancel and burst have cooldowns and can be baited (§2).

**QA bands** (a scripted masher pressing light every 8 ticks):
- against the easy AI it wins at least 60%;
- against the medium AI it wins 35 to 50%;
- against a script that perfect-blocks enders and ripostes it wins at most 15%.

## 7. The placeholder transform

**The next build: Encounter's smaller version** (the EP's pick; `docs/director/control-scheme-plan.md`). It is a manual tier-up with a short set piece.
- The automatic tier-up waits at its threshold, and the fighter shows "ready".
- The transform input takes it, between exchanges only: both triggers for 0.5 s, or on the Simple layout Power held alone for 0.5 s.
- A 0.8 s hold plays on the existing power-up burst (the aura, the ground crater and the banner), and the rival is pushed back. No exchange can start during it.
- The tier's existing bonuses then apply. It works at every tier-up, with no surge, no new art and no per-fighter rules.
- The AI takes it at once.

**The follow-up: one form with a surge** (Game Design's version, after the next build).

*Updated by questionnaire 10.* The placeholder keeps all three ladder steps, not one form. Their pace, the retuned ladder data and the full, short and live versions of the set piece are in `spec-wounds.md` §8b. The table below still gives the cues, the input and the surge; its "once per match" and "2 s" rows are replaced by §8b.

| Part | The rule |
| :--- | :--- |
| **Fill** | Reaching power tier 3. The rival slows it as now, with CHARGE INTERRUPT |
| **Ready cues** | The aura pulses, a "ready" icon appears by the portrait, and a sting plays (`moveset-rules.md` §10.1) |
| **Input** | Hold both triggers for 0.5 s (§3). On touch, hold the ready icon |
| **Cinematic** | 2 s, respected: a camera push, an aura flare and the existing power-up crater at ground level |
| **The change** | For the rest of the match: +10% damage and +10% speed, the fighter drawn 10% larger, and the aura changes shape and colour mass |
| **Surge** | The standing 15 s surge applies (+20% damage, +10 mood), so the timing of the hold matters |
| **Limits** | Once per match per fighter, with no drain and no way back. It counts as an act beat |
| **AI** | Takes it 5 to 10 s after it becomes ready |

It needs one data flag per fighter and no new art. The real forms replace it fighter by fighter.

## 8. Entries out of reach: physical stand and retreat

Combat's recommendation is confirmed (`docs/combat/moveset-system.md` §9.2). A physical press never whiffs for range, which keeps pillar 3.

| Entry | In reach | Out of reach |
| :--- | :--- | :--- |
| **Rush** (toward) | Closes and strikes | The same: the fastest close |
| **Stand** (neutral) | Plants and strikes | **The minimum approach.** The fighter closes by plain flight, arrives about 12 ticks later than a rush, plants and strikes. It gets no rush momentum, and a backstep counter doesn't trigger against it. Beyond 2,500 units it is the pursuit flight (`balance-targets.md` §10) |
| **Retreat** (away) | A backstep strike | **A counter stance that needs no reach.** The fighter gives ground and holds the backstep for 45 ticks. If the rival's rush arrives in that time, the backstep strike meets it with the trade bonus in `stance-matrix.md` §7.2. If nobody comes, it ends as a plain backstep with a 10-tick recovery |

In energy mode all three entries reach at any range, as Combat has them.

## 9. Context actions against each held state

**The grab rule covers three actions.** Grab, tackle and dive grab all beat Guard, Neutral and Power, lose to an attack in progress, and whiff against a dodge. A throw is a launch, so it counts as a decisive exchange.

| Action | Neutral | Press (attacking) | Guard | Dodge | Sprint | Power (channelling) |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Grab and throw** | Thrown: a launch at ×0.8 of a heavy | **Stuffed:** the rival's strike lands first | **Thrown:** the grab beats the guard | **Whiff:** 20 ticks open, and the 1.5 s cooldown | Whiff: the rival has gone | Thrown, and the charge is interrupted |
| **Tackle** | Carried: a long-haul launch | Stuffed, and the tackler takes the opening strike at ×1.2 for running onto it | Carried | Whiff: the tackler overshoots, with 30 ticks of recovery | The chase: the ESCAPE gamble with +0.10 for the tackler | Carried, and the charge is interrupted |
| **Dive grab** | Slammed | Stuffed | Slammed | Whiff: lands with 30 ticks of recovery | Whiff | Slammed, and the charge is interrupted |
| **Thrown object** (after a pick-up) | Hit, with damage by the object's size | A trade: the object hits, and the rival's attack continues | Blocked at the guard's rate. An object of tier 3 or above also staggers | Dodged | Misses beyond 4 bh, otherwise hit | Hit, and the charge is interrupted |
| **Energy shove** | Pushed back about 6 bh, with no damage | Pushed if the rival's tell hasn't started; otherwise the attack lands | Stopped | Avoided | No effect: out of reach | Pushed, and the charge is interrupted |

**The two guard actions** are used by the defender, so they read the attacker's situation, not a held state.

| Action | Against | Outcome |
| :--- | :--- | :--- |
| **Reversal** (after a normal block, close) | An attacker with links still queued | It lands. The string ends and the defender's own exchange starts with a throw or a sweep |
| | An attacker who dodge-cancels | Whiff, and the ki is spent |
| | An attacker who stopped and guards (a bait) | Blocked, and the reverser is 12 ticks behind |
| **Deflect** (guarding at range, 10 ki) | A light blast or a volley | Turned aside, with no damage |
| | A heavy charged shot | Turned aside, and the defender is pushed back |
| | A signature beam | No effect: the outcome is GUARD. Only a perfect block deflects a beam |

## 10. Answering a beam with a beam: the AI and the Simple layout

- **The AI: yes,** by the same rules as a player (`stance-matrix.md` §7.2). It needs the ki and a ready signature, or 40 ki for a heavy blast. How often it answers when it can is its difficulty: easy 15%, medium 35%, hard 60%.
- **The Simple layout: never automatically.** No layout fires a beam for a human. The Simple player answers with the same signature input (Power plus Heavy, or a swipe up on touch) during the tell, and an "answer" prompt shows when they have the ki.
- QA keeps the clash band at 30 to 60% of signatures fired (`balance-targets.md` §8) and reports human and AI answers separately.

## 11. Blitzes: the flurry and the ping-pong (Orb, questionnaire 10)

There are two kinds of blitz. The **flurry** is the fast chain in place. The **ping-pong** is Combat's new choreography (`docs/combat/blitz.md`): the attacker knocks the rival away, outruns them on a spiral flight or a blink, arrives ahead and knocks them back. Combat owns how it looks. These are the rules it asked for.

**When a ping-pong starts.**
- *The request:* an attack pressed while holding toward, during the flight of a launch the attacker just caused. It works in any mood and at any tier; those only set the length.
- *For the AI and the Simple layout* the director decides, with the standing blitz chance: 0.25 in Tense, 0.50 in Frenzied, +0.05 per act, capped at 0.60.
- *Conditions:* the rival is still in flight, the attacker has the ki for one bounce, and the attacker's blitz cooldown is over.
- A blitz never starts from another blitz's ender, so it can't loop.

**How long it runs.** A ping-pong is 2 to 5 return blows, and the last one is the ender. The cap comes from tier and mood:

| Mood | Tier 1 | Tier 2 | Tier 3 | Tier 4 |
| :--- | ---: | ---: | ---: | ---: |
| Calm | 2 | 2 | 2 | 2 |
| Tense | 2 | 3 | 3 | 4 |
| Frenzied | 3 | 4 | 5 | 5 |

- The request gives the minimum: one bounce and the ender. Each further queued press adds a bounce before the ender, up to the cap. Presses made during the blitz count, so pressing in rhythm extends it.
- The AI and Simple continue each bounce with a chance of 0.7 in Tense and 0.85 in Frenzied.
- The intercept takes 30 ticks by flight (24 in Frenzied) and 16 by blink, as Combat proposes.

**Costs and damage.**

| | Flight bounce | Blink bounce | Ender |
| :--- | ---: | ---: | ---: |
| **Ki** | 6 (a chain link) | 10 | 4 (a heavy) |
| **Damage** | ×0.6 of a light | ×0.5 of a light | ×1.0 of a heavy |

- Without the ki for the next bounce, the blitz goes straight to its ender, or ends with the rival tumbling free if even that can't be paid.
- **A 10 s cooldown** per fighter after a blitz ends.
- The whole blitz is **one** decisive exchange, decided at the ender. Each bounce counts as a chain link for mood (+3). Its damage counts in the rate that k is tuned against.
- Bounces stay in the lane and never pass through buildings (ADR 0009). Only the ender may be a targeted smash.

**Flight or blink, per bounce.**
- *Tiers 1 and 2:* flights only. The exceptions are a fighter with the `blink` trait (the Protagonist), and Combat's last resort when no spiral clears.
- *From tier 3,* every fighter blinks with Combat's suggested chances, confirmed: 0.2 in Calm, 0.4 in Tense and 0.6 in Frenzied, +0.2 with the `blink` trait. Blinks then read as power, which fits pillar 4.
- *The whole blink chain* ("teleport spam") is for Frenzied only: a `blink` fighter at any tier, or anyone at tier 4. Its limit is ki: five blinks cost 50.

**How the defender answers.**

| Answer | When | Result |
| :--- | :--- | :--- |
| **Burst** (30 ki) | Any time in the ping-pong before the ender lands. Bounces count as hits here, not launches | The escape. The blitz ends and the attacker is pushed away, with no winner |
| **Perfect block on a return blow** | A middle bounce's 6-tick anticipation is its whole window, with no early tolerance. The ender has the heavy's window: the last 10 ticks of its 18-tick wind-up. Both work in the air | The blitz ends and the attacker staggers. The defender's riposte launches, and the defender may blitz back at once. That reversal is the ping-pong between both fighters |
| **Teleport clash** | **It needs the defender's request:** an attack pressed during the blitz, with 10 ki | Both blink and meet (Combat's `blink_clash`), decided like a heavy clash by tier and ki. If the defender wins, the blitz reverses. If the attacker wins, it continues |
| **Dodge-cancel** (15 ki) | In the gap between bounces | The defender slips the next intercept, with no winner |
| **A held guard** | Any time | Each bounce does guard damage only, but the heavy ender is a GUARD BREAK. Holding guard is not the answer |

The middle window is short on purpose. The bounces land on a steady rhythm, so it is a timing read, and the 20-tick mash lockout (§1) keeps mashing from finding it.

**QA bands.**
- Blitzes of both kinds: 2 to 6 a minute in Tense and Frenzied (unchanged).
- Return blows per ping-pong: a mean of 2.5 to 3.5.
- The defender ends 25 to 45% of ping-pongs early.
- Blink intercepts: none at tiers 1 and 2 without the trait, and 30 to 60% of intercepts at tiers 3 and 4.
- Blitzes deal at most 35% of a match's damage.
