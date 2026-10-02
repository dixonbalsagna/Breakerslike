# Agency, slice 3: the far taunt as a challenge, the held charge, the AI's use of the free time, the rulings of §11 and §12, and the ending events

Owner: Encounter Systems Director. Date: 2026-10-02. Status: in the tree on HEAD `7001bf0`, waiting for the EP's commit. Rules: `docs/design/agency-pass.md` §1, §3, §11 (3b and 4) and §12. Items 1c and 1d of `agency-plan.md`.

Everything here runs only in the `dynamic` profile. The old profiles are unchanged.

## What changed

| Part | Rule | Where |
| :--- | :--- | :--- |
| **A far press fires on its tick** | Beyond 12.5 bh, with no exchange or approach running, an attack press never waits in the queue. It opens his taunt, or answers the rival's. A request that waited in the queue and comes up in the far band is dropped: it was pressed somewhere else | `bands.gd` `farPressNow`; `exchange.gd` `requestAttack`, `_start` |
| **Tap: the taunt** | It plays for 45 ticks while he keeps flying. Nobody is locked. His dodge cuts it short | `bands.gd` `farPress`, `_tauntTick` |
| **The challenge** | The rival's attack press while it plays answers it. Each dashes half the distance and they arrive on the same tick, 2.5 bh apart about the midpoint. The exchange is the answerer's attack against a rival who is pressing too: a clash if either pressed a heavy, otherwise a trade (today's HEAVY CLASH and TRADE BLOWS until Combat's meeting pieces are wired) | `bands.gd` `meet`; `data.gd` `_flags` |
| **What a taunt pays** | Answered: in full. Ignored: a half, a quarter, an eighth, then nothing until the two have traded blows. A take-off and a taunt cut short pay nothing. The director sends the amount as a cue; no meter is written yet | `bands.gd` `endTaunt` |
| **Hold: the charge** | A press still held 8 ticks later (16 for a heavy) becomes a charge. A light charge flies 18 to 60 ticks; a heavy 30 to 84 (§12 a). The rival is free, and the exchange starts at the wind-up, as any approach | `bands.gd` `_tauntTick`, `begin` |
| **The light charge's feint** | Letting the button go stops it for nothing. On a Simple layout the hold that turns the light into a heavy is not a release, and with the `autoCharge` assist a charge never feints | `bands.gd` `tick` |
| **The heavy charge is committed** | Only a dodge stops it, at the dodge-cancel's full cost (15 ki and the 3 s cooldown). Its heavy counts as held, so landing it earns a launch | `bands.gd` `cancel`, `_engage`; `alchemy.gd` `heldAt` |
| **The AI in the far band** | Its attack beat is a taunt 6% of the time (medium) and otherwise a charge: it holds its button. It answers a rival's taunt half the time, 20 ticks in (past a heavy's hold, so it answers taunts, not charges) | `ai.gd`; `ai.json` `farTaunt`, `farCharge`, `farHeavy`, `answerTaunt`, `answerTicks` |
| **The guard lockout** (§11, 3b) | A guard press starts the perfect block's 20-tick lockout only when it comes during a visible wind-up and misses the window, or within 20 ticks of his last guard press. A single press with no wind-up showing starts nothing: raising a guard as a rival flies in no longer costs the perfect block | `interrupt.gd` `guardPress`, `_windupShowing` |
| **The starts floor** (§11, 4) | When both fighters have a press waiting, the one who did not start the last exchange starts this one, whichever press is older. It stands until the alchemist | `exchange.gd` `_drain` |
| **The band edges** (§12 b) | The far band starts beyond 12.5 bh, so the opening press (12 bh) is a lunge. The band is held state with 0.5 bh of hysteresis on each edge: going out an edge sits a quarter of a body height further out, coming in a quarter further in | `bands.gd` `band`, `_bandAt`, `_bandTick`; `bands.midBh`, `bands.hysteresisBh` |
| **A met heavy charge** (§12 c) | A rival's press while he holds a heavy meets it in a clash, and he enters with an edge for the charge he had built. Today's clash is a chance, not a score, so the +5 is 10 points off the attacker's chance (`chargerEdge`, in points of 100) until the fist clash on the pulse is wired | `bands.gd` `meet`; `data.gd` `_select`; `bands.meet.chargerEdge` |
| **The ending events** | `exchange_end` as each exchange ends: `launch`, `knockback` or `continue`. `knockback` as a rival is sent back: `slideShort`, `slideLong` or `drift`, with the distance and the tick it ends (an estimate for the long slide; World's journey decides). The bump is World's | `exchange.gd` `endEx`; `launch.gd` `knock`, `doLaunch` |
| **The flow count** | A timed press (within 4 ticks of one of his own blows landing) adds 1, up to 5. A press off the beat, or 90 ticks without one, sets it back to 0. It is sent as `flow` on a change. Nothing reads it yet but the HUD and QA | `alchemy.gd` `log`, `tick` |
| **The AI uses the free time** | When a rival's approach will take 16 ticks or more, it picks an answer once: guard (20%), dodge (10%) or press to meet him (15%); otherwise it carries on. It acts 14 ticks later. The feed says what it chose | `bands.gd` `_aiChoose`, `aiAnswer`; `ai.json` `approachReact`, `reactTicks` |

**One core line, by the EP's grant:** Controls' `intent-hash.patch` in `sim/core/hash.gd`. The state is seven more integers in the fighter's director state. The code now reads `lightHeld` and `heavyHeld`, and the goldens are generated with the patch.

**Cues** (the existing `cue` event; names are the director's until Simulation's taunt events exist):
- `taunt_start`; `taunt_end_finished`, `taunt_end_accepted`, `taunt_end_takeoff_light`, `taunt_end_takeoff_heavy`, `taunt_end_cut`.
- `taunt_credit_full`, `taunt_credit_half`, `taunt_credit_quarter`, `taunt_credit_eighth`, `taunt_credit_none`.
- `challenge_answered` (the answerer); `charge_light`, `charge_heavy`; `charge_feint`.

**Feed lines:** `TAUNTS`, `TAUNT ANSWERED`, `TAUNT IGNORED`, `ANSWERS THE CHALLENGE`, `CHARGES`, `SEES HIM COMING`, `WILL ANSWER`.

## Results

**Gates** (on a clean copy of HEAD `1a7efb9` with this slice, Controls' hash patch, Tools' schema script and World's blast rows; parity again in the tree on `7001bf0`): goldens regenerated (9 matches, 184,933 ticks); parity, the loader check at 200 matches, `npm test` 5 of 5, determinism, seam, the animation check, the cue check, Controls' ten input tests and its mash probe (6 of 6) pass. The validator shows 0 errors and its self-test passes.

**The events, on three AI matches:** 750 `exchange_end` (545 continue, 87 knockback, 118 launch) for 740 melee exchanges and 10 signatures; 87 `knockback` (60 drift, 25 slideLong, 2 slideShort). The AI never times its presses, so its flow stays 0; a scripted player pressing as each of his blows lands sends flow 1, 2, 3, 4, 5, and 0 again 90 ticks after his last press.

**The rulings, measured:**
- *The lockout:* raising a guard as the rival lunges and then pressing in the window is a perfect block (it was refused). Mashing guard every 5 ticks is still refused. A press early in the wind-up that misses still locks the next one out.
- *The starts floor:* against a 4-tick masher, a player pressing about every 40 ticks starts 44% of exchanges (it was 22%), and one pressing about every 20 ticks starts 49% (it was 30%). Game Design's target is 35 to 50%.

100 AI matches, seeds 1 to 100. Before is HEAD `1a7efb9` (slice 2 with World's skid fix and embed). The far-band counts and the defender's state are from the first 50.

| | Before | After |
| :--- | ---: | ---: |
| Charges a match | 0 | 81.5 (light 48.8, heavy 32.8) |
| Charge flight, median (p10 to p90) | | 40 ticks (19 to 84) |
| Far taunts a match (taps) | 0 | 5.0 |
| ... answered | | 2.6 |
| ... ignored | | 2.1 (each paid a half) |
| Meetings a match | 0 | 2.6 |
| Mid lunges, share of melee exchanges | 27% | 27% |
| Apart as a melee exchange starts, median (p99) | 2.5 bh (2.93) | 2.5 bh (3.04) |
| Strikes from out of reach | 0 | 0 |
| Melee exchanges a minute | 24.8 | 24.6 |
| Match median | 8:52 | 9:02 |
| KAI | 54% | 51% |
| Civilians lost, mean | 22.8% | 25.5% |
| Structures lost, mean | 39.4% | 45.6% |
| Launch share of exchanges reaching a launch decision | 28.4% | 26.9% |
| Knock-backs a match | 23.5 | 27.1 |
| Time both fighters are locked in an exchange | 45.8% | 44.6% |

| What the defender was doing at the start | Slice 2 | After |
| :--- | ---: | ---: |
| Nothing (NEUTRAL) | 33.8% | 32.9% |
| Guarding | 23.7% | 27.4% |
| Dodging | 15.8% | 17.1% |
| Pressing (AGGRESSIVE) | 15.6% | 14.2% |
| Escaping | 11.1% | 8.3% |

**Two scripted humans, from 20 bh:**

| Case | Result |
| :--- | :--- |
| A tap, ignored | The taunt ends at 45 ticks and pays a half |
| Four taps, all ignored | A half, a quarter, an eighth, then nothing |
| A tap, answered with a light at 20 ticks | Both rush for 20 ticks; TRADE BLOWS 2.5 bh apart; the taunt pays in full |
| A tap, answered with a heavy (or a heavy tap answered with a light) | HEAVY CLASH; the winner's launch is earned by the clash |
| A tap, answered after the window | The first taunt was ignored; the late press is the rival's own taunt |
| A light held through | The charge starts at 8 ticks and flies 19; first blow at 41 |
| A light held, let go 8 ticks into the flight | The charge stops; no ki spent |
| A heavy held through | The charge starts at 16 ticks and flies 30; a clean hit; the launch is earned by the held heavy |
| A heavy held, a dodge 14 ticks into the flight | The charge stops; 15 ki |
| A heavy held, the rival presses 10 ticks into the hold | A meeting: HEAVY CLASH, the charger with the edge |
| A Simple hold (light, the upgrade to heavy at 12 ticks) | A light charge at 8 ticks that becomes the heavy one; the launch is earned by the held heavy, held on or let go after the upgrade |
| A light charge, the rival guards once it is coming | PRESSURE: GUARD HOLDS |
| A light charge, the rival presses once it is coming | TRADE BLOWS |
| A tap, then his own dodge | The taunt is cut; it pays nothing |
| A light let go at 5 ticks | It was a tap: the taunt plays out |

## Notes

- **Matches are 10 s longer** with the charges of §12 (they were 80 s longer with the first numbers: a 12 or 24-tick hold and 0.5 to 2 s of flight).
- **Structures lost are 6 points up** (39.4% to 45.6%) and civilians 2.7. On the HEAD before World's embed the same build measured 1 point up (42.8% to 43.9%), so part of it is the run and part the embed's interplay; QA should watch it. QA re-tunes k for a 7:00 to 7:30 median. Three AI policies that tried to avoid the cost measured worse, on the first numbers:
  - holding half its far beats: median 11:04, at the time cap;
  - flying in to lunge range first: 9:20 on 25 matches, against 9:12 for always charging (before the starts floor);
  - light charges only: 9:38.
- **The AI charges a lot** because launches leave the fighters far apart: with no exchange running, the pair is in the far band for about 40% of the match (two matches traced).
- **The taunt pays nothing real yet.** The director counts and announces the share; the mood's taunt impulse and the fighters' meters have no reader for it.
- **The meeting uses today's templates.** Both dash to the middle, then the answerer closes the last 2.5 bh during the wind-up. Combat's `clash.fist` and `clash.blur` on the pulse are not wired.
- **Simple layouts need no automatic release.** Under Game Design's rule a charge goes by itself after the hold and a heavy is committed, so a held button is never stuck. A Simple hold starts as a light charge at 8 ticks and becomes the heavy one at the layout's 12-tick upgrade. `autoCharge` is read for one thing: with it, letting go never feints.
- **An older fault of mine fixed:** a layout's hold turned the request into a heavy but the press log still said light, so a held heavy made that way never earned its launch. The log now records the heavy.
- **The band is state now.** `DirBands.band(a, b)` is what the HUD's icon should read. With the hysteresis the close band reaches 3.25 bh for a pair coming from close, so 37 of 11,123 exchanges began more than 3.2 bh apart (the largest 3.5).
- **Release follows Game Design, not Controls' note:** letting a light go stops the charge (the feint). Controls' R2 has the release launch it and the dodge feint it; the dodge also stops it here, free.
- **`taunt.enabled` off** restores slice 2: a far tap flies in.

## Left for the next slice

- **The buried fighter** (§7; World's embed is live): the attacker's one blow that can't be answered within 40 ticks (clean, no launch, deepens the crater), the buried fighter's guard only from tick 40, his burst not before it, and 10 ticks of safety as he rises. It needs Combat's piece and a no-launch ending, so it is not small.
- **The slide's bump** (`docs/world/ground-contact.md` §24): `WorldContact.slideObstacle` when the upright slide is planned, `WorldContact.bump` and a `knockback` of kind `bump` when it ends early, and the `slideFeet` flag from `doLaunch` for the long slide. World's two functions and the field come in its next window.
- **The meeting's own pieces:** Combat's `clash.fist` and `clash.blur` on the pulse, and the +5 as a score.
- **What a taunt pays:** Simulation's taunt events and the meters.

## Data keys for Tools

| File | Keys |
| :--- | :--- |
| `data/director/interrupts.json` | `bands.hysteresisBh`, `bands._edge` (`bands.midBh` is now 12.5); `bands.taunt` {`enabled`, `windowTicks`}; `bands.charge` {`light`, `heavy`: each {`holdTicks`, `speed`, `minTicks`, `maxTicks`}}; `bands.meet` {`speed`, `minTicks`, `maxTicks`, `chargerEdge`}; `bands._far` |
| `data/director/ai.json` | `reactTicks`, `answerTicks`, `_far`; per level: `farTaunt`, `farCharge`, `farHeavy`, `answerTaunt`, `approachReact` (three numbers) |
