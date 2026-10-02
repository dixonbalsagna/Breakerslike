# Input for the agency pass: the press reader, energy hold, boost and escape, air recovery, the taunt

Owner: Controls and Game Feel. Date: 2026-10-02. Answers the EP's brief from Orb's first two-player playtest (`docs/ep/vision.md`, "Orb's first two-player playtest", items 1, 3, 6, 8, 9). **Proposal only: nothing is built, no code touched.** Game Design leads the pass (`agency-pass.md`); every number below is data in `timing.json` and Game Design's to retune. Ticks at 60 a second. Terms: ADR 0008 and `input-scheme.md`.

**Revised 2026-10-02 for Orb's questionnaire 14.** Confirmed: hold RB for energy; hold LT to boost in any direction, draining ki; the alchemist reads **5 presses** (the log is sized for it); the recipe display is a setting. **Changed: air recovery is hold to brake at a ki cost, on the Guard button, not the dodge tap** (4a). Escape: Orb picked the counters (chase and catch, blasts clip the escaper, intercept ahead at a ki cost, exhaustion at empty ki) and **not** paying to break out of a brawl, so the R3 Escape control is an **open question** for Orb (3). The ranged press and hold, mash and timed results stay open for hybrid pitches. **Built (no grant needed):** `sim/input/press_read.gd`, momentary mode with the hold-or-toggle setting, the attack debounce; see the last section.

## Revision 2: Orb's picks after the pitches (2026-10-02)

Orb picked the EP's mix for the ranged press, wants timing to upgrade every reading style, and wants a provisional Escape now. This section **replaces 4b (the taunt) and the Escape recommendation**; the rest stands. **Built and tested:** `lightHeld`, `heavyHeld` and `escape` in the intent; Escape on every layout; the release timing in the classifier. **Patches for grants:** `intent-fields-sim.patch`, `intent-hash.patch`, `agency-schema.patch` (end of this section).

### R1. Escape, provisional (mapping A, built)

Orb: "something that works now", to revisit with more combat in place. A deliberate, remappable control, an **`escape` edge** in the intent (the sim reads it; the interrupt, its ki cost and the contest are Encounter's and Game Design's):

| Layout | Escape | Notes |
| :--- | :--- | :--- |
| Arena, Brawler, Simple pad | **R3** (click the right stick) | the old L3 + R3 transform alternative is dropped; **Brawler's transform moves to D-pad up held 30 ticks** (its only transform was that chord). Arena keeps LT + RT, Simple keeps RB held |
| Keyboard solo, shared P1, shared P2 | **C**, **X**, **Quote** (') | N stays reserved for a new match; all remappable |
| Touch Simple and Full | a **swipe up on Guard** (40 dp or more within 24 ticks of touching it; Guard stays down) | no new widget, so UI draws nothing new; a long-held Guard is never an Escape. UI may add a visible Escape button to Full later |

It is a normal binding (not a required action), so the Remap screen lists it; UI adds the row text. `escape` passes a stun in the proposed patch: it is "a way out of any situation".

### R2. Ranged press: three bands, and what the input sees

Orb: close strikes; **mid is a short lunge decided at the wind-up; far is tap to taunt and hold to charge**. The taunt is a challenge the opponent can answer by pressing attack, so both rush and meet in a clash or blur. The button picks the charge: **a held light is fast and can be feinted; a held heavy is slower, shrugs off blasts and can earn a launch.** A strike never exists at range. The bands and their distances are Game Design's and Encounter's; the input rules are the same in every band, which is the point:

1. **A press fires on the tick** (Rule 1) and the sim classes the band from the distance: close and mid start the exchange as now; **far plays the taunt on that tick.** No delay, no hold needed to see anything.
2. **A hold adds behaviour on top.** Far: `lightHeld` or `heavyHeld` for **12 ticks** starts the **charge** of that weight (light fast, heavy slow and armoured). Close and mid: the held press charges the blow, as the alchemist's "held" reading.
3. **Release launches.** The fighter takes off at max speed when the button comes up. **Release timing is graded against the charge's flash** (R3). Releasing before the flash is an early, weaker rush; on it is the full one.
4. **Feint a light charge: tap Dodge** while holding it. The fighter slips aside (the free dodge outside an exchange, its 0.5 s cooldown), the charge is cancelled, nothing is spent. A heavy charge **cannot be feinted** (armoured, committed). Why Dodge and not Guard: a fresh Guard press is also a perfect-block attempt and would feed the 20-tick lockout; Dodge says "slip away" and is free here.
5. **Answering a taunt: any attack press (light or heavy) while the opponent's taunt plays.** The sim reads the opponent's state; no new input. Both fighters rush and meet in a clash or a blur (Encounter's), decided on the pulse where it applies. A mash at range is a taunt then an answer or a launch, never endless posing.
6. **Nobody is locked.** The taunt and the charge are not exchanges: the taunter or charger can **Guard or Dodge out at once**, and the opponent is free throughout. Orb's complaint was the lock; the contact starts the exchange (agency-pass.md, rule 2).
7. **Taunts feed meters, with a guard against farming** (Orb's working ruling; the guard is Game Design's and the dialogue director's). Nothing for the input beyond the press.

### R2a. What the Simple layouts do at range

A strike never exists at range, so Simple's tap cannot attack there either. Simple's job is to own the engagement for a player who does not want to time or hold things, so:

- **Tap X at range: the answer or the rush.** Against an opponent's taunt, a tap answers (R2.5). Otherwise a tap launches a **fast light rush with no charge**, base grade: the assist takes the commitment so a tap never ends in a taunt and a standoff. (The taunt on Simple is **LB, the context button**: `context` is "provoke" when nothing else applies; the sim decides.)
- **Hold X at range: the heavy charge with an assisted release.** X held 12 ticks is the heavy charge (the existing hold gesture is the upgrade). The sim **releases it automatically a few ticks after the flash** (`autoCharge`, an assist flag beside `autoBurst`, grade "good", never "perfect"). A Simple player who releases **on the flash by hand** gets "perfect", so the ceiling is the same as every other layout and the floor is a safe release. A held X is never stuck.
- **Close and mid:** the same, with the hold gesture a heavy as today. The press log runs for Simple players too.
- **Feint:** Simple has A (Dodge): tap it while holding X on a light charge; but since Simple's hold is already the heavy, a Simple charge is never a light, so Simple has **no feint**. That is the assist's trade.
- **Touch Simple:** the same through its Attack button (light level to 12 ticks, heavy level after, now sent as `lightHeld` and `heavyHeld`).
- **Needs:** an `autoCharge` assist name beside the others in `SimAct.ASSISTS` (Simulation, appended), `"autoCharge": true` in the Simple presets' `slot` (mine, with Tools' schema line), and the sim's auto-release.

### R3. Reading presses: timing grades and the flash release

Orb: timing upgrades each style (a steady mash becomes a perfect blur, a hold released on the flash breaks guard, taps in time land clean) and earns the ending; "consistent timing should give the fighter a substantial edge". The classifier now returns the grade; **what each grade is worth is Game Design's number.**

| Style | The timing that tops it | The classifier says | Reading (ticks, data) |
| :--- | :--- | :--- | :--- |
| **Mash** | a **steady** mash: the gaps of the last 4 presses differ by 3 ticks or fewer | `timing: "perfect"`, `steady: true` | a perfect blur; a ragged mash stays `timing: "none"` |
| **Taps** | **three perfect taps in a row**, each within 4 ticks of a blow (10-tick window on touch, doubled with assist, the player's offset applies) | `style: "rhythm"`, `streak: 3`, `timing: "perfect"` (two: `"good"`) | taps in time land clean; one off press breaks the streak |
| **Hold** | **released on the flash** of the charge | `release: "perfect"` (within 4 ticks), `"good"` (within 8), `"early"`, `"late"` | a hold released on the flash breaks guard; early is the weak rush, late is "good" at best |

Rules the sim follows when it reads them:
- **The flash is the sim's.** It stamps the charge's flash tick on the log entry (`SimPressRead.set_flash`), the release closes it (`release`), and `release_grade(entry, opts)` or `classify().release` says how it was let go. The level fields (`lightHeld`, `heavyHeld`) are what make the release visible: the release tick is the tick the level falls.
- **The grades are per press.** `grade_of(distance, opts)` grades any press or release: perfect within the window's half (4), good within 8, off beyond. Touch widens the perfect window to 5, assist doubles both, the optional per-player timing offset (-6 to 6, in the match header) shifts the mark.
- **Timing earns the ending** (a perfect streak or a perfect release makes the string's last blow the clean ender): the sim reads `timing` when the string closes. When both fighters have timing, the **timed press wins the trade beat** (agency-pass.md, B with C's rule).
- **A flash must be seen and heard** (Animation, VFX, Audio): the window is 8 ticks, 133 ms, a readable cue, not a guess. Flash times per weight are Combat's data (light fast, heavy slow).

**Balance tests (Orb: run them on the recommendation).** They need the alchemist in the sim, which is Encounter's, so here is the recipe for QA's bots: three press bots on the same fighter and seed, one **mash** (steady 8-tick gaps), one **timed** (presses within 0 to 4 ticks of the blows) and one **ragged** (gaps jittered by 6 ticks); hold bots **released on the flash**, **early** and **late**; every pairing, 100 seeds. Pass: the consistent timer beats the mash by a clear margin (Game Design's "substantial": I propose 60 to 65% and up), the ragged player sits between, and a perfect hold-release beats an early one. `SimPressRead.classify` already labels what each bot did, so the report can count styles and timings next to the win rate.

### R4. What changed in the intent and who must apply what

Three additive fields, bits 40 to 42 of the packed intent, so **every older replay still unpacks** (the new bits are zero) and the intent version stays 2: `lightHeld`, `heavyHeld` (levels) and `escape` (edge). They live in `sim/input/intent.gd` (mine, applied) and the layout and touch layers fill them (applied, tested: `agency_input_test.gd`, 79 checks). The lines outside my paths are patches, to apply in this order:

| Patch | Files | What | Effect |
| :--- | :--- | :--- | :--- |
| `agency-schema.patch` | `tools/schemas/input-actions.schema.json`, `input-timing.schema.json` | the three action fields; `read.steadyJitter` and `read.perfectStreak` | the validator accepts my data (95 files, 0 errors) |
| `intent-fields-sim.patch` | `sim/core/tools/parity.gd`, `wounds.gd`, `intro.gd` | the pack test covers the new fields (and refuses `1 << 43`, not `1 << 40`, as the first invalid integer); a stun clears the held levels and leaves `escape` through; `escape` skips the intro | **golden unchanged**: parity, the golden check and `npm test` pass (5 of 5) |
| `intent-hash.patch` | `sim/core/hash.gd` | the three fields in the hashed intent record | **moves every state hash: regenerate `golden.json` in the same commit** (`sim/core/tools/golden.gd`), best done when Encounter's code first reads them |

Until `intent-hash.patch` lands the new fields are in the record and the replay but not in the state hash; that is harmless while nothing reads them.

## Recommendations at a glance

| # | Item | Recommendation |
| :--- | :--- | :--- |
| 1a | Telling hold, mash and timed taps apart | A per-fighter **press log** in the sim (last 5 attack presses with down and up ticks), classified by a pure function. **Hold** = down 12 ticks or more. **Rhythm** = 2 of the last 3 presses within ±4 ticks of a blow's contact. **Mash** = 3 gaps of 10 ticks or less. Needs two new held fields in the intent |
| 1b | Stick tilt at the launch | **Screen-absolute, 8 sectors**, the attacker's stick latched over the 12 ticks before the launch beat. No new intent field |
| 2 | Hold RB for energy | `mode` becomes **momentary**: held = energy, released = physical. The intent field is unchanged, so **no sim change**. Brawler uses its `mode` button (X), not RB. Simple stays on auto |
| 3 | LT and Escape | **Boost is just flight**: hold LT, any direction, draining ki (confirmed). Escape's counters need no new control. **A deliberate Escape control (R3 click on pad, a key, a touch button) is an open question for Orb**; two alternatives below |
| 4a | Air recovery | **Hold Guard to brake** (confirmed: hold to brake, ki cost per tick). **No new input**: the sim reads `guard` while launched. Locked for 20 ticks after the last hit so a juggle still pays; the dodge tap stays the tech at a bounce or tumble |
| 4b | Taunt, hold to launch | The press plays the taunt **on the tick** (no latency, Rule 1). Holding the button, or pressing again, through the taunt takes off. Applies to light and heavy at range on every layout except Simple |
| 5 | ADR 0008 | Seven things change (the last section). Simple keeps its direct attack and loses nothing it has |

## 1a. Reading holding, mashing and timed taps

**What the sim sees today:** `light`, `heavy`, `sig` are one-tick edges. A hold, a mash and a rhythm all look like a string of edges; a hold looks like one edge. So two things are needed: the **level** of the attack buttons, and a short **memory** of presses.

**Intent change (two new fields, Simulation's I3):** `lightHeld`, `heavyHeld` (bool, level, true on every tick the button is down). A press shorter than a tick is still stretched to a tick with its edge (host guarantee), so a tap never loses its level. `sig` needs no level. The layout fills them on every layout; on Simple, X is both and the existing 12-tick `upgrade` stays.

**The press log (sim state, Encounter and Simulation's):** a ring of the last 5 attack presses per fighter: `{kind: light | heavy | sig, mode, down_tick, up_tick or -1, beat_offset}`. `beat_offset` is the signed distance in ticks from the press to the nearest **blow contact** of the running exchange (`null` outside one). Clash presses (the pulse, the finisher struggle) are **not logged**, or a clash mash reads as the string. Hashed, so replays and rollback carry it.

**The classifier** is a pure function `classify(log, now) -> {style, rate, on_beat}` with no state. I can build and test it in `sim/input/press_read.gd` as soon as the log's shape is agreed, so Encounter calls it and nobody re-derives a threshold.

| Style | Rule (data in `timing.json`, `read` block) | Why |
| :--- | :--- | :--- |
| **Hold** | the button has been down for **12 ticks** (`holdStart`, the number sprint and the channel already use). Live at tick 12, not on release | one hold threshold across the whole game |
| **Rhythm** | **at least 2 of the last 3 presses** have `abs(beat_offset) <= 4` (an 8-tick window, the pulse's, 10 on touch, assist ×2, the optional per-player timing offset applies) | the player is watching the blows |
| **Mash** | the last **4** presses with all 3 gaps **10 ticks or less** (6 a second or faster). Clears after 20 ticks with no press | human mashing is 6 to 10 a second with jitter, so the mean gap sits at 6 to 10; 4 presses stops two quick taps from counting |
| **Taps** | anything else: presses more than 10 ticks apart and off the beat | a deliberate string |

**Precedence: hold, then rhythm, then mash, then taps.** A mash that happens to land on the blows is rhythm (the player did read the fight); blows closer than 10 ticks apart make the two the same thing and that is fine. The classifier also reports the **mix** (counts of light, heavy, energy among the last 3 and the last 5) for the "running mix" Orb describes.

**Robust on pad and keyboard:** everything is in ticks off the same edges and levels, so the numbers are the same on every device. Specific hazards:
- **Key repeat:** the layout tracks down and up itself and ignores the OS auto-repeat events, so a held key is one press and a level, never a mash.
- **Trigger chatter:** an analog trigger bound to an attack (Brawler RT) already has hysteresis (on 0.35, off 0.25). Add a **2-tick debounce** on every attack button: a press within 2 ticks of that button's release is the same press (worn pad contacts). It does not change `light` edges the sim already counts at 60 Hz.
- **Hit-stop:** a press made during a freeze is kept and sent on the first live tick (a host guarantee). The log must stamp it with its **real tick** (the freeze counts as time the player lived through), or a rhythm player is penalised for the freeze. **Question for Simulation: does `S.tick` advance on a frozen tick?** If not, the log needs a real-time counter.
- **Two players:** one log per fighter, no cross-talk; on a shared keyboard a ghosted key shows as a missing press and the classifier degrades to taps, never to a wrong hold.

## 1b. Stick tilt at the launch becomes a screen direction

- **Which stick:** the attacker's `mx, my`, already in the intent. No new field. (The stick is free during an exchange: the entry class is read once at the press and nothing else uses it after.)
- **Which frame:** **screen-absolute**, as flight already is (stick right flies right). I recommend this over "relative to the attacker" because both players and the audience see the same screen, and "toward or away" is already the entry language; a second relative frame for the launch would be a second thing to learn. The wrap does not break it: the camera frames the shortest arc, so right on screen is +x in the local frame. If Orb meant attacker-relative, it is the one line `mx * sign(sdx(...))` already in `act.gd:73`; say so.
- **Sectors, not a free angle:** 8 sectors of 45 degrees (right, up-right, up, ...), dead zone 0.35 of full deflection (about 45 on the 1/127 grid). A keyboard has only 8 directions anyway; quantising the stick the same way means **neither device is at an advantage**.
- **When it is read: latched.** The most recent sample **beyond the dead zone within the 12 ticks before the launch decision**. Players release the stick as they press the last button; the latch keeps the intent. Nothing latched means no aim, and the planner picks as today.
- **Snapped by the director** (Orb, questionnaire 14): the sector is the *aim*, and the director snaps it to the nearest launch it can make; the stick never has to be exact. **Use:** a strong term in the launch planner's score for the candidate whose launch direction is nearest the sector; up reads as UPPERCUT, down as SLAM DOWN, sideways as SMASH ACROSS, diagonals blend. The planner's debug feed prints "aim: up-right (latched 5 ticks)". Encounter's call.
- **The defender's stick** is not the attacker's aim. It is the **recovery direction** (4a).

## 2. Hold RB for energy attacks

**The mechanic:** `mode` is **momentary** while the control is held: `mode = 1` (energy) while down, `0` after. The record already sends `mode` every tick, and a request carries the `mode` it was pressed in, so **the sim changes nothing**. The 12-tick toggle cooldown goes. Press the modifier first; a face press lands in the mode of its own tick (no latency, no retroactive change).

**What each control does while the mode control is held** (the energy variants are the existing "context in energy mode = energy shove" and the piece family swap):

| Layout | Mode control (held) | Light | Heavy | Signature | Context | Power layer (RT or Y held) |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| **Arena** | **RB** | X: energy blast | Y: heavy blast (the charged one) | B: signature, as now | A: energy shove | specials as now; mode does not change them |
| **Brawler** | **X** (its mode button; RB is its light) | RB: energy blast | RT: heavy blast | B: signature | A: energy shove | Y held + RB, RT, X as now |
| **Simple** | none: `autoMode` (the director picks blasts at range, melee close) | X tap | X hold | Y | LB | as now |
| **Keyboard solo** | **Q** | J | K | L | I | E held + J, K, I, L |
| **Keyboard P1 (shared)** | **E** | F | G | R | V | Q held |
| **Keyboard P2 (shared)** | **O** | H | M | U | Comma | Slash held |
| **Touch Full** | the Mode button: **tap latches, hold is momentary** (a thumb is busy) | Attack | Attack swipe up or hold | Signature | Context | Power |

**What RB does today, and what becomes of it.** Arena: RB is the mode **toggle**; it becomes the mode **hold**. Brawler: RB is **light**; it stays light, and the hold goes on X, which was its mode toggle. Simple: RB is the **transform** hold (0.5 s); it stays. Nothing else uses RB, so nobody loses a control.

**Accessibility:** a setting **"Energy: hold or toggle"** (default hold) restores the toggle for a player who cannot hold a shoulder button while pressing a face button. It is the old behaviour, so the code stays.

**On screen (UI, VFX):** hands glow and the prompt row shows energy variants while held, so the held state is never invisible. Energy costs ki (Game Design).

**Keyboard cost.** On the solo layout Q is under the left hand with WASD and Shift; it is reachable with the pinky but crowded. The binding is remappable, and a right-hand alternative is an option (`U`). Check it in the keyboard playtest.

## 3. LT: fly fast at will, and Escape

**What Orb found strange:** Escape was a stance (sprint held plus the stick away, read when an exchange starts), so the same hold was both "run" and "escape" and the difference was a direction. The fix is to **separate the two ideas.**

**Boost, in every mapping** (confirmed by Orb, with a ki drain per tick, Game Design's rate). Holding LT (or Space, A on Simple, the touch Dodge button) **is high-speed flight in the stick direction, in any direction, any time.** The dodge tap fires on press and the lunge flows into the boost if the button stays down (a lunge into a sprint is already free); the 12-tick threshold only decides tap against hold, not whether you are fast. **Boosting never means Escape by itself.** It keeps the tackle (context while boosting) as the pursuer's "stop him escaping" tool, which exists today.

**Escape's counters need no new control** (Orb's picks): *chase and catch* is boost toward the escaper plus the tackle (context while boosting), which exist; *blasts clip the escaper* is the energy hold (RB) and light or heavy; *intercept ahead at a ki cost* is a boost whose aim leads the escaper, the director's, on the same LT hold; *exhaustion at empty ki* is the sim's. Orb did **not** pick paying to break out of a brawl, so the question below was open (now a provisional build, R1): does Escape need a deliberate control at all, or does the old stance (boost away) stay the only escape? Orb has since asked for a provisional Escape to feel in play: **built as mapping A**, see Revision 2, R1.

**If Escape gets a control, three mappings:**

| | A: a deliberate control (recommended) | B: Guard and Dodge together | C: double-flick |
| :--- | :--- | :--- | :--- |
| Pad (Arena, Brawler) | **R3 click** (free today) | LB with LT within 6 ticks | flick the stick away twice while boosting |
| Simple | **R3 click** (not a "button" in the legend) | B and A together | flick |
| Keyboard | a key: **C** (solo), **X** (P1), **Quote** (P2); N is reserved for a new match | Shift with Space | tap away twice |
| Touch | a button that **appears only while threatened**, like Context | Guard and Dodge buttons together | flick away twice |
| Conflicts | none; the old L3 and R3 transform alternative is dropped (LT and RT still do it) | **real:** a defender who raises Guard then dodge-cancels within 6 ticks gets Escape, and dodge then guard fires the dodge first (Rule 1) | high: players flick away constantly |
| Cost of an accident | none, a deliberate click | an Escape costs ki and risk when a dodge-cancel was meant | the same, often |
| Parity on every layout | yes, with one new control each | yes with no new control | yes |

**Recommendation: A.** Escape is a **risky, costly interrupt usable from any state** (Orb: "exit any situation at some risk"), so the control should be deliberate: a stick click takes the right thumb off the face buttons, which is the friction a panic button should have, and nothing else in the scheme is on it. B reuses buttons but collides with the dodge-cancel the game is built on. C costs no control and gives players accidents all day. The cost, the risk and the contest against a boosting pursuer (the tackle, a grab) are Game Design's.

**What the sim sees:** a new **`escape` edge** (Simulation's I3). Escape stops being a stance derived from `sprint` and the stick, and the `awayDead` test in `act.gd` for Escape goes; `sprint` stays for boost. In the director, an escape is an interrupt of the same family as the burst and the dodge-cancel (Encounter orders them).

## 4a. Air recovery: hold Guard to brake

**Orb's answer: hold to brake, at a ki cost, not the dodge tap.** Which button: **Guard** (LB on Arena and Brawler, B on Simple, Shift or Semicolon on the keyboard, the Guard button on touch). Reasons: LT held is now *boost* (accelerate, draining ki), so braking on LT would be the opposite on the same button; braking is defensive ("plant yourself"), which is what Guard already says; and every layout has Guard held with a thumb or finger that is free in a knockback.

- **No new input.** The intent already carries `guard` as a level. A launched fighter holding `guard` brakes: speed bleeds off quickly while it is held, ki drains each tick, and the fighter returns to free flight when the speed is gone, the button is released, or the ki runs out. The rate, the cost and the speed below which it ends are Game Design's and the sim's (`balance-targets.md`).
- **Lock:** the brake does not start in the first **20 ticks after the last hit** (data), so a juggle still pays at 2 or more hits. Pressing early is not remembered: the player simply holds on (a hold already down when the lock ends starts braking on that tick, which is what "hold to brake" should feel like).
- **A fresh `guardPress` during a knockback is not a perfect block** (nothing to block mid-flight): the sim ignores the edge while launched, so a brake press never feeds the 20-tick anti-mash lockout of the perfect block.
- **The stick** steers nothing while braking; the fighter stops where he is. (A direction on release is Game Design's to add, not needed.)
- **The tech stays.** The dodge tap at a bounce (4 ticks before to 8 after) or in a tumble (`tech-and-pulse-input.md`, balance-targets section 20) is the ground-contact recovery; air recovery is the brake. Game Design may fold them. Escape (if Orb picks a control) still works in a juggle.
- **Touch:** the Guard button held. **Simple:** B held.

## 4b. Taunt, then hold to launch (superseded by Revision 2, R2: bands, charges, answering the taunt)

Orb's idea: at range, a press plays a taunt; holding the attack through the taunt ends it by taking off at max speed to attack. The input fits the scheme without a new control because it is the **tap-fires-on-press, hold-adds-behaviour** rule (Rule 1) applied to attack.

**Spec (ticks; the taunt length T is Combat's, I assume 30):**
1. **At range** (beyond a reach R, the sim's, set so a press never starts a flight the opponent could not see coming; at a melee distance a press starts the exchange as it does now): a **fresh `light` or `heavy` edge starts the taunt on that tick.** No delay, no hold needed to see the pose.
2. **Takeoff:** the attack button still **down at tick T minus 6** (a hold through the end of the taunt), **or a second attack press during the taunt** (so a masher is not stuck taunting), ends the taunt by **taking off at max speed** into the exchange, as the held weight's attack (light: the quick rush, heavy: the heavy rush). The sim reads `lightHeld` or `heavyHeld` at that tick, which is why the held fields are needed.
3. **Release before T minus 6 with no second press:** the taunt plays out and the fighter is **free the tick it ends**. Nothing is queued.
4. **Nobody is locked.** The taunt is not an exchange: the taunter can **guard or dodge out at once at no cost**, and the opponent is free to act. This is the point of Orb's complaint; the taunt leaves both players in control and the takeoff is the commitment.
5. **Signature at range** is not a taunt: it is a beam and needs no approach. **Context and the power layer** are unchanged.
6. **Simple: no taunt by default.** A tap at range attacks as it does today, because the assist's job is to own the engagement for a player who does not want to hold buttons, and hold already means heavy there. A setting can turn the taunt on for Simple; with it, hold takes off as a heavy and a second press as a light.
7. **Cooldown:** none from input; a taunt costs a short cooldown on the taunt pose only (Combat's), so it cannot be spammed into a stall. Game Design may give it a small reward (meter, pride, menace) to make it worth playing; not mine.

**The mash case:** presses at range read as a taunt followed at once by takeoff (the second press), so a masher closes the gap with one wasted pose, not forever. The classifier of 1a sees that exchange as the mash it is.

## 5. What this breaks in ADR 0008, and what Simple does

| # | ADR 0008 or its docs | What changes | Who |
| :--- | :--- | :--- | :--- |
| 1 | `input-scheme.md` §1, "Held states drive the director": Escape is `dodge` held and moving away, read at exchange start | Escape is the **`escape` edge** from its own control, usable in any state. Guard, Dodge and Press are still read at the start. Boost stays `sprint` | Simulation (field), Encounter (interrupt) |
| 2 | `intent-v2.md` §2: no hold information for attack buttons | **`lightHeld`, `heavyHeld`** levels; `escape` edge. The record's hash list and the golden change; a replay version bump | Simulation |
| 3 | The attack queue (depth 3, expiry 36) as the model of a string | The alchemist reads a **press log**, not a queue: presses are ingredients, not requests. The queue stops being the way a string is built. `mash_probe`'s fairness numbers are void for the new director and I rerun them | Encounter, Simulation |
| 4 | `mode` is a **toggle** (Arena RB, Brawler X, keyboard Q, E, O) | `mode` is **momentary** by default, with the toggle as a setting. The record is unchanged | Controls (layout), UI (glyphs, prompts) |
| 5 | Rule 1: the tap fires on press | **Kept**, and the taunt depends on it. But Simple's light **on release** (the bridge until the queue upgrade) must go first, or a taunt would play on release and a hold would be unreadable. Simple's X must fire a light on press and upgrade to heavy at 12 ticks | Controls (on Encounter's go) |
| 6 | The transform chord's alternative L3 and R3, and R3 as unused | **R3 is Escape**; the L3 and R3 transform alternative is dropped (LT and RT, or Simple's RB hold, remain). `remap.md` and the glyphs lose one row | Controls, UI |
| 7 | Clash presses (the pulse, the struggle) are attack edges | They must be **excluded from the press log** and from taunt logic, or a clash mash reads as the string and a press at the wrong time takes off | Encounter |

**What Simple does.** Its six buttons are unchanged and it loses nothing it has: attack stays a direct press that starts the exchange (no taunt unless the setting is on); the director still picks the mode (energy blasts at range, melee close: this is "kiting" for a player who does not hold RB); X hold is still heavy; A hold is boost, no longer coupled to Escape; **Escape is R3** (touch: the threatened-only button); the transform is RB held (or `autoForm` if Orb approves it, `auto-form-spec.md`); the launch tilt and air recovery work as on every layout (the stick and A). The press log runs for Simple players too, so the alchemist reads their taps; they will mostly be read as taps, which is the plain, predictable outcome the layout is for.

## What I need, and what I can start

- **Simulation:** `lightHeld`, `heavyHeld`, `escape` in the intent and hash (I3); the press log in state; whether `S.tick` advances in a freeze.
- **Encounter:** the log's contents (blow contact ticks for `beat_offset`), the classifier's callers, the clash exclusion, the taunt in the director, the aim term in the planner, the escape interrupt.
- **Game Design:** the lock (20), the energy and escape costs, the taunt's reach R and length T, whether R3 is an acceptable Escape for Orb's hands (the questionnaire: "Escape: a dedicated click, or a button chord?").
- **Combat and Animation:** the taunt pose (T ticks, interruptible), the energy hands.
- **UI:** the mode and escape prompts and glyphs, the energy toggle setting, an aim arrow while the stick is tilted in an exchange.
- **Tools:** the `read`, `tech` and `clash` blocks in `timing.json`'s schema (one patch).
- **Me, once the shapes are agreed (about a day, with tests):** `sim/input/press_read.gd` (the pure classifier), the momentary `mode`, the `lightHeld`, `heavyHeld` and `escape` fields in the layout and hub, the 2-tick debounce, the R3, keyboard and touch Escape controls, the layout and remap data, and the tests. The classifier and the momentary mode need no one's permission and can start on Orb's go.

## Built 2026-10-02 (code and tests in my paths; no `sim/core` lines)

| What | Where |
| :--- | :--- |
| The pure press classifier: the log helpers (`push`, `release`, `beat_offset`) and `classify(log, now, opts)` returning `{style, hold_ticks, on_beat, presses, mix_short, mix_long, rate}`. Log of 5. `rate` is for display only; no sim decision may use a float | `sim/input/press_read.gd`, `sim/input/test/press_read_test.gd` (53 checks) |
| Its numbers: a `read` block in `data/input/timing.json` (the code defaults match). **The schema needs the patch before the validator accepts the block** | `data/input/timing.json`, `docs/controls/read-schema.patch` (Tools') |
| **Momentary mode:** `mode = 1` while the mode control is down on Arena (RB), Brawler (X), the keyboards (Q, E, O) and Full touch (hybrid: a tap latches, a hold is momentary); toggle is the accessibility style; Simple stays -1. A press shorter than a tick counts for its tick | `sim/input/layout.gd`, `touch.gd`, `hub.gd` (`set_mode_style(style, slot)`, `mode_style_of`), `sim/input/test/mode_test.gd` (62 checks) |
| **The setting:** per player "Energy: hold or toggle". UI adds the options `energy_style` and `energy_style_p2` (choices `hold`, `toggle`, default `hold`) and the screen text; Rendering applies `energy-style.patch` (a few lines in `main.gd`) | `docs/controls/energy-style.patch` |
| **The attack debounce:** a press within 2 ticks of the same attack button's release (light, heavy, signature) is the same press, no new edge (not for dodge or guard, never over the power layer) | `layout.gd`; `timing.json` `read.debounce` |

**How Encounter uses the classifier:** on each light, heavy or signature edge, `SimPressRead.push(log, kind, f.input.mode, tick, SimPressRead.beat_offset(tick, blow_ticks))`; on its release, `release(log, kind, tick)` (once `lightHeld` and `heavyHeld` exist; until then a hold is not visible and `classify` reads taps, rhythm and mash). Call `classify(log, tick, {touch, assist, offset})` when the alchemist composes a string; the recipe display is `mix_long`. Clash presses are not pushed.
