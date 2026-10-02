# Agency, slice 7: Game Design's rulings on the slice 4 and energy baselines

Owner: Encounter Systems Director. Date: 2026-10-02. Status: in the tree on HEAD `eb029ba`, waiting for the EP's commit. Rules: `docs/design/agency-pass.md` §14 (items 4, 5 and 6, and the gap measure of item 2) and §16.

Everything here runs only in the `dynamic` profile. The old profiles are unchanged.

## What changed

| Part | Rule | Where |
| :--- | :--- | :--- |
| **A plain blur's ender is half a set-up** (§14.4) | A decisive win against a fighter on the brink is worth `setup.weight` of its kind: 1 for everything, 0.5 for a plain blur's own ender. Whole set-ups are the fighter's count, as before; the half left over is the director's state and lapses with the brink. `brinkSetups` stays 1, so a masher needs two enders where anyone else needs one win | `exchange.gd` `decisive`, `_setup`, `_winCloses`, `_setupLapse`; `melee.gd` `launchBeat`; `launch.json` `setup` |
| **The follow-up is a dive with a time limit** (§14.5) | The attacker presses within 40 ticks. The director flies him to the crater at 4,000 units a second (the light charge's speed; at least 18 ticks), and the blow must land by tick 100 of the burial. If it cannot, there is no follow-up and the press is an ordinary press. No distance limit | `bury.gd` `followUp`, `diveTicks`, `plan` |
| **A blast is the other free blow** | With the energy family held, the press sends a charged shot into the crater at once, free of ki. It arrives within 45 ticks from any distance (the shot's own rule) and does 44, two-thirds of the dive's blow | `bury.gd` `blastFollow`, `fireBlast`, `followShot`; `blast.gd` `press`, `hit` |
| **He is held until the blow lands** | A dive holds him as its exchange does. A shot on its way holds him in the crater past World's 60 ticks, never past tick 100. Nothing of his stops a follow-up on its way: no burst, no dodge-cancel, no reversal | `bury.gd` `_hold`, `diving`, `canBurst`; `interrupt.gd` |
| **The AI bursts out** | Only when no follow-up is coming: from tick 40, with nothing used or on its way and its rival within 12 bh, one draw a burial at 20%, 50% or 80% by level | `bury.gd` `_aiBurst`; `ai.json` `buriedBurst` |
| **The AI's free blow** | It dives when the dive can land in time, and fires the charged shot when it cannot | `bury.gd` `aiFollow`; `ai.gd` |
| **The crater deepens by World's call** | The follow-up's blow calls `WorldCrater.deepen` with 1.2: the crater he lies in becomes 1.2 times as deep | `bury.gd` `opDeepen` |
| **Bolts and charged shots hit harder** (§14.6) | A bolt does half a light (13, was 8.67). A full charged shot does 1.25 of a heavy (82.5, was 66); a tap does 0.6 of that | `data/fight/shots.json` (Simulation's, by the EP's grant) |
| **A full charged shot knocks back** | A fully charged shot that lands clean (not guarded, not shrugged off) on a fighter who is up and outside an exchange is a knock-back, and decisive (kind `blast`) | `blast.gd` `_knock`; `interrupts.json` `blast.heavy.knockFull` |
| **A barrage closes** (§16) | When four of a fighter's bolts land clean on his rival inside 90 ticks, the fourth is a knock-back he did not press: decisive (kind `barrage`), never a launch. Guarded, shrugged-off and deflected bolts do not count. If each was fired 10 ticks or more after the one before, it goes the tier's full distance and is a full set-up; otherwise 0.6 of it and half a set-up. The count starts again and the rival cannot be knocked back by another barrage for 90 ticks. A bolt that would close while he is in an exchange, down, flying or immune still counts, and the next clean one closes | `blast.gd` `_barrage`; `interrupts.json` `blast.barrage`; `launch.json` `setup.weight.barragePlain` |
| **A decisive shot can finish** | A decisive shot (the full charged shot, the barrage's ender) is in the brink chapter as any decisive win is: it closes the shooter's own opening, it is a set-up against a fighter on the brink, and against one who is open (or past the time cap) it starts the shooter's finisher. There is no exchange to take over, so one starts there with the shooter as its attacker; he closes in as any finisher's winner does. It needs the shooter free; otherwise the rival stays open | `exchange.gd` `decisiveShot`, `_shotFinisher` |
| **The AI guards against a barrage** | As the second clean bolt of a barrage lands on it, one draw at its level's rate (20%, 50%, 80%); on a yes it holds guard until those bolts have left the window | `blast.gd` `_barrage`; `ai.gd`; `ai.json` `barrageGuard` |
| **The AI fires more** | `blastShare` 0.18, 0.35, 0.45 (was 0.1, 0.2, 0.25): the EP's ruling on the measured rates below | `ai.json` |
| **The hard AI perfect-blocks less** (§16) | `perfectBlockMul` 1.0 to 0.9 | `ai.json` `levels.hard` |
| **The medium AI against a masher** | `guardRepeat` 8.75 to 6.5: half set-ups slow his kills | `ai.json` `levels.medium` |

**Not in this slice:** §14.6's "a missed bolt doesn't wreck buildings". Orb ruled the other way on 2026-10-02 (`docs/ep/vision.md`; §15): small shots keep their structure damage. `data/biomes/blast.json` is unchanged.

**No core lines.** The director writes `Fighter.embedT` (to hold him for a shot on its way, and to 0 when he is taken out), and starts the shot's finisher as its own exchange.

**Cues:** `buried_blast` (the attacker, as the follow-up shot leaves), `barrage_ender` (the shooter). `decisive` kinds `blast` and `barrage`. Feed lines: `DIVES`, `FIRES INTO THE CRATER`, `CHARGED SHOT: KNOCK BACK`, `BARRAGE ENDER`, `FINISHES FROM RANGE`, `PART OF A SET-UP`. A shot's finisher sends an `attack` event of kind heavy with the template `SHOT FINISHER`.

## Results

**Two scripted humans.** The buried fighter (P2 put in a crater as World's embed does):

| Case | Result |
| :--- | :--- |
| A heavy at tick 10 from 5 bh | The dive: 18 ticks, 62.7 damage at tick 27; he is out at tick 36 |
| A heavy at tick 10 from 50 bh | The dive: 57 ticks, the blow at tick 66 |
| A heavy at tick 30 from 80 bh | It cannot land by tick 100: no follow-up; the press is a far taunt |
| An energy light at tick 10 from 80 bh, into a held guard | The charged shot: 41.8 damage at tick 55, through the guard |
| An energy heavy at tick 39 from 120 bh | The charged shot lands at tick 84; he is held for it and is up at 107 |
| A heavy at tick 30 from 50 bh; he bursts at 45 and dodges at 50 | Both refused; the blow lands at tick 86 |
| An energy light at tick 35; he bursts at 45 | Refused: he is held until the shot lands at tick 80 |
| Nobody presses; he bursts at 45 | He bursts out |
| An energy light at tick 45 | Too late: an ordinary bolt, and it passes him as he rises |

Shots (P1 fires from 20 bh):

| Case | Result |
| :--- | :--- |
| A bolt | 13.8 damage |
| A tapped charged shot | 53.8 |
| A full charged shot | 87.8, a knock-back of 3.5 bh, decisive |
| A full charged shot into a held guard | 29.8, no knock-back |
| A bolt every 8 ticks | The fourth clean bolt closes at tick 63 (spammed: 2.1 bh); the next ender at 145 |
| A bolt every 12 ticks | The fourth closes at tick 79 (measured: 3.5 bh); the next at 167 |
| A bolt every 8 ticks into a held guard | No ender |
| A bolt every 30 ticks | No ender: never four inside 90 ticks |

**100 AI matches,** seeds 1 to 100. Before is HEAD (`d08bf6b`; nothing in the sim changed between it and `eb029ba`).

| | Before | After | Band |
| :--- | ---: | ---: | :--- |
| Blasts' share of damage | 4.3% | 11.3% | 10 to 25% |
| Match median (mean) | 7:41 (7:51) | 8:31 (8:13) | |
| KAI | 55% | 60% | |
| Civilians lost, mean | 22.1% | 25.3% | |
| Structures lost, mean | 37.7% | 44.9% | |
| Launch / knock-back / stay, of decided exchanges | 20.7 / 31.8 / 47.5 | 20.9 / 32.1 / 47.1 | 18 to 30 / 25 to 35 / 40 to 50 |
| Launches, of the exchanges that separate | 39.4% | 39.4% | 25 to 40% |
| Exchanges a minute | 24.1 | 22.3 | 15 to 28 |
| Matches with no gap over 10 s (the new measure) | | 98 of 100 | 95% |
| Burials a match (50 matches) | | 2.4 | |
| ... a dive pressed at tick 14 could land in time | | 37% | |
| ... dives taken / charged-shot follow-ups | | 0.3 / 1.0 a match | |
| ... the rival's distance at the burial, median | | 175 to 228 bh | |
| ... the crater deepened by, median | | 28 to 48 units; never zero | |

The lengths carry about 8 s of standard error and the structures about 2.4 points.

**Scripted players:**

| | Result | Band |
| :--- | ---: | :--- |
| The masher against the easy / medium / hard AI | 50 of 50 / 41 of 100 / 0 of 50 | medium 35 to 50% |
| The lights-only mirror, brink to KO | 62.6 s (was 26.3 s) | expected 45 to 55 s |
| A bolt-only player against a lights-only masher | decided 40 of 40; he wins 23 | at least 95% decided |
| A bolt-only player against the medium AI | 34 of 100 | 20 to 40% |

**Gates** (on a clean copy of HEAD with exactly the tree's changes; parity again in the tree): goldens regenerated (9 matches, 173,526 ticks); parity, the loader check at 200 matches, `npm test` 5 of 5, determinism, seam, the animation check, the cue check, Controls' input tests and its mash probe (6 of 6) pass. The validator shows the new keys below as errors until Tools' schema lands.

## Notes

- **The firing share.** Measured on the build before World's bump window, 100 matches each: share 0.2 (as it was) gave blasts 4.4% of damage, a mean match of 7:49 and 36.5% of structures lost; 0.3 gave 9.7%, 7:57 and 40.0%; 0.35 gave 11.5%, 8:18 and 41.6%; 0.5 (the rate §14.6 named) gave 18.4%, 8:26 and 46.6%. Stronger shots did not bring the minute back: only 38% of the shots fired land, and the two AIs' shots cancel in the air a lot. The EP ruled 0.35.
- **Structures.** The rise is not from shots on the ground (5 buildings in 25 matches). The AI brawls less, so it has more ki for signatures (4.8 to 5.8 a match), and the knock-backs from barrages and charged shots send fighters through buildings.
- **The dive reaches about a third of burials.** A fighter is buried 175 to 228 bh from his rival in the median case; to land by tick 100 the dive would need 8,000 to 11,000 units a second. The charged shot covers the rest. The AI never burst out in 100 matches: its rival is rarely within 12 bh with no follow-up coming.
- **The lights-only brink to KO is 63 s, not 45 to 55.** A weight of 0.5 means two enders; any weight between 0.5 and 1 also means two, so there is no value in between.
- **Bolt-only without a finisher was 8 of 100 against the medium AI,** and with one, 72 of 100. The AI's guard against a barrage brings it to 34. It is steep: at 0.8 he wins 4 of 100.
- **A bolt-only player beats a lights-only masher in 82 s** (median), and takes him from the brink to KO in 9 s: three enders, each 90 ticks after the last. Neither script defends. The levers are Game Design's: `barrage.immune`, `barrage.window`, `barrage.enderAfter`.
- **Windows count every tick,** hit-stop included (a bolt's hit stops for one tick).

## Left for later

- Combat's piece for the follow-up, and for a finisher that starts from range.
- §15 (wild deflects, the spray, mines, shots meeting buildings, explosions): not built.
- Whether `blast` and `barrage` are "by hand" for the Spite rally (`SimWounds.BY_HAND`, Simulation's).

## Data keys for Tools

| File | Keys |
| :--- | :--- |
| `data/director/interrupts.json` | `buried`: `reachBh` is gone; new `landByTick`, `burstWithinBh`, `dive` {`speed`, `minTicks`}, `blast` {`damage`}. `blast.heavy.knockFull` (boolean). `blast.barrage` {`enderAfter`, `window`, `measuredTicks`, `immune` (integers), `enderDist` {`measured`, `plain`}, `_note`} |
| `data/director/launch.json` | `setup` {`weight` {`default`, `blurPlain`, `barragePlain`, and any decisive kind; numbers, 0 or more}, `_note`} |
| `data/director/ai.json` | per level `buriedBurst`, `barrageGuard` (chances, 0 to 1) |
