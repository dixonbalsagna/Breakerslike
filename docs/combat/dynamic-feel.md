# Dynamic feel pass

Owner: Combat and Choreography, with Encounter Systems implementing and Game Design re-banding. Date: 2026-09-29. Status: diagnosis measured; data profile written (`data/combat/templates.json`, profile `dynamic`); the code changes are listed for Encounter.

**Orb's playtest** (`docs/ep/vision.md`, playtest feedback): "the fighters seem to lock together and not do anything for moments before launching attacks. Let's really nail down the engaging, dynamic feel of combat the prototype had." Orb's feel overrides `balance-targets.md` section 10 where they conflict.

---

## 1. What the measurements show

**Method.** A probe steps AI-vs-AI matches headlessly and sorts every frame into one of three classes:
- **freeze:** hit-stop; sim time did not advance.
- **active:** a fighter moved faster than 100 u/s (about 1.3 fighter heights a second), or a strike-type event (damage, parry, clash, launch) happened in the last 6 frames.
- **idle:** everything else.

Inside an exchange, idle frames are what Orb sees as "locked together, doing nothing". Outside one, a **standoff** is a frame where both fighters are within 400 u horizontally and 300 u vertically, and still.

**Melee** excludes the set pieces: signatures, and exchanges that turn into a finisher. Samples:
- the prototype at `7233c96`: 60 matches;
- the live GDScript build: 40 matches per profile, default arm.

The probes (a GDScript `SceneTree` script and a Node script) are read-only and available to QA and Encounter.

| Measure | Prototype | Live, `parity` timing | Live, `spaced` (today) | Live, `dynamic` (this pass, data only) |
| :--- | ---: | ---: | ---: | ---: |
| **Melee idle share** (of live frames) | 22.5% | 22.2% | **42.5%** | **11.8%** |
| Melee longest still stretch per exchange, median | 0.22 s | 0.22 s | **0.85 s** | 0.15 s |
| Melee longest still stretch, p90 | 0.65 s | 0.65 s | 1.28 s | 0.28 s |
| Request to first strike, median | 0.40 s | 0.47 s | **1.45 s** | 0.57 s |
| Melee exchange length, median | 1.17 s | 1.23 s | 2.75 s | 1.65 s |
| Hit-stop share of exchange frames (deliberate) | 12.6% | 11.1% | 7.1% | 10.3% |
| Gap between visible strikes, median / p90 | 0.18 / 1.88 s | 0.17 / 3.28 s | 0.20 / 4.18 s | 0.20 / 3.33 s |
| Strikes per minute | 91 | 66 | 52 | 65 |
| **Release to the next request, median** | **0.75 s** | 2.67 s | 2.87 s | 2.68 s |
| Share of fight time inside exchanges | 58% | 36% | 47% | 39% |
| Standoff runs, median / p90 | 0.07 / 0.58 s | 0.28 / 1.57 s | 0.28 / 1.68 s | 0.28 / 1.62 s |

Two separate problems stack up, and both show in Orb's sentence:

**A. Inside the exchange, the fighters freeze (Combat's data).** The `spaced` profile nearly doubled idle time inside melee (22% to 42%) and quadrupled the typical still stretch (0.22 s to 0.85 s). The first strike now lands 1.45 s after the request, against 0.40 s in the prototype. There are three causes:
1. **The `cue` beats render nothing.** No consumer of the `cue` event exists in `render/`, `ui/` or `audio/`. Every choreography beat I authored in `spaced` is a frozen frame: tell, glance, brace, bind, turn, whiff, exposed, overextend, guard set, recover, reset, pull up, scan, catch. The worst cases:
   - HEAVY CLASH stands still for about 1.05 s (glance, then brace) before its strike.
   - DODGE stands for about 1.05 s (whiff, then turn) before the read.
   - TRADE BLOWS stops for 0.35 s in the middle (bind).
   - PURSUIT — CAUGHT waits 0.35 s after the catch.
2. **The 0.35 s step with nothing between contacts.** Section 10's 0.25 to 0.40 s spacing is only readable if the space is filled.
3. **Chain windows hold the attacker still for 0.6 s**, and 59% of them close unused.

**B. Between exchanges, the fighters hover (Encounter's code).** The median from release to the next request is 2.7 to 2.9 s, against 0.75 s in the prototype:
- the director's cooldown is 0.8 to 1.5 s (the prototype's was 0.22 s);
- the AI waits 1.2 to 2.5 s between attack beats when AGGRESSIVE, 2.0 to 3.6 s DEFENSIVE and 1.6 to 3.0 s otherwise (the prototype: 0.35 to 1.0, 1.2 to 2.5 and 0.9 to 1.8);
- each beat attacks only about half the time (`P_ATTACK` 0.43 to 0.52).

Strikes per minute fell from 91 to 52, and close standoffs last three times as long (p90 1.6 s against 0.6 s).

**Not the problem:**
- **Hit-stop:** 7 to 11% of exchange frames, close to the prototype's 12.6%. It is deliberate and reads as weight.
- **The parry and chain window widths:** they are unchanged. The windows only felt dead because nothing moved inside them.
- **Set pieces** (beam clash, finisher contest): they hold on purpose. Their still stretch (median about 0.9 s) is shown by VFX (the beam struggle, the struggle rings), and it is excluded from the melee targets.

---

## 2. The proposal

**Principle: keep every window and outcome, and fill every beat with motion.** Nothing freezes except deliberate hit-stop and the set pieces.

### 2.1 Data (Combat, written): the `dynamic` profile in `templates.json`
The new profile sits beside `parity` and `spaced`:
- It changes **only timing and choreography**.
- Outcomes, damages, forces, tags, parryable strikes and the selectors' RNG draws are those of `spaced` and `parity`.
- The motion beats use existing ops (`rush`, `finRush`, `separate`), which draw nothing.

| Rule | How |
| :--- | :--- |
| **No still beat** | Every `cue` now shares its tick with a motion or a contact, so the cue labels stay for Animation and Audio, but the frame moves even while they render nothing |
| **Contacts every 0.233 s** (14 ticks) | Orb's prototype feel (0.16 to 0.20 s) over section 10's 0.25 to 0.40 s. Exchanges carry more contacts, not more waiting: TRADE BLOWS trades four blows, circles, then decides |
| **Wind-ups inside motion** | The approach is at least 0.25 s, so the 15-tick light wind-up always falls during the approach flight. In HEAVY CLASH a forearm glance throws both fighters back (`separate`), and the attacker's 20-tick lunge back in is the wind-up. The tell is the motion. Controls' widths (15 and 20 ticks) are unchanged |
| **Footwork** | backstep and re-close (`rush` to a longer offset, then back), a pivot after a dodge, a circle to the far side before TRADE BLOWS' deciding blow (`rush` with a negative offset), and a guard shove (`separate`) |
| **Pursuit through the chain window** | Whoever wins the launch chases the flying body for 0.35 s: the attacker with `rush`, or the winning defender with `finRush`. A chain takes over from there. With no chain, the fighters are released already close, and the exchanges flow into each other |
| **Short tails** | No recover or reset holds: the defender-wins branches end on the pursuit (0.35 s), not a 0.35 to 0.7 s stand |
| **Chain link** | 0.15 s re-close, strike, launch, then a pursuit into the next window |
| **Signature and finishers** | unchanged this pass (their timing lives in ops; the set pieces hold on purpose). Finisher `cue` beats also render nothing today; that closes when cue poses render (section 2.3) |

**Result (data only, measured):**
- melee idle share 11.8% (the prototype's is 22.5%);
- still stretch 0.15 s median and 0.28 s at p90;
- first strike after 0.57 s;
- melee exchanges of 1.65 s: longer than the prototype's (1.17 s), with more contact beats and no holds.

**The rest of the gap is between exchanges** (2.7 s against 0.75 s). Data cannot close it.

### 2.2 Code (Encounter Systems)
| # | Change | Why | Suggested value |
| :--- | :--- | :--- | :--- |
| 1 | **The loader reads any profile by name.** Beats come from `branch[profile]`, `shared[profile]` and `chainLink[profile]`, and tick timing applies when the profile's `timeUnit` is `"tick"`. Today `DirData.spaced()` and the `"spaced"`/`"parity"` keys are hard-wired | so `"profile": "dynamic"` works; a one-line key change plus the tick test | none |
| 2 | **The director cooldown** back toward the prototype's | 0.8 to 1.5 s of enforced nothing after every exchange | 0.25 s + 0.1 s per second of exchange, at most 0.6 s |
| 3 | **The AI attack cadence** back toward the prototype's | the main cause of the 2.7 s gaps | AGGRESSIVE 0.5 to 1.2 s, DEFENSIVE 1.0 to 2.0 s, EVASIVE and ESCAPE 0.8 to 1.6 s. `P_ATTACK` 0.8 to 0.9. `CAD_MIN` scaled to match |
| 4 | **The AI never halts at close range.** Today an AGGRESSIVE AI in reach stops (`mx = 0`) and waits for its timer | this is the "lock together" standoff | Circle and feint instead: orbit the opponent (a small lateral and vertical weave), with a short hop back when the other side attacks |
| 5 | **The beam-dodge hang** (CC-005): the defender floats up and keeps moving, or is freed | 0.9 s frozen in mid-air | free the defender at the dodge |
| 6 | The chain-reach check stays | the pursuit rush already follows long hauls visually | none |

Rows 2 to 4 are what Orb's sentence is mostly about.

### 2.3 Later, through the EP
- **Render and Animation: consume `cue` events as poses** (tell, brace, glance, turn, guard set...). The cue vocabulary is in `finishers.json` `cues`. Once they render, the finisher cue beats come alive too.
- **Game Design: re-band.** Rows 2 and 3 raise the exchange rate (probably to 16 to 20 a minute, against about 12 today), which raises the wear rate and shortens matches. k and the section 10 tempo bands need re-banding (section 3).

---

## 3. Targets that express "dynamic" (for Game Design to adopt)
These replace section 10's exchange-length band (2.5 to 4.0 s) and strike spacing (0.25 to 0.40 s), which conflict with Orb's feel. Measured with the probe definitions above, on the default arm.

| Target | Value | Prototype | Live `spaced` | `dynamic`, data only |
| :--- | :--- | ---: | ---: | ---: |
| Melee idle share inside exchanges | **at most 15%** | 22.5% | 42.5% | 11.8% |
| Melee longest still stretch per exchange | **median at most 0.25 s, p90 at most 0.5 s** | 0.22 / 0.65 | 0.85 / 1.28 | 0.15 / 0.28 |
| Request to first strike, median | **at most 0.6 s** | 0.40 | 1.45 | 0.57 |
| Gap between visible strikes | **median at most 0.25 s, p90 at most 2.0 s** | 0.18 / 1.88 | 0.20 / 4.18 | 0.20 / 3.33 (needs 2.2) |
| Strikes per minute | **at least 80** | 91 | 52 | 65 (needs 2.2) |
| Release to the next request, median | **at most 1.0 s** | 0.75 | 2.87 | 2.68 (needs 2.2) |
| Close standoff runs, p90 | **at most 0.6 s** | 0.58 | 1.68 | 1.62 (needs 2.2) |
| Share of fight time inside exchanges | **at least 50%** | 58% | 47% | 39% (needs 2.2) |
| Hit-stop share of exchange frames | 7 to 13% (deliberate, unchanged) | 12.6% | 7.1% | 10.3% |
| Set pieces (beam clash, finisher contest) | exempt from the idle targets; they must show continuous VFX or struggle cues | | | |

**Readability is kept, and measured:**
- window widths are unchanged (15 and 20 ticks for the parry, 36 for the chain);
- every parry window opens during visible motion (the approach or the lunge);
- every outcome keeps its own tag and parryable strike;
- the hit-stop floors are Controls'.

---

## 4. Risks
- **Match length.** A higher exchange rate means faster wear. Game Design retunes k (spec-wounds.md section 1b's lever order) after rows 2 and 3 land, or matches drop well under 6 minutes.
- **Collateral.** More strikes per minute near settlements raises casualties; watch QA's collateral band.
- **AI parry success.** The windows are unchanged, so it should hold near 41%; confirm.
- **Readability.** The pace is Orb's call. If it reads too fast, raise `tempo.step` (14 ticks now) before adding holds back. The pace comes from the motion, not from the step.

## 5. Verify
1. Encounter lands row 1 and switches `templates.json` to `"profile": "dynamic"`. QA regenerates the goldens; the change is intended.
2. Run the probe on 40 or more default-arm matches. All the rows marked "needs 2.2" should pass once rows 2 to 4 land.
3. Orb plays it.
