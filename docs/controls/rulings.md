# Controls and Game Feel: rulings on windows, buffering, hit-stop and the finisher struggle

> **2026-09-30 notice:** Orb's questionnaire 4 moves parry and the finisher struggle to the director, so the press-timing parts of this document (sections 3, 4, 6, 8 and the press ticks of Stage A) are **on hold** until Game Design reports. Sections 5, 7, 10 and the hit-stop stages stand. See [intent-queue-plan.md](intent-queue-plan.md).

Owner: Controls and Game Feel. Audience: Combat (windows), Encounter Systems (sim), Game Design, UI/UX, Camera, Accessibility, QA. Date: 2026-09-29. Status: **design, no code yet** (ADR 0006: the GDScript sim is the source of truth; I write code in `sim/input/` when the EP hands me the tree). Numbers are whole 60 Hz ticks, stored as data. ms = ticks × 16.67.

Sources checked in the GDScript sim: `sim/input/control.gd`, `sim/core/sim.gd` (step), `sim/core/damage.gd`, `sim/director/melee.gd`, `exchange.gd`, `beam.gd`, `sim/core/fighter.gd`, and Combat's `data/combat/templates.json` (spaced profile), `finishers.json`, `docs/combat/data-fields.md` §10.

## 0. Summary of rulings

| Item | Combat / Game Design proposed | Ruling | Why, in one line |
| :--- | :--- | :--- | :--- |
| Light parry window | 12 ticks (0.20 s) | **15 ticks (250 ms)**, ending on the strike tick, inclusive | The window must equal the tell the player sees. A 12-tick window under a 15-tick tell shows "now" three ticks before the sim agrees |
| Heavy parry window (HEAVY CLASH: WON) | 20 ticks | **Accepted: 20 ticks (333 ms)** | Matches `heavyWindup` and today's 19 to 20 |
| Wind-up (tell) width | 15 ticks light (0.25 s), 0.20 to 0.30 asked | **Accepted: 15 light, 20 heavy** | Human reaction to a pose change is about 12 to 15 ticks; anything shorter is a pure memory test |
| Parry press buffer | none today | **4 ticks before the window opens** | Forgives an early press without making mashing free |
| Chain window | 36 ticks, 4-tick buffer | **Accepted: 36 ticks (600 ms), 4-tick buffer** | No cost for pressing, so no reason to narrow it; the stall is Combat's to fill (phrases) |
| Whiff cost (R5: 5 ki, 0.5 s lockout) | Game Design | **Amended: first stray press free with a 12-tick lockout; each press inside a lockout costs 5 ki and restarts it** (section 3.4) | R5 as worded leaks the branch and punishes reacting to the rush rather than the tell |
| Hit-stop floors | light 0.07 s, heavy 0.12 s, finisher 0.30 s | **Adopted as whole ticks: light 4, heavy 7, final blow 18** (table, section 5) | Ticks, never seconds. Also fixes a float bug: 0.05 s runs 4 ticks today, not 3 |
| Finisher struggle | Game Design: three timed presses, +10 / −5 | **Three beats 18 ticks apart, ±4 ticks (assist ±8), on the light or heavy button** (section 8) | Same button as parry: nothing new to learn |

## 1. Ground rules

1. **Whole ticks, as data.** Every window, buffer, lockout and hit-stop is an integer count of 60 Hz ticks in data (draft block in section 11). No seconds in the sim for anything a player presses against.
2. **What you see is what you get.** A window's first tick is the first tick of its visible cue; its last tick is the tick the strike lands. The `window_open` event carries `dur_ticks`.
3. **Hit-stop never eats a press.** Presses made during a freeze are kept and stamped on the first live tick. Buffers age in live ticks only.
4. **Presses are timestamped by tick.** Today `control()` stamps `f.lastAtkT = S.T` (a float) on any light or heavy press (`control.gd:18-19`), and `strike()` compares it (`melee.gd:212`). I replace it with integer press ticks (section 3.5).
5. **A press made on tick t means pressed in (t−1, t].** `control()` runs before `dirUpdate` in the same step (`sim.gd:82-87`), so a press on the strike's own tick still counts. That is the only "late" grace there is, and it is enough (section 3.3).

## 2. Windows in ticks, per template

Derived from `data/combat/templates.json`, profile `spaced` (wind beat to the first parryable strike). `c` is the contact anchor, at least 24 ticks.

| Template, branch | Wind beat | First parryable strike | Parry window today (parity) | Parry window (spaced) | Chain window |
| :--- | :--- | :--- | ---: | ---: | :--- |
| TRADE BLOWS, won and lost | c−15 | c (A's) | 6 ticks (100 ms) | **15** (250 ms) | after a win only, 36 |
| PRESSURE, holds and counter | c−15 | c | 6 | **15** | after holds, 36 (R6 removes it) |
| GUARD BREAK | c−15 | c | 6 | **15** | after the break, 36 |
| HEAVY CLASH: WON | c+63−20 | c+63 | 19 to 20 | **20** (333 ms) | 36 |
| HEAVY CLASH: COUNTERED | c+63−20 | none (D's strike, no-parry) | **dead** | **dead, silent** | none |
| HEAVY CLASH: SHOCKWAVE | c+63−20 | none | **dead** | **dead, silent** | none |
| DODGE: READ and COUNTER | parity only, at t−0.12 s | none | **dead** (CC-009) | none (wind dropped) | after READ |
| PURSUIT (both), CHARGE INTERRUPT | none | none | none | none | CAUGHT and INTERRUPT |
| Chain link, signature | none | none | none | none | link: yes |

**Templates that open a window with nothing to parry:**
- parity: DODGE (both branches, wind at t−0.12 s, every strike no-parry), HEAVY CLASH: COUNTERED and SHOCKWAVE;
- spaced: **HEAVY CLASH: COUNTERED and SHOCKWAVE still do**. `opWind` sets `ex.windowStart` and rolls the AI's press draw, but emits no `window_open` (`melee.gd:139-142`), so the window is silent. A human press there does nothing.

**Ask to Combat:** drop the wind beat from COUNTERED and SHOCKWAVE, as was done for DODGE. A dead window is a hidden rule; a silent one that also costs an AI draw is a bug waiting for a replay diff.

Rule for the sim: `windowStart` and the AI press draw exist only when `window_open` is emitted.

## 3. The parry

### 3.1 Widths

| | Light (TRADE BLOWS, PRESSURE, GUARD BREAK) | Heavy (HEAVY CLASH: WON) |
| :--- | ---: | ---: |
| Tell (visible anticipation) | 15 ticks, 250 ms | 20 ticks, 333 ms |
| Accepted press interval, start to strike | 15 | 20 |
| Pre-press buffer (before the window opens) | 4 | 4 |
| **Effective interval a rhythm player can hit** | **19 ticks, 317 ms** | **24 ticks, 400 ms** |
| **Clean parry** (last N ticks) | 6 (100 ms, today's window) | 8 (133 ms) |
| Accessibility assist | window extended earlier by ×2 (section 7 of `input-map.md`) | same |

Why 15 and not 12: at 250 ms the tell fits a human's visual reaction onset (about 200 to 250 ms) only for the last few ticks. Reactive parrying is hard for a new player and possible for an expert, and anticipation from the approach rhythm makes it fair. At 12 ticks a reaction is out of reach for almost everyone and the parry becomes a memory test.

### 3.2 Skill ceiling: the clean parry
A press in the last 6 ticks (heavy: 8) is a **clean parry**. The width is mine. The reward is Game Design's and Combat's; my proposal: +4 more ki (12 in all), the parry hit-stop at 12 ticks instead of 9, and a distinct cue. This gives the expert something to chase while the 15-tick window keeps the floor fair.

### 3.3 No late coyote time on the parry
A press after the strike tick cannot cancel it: the contact frame is validated against the sim contact tick (`data-fields.md` §9), so delaying resolution to forgive a late press would break the animation contract. The one tick of grace in rule 1.5 stands. Forgiveness on the early side is the 4-tick buffer.

### 3.4 Anti-mash rule (replaces R5's cost trigger; keeps its intent)
R5 charges a whiff "when no parryable strike falls inside the window". Two problems:
- It **leaks the branch**: in HEAVY CLASH a press costs ki only when the WON branch (a parry window) exists. Pressing early becomes a probe.
- It **punishes the wrong reaction**: the approach lasts 24 to 39 ticks, but the tell starts at c−15. A defender who reacts to the rush at tick 12 in a 39-tick approach is a whiff.

Proposed rule, independent of which template was chosen:
- A **stray** is a light or heavy press by the defender during an exchange, earlier than the buffer allows (or while locked out). The first stray is **free** and ignored, and starts a **12-tick (200 ms) lockout**.
- Each press **inside** a lockout is ignored, **costs 5 ki**, and restarts the lockout at 12 ticks.
- A press in the buffer or the window is never a stray.
- After the last parryable strike, presses in that exchange are free and ignored. The mash tax never applies outside the approach and tell.
- Assist on: no ki cost.
- **Worst case for one honest early press:** at c = 24, the tell opens at tick 9. A stray at tick 3 locks out until tick 15, leaving ticks 15 to 24 (9 of the 15) live. The parry is never fully forfeited by a single mistake.

Game Design owns whether R5's 5 ki and 0.5 s stay as written. I am asking for this shape instead and will re-test with QA.

### 3.5 Implementation shape (for when I have the tree)
Replace `f.lastAtkT` with `f.pressTick` (int) and per-exchange window records `{kind, owner, openTick, closeTick, cleanTick}`. The same mechanism serves parry, chain and struggle. The AI uses the same path (its `press` beat writes `pressTick`), so AI and human parries are one code path in replays.

## 4. The chain

| | Value |
| :--- | ---: |
| Window | **36 ticks (600 ms)** from the WIN beat |
| Buffer | **4 ticks** before it opens (a press during the last strike's tail or hit-stop counts) |
| Presses that count | light or heavy edges (never the signature, CC-010); one chain per window |
| Ki cost, cap | 6 ki, 5 hits (data: `chainCap`), unchanged; Anti-hero's Drop the Act raises the cap to 6 |
| Held button | a button already held when the window opens does **not** chain (edges only) |

Accepted as Combat proposed. The prototype's 59% unused windows read as a stall, which is Combat's problem to fill with a follow-up pose; narrowing the window would only make the prompt harder to catch. The chevron prompt (UI) is the readability lever. Assist: buffer ×2 (8 ticks) and a button held into the window counts.

## 5. Hit-stop and shake per impact class

**Finding (verified with a float loop, same doubles as GDScript):** the sim counts hit-stop down in seconds (`sim.gd:73-74`, `dirS.stop -= dtReal`), so `0.05` runs **4** ticks, `0.10` runs **7**, `0.12` runs 8, `0.14` runs 9 and `0.16` runs 10. The float remainder after three subtractions of 1/60 is positive, so it freezes one tick more. Seconds are the wrong unit. The table stores ticks.

**Stage A (representation only):** move to an integer counter with the *effective* ticks below. Goldens stay bit-identical, which QA can prove. **Stage B:** apply the "proposed" column; QA regenerates the goldens; the change is intended.

Stacking stays `max`, not sum (`damage.gd:63`). Shake `k` is on the 0 to 30 scale where 30 is 3.0% of the screen height (Camera's cap); the proposed `k` is "to fit Camera's caps" and is detailed in `shake-pass.md`.

| Impact class | Source (line) | Proto stop (s) | Today, ticks | **Proposed ticks** | ms | Proto shake k | **Proposed k** (to fit Camera's caps) | Reason |
| :--- | :--- | ---: | ---: | ---: | ---: | ---: | ---: | :--- |
| Light strike (default) | `damage.gd:63-64` | 0.05 | 4 | **4** | 67 | 6 | **4** | Combat's floor 0.07 s = 4 ticks. Many per exchange, so a lower shake stops constant tremble |
| Chain link | `exchange.gd:126` | 0.08 | 5 | **5** | 83 | 6 | **6, +1 per link, cap 9** | Escalation mirrors the +12% per link |
| TRADE BLOWS last blow | `melee.gd:101,105` | 0.10 | 7 | **6** | 100 | 6 | **8** | The exchange's punctuation |
| Heavy strike (HEAVY CLASH deciding blow, heavy default) | `melee.gd:114,119` | 0.12 | 8 | **7** | 117 | 12 | **10** | Combat's heavy floor 0.12 s = 7 ticks |
| GUARD BREAK | `melee.gd:86,178` | 0.12 | 8 | **8** | 133 | 12 | **12** | The heaviest melee blow that is not a reward |
| **Parry** (defender's counter) | `melee.gd:214` | 0.12 | 8 | **9** | 150 | 9 | **8** | The success cue must read as the biggest small hit. Clean parry: 12 ticks (proposal) |
| HEAVY CLASH shockwave | `melee.gd:192-199` | 0.10 | 7 | **7** | 117 | 18 | **16** | Shock-apart, not a finishing blow |
| Launch impact (ground) | `fighter.gd:56-57` | 0.06 | 4 | **4** | 67 | min(30, v×0.01) | **unchanged** | Proportional already |
| Launch (`doLaunch`) | `launch.gd:207` | none | 0 | 0 | 0 | 10 | **8** | Frequent, not a hit |
| Explosion | `structures.gd:86-87` | 0.08 | 5 | **5** | 83 | 16 | **14** | Repeats in clusters |
| Structure collapse (h > 200) | `structures.gd:53` | none | 0 | 0 | 0 | 10 | **10** | Distance-falloff by Camera |
| Beam fire | `beam.gd:169` | none | 0 | 0 | 0 | 14 | **10** | The connect is the peak, not the shot |
| Beam connect (HIT, GUARD) | `beam.gd:88` | 0.14 | 9 | **9** | 150 | 16 | **16** | |
| Beam clash resolution | `beam.gd:156` | 0.16 | 10 | **10** | 167 | 18 | **18** | Largest non-finisher freeze |
| Clash held (beam struggle) | `sim.gd:99` | none | 0 | 0 | 0 | 7 per tick | **4 per tick** | Sustained shake tires; 3.4 s of it is too long |
| Tier-up | `fighter.gd:18` | none | 0 | 0 | 0 | 14 | **12** | Self-inflicted and local |
| Finisher strike 1 | `exchange.gd:294` | 0.05 | 4 | **4** | 67 | 6 | **6** | |
| Finisher strike 2 | `exchange.gd:295` | 0.12 | 8 | **7** | 117 | 14 | **10** | |
| **Finisher final blow (`finalBlow`)** | `templates.json` finishers | 0.12 today | 8 | **18** | 300 | 14 | **22** | Combat's 0.30 s floor. The KO frame, then `game.ts` 0.35 slow-mo. Render must keep moving (camera push) or a web build reads as a hang |
| KO slow-mo | `damage.gd:78` (`game.ts` 0.35) | n/a | n/a | see hazard | | | | see 5.1 |

Exchange budget: a five-hit TRADE BLOWS exchange freezes 4+4+4+4+6 = 22 ticks (0.37 s). Target: at most 45 ticks (0.75 s) frozen per exchange; QA reports the median and the maximum. If it goes over, the first lever is the light stop, then the chain stop.

### 5.1 Hazards to fix, not copy
- **Real-dt countdown** (`sim.gd:73-74`): the sim's hit-stop is timed by the real step, not by sim time. Netcode must store it as an integer counter in sim state so a rollback restores it.
- **`game.ts` slow-mo** (`damage.gd:78`, 0.35 after a KO; applied at `sim.gd:70`): scales the sim `dt`, so windows in `S.T` seconds stretch. It is harmless after a KO (no window exists), but a second slow-mo (a cinematic) would silently widen windows. Windows are in ticks and never in `S.T`.
- **Hit-stop drops the input stage today**: `step()` returns before `control()` (`sim.gd:73-76`) and the host keeps edges. In the tick-based plan the input stage runs during a freeze (buffer push, stance apply) and the world does not. That makes the replay log identical to what the sim saw.

## 6. Buffering

Buffers live in **sim state** (integers on the fighter), so replays and rollback carry them. The host only reports edges and holds.

| Action | Buffered? | Length (live ticks) | Notes |
| :--- | :--- | ---: | :--- |
| Light, heavy | yes, one slot, newest wins | **6** (100 ms) | Refused only for a transient reason (below) |
| Signature | yes, same slot | **6** | Only if ki ≥ 45 when pressed or gained within the buffer |
| Stance (direct or cycle) | no | n/a | Always applied on the tick it arrives; it costs nothing |
| Dash, charge, special, transform | no (holds) | n/a | A hold begun while illegal starts counting when it becomes legal |
| Parry | yes, pre-window | **4** | Section 3 |
| Chain | yes, pre-window | **4** | Section 4 |
| Struggle | no | n/a | Beats are timed; the debounce is 4 ticks (section 8) |

**Transient refusals that buffer** (`requestAttack`, `exchange.gd:30-38`): an exchange is running (the press is a parry or chain press first), `dirS.cool` (0.22 s and more), `A.state` not free or charging (recovery), stagger (`stunTicks`). **Refusals that do not buffer** (predictable, so no ghost attacks): ki below 45 for a signature by more than the buffer can recover, lock lost (`D.hidden`), KO. A refused press still shows an acknowledgement (`press_ack`, section 10).

**Priority when several presses share a window:**
1. **Signature beats light or heavy** if pressed within 2 ticks of each other and ki allows it. Today `control()` tests light, then heavy, then sig (`control.gd:20-25`), so a mashed light silently wins over the costly signature.
2. Heavy beats light.
3. Otherwise the newest press wins.
4. Special holds: **transform > special > charge**. If two are held, the one pressed last wins and the earlier resumes on release.

**The initiative race.** Only one exchange runs at a time (`dirS.ex`), so whoever's press lands first attacks. With buffers, both fighters usually have a press queued at the end of the cooldown; the step order is a seeded coin (`sim.gd:82`). That is fair, and QA checks it (risk 6).

**During an opponent's respected cinematic** (spec-wounds §8): movement and dash are ignored, **charge, special and stance stay live** (the waiting fighter may charge or stoke), and attack presses are dropped, not buffered, so nothing fires the tick the cinematic ends.

## 7. Stance switching

R8 stands: **free, instant, no cooldown in the sim.** Feel, not cost, is what I own here:
- **Feedback:** a `stance` event and a same-tick posture flash and plate chip change (target: visible within 2 ticks, 33 ms).
- **Repeat guard (input layer only, not a rule):** a held cycle button repeats every 12 ticks; a cycle press within 4 ticks of the last cycle is ignored, so a fumbled double tap does not skip a stance.
- **Ring order:** PRESS → GUARD → DODGE → ESCAPE → PRESS (proposed names; the sim ids stay AGGRESSIVE, DEFENSIVE, EVASIVE, ESCAPE). Two cycle presses reach any stance.
- **Open exploit, not mine to fix (Game Design or Combat):** the template is fixed when the attack starts, but `hit()` reads the defender's stance at hit time (`damage.gd`, multiplier `[1.12, 0.38, 1.0, 1.25]`). A fast flick to DEFENSIVE after the attack starts still cuts the hit to ×0.38. Recommend freezing the multiplier at exchange start. QA arm in risk 5.

## 8. The finisher struggle

Game Design (spec-wounds §1, Finisher): three timed presses on a visible rhythm; +10 survival per on-beat press, −5 per miss; base survival 15%; accessibility assist doubles the windows.

Combat's finishers open the contest window at `contestOpen` and resolve at `contest`, **48 ticks apart** in all three placeholders (108→156, 141→189, 159→207). Three beats at a readable pace do not fit in 48 ticks.

**Ruling (widths, rhythm, input):**

| Setting | Value |
| :--- | ---: |
| Beat period | **18 ticks (300 ms, 200 per minute)** |
| Beat centres, from `contestOpen` | **tick 18, 36, 54** |
| Count-in markers (shown, not scored) | tick −18 and 0 |
| Contest resolves | **tick 66** (window closes at 65) |
| On-beat half-width, standard | **±4 ticks** (a 9-tick window, 150 ms) |
| On-beat half-width, assist | **±8 ticks** (17 ticks; still under half the period, so beats never overlap) |
| Debounce | a press within 4 ticks of a scored press (hit or stray) is ignored, no penalty |
| Input | **the light or heavy button** (the parry button; either counts) |

**Consequence for Combat:** lengthen the contest window from 48 to **66 ticks (0.8 s to 1.1 s)** in all finishers, and let the existing `final_windup` cue (about 21 ticks before `contestOpen`) serve as the count-in. That is inside the 3 to 8 s finisher budget.

**Scoring (one integer sum, then the existing single draw):**
- `chance = max(0, 15 + 10 × hits − 5 × (missed beats + stray presses) − tilts)`, in percent. `tilts` are the existing −10 per Rally used and −10 per minute past 8:00.
- A press matches the nearest unclaimed beat within the half-width; otherwise it is a stray (−5). Strays are uncapped (mashing loses: chance floors at 0).
- Perfect: 15 + 30 = 45%. No presses: 15 − 15 = 0%. Mash of 12 presses: 0%.
- The contest still draws **once** (`S.rng.next()`), so the RNG sequence does not change with the number of presses.
- **AI accuracy** for the QA band (average survival 20 to 35%): if the AI hits each beat with probability p and never strays, the mean survival is 45p, so p between 0.44 and 0.78 fits the band. Default 0.60 (mean 27%); Encounter maps difficulty to p.
- **Determinism:** presses are stamped by tick relative to `contestOpen`, so the result is a pure function of the input log.

**How UI shows the beat (timing spec; the look is UI's and VFX's):**
- A ring around the fighter on the brink, closing on a fixed target ring, one per beat, arriving exactly on the beat tick. The three rings are drawn in sequence, with the count-in rings at −18 and 0 so the tempo is visible before the first scored beat.
- Every beat also has an **audio tick** and, on gamepad, a **short rumble**. Neither may carry information the ring does not.
- On press: hit, early or miss are distinct in **shape**, not only colour (`press_ack` result).
- No survival percentage on screen (`finisher_contest` is ignored by design).
- Reduced motion keeps the shape change and stops the ring's easing.

**Latency offset (optional, accessibility):** a per-player timing offset of −6 to +6 ticks shifts that player's struggle window centres. It is recorded in the match header, so replays stay identical.

## 9. Mechanics table (movement and gating) with proposals

| Mechanic | Prototype value | Source | Ticks | Proposed | Reason |
| :--- | :--- | :--- | ---: | :--- | :--- |
| Dash | ×2.4 speed while the dash input is **held** | `fighter.gd:227-228` | n/a | keep; toggle-hold is an input option | |
| Stance speed | EVASIVE ×1.25, ESCAPE ×1.35, DEFENSIVE ×0.8 | `fighter.gd:220-226` | n/a | keep | |
| Diagonals | `mx` and `my` are independent axes, so a keyboard diagonal is √2 faster | `fighter.gd:214-237` | n/a | **Normalise in the sim, Stage B** (Game Design ruled); the gamepad uses a square gate until then (`input-map.md` §3.1) | parity |
| Charge | +30 ki/s, +9 power/s; the state is exposed | `fighter.gd:254-255` | n/a | keep | |
| Attack gating | no exchange running, `dirS.cool` ≥ 0 blocks | `exchange.gd:31` | | buffer 6 ticks | responsiveness |
| Heavy cost | 4 ki; below 4 ki it falls back to light | `exchange.gd:42-43,65-66` | | keep; show the fallback | |
| Signature cost | 45 ki; else a "NEED 45 KI" banner (humans only) | `exchange.gd:38-41,67-68` | | keep; the word is CHARGE in the HUD (glossary) | |
| Lock lost | 2 ki and 0.5 s cool | `exchange.gd:44-50` | 30 | keep | |
| Director cooldown | 0.22 s after an exchange (`cooldownAfter`) | `exchange.gd:214` | 13 | Combat and Encounter own; buffered | |
| Stance switch | free, instant | `control.gd:16-17` | 0 | keep (R8) | |

## 10. Latency budget

Measured from the physical input to the first visible reaction, on the target surface.

| Stage | Budget |
| :--- | ---: |
| Device to the engine (wired pad or keyboard; Bluetooth adds up to 15 ms) | outside our control |
| Host reads edges at the start of the tick | **≤ 1 tick (16.7 ms), no extra queue** |
| Sim reaction in the same tick (velocity, stance, attack request, rush start) | **0 ticks** |
| Render of that tick | ≤ 1 frame |
| **Press to first visible reaction, excluding display and OS** | **≤ 3 ticks (50 ms)** |
| **Button contact to photon, high-speed camera:** desktop / web / mobile touch | **≤ 100 / ≤ 133 / ≤ 150 ms** |

- **First visible reaction, per action:** movement (velocity begins, 3 ticks); stance (chip and posture flash, **2** ticks); attack (the rush begins on the request tick, 3); **any press, including a stray or a locked press, a `press_ack` mark within 2 ticks**, so the player always sees that the game heard them.
- Hit-stop is not latency: it is a deliberate freeze, and presses in it are kept.
- QA harness: timestamp the event, the tick that consumed it and the frame that drew it. Report p50, p95 and max over 1,000 presses per platform.

## 11. Draft data (`data/input/feel.json`, to be created when the tree is handed over)

```json
{
  "schema": "input.feel/1",
  "ticksPerSecond": 60,
  "parry": { "lightTell": 15, "heavyTell": 20, "buffer": 4, "cleanLight": 6, "cleanHeavy": 8,
             "strayLockout": 12, "strayCostKi": 5, "assistFactor": 2 },
  "chain": { "window": 36, "buffer": 4, "cap": 5, "kiCost": 6, "assistBuffer": 8 },
  "attackBuffer": 6,
  "sigOverLightTicks": 2,
  "stance": { "cycleRepeat": 12, "cycleDebounce": 4 },
  "hitstopTicks": { "light": 4, "chain": 5, "tradeFinal": 6, "heavy": 7, "guardBreak": 8, "parry": 9,
                    "parryClean": 12, "clashWave": 7, "impact": 4, "explosion": 5, "beamConnect": 9,
                    "beamClash": 10, "finisherHit1": 4, "finisherHit2": 7, "finalBlow": 18 },
  "struggle": { "period": 18, "beats": [18, 36, 54], "countIn": [-18, 0], "resolveAt": 66,
                "halfWidth": 4, "halfWidthAssist": 8, "debounce": 4,
                "base": 15, "perHit": 10, "perMiss": -5, "aiHitChance": 0.60 },
  "hold": { "confirmTicks": 30, "stickDeadzone": 0.2, "stickQuant": 16, "triggerOn": 0.35, "triggerOff": 0.25 }
}
```

## 12. Risks and tests (ranked)

| # | Risk | Mitigation | Test that confirms it |
| :-: | :--- | :--- | :--- |
| 1 | **Mash-parry through `lastAtkT`**: any light or heavy press stamps it, so pressing every few ticks parries every window at no cost | Press ticks, the stray and lockout rule (§3.4) | Scripted masher (a press every 4 ticks) over 1,000 seeded matches: parry rate at most the AI's about 41%, net ki negative. A rhythm bot (press in the last 6 ticks) must beat the masher |
| 2 | **A 15-tick tell is a wall for a new player** (reaction alone cannot make it) | Effective interval 19 ticks, the visible ring, the approach as a metronome, assist ×2, training mode | New-player sessions: parry success 15% or more in match 1, 30% or more by match 3; at most 1 in 3 players say "unfair" |
| 3 | **Windows with nothing to parry** (HEAVY CLASH: COUNTERED and SHOCKWAVE; DODGE in parity) | No wind beat where no parryable strike follows; `windowStart` only with `window_open` | Static check plus a run: every `window_open{parry}` is followed by a parryable strike in the same exchange; the count of dead windows is 0 |
| 4 | **Unreadable chain cue**: 59% of windows go unused | 36 ticks with a 4-tick buffer, chevron prompt, phrases fill the hold | After 3 matches, at least 50% of the human's chain windows are taken or consciously declined (a think-aloud check) |
| 5 | **Free, instant stance switching** and the hit-time stance multiplier | R8 stays; ask to freeze the multiplier at exchange start | Forced-flick AI arm (flip to DEFENSIVE at the wind beat): win rate at most 55%, and no template beats the flick by a margin over the baseline |
| 6 | **The initiative race**: one exchange at a time, and both fighters have a buffered press | Buffer, seeded coin on the step order | Mirror match with scripted identical inputs: first-attacker split 50% ± 3% over 2,000 seeds |
| 7 | **The finisher struggle is a mash trap or unreadable** | Beats at 200 per minute, ±4 (assist ±8), uncapped strays, count-in, audio and rumble | Human sessions: perfect struggle reachable by at least 60% of players in 3 tries; a masher gets at most 5% survival; AI mean survival 20 to 35% |
| 8 | **Hit-stop reads as a hang** (18-tick final blow, chained stops, the web build) | Render keeps moving (camera push); exchange budget 45 ticks | Frame-time log across a final blow on web; freeze totals per exchange at p95 ≤ 45 ticks |
| 9 | **The float countdown** (0.05 s runs 4 ticks) hides intent | Integer ticks, Stage A proves parity first | Golden hashes unchanged after Stage A |
| 10 | **Keyboard vs pad diagonals** (√2 on keyboard) | Pad square gate now; flag to Simulation | Same route, same time on both devices within 2% |

## 13. Needs (also in the report)
- **Combat:** drop the wind beat in HEAVY CLASH COUNTERED and SHOCKWAVE; lengthen the finisher contest window to 66 ticks with beats at 18, 36, 54; accept clean-parry numbers; freeze the stance multiplier at exchange start (with Game Design).
- **Encounter Systems / Simulation:** `SimIntent` gains `special`, `transform` (held) and `stanceStep` (−1, 0, +1); the sim counts hold ticks; presses stamped as ticks; hit-stop as an integer counter; the input stage runs during a freeze; `window_open` gains `dur_ticks` and `clean_ticks`; new events `press_ack` and `struggle_open` (below).
- **UI/UX and VFX:** the struggle ring timing (§8); the `press_ack` marks; the parry and chain prompts carry the glyphs of `prompt-glyphs.md`.
- **Camera:** shake table in `shake-pass.md`.
- **Netcode:** hit-stop and buffers as integer sim state; the struggle offset in the match header.
- **Accessibility:** assist numbers above (parry ×2 earlier, chain buffer 8, struggle ±8, no whiff cost).

## 14. Status after the EP's rulings (commit 281b3eb, 2026-09-29)

- **Accepted:** light parry 15, heavy 20, chain 36 plus a 4-tick buffer, clean-parry tails, the hit-stop table and its two stages.
- **Accepted pending Game Design:** the R5 amendment (section 3.4).
- **Order of work:** Stage A (integer hit-stop, press ticks, `SimIntent` `special`, `transform`, `stanceStep`; goldens bit-identical, with QA's proof) comes after S3b, S4 and World's collateral window. Stage B follows. I may edit the hit-stop counter in `sim.gd` and `damage.gd` for those slices only.
- **Stage B also includes:** holding the shake decay through freezes, with Camera's agreement.
- **Orb-level defaults (Orb can overturn):** a dedicated second keyboard layout for hot-seat, as an option, with the current layout the default; a `hitstopScale` accessibility option, 0.5 to 1.0, default 1.0, recorded in the match header; mobile cross-play policy deferred to the online phase.

## 15. Game Design's answers (2026-09-29)

- **R5 amendment confirmed** (section 3.4).
- **No Rally button.** Rallies fire automatically. The Empress's Encore is a contextual prompt: `transform`, offered for 180 ticks after she enters the brink, hold 18 ticks to confirm (`input-map.md` §4).
- **Press is a hold**: the charge input held near people. No `special` slot is needed for the Cyborg.
- **Diagonal movement is normalised in the sim.** It changes the goldens, so it is in **Stage B**. Stage A stays bit-identical.
- **Camera confirmed the shake pass:** far pane 35%, falloff `clamp(1 - d/4000, 0.35, 1)`, and holding the decay through freezes.

## 16. Game Design's R5 ruling: where the lockout lives (2026-09-29)

- The parry anti-mash rule (first stray free, 12-tick lockout, 5 ki per press inside a lockout; section 3.4) lives in the **input layer** in `sim/input/`, next to the press ticks. Encounter's `strike()` only consumes a **validated** press; it never sees a stray.
- **Stage A** (bit-identical) carries the press ticks only: `f.pressTick` replaces `lastAtkT` with the same parry behaviour as today. **Stage B** adds the lockout and the ki tax, together with diagonal normalisation, the hit-stop values and the shake decay hold, because each changes behaviour or the goldens.
