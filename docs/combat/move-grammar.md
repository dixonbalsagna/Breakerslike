# Move grammar

Owner: Combat and Choreography. Status: P0 wave 1, a description of the prototype as it is, with its defects recorded and not fixed. This is the canonical source for atom names and timings (EP ruling, 2026-09-28). The Godot port in `sim/` is bit-identical to the prototype's deterministic core, so these atoms describe both. The procedural move system (`procedural-moves.md`) turns them into its first parts. Companion documents: `exchange-templates.md` (how atoms are sequenced into exchanges), `signature-variants.md` (the signature beam and its variants), `data-fields.md` (the field list for the Tools schemas).

**Source.** Every reference `index.html:NNN` is a line of `prototype/index.html` at commit `7233c96`. Numbers are copied from the code; nothing in this document changes it. The prototype stays behaviour-identical until the port proves parity.

**Names from M0.** The canonical vocabulary moves to entry, key strike, a role flag for counters, launch vector, follow-up, situation layers and signature layers; the mapping is in `moveset-system.md` section 7.1. This document keeps the prototype's op names, because it describes the prototype.

**Units.** Distances in world units (u); the planet is 9,600 u around (`index.html:115`). Time in simulation seconds (s) at a fixed step of 1/60 s (`index.html:112`), so one frame is 0.0167 s. Speeds in u/s. "Tier" is the power tier, 1 to 4. A value written `a + b·tier` scales with the attacker's tier unless stated otherwise.

**Roles.** A is the attacker (the fighter who requested the exchange), D the defender. `rt` is the rush time of a melee exchange, `rt = clamp(dist/2600, 0.18, 0.65)` where `dist` is the shortest-arc distance between them at the request (`index.html:420`).

---

## 1. How an exchange runs

An exchange is a short, authored scene. The player (or the AI) supplies intent: an attack kind (light, heavy or signature) and, separately, a stance. The director turns that into a timed list of atoms.

1. **Request** (`requestAttack`, `index.html:390-416`). Refused if an exchange is already running, if the director cooldown is active, if the match is over, if the attacker is not `free` or `charging`, or if the defender is `launched`, `locked` or dead (`index.html:391-394`). A signature needs 45 ki (`index.html:395`); a heavy with less than 4 ki becomes a light (`index.html:396`). Attacking a hidden defender costs 2 ki, starts a 0.5 s cooldown and does nothing else (lock lost, `index.html:397-401`). Ki is paid up front: heavy 4, signature 45 (`index.html:405-406`).
2. **Face and lock.** Both fighters turn to face each other and both become `locked` (`index.html:408-411`). The defender's state before the lock is kept in `D.dPrev`; `charging` there is what makes the director treat the defender as CHARGING.
3. **Plan.** `planMelee` (`index.html:418-508`) or `planBeam` (`index.html:581-622`) picks the template from the defender's state and the attack kind, rolls every random branch immediately, and schedules beats on the exchange clock `ex.t`. The feed line `<A> <KIND> vs <DEFENDER STATE>` with the template tag is written at once (`index.html:414-415`).
4. **Beats** fire in time order as `ex.t` advances (`dirUpdate`, `index.html:567-578`). A beat is a closure run once when `ex.t` reaches its time, so beat times resolve to the next frame boundary.
5. **Windows.** A beat may open a chain window that keeps the exchange alive after its last beat (`index.html:572-577`).
6. **End** (`endEx`, `index.html:558-566`) when no beat is pending and no window is open. Locked fighters are freed, the attacker's rush, beam charge and ambush flag are cleared, and the director cooldown is set to 0.22 s (`index.html:565`).

What "locked" means: no input movement; velocity decays by a factor of 0.03 per second (`index.html:792`); the fighter is drawn in the extended-arm "punch" pose, and so is the defender (`index.html:1004`). Both fighters look identical for the whole exchange unless an atom moves them.

**Initiative.** Each frame both fighters' inputs are read in a random order (`index.html:886-887`). When both press attack on the same frame, a coin flip decides who becomes the attacker. The flip is a draw from the simulation RNG.

**Input precedence.** Light, then heavy, then signature (`index.html:854`). Only light and heavy set `lastAtkT`, the time stamp that parry and chain read (`index.html:853`); pressing signature can never parry or chain.

---

## 2. Atom catalogue

Each entry gives what the atom does, its timing, its warp target (where it moves a fighter), its hit data, the windows it opens, and its cancel rules, with the constants that set them. "Defect" marks behaviour recorded for the port and not fixed here; the numbered defects are collected in section 5.

### 2.1 Approach

#### `rush` (gap close)
The attacker flies to a point beside the defender and arrives exactly on time, whatever the distance. This is the atom that makes pillar 3 true: no melee exchange can miss for range.
- **Timing.** Starts at `ex.t = 0` (it fires on the first director update after the request). Lasts `rt = clamp(dist/2600, 0.18, 0.65)` s (`index.html:420, 423`). Any distance under 468 u takes 0.18 s; any distance over 1,690 u takes 0.65 s. Implied speed is `dist/rt`: 2,600 u/s in the middle band, up to about 7,400 u/s across half the planet.
- **Warp target.** `D.x - A.face·58` (58 u short of the defender, on the attacker's side) at `D.y` (`index.html:422-423`). The target is tracked live: every frame the rush re-reads the defender's current position (`index.html:747`).
- **Motion.** Each frame the fighter covers `dt/remaining` of the remaining shortest-arc offset in x and of the height difference in y (`index.html:749-751`), so the approach decelerates into contact. Afterimages (0.16 s) mark the path (`index.html:750`). On the last frame the fighter snaps to the target and is clamped to the ground (`index.html:748`).
- **Cancel.** Cleared by `endEx` (`index.html:561`) and when its owner is launched (`index.html:379`). A rush cannot be interrupted by the defender.
- **Variants.**
  | Variant | Used by | Offset | Duration | Citation |
  | :--- | :--- | ---: | ---: | :--- |
  | `rush` | every melee template except the slip-away | 58 u | rt | `index.html:423` |
  | `rush.far` | PURSUIT — TARGET SLIPS AWAY | 260 u | 0.8·rt | `index.html:444` |
  | `rush.chain` | each chain link | 60 u | 0.24 s | `index.html:553` |
  | `rush.rise` | signature charge | to a fixed point (A.x, min(2400, D.y + rise)) | 0.55 s | `index.html:595` |
- **Defect CC-006.** The path ignores terrain until the final frame: a rush flies straight through mountains and buildings (`index.html:751` has no ground test).

### 2.2 Offence

#### `windup` (opens the parry window)
An invisible beat that marks the start of the defender's parry window.
- **Timing.** Scheduled shortly before contact: `rt - 0.1` in TRADE BLOWS, PRESSURE and GUARD BREAK (`index.html:497, 477, 483`), `rt - 0.12` in the DODGE templates (`index.html:461`), `rt - 0.05` in HEAVY CLASH (`index.html:503`).
- **Effect.** Stamps `ex.windowStart = T` (`index.html:425`). If the defender is AI, it decides now whether to press attack: 50% when DEFENSIVE, 30% when AGGRESSIVE, 12% otherwise, pressing 0.05 to 0.16 s later (`index.html:426`).
- **Presentation.** None. Nothing is drawn, played or shaken when the window opens (defect CC-011).

#### `strike`
One blow, resolved instantly on its beat.
- **Parameters** (`index.html:521-536`): damage, knockback `kb` (default 220 u/s, 120 in PRESSURE, 150 in GUARD BREAK), `noParry`, `ignoreStance`, hitstop `stop` (default 0.05 s), camera `shake` (default 6), `big` (a larger spark burst: 18 sparks instead of 9, `index.html:332`).
- **Facing.** The striker turns to the target first (`index.html:524`).
- **Parry check.** Only a strike by the attacker, without `noParry`, after a window has opened, can be parried (`index.html:525`). See `parry`.
- **Catch.** Striking a `launched` or `down` target re-locks it and keeps 10% of its velocity (`index.html:533`). This is how chain links catch a body in flight.
- **Knockback.** Adds `face·kb` to the target's horizontal velocity (`index.html:535`). The target is locked, so the push dies away at the locked decay rate.
- **Cancel.** Skipped if the exchange was cancelled (parried), the match is over, or either fighter is at 0 hp (`index.html:523`).

**Damage model** (`hit`, `index.html:319-338`). Every strike, counter, clash and beam connection goes through it:
- Attacker multiplier `m = dmgMul · (1 + 0.09·(tier - 1))` (`index.html:321`).
- Villain: `· (1 + 0.25·menace/100)`, up to +25%. Hero: `· (1 + 0.5·(1 - hp/maxhp)²)`, a comeback bonus up to +50% (`index.html:322`).
- Chain scaling `· (1 + 0.12·(combo - 1))` (`index.html:323`); ambush `· 1.5` (`index.html:324`).
- Stance multiplier on the target, unless `ignoreStance`: AGGRESSIVE 1.12, DEFENSIVE 0.38, EVASIVE 1.0, ESCAPE 1.25 (`index.html:326`). The CHARGING value 1.35 in the same line can never apply (defect CC-003).
- Side effects: a DEFENSIVE target loses ki equal to 8% of the damage (only when stance applies, `index.html:329`); the striker gains ki equal to 4% of the damage (`index.html:330`); the target gains power equal to 1% of the damage and the striker 0.6% (`index.html:331`); hitstop is raised to `stop` (`index.html:334`); the camera shakes (`index.html:335`).

The stance multiplier applies to whoever is struck. When the defender strikes back without `ignoreStance`, the **attacker's own stance** sets the damage the attacker takes. This is one of only two ways the attacker's stance affects an exchange (the other is the DODGE & READ chance, `index.html:458`).

### 2.3 Defence

#### `guard` (the DEFENSIVE stance)
There is no block animation or block atom: guarding is the DEFENSIVE stance's damage multiplier of 0.38 (`index.html:326`), paid for with ki (8% of the damage taken, `index.html:329`) and with 0.8 movement speed (`index.html:771`). Because every attack closes the gap for free (`rush`), the speed penalty costs a DEFENSIVE fighter almost nothing in an exchange (Game Design's finding, `docs/design/stance-matrix.md` section 4; the fix is `exchange-templates.md` section 5.1).

#### `guard.drain` (guard break)
- **Timing.** `rt + 0.4` in GUARD BREAK (`index.html:485`).
- **Effect.** Removes 25 ki from the defender, shows the GUARD BREAK banner, shakes the camera at 12. Skipped if the exchange was parried.
- The strike that follows at `rt + 0.42` ignores stance (`index.html:486`): that strike, not the drain, is what actually breaks the guard.

#### `parry` (strike cancel)
- **Input.** The defender presses light or heavy at any moment from the window's opening to the first parryable strike (`index.html:525`; `lastAtkT` is set by light or heavy only, `index.html:853`).
- **Effect** (`index.html:526-531`). Cancels the rest of the exchange (`ex.cancel = true`); the defender hits the attacker for 18 (stance ignored, hitstop 0.12, shake 9); the attacker is pushed back at 520 u/s; the defender gains 8 ki; PARRY banner and feed line.
- **Width.** The window is the time from `windup` to the first parryable strike: 0.10 s in TRADE BLOWS, PRESSURE and GUARD BREAK, 0.33 s in HEAVY CLASH — WON. No other template can be parried (table in section 4).
- **No whiff cost.** Pressing early, late or repeatedly costs nothing, so mashing parries every parryable strike (defect CC-008).
- **Cancel reach.** A parry stops later strikes, launches and the guard drain. It does not stop chain windows or rushes (defect CC-001).

#### `dodge.warp` (EVASIVE melee dodge)
- **Timing.** At `rt`, the moment the rush arrives (`index.html:462`).
- **Warp target.** The defender teleports to `A.x - A.face·74`, which is 74 u behind the attacker (a cross-up), at height `max(ground, A.y + R(-30, 70))`, with velocity zeroed. An afterimage is left at the old position and a ring at the new one. One RNG draw (the height offset).
- The defender stays `locked`: the dodge is a repositioning, not an escape. What happens next is the READ or COUNTER branch already rolled at plan time (`index.html:458-459`).

#### `slip` (ESCAPE melee escape)
- **Timing.** At `0.55·rt` (`index.html:445`), before the rush can arrive.
- **Effect** (`index.html:446-447`). The defender becomes `free` and bursts away from the attacker at `1500 + 200·D.tier` u/s horizontally with a vertical `R(-150, 300)` u/s; afterimage; SLIPPED AWAY banner; the attacker loses 3 ki.
- The attacker, meanwhile, is on `rush.far`: it keeps chasing the escaping defender until `0.8·rt`, then stands locked until the exchange ends at `rt + 0.5` (`index.html:444, 449`).

#### `counter` (the defender strikes back)
The same `strike` atom with the defender as striker. Four uses:
| Template | Time | Damage | Stance on the attacker | Follow-up | Citation |
| :--- | ---: | ---: | :--- | :--- | :--- |
| DODGE & COUNTER | rt + 0.24 | base·0.9 (23.4 light, 59.4 heavy) | applies | launch 900 at rt + 0.3 | `index.html:468-469` |
| PRESSURE → COUNTER | rt + 0.55 | 24 | ignored | none | `index.html:479` |
| TRADE BLOWS, defender wins | rt + 0.72 | 32 | applies | launch 1000 at rt + 0.76 | `index.html:500` |
| HEAVY CLASH — COUNTERED | rt + 0.28 | 66 | ignored | launch 1600 at rt + 0.32 | `index.html:505` |

The two exchange blows the defender lands in every TRADE BLOWS (20 each at rt + 0.17 and rt + 0.51, `index.html:498`) are counters too.

### 2.4 Launch and aftermath

#### `launch`
Sends the target flying and hands the fight a new place to happen.
- **Choice.** `launchBeat` asks the launch planner `chooseLaunch` for a direction (`index.html:537-543`, `359-376`). The planner and its scores belong to Encounter Systems; this grammar only defines the five candidate launches:
  | Launch | Direction (ux, uy) | Offered when | Citation |
  | :--- | :--- | :--- | :--- |
  | UPPERCUT | (0.25·face, 1.0) | always | `index.html:361` |
  | SLAM DOWN | (0.2·face, -1.25) | always | `index.html:362` |
  | SMASH ACROSS | (face, 0.18) | always | `index.html:363` |
  | BUILDING SMASH | (±1, 0.12) toward a standing building 60 to 1,100 u away | a building is in range | `index.html:365-366` |
  | MOUNTAINSIDE | (±1, 0.05) toward mountains 520 u away | mountains are there | `index.html:367` |
- **Force.** `force·(1 + 0.16·(tier - 1))` of the launcher (`index.html:378`); per-template forces are in `exchange-templates.md`. Velocity is direction times force (`index.html:381`).
- **Effect** (`index.html:379-383`). The target becomes `launched`, loses any rush and is revealed if hidden; it spins at `R(8, 16)` rad/s (one RNG draw); a ring and a camera shake of 10.
- **Cancel.** Skipped if the exchange was parried, the match is over or the target is dead (`index.html:538`).

#### `flight` (a launched body)
- Gravity 1,000 u/s², horizontal drag to 55% per second (`index.html:720`); a ceiling at 2,600 u (`index.html:743`).
- **`water-catch`.** Entering the sea splashes and applies heavy drag (horizontal to 5% per second, vertical to 10% per second). Once slower than 200 u/s and airborne for over 0.3 s, the fighter is simply freed: no impact, no crater (`index.html:723-726`). Most launches over the ocean end this way.
- **`wall-hit`.** Passing through a standing building damages it by `speed·(0.55 + 0.25·tier)` of the launcher and the body by `speed·0.006`; the body slows to 60% horizontally and 85% vertically, and if the building survives it rebounds at a quarter of its speed and is placed outside the wall (`index.html:727-740`).

#### `impact`, `bounce`, `down`, `recover`
- **`impact`** when the body reaches the ground (`index.html:742`, `704-718`). Above 350 u/s: a crater of radius `28 + 0.05·speed + 12·tier` and depth `min(90, 0.02·speed + 3.5·tier)`, area damage of radius 1.7 times the crater at `speed·(0.22 + 0.12·tier)`, a splash or debris, shake up to 30, hitstop 0.06 s, and self-damage of `speed·0.018` (`index.html:706-713`). Tier is the launcher's.
- **`bounce`.** Above 700 u/s, up to two bounces: vertical speed reflected at 30%, horizontal kept at 75% (`index.html:716`).
- **`down`** otherwise: the fighter lies still for 0.75 s (`index.html:717, 788`), then **`recover`**s to `free` (`index.html:788`). Nothing authors the get-up; it is a state flip.

#### `ko-launch`
On a KO (`index.html:339-347`) the running exchange ends, time slows to 0.35 for 2.2 s of match time (`index.html:341, 885`), and the loser is launched from the winner at a fixed direction (0.9·face, 0.5) with force 1,800 (planner not used).

### 2.5 Chain

#### `chain-window`
- **Opens** on a WIN beat (`openWindow`, `index.html:544-547`) and lasts 0.6 s (`index.html:545`).
- **Input.** The attacker presses light or heavy after the window opened (`index.html:574`, with `lastAtkT` from `index.html:853`). Conditions: fewer than 5 linked hits so far, at least 6 ki, both fighters alive (`index.html:574`).
- **AI.** The AI attacker presses with probability `clamp(0.62 - 0.14·combo, 0.05, 0.6)`, 0.12 to 0.35 s after the window opens (`index.html:546`).
- **Hold.** While the window is open the exchange cannot end and a new exchange cannot start (`index.html:577, 391`). The attacker stays locked the whole time.
- **Presentation.** None while open. After a successful chain the banner reads "N HIT CHAIN" (`index.html:552`) and the HUD shows "N CHAIN" (`index.html:1123`).

#### `chain-link`
One press adds a scripted link (`chain`, `index.html:548-557`), timed from the press `tc`:
- `tc`: `rush.chain` to 60 u from the target in 0.24 s, tracking it in flight (`index.html:553`);
- `tc + 0.26`: strike for `52 + 7·combo` (66, 73, 80, 87 for links 2 to 5), stance ignored, not parryable, hitstop 0.08 (`index.html:554`);
- `tc + 0.3`: launch at force 1,500 (`index.html:555`);
- `tc + 0.55`: a new chain window (`index.html:556`).
- Cost 6 ki, paid at the press (`index.html:550`). The combo counter raises the damage of every later hit by 12% per link (`index.html:323`).

### 2.6 Clash

#### `clash.shockwave` (heavy against heavy, even)
At `rt + 0.28` in CLASH SHOCKWAVE (`index.html:506`, `510-519`):
- Both fighters are pushed apart at 900 u/s.
- Each takes 18 damage, stance ignored. The attacker's hit to the defender uses hitstop 0.1, the defender's reply 0.02.
- At the midpoint between them: a crater of radius `60 + 16·tier` and depth `10 + 4·tier` if within 200 u of the ground, and area damage of radius `160 + 40·tier` at `110 + 80·tier`. Tier is the higher of the two.
- CLASH banner and a shake of 18.

#### `clash.beam` (signature against an AGGRESSIVE defender with ki)
See `signature-variants.md` for context. The mechanics (`index.html:603, 623-641`):
- The defender pays 40 ki.
- Each side scores `10·tier + 0.35·ki + R(0, 16)`, plus `0.08·menace` for a villain (`index.html:625`); the higher score wins.
- For 1.6 s both beams are drawn meeting at a point that starts halfway between the fighters and drifts toward the loser until it is 85% of the way there (`index.html:627`, drawn at `index.html:1072-1078`). The outcome is already decided when the struggle starts; nothing either player does during it changes the winner.
- The winner then fires a full beam at the loser: 260 damage, stance ignored, an explosion of radius `70 + 32·tier`, and a launch at 2,600 along the beam (`index.html:629-638`).
- The exchange holds until 2.6 s after the clash started (`index.html:640`).

### 2.7 Signature beam

#### `beam.charge` (charge and rise)
At `ex.t = 0` (`index.html:593-597`):
- The attacker shows its aura orb and its signature's name as a banner.
- It moves straight up or down on `rush.rise` to `min(2400, D.y + rise)`, with `rise = clamp(0.22·dist, 90, 300)` (`index.html:592, 595`), over 0.55 s: it ends above the defender, descending if it started higher.
- It then holds until 0.8 s.
- The orb grows over 0.8 s (`index.html:1013-1017`).

#### `beam.fire`
At `ex.t = 0.8` (`index.html:598-606`):
- The beam leaves `(A.x, A.y + 38)` aimed at `(D.x, D.y + 36)`, so it angles down at the defender (unless the 2,400 u cap on the rise left the attacker below it) and carries on past it into the ground or the sky.
- Length `min(4200, dist + 2000 + 400·tier)` (`index.html:601`); width `24 + 9·tier`; life 0.95 s (`index.html:643`).
- The beam front sweeps its whole length in 0.22 s (`index.html:660`).

#### `beam.carve`
Every 36 u along the swept length (`index.html:661`, `646-656`):
- Where the beam is within `40 + 12·tier` of the ground, it craters (radius `20 + 7·tier`, depth `5 + 2.2·tier`, or `9 + 2.2·tier` for RIDGE BORE) and raises dust.
- Everywhere along the path it damages structures in radius `26 + 8·tier` at `110 + 75·tier`.
- Over the sea, below y = 30, it splashes; this is a random draw from the simulation RNG (`index.html:654`, QA-002).
- The variant's extras (glass sparks, fire) apply along the whole path, not only in the variant's biome (defect CC-012).

#### `beam.connect` (HIT or GUARD)
At `0.8 + reach`, where `reach = min(0.2, 0.22·dist/len)` is when the beam front reaches the defender (`index.html:606-614`):
- The defender is briefly freed then struck:
  - HIT: 230 damage, stance ignored.
  - GUARD: 200 damage with the stance multiplier applied. GUARD only happens against DEFENSIVE, so that is 76 before the attacker's multipliers.
  - Either way: hitstop 0.14, shake 16.
- An `explode` of radius `60 + 30·tier` follows.
- Unless KO'd, the defender is launched along the beam direction, lifted by 0.12: force 2,600 for HIT, 1,300 for GUARD (`index.html:613`).

#### `beam.dodge`
At `0.8 + 0.02` (`index.html:616`):
- The defender leaves an afterimage and teleports 300 u straight up with zero velocity (DODGED banner).
- It stays `locked`, hanging still, until the exchange ends at 1.7 s (defect CC-005). No counter follows.

#### `beam.escape`
At `0.8 + 0.02` (`index.html:618`):
- The defender is freed and bursts away from the attacker at 1,600 u/s horizontally, with `R(-100, 300)` u/s vertically (ESCAPED banner).
- The attacker stays locked until 1.7 s.

#### `explode`
Used by beam connections and the clash resolution (`index.html:304-310`):
- Area damage of radius 1.8·r at `130 + 110·tier`.
- A crater of radius 0.9·r and depth `18 + 8·tier` if within r of the ground.
- A shake of 16 and hitstop 0.08.

### 2.8 Holds and time

| Atom | What it is | Values | Citation |
| :--- | :--- | :--- | :--- |
| `hold` | An empty beat that keeps the exchange (and both locks) alive | melee tails at rt + 0.5, 0.6, 0.7, 0.8 or 1.0; beam tail at fire + 0.9; clash tail at clash + 2.6 | `index.html:431, 620, 640` |
| `hitstop` | Freezes the whole simulation, the exchange clock included, while particles crawl at 10% speed | 0.05 s per hit by default; 0.06 impact, 0.08 explosion and chain link, 0.1 last trade blow and clash wave, 0.12 parry, heavy clash and guard break, 0.14 beam connect, 0.16 clash resolution | `index.html:334, 883` |
| `cooldown` | No new exchange may start | 0.6 s at match start, 0.22 s after every exchange, 0.5 s after a lock loss | `index.html:216, 565, 398` |
| `slow-motion` | Match time runs at 0.35 after a KO for 2.2 s of match time | 0.35, 2.2 s | `index.html:341, 885` |

Hitstop stacks by maximum, not by sum (`Math.max`, `index.html:334`), and it lengthens every exchange in real time without appearing in the beat times.

### 2.9 State atoms that exchanges read

| Atom | What it does | Constants | Citation |
| :--- | :--- | :--- | :--- |
| `charge` | Holding charge: velocity damped by 15% per frame, +30 ki/s, +9 power/s. Being attacked while charging selects CHARGE INTERRUPT | 0.85 per frame (frame-rate dependent), 30, 9 | `index.html:768, 780-786` |
| `tier-up` | Power thresholds 25, 50, 75 raise the tier. Within 140 u of the ground it craters (radius `60 + 28·tier`, depth `12 + 7·tier`) and damages the area | 25/50/75, 140 | `index.html:692-703, 756` |
| `hide` | ESCAPE stance, in cover, over 170 u from the opponent, slow and not dashing or charging, for 0.9 s. Hidden fighters regenerate 25 extra ki/s and 40 hp/s and cannot be targeted | 170, 260, 0.9 s | `index.html:668-690, 758, 762` |
| `ambush` | After 1.8 s or more hidden, an attack made straight from hiding, or within 2.5 s of breaking cover, is an ambush. That exchange deals 1.5× damage on every hit (chain links included), always catches a pursuit and always reads a dodge, and its signature cannot be clashed or dodged (it can still be escaped, CC-007) | 1.8 s, 2.5 s, 1.5× | `index.html:402-403, 687, 324, 441, 458, 586, 588` |
| `lock-loss` | Attacking a hidden target: 2 ki and a 0.5 s cooldown | 2, 0.5 s | `index.html:397-401` |

---

## 3. Cancel and priority rules

| Rule | Effect | Citation |
| :--- | :--- | :--- |
| One exchange at a time | A request during an exchange, a chain window or the cooldown is ignored | `index.html:391` |
| Launched or locked targets are safe | Nobody can start an exchange against them | `index.html:394` |
| Parry cancels | Later strikes, launches and the guard drain are skipped. Windows and rushes are not (CC-001) | `index.html:485, 523, 526, 538` |
| KO ends everything | The exchange ends at once; the KO launch replaces its remaining beats | `index.html:344` |
| Dead fighters stop atoms | Strikes, launches and beam beats check hp | `index.html:523, 538, 600, 609, 631` |
| Hitstop outranks everything | Nothing advances during hitstop, not even the exchange clock | `index.html:883` |
| Initiative | Simultaneous requests are settled by a per-frame coin flip | `index.html:886` |
| Heavy downgrade | A heavy with under 4 ki is performed as a light | `index.html:396` |

---

## 4. Windows

A window is a span in which one player's input changes the exchange. The prototype has two kinds.

| Window | Who | Input | Opens | Closes | Width | Where it exists |
| :--- | :--- | :--- | :--- | :--- | ---: | :--- |
| Parry | defender | light or heavy | `windup` | first parryable strike | 0.10 s | TRADE BLOWS (rt - 0.1 to rt), PRESSURE (rt - 0.1 to rt), GUARD BREAK (rt - 0.1 to rt) |
| Parry | defender | light or heavy | `windup` | first parryable strike | 0.33 s | HEAVY CLASH — WON (rt - 0.05 to rt + 0.28) |
| (dead) | defender | light or heavy | `windup` at rt - 0.12 | never: every later strike is `noParry` | 0 | DODGE & READ, DODGE & COUNTER (CC-009) |
| Chain | attacker | light or heavy | WIN beat | 0.6 s later | 0.6 s | every branch that ends on WIN: CHARGE INTERRUPT, CAUGHT, DODGE & READ, GUARD HOLDS, GUARD BREAK, TRADE BLOWS won, HEAVY CLASH — WON, each chain link |

Not parryable at all: CHARGE INTERRUPT, both PURSUIT branches, CLASH SHOCKWAVE, HEAVY CLASH — COUNTERED, every chain link and every signature.

**How the windows are surfaced to the player today: they are not.** The wind-up draws nothing (`index.html:424-427`). Both fighters hold the same punch pose from the first frame of the exchange (`index.html:1004`). The chain window draws nothing until after a chain has been taken. A new player cannot see either window and an expert can only learn them by rhythm. Which templates have windows, the cue proposals and the proposed widths are in `exchange-templates.md` section 5.2; widths are for Controls and Game Feel to decide.

---

## 5. Defects and porting notes

Recorded for the port, not fixed in the prototype. IDs are this team's; QA's IDs are cited where they overlap.

| ID | Finding | Consequence | Citation |
| :--- | :--- | :--- | :--- |
| CC-001 | A parried exchange still opens its chain window, and the attacker can "chain" | The chain costs 6 ki, shows the "N HIT CHAIN" banner and rushes, but its strike and launch are skipped. Measured: 13.4% of all chain links, and 13.1% of QA's "CHAIN xN ended" lines | `index.html:544-547, 572-575` (no `ex.cancel` check) |
| CC-002 | PRESSURE — GUARD HOLDS ends on a chain window, and the chain strike ignores stance | Whenever the guard holds without a counter (always when the defender has 25 ki or less, 60% of the time otherwise), one more press within 0.6 s is a guard bypass: a 66-base strike and a launch | `index.html:479-480, 554` |
| CC-003 | The 1.35× damage against a charging defender is unreachable | By the time `hit()` runs the defender is `locked`, not `charging`; the intended punish is carried only by CHARGE INTERRUPT's base × 1.4 | `index.html:326, 328, 411` |
| CC-004 | The signature's HIT chance against ESCAPE falls as the attacker's tier rises | `0.5 - 0.05·(A.tier - D.tier)`; the melee pursuit (`index.html:441`) and the beam dodge (`index.html:588`) both move the other way. Game Design found this independently | `index.html:589` |
| CC-005 | A dodged signature leaves the defender hanging, frozen and locked, 300 u up for about 0.9 s | Dead time for the defender with no follow-up; reads as a stall. **Closed in `da5fb09`:** the GDScript sim frees the dodger to drift (`beam.gd` `opBeamDodge`) | `index.html:616, 620` |
| CC-006 | The rush flies through terrain | Fighters pass through mountains and towers on the way in; only the final frame is clamped | `index.html:751, 748` |
| CC-007 | Ambush does not affect the signature against ESCAPE | Inconsistent with melee, where an ambush always catches a pursuit | `index.html:589` versus `441` |
| CC-008 | No cost for a missed or early parry press | Mashing parries every parryable strike; the parry is not a read | `index.html:525, 853` |
| CC-009 | The DODGE templates open a parry window that can never parry | Every later strike is `noParry`; the AI defender's 12% press does nothing. **Resolved:** the dynamic profile drops the dead wind-up; the DODGE templates get a tell, not a window (R5: EVASIVE never parries; `moveset-system.md` section 7.3) | `index.html:461, 464, 468` |
| CC-010 | Pressing signature never parries or chains | Only light and heavy stamp `lastAtkT` | `index.html:853` |
| CC-011 | No window is visible | See section 4 | `index.html:424-427, 544-547, 1004` |
| CC-012 | The signature variant is keyed to the defender's biome but its extras apply along the whole path | A FIRESTORM fired from the forest at a target in the desert burns the desert | `index.html:584, 649-655` |
| CC-013 | `charge` damping is per frame, not per second | Correct at the fixed 60 Hz step; a port with another step rate must convert it | `index.html:783` |
| CC-014 | Downed defenders are valid targets and get their full stance options | 15.4% of exchanges target a downed fighter, who can then dodge-warp, win a trade or win a beam clash; being attacked cancels the knockdown | `index.html:394, 421` |
| CC-015 | A parry cancels the defender's own scripted strikes too | In a TRADE BLOWS the defender would have won, parrying pays less: the attacker loses about 20 hp instead of about 90 | `index.html:523` |
| CC-016 | The template is fixed at plan time, but the stance multiplier is read live | A human can switch stance mid-exchange: an attacker who switches to DEFENSIVE takes 0.38× from counters, and a GUARD beam against a defender who has left DEFENSIVE deals 200 × 1.12 | `index.html:326, 421, 852` |
| CC-017 | At long range the rush's final snap can land a frame after the dodge-warp | The attacker then teleports past the defender, undoing the dodge (seen in probes at the maximum rush time) | `index.html:748, 462, 571` |
| — | Cosmetic effects draw from the simulation RNG inside exchanges (sparks, debris, splashes, spins) | QA-002: any VFX change rewrites gameplay | e.g. `index.html:381, 654` |

---

## 6. Events for Animation and VFX (first pass)

Each atom already emits the events a presentation layer needs. This table is the anchor list, meaning the authored moments that Animation should key and VFX should hang effects on. Timings are the grammar's; poses and effects are for those teams to design.

| Atom | Key moments (Animation) | Events emitted today (VFX) |
| :--- | :--- | :--- |
| `rush` | launch pose, flight, arrival brace | afterimage trail every frame, 0.16 s life |
| `windup` | anticipation, the tell the defender reads (missing today) | none (CC-011) |
| `strike` | contact frame on the beat; recoil scaled by `kb` | spark burst (9, or 18 if big), damage number, hitstop, shake |
| `parry` | deflect on the beat; attacker stagger | blue ring of radius 700, PARRY banner, hitstop 0.12 |
| `dodge.warp` | vanish, reappear behind the attacker | afterimage at the old spot, ring at the new one |
| `slip` | burst away | afterimage, SLIPPED AWAY banner |
| `guard.drain` | the guard visibly giving way | banner, shake 12 |
| `launch` | the blow's follow-through, the body leaving | ring of radius 600, shake 10, spin |
| `impact`, `bounce`, `down`, `recover` | ground contact, bounce, lying, get-up | crater, splash or debris, dust, ring, shake up to 30, hitstop 0.06 |
| `chain-link` | pursuit, catch in the air, strike | banner, afterimages, big sparks |
| `clash.shockwave` | both fighters thrown apart | two rings (1,400 and 800), 30 sparks, crater, banner, shake 18 |
| `beam.charge` | rise, charge pose, orb growing for 0.8 s | orb, aura ring, name banner |
| `beam.fire` / `beam.carve` | release pose | beam body, craters and dust along the path, splashes, glass sparks or fire by variant |
| `beam.connect` | defender caught by the beam | explosion (sparks, two rings, fire, debris), hitstop 0.14, shake 16 |
| `clash.beam` | two beams meeting, pushing | beam struggle point with sparks for 1.6 s, then the winner's beam and explosion |
