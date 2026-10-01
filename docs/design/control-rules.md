# Rules for the new control scheme (ADR 0008)

Owner: Game Design. Orb decided the scheme in `docs/decisions/0008-control-scheme.md` (questionnaire 8). This page sets the game rules it needs: windows, costs, cooldowns, priorities and automatic choices. Controls owns the bindings and layouts, and Encounter owns the director's use of them. Numbers are starting values in ticks (60 a second) and ki (cap 100), and QA tunes them.

**What this replaces.** Stances are now held states, read at exchange start as before:

| Held state | Old stance |
| :--- | :--- |
| Press (attacking) | AGGRESSIVE |
| Guard held | DEFENSIVE |
| Dodge tapped | EVASIVE |
| Sprint away | ESCAPE |

`stance-matrix.md` R5 (the parry by state) and R9 (the weight latch and the signature queue) are superseded for human players. The R5 numbers stay as the AI's skill model.

## 1. The perfect block

- **The window.** A Guard press that lands in the **last 10 ticks (0.17 s) of a visible wind-up** is a perfect block.
- **A mistimed tap still blocks.** A press earlier in the wind-up, or a guard already held, is a normal block. Only a press after the strike lands is a hit.
- **Which strikes have a window.** Every strike with a wind-up of 10 ticks or more: an exchange's opening strike, every heavy, every ender, and ordinary energy blasts (a perfect block deflects them). Mid-string follow-ups have no fresh wind-up and no window. Signatures can be guarded but not perfect-blocked.
- **The reward:**
  - no damage, no guard wear and no ki loss;
  - +8 ki;
  - the attacker's string ends and they stagger for 24 ticks (0.4 s);
  - the defender keeps their momentum: an attack pressed within 30 ticks is a **riposte** that can't be blocked or dodged. Against a heavy or an ender, the riposte launches;
  - it counts as a parry for mood (+4) and as a humbling for Pride.
- **The risk.** Tapping without holding guard is the "moving parry": it works the same, but a late tap takes the full hit with no guard up.
- **Mashing Guard gives normal blocks only.** A Guard press outside a window locks the perfect block out for 20 ticks, and each further press restarts the lockout. The guard itself still works.
- **Beam clash.** The director never fires a beam on its own, so the old "AGGRESSIVE with 40 ki meets the beam" rule goes. A clash now happens only when the defender fires their own signature or power-layer blast during the incoming beam's wind-up. It costs 40 ki, as before.
- **QA bands:** perfect blocks are 5 to 15 per 100 melee exchanges at mid skill, and at most 2 per 100 for a scripted Guard masher.

## 2. Dodge-cancel, burst and reversal

| Action | Cost | Cooldown | When it works | What it does |
| :--- | ---: | ---: | :--- | :--- |
| **Dodge-cancel** (Dodge tap mid-exchange) | 15 ki | 3 s | As the attacker: at any time, cancelling your own strike or recovery. As the defender: only in the gaps between strikes, never during hit-stun or a launch | 12 ticks of invulnerability and a dash in the held direction. The exchange ends with no winner |
| **Burst** (Power tap) | 30 ki | 8 s | Also while being hit. Not during a launch, a cinematic or a finisher | A 360-degree shove that pushes the rival back about 8 bh and ends the exchange. No damage, and no winner |
| **Reversal** (context button in guard, close up) | 20 ki | 6 s | Only just after a normal block | A guard-cancel counter-strike that starts the defender's own exchange |

- **Burst bait.** If the rival is holding Guard when the burst fires, they absorb it and the burster staggers for 30 ticks. An expert pauses a string and guards to draw the burst out.
- **No fallback.** Without the ki, or on cooldown, the press does nothing except its acknowledgement. Two small pips by the ki bar show the dodge-cancel and burst cooldowns.
- A plain dodge outside an exchange is free, with a 0.5 s cooldown.
- **For scale:** a signature costs 45 ki, a clash 40 and a chain link 6. A burst therefore delays a signature, which is the trade.

## 3. The power layer and the transform hold

- **Power tap** (released within 12 ticks with no face button): a burst.
- **Power held** (12 ticks or more with no face button): the channel. It charges at +30 ki a second, and runs the fighter's own channel where they have one (the Protagonist's stoke). Guard is down while channelling, and CHARGE INTERRUPT applies as now.
- **Power plus a face button:** one of the three loadout specials, or the signature. Costs and cooldowns are unchanged: specials cost 15 to 30 ki with a 25 s cooldown, and the signature costs 45 ki with a 120 s cooldown per fighter. A special or signature fired this way never also bursts or charges.
- **Requests, not queues.** A funded press fires at the next exchange boundary. An unfunded press is refused with the "need ki" cue and doesn't wait: the same trigger, held, is how the player charges. This replaces the 180-tick and 600-tick queue rules.
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
| **Which special** | Power plus Attack fires one of the three loadout specials, picked by range, by the rival's state (guarding, airborne) and by a variety penalty against repeating the last one |
| **Signature** | Never automatic. Power plus Heavy on a controller, or a swipe up on Attack on touch |
| **Weight** | On touch, a tap is a light and a hold is a heavy |

- The automatic picks are sound but plain: mode follows range alone, and specials follow the obvious context. The full layouts add choice, such as picking the exact special, mixing modes at will, and timing or baiting a burst.
- The perfect-block window is the same 10 ticks on every layout. Touch may get +2 ticks if device tests show screen latency needs it.

## 6. Mashing: fine for beginners, beatable by experts

**Why mashing works.**
- Every attack press is one exchange request, and extra presses queue a short combo up to **3 deep**. Presses beyond that are ignored, never punished.
- The director composes real strings from those presses, so a masher sees good-looking combat and beats the easy AI.

**Why an expert beats it.**
1. **A queue is a commitment.** Three queued presses commit about 1.5 to 2 s, and the string's ender has an 18-tick wind-up with a perfect-block window. A perfect block gives the riposte.
2. **Repeats go stale.** The same weight in three exchanges running adds 2 ticks to its wind-ups for each further repeat (at most +6) and widens the rival's perfect-block window by 2 ticks (at most +4). Changing weight, mode or direction clears it.
3. **A blocked string is punishable.** A fully blocked string leaves the attacker 12 ticks behind, which is the guard's punish window.
4. **The triangle.** Attacks lose to guard and dodge, and a masher never grabs, so guarding a masher is safe.
5. **Defensive mashing fails too.** Mashed Guard gives normal blocks only (§1), and dodge-cancel and burst have cooldowns and can be baited (§2).

**QA bands** (a scripted masher pressing light every 8 ticks):
- against the easy AI it wins at least 60%;
- against the medium AI it wins 35 to 50%;
- against a script that perfect-blocks enders and ripostes it wins at most 15%.

## 7. The smallest placeholder transform (next build)

One form, the same for both placeholders, built from what exists.

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
