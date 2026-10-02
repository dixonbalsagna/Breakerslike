# Agency, slice 2: the exchange starts at the wind-up, and the three bands

Owner: Encounter Systems Director. Date: 2026-10-02. Status: in the tree on HEAD `d732355`, waiting for the EP's commit. Rules: `docs/design/agency-pass.md` §1 and §3. Items 1a and 1b of `agency-plan.md`, with the upright slide from §3.

Everything here runs only in the `dynamic` profile. The old profiles are unchanged.

## What changed

| Part | Rule | Where |
| :--- | :--- | :--- |
| **The bands** | Close is within 3 bh, mid is 3 to 12 bh, far is beyond. The distance is centre to centre: the shortest arc and the height together | `bands.gd` `band`, `dist`; `interrupts.json` `bands` |
| **A close press** | The exchange starts at once, as before | `exchange.gd` `_start` |
| **A press from farther off** | Only the attacker's approach starts: a lunge in the mid band, a flight in the far band. No exchange exists. The rival is free: he can move, guard, dodge, press or fire. The approach ends 2.5 bh from the rival, on the attacker's own side and at the rival's height | `bands.gd` `begin` |
| **The engage** | When the approach ends, the exchange is planned from where both stand and what the rival is then doing, exactly as a close press is. The wind-up follows: 15 ticks for a light, 20 for a heavy | `bands.gd` `_engage` |
| **The rival's answer** | His guard, dodge, sprint or charge is read at the engage. His attack press during the approach waits and counts as his answer (a trade or a clash). His signature starts at once and ends the approach | `exchange.gd` `_start`, `_queues` |
| **The attacker on the way** | His dodge calls the approach off for nothing. A hold upgrades the press to a heavy. His later presses wait as his chain links | `bands.gd` `cancel`, `upgrade` |
| **Openings** | A riposte, a reversal or a punish from outside the close band approaches too, and keeps its opening for the engage | `bands.gd` `begin`; `exchange.gd` `planOpen` |
| **Slopes and a moving rival** | The end point follows the rival each tick. On a slope it is brought in until the pair is inside the close band | `bands.gd` `_endOff`, `tick` |
| **The AI** | It presses nothing while an approach is on, and it does not roam off while the rival approaches: it answers by its stance | `ai.gd` |
| **The upright slide** | A ground knock-back under 4 bh (tier 1's 3.5) is carried back upright by the director over 18 ticks: no launch, no journey, no trench. At 4 bh and over it is still the skid, and its launch plan now carries `slide: "feet"` and the distance for World | `launch.gd` `knock`; `launch.json` `knockBack` |
| **A heavy's wind-up** | A heavy's least approach was compared in seconds, so a close heavy wound up in 15 ticks. It is 20 now, as ruled | `data.gd` `_approachTicks` |

**No core lines.** The approach lives in the fighter's own director state (three integers) and in his rush. Nothing in `sim/core` changed.

**Events.**
- The `attack` event now fires at the engage, complete as before. A cancelled approach sends none.
- The approach is announced by the existing `rush` event (actor, target, end tick) with no exchange running.
- A ground knock-back sends the cue `slide_brace` (Combat's name).
- New feed lines: `LUNGE`, `FLIES IN`, `APPROACH ENDS`.

**The interim far press.** Until the taunt (1c) and the held charge (1d) are built, a tap in the far band flies in at about the speed it had. The charge's own flight times (0.5 to 2 s) come with the hold.

## Results

100 AI matches, seeds 1 to 100. Before is HEAD `2c4c0de` (nothing in the sim changed between it and `d732355`).

**Gates** (on a clean copy of HEAD with this slice's files; parity again in the tree): goldens regenerated (9 matches, 180,540 ticks), parity, the loader check at 200 matches, `npm test` 5 of 5, determinism, seam, the touch test, the animation check and the cue check pass. Controls' mash probe fails its two latency checks by design: they expect an exchange on the press tick from 12 bh, where a press now starts an approach. The validator shows three errors, the new keys below.

| | Before | After |
| :--- | ---: | ---: |
| Melee exchanges that began with an approach | 0 | 65.5% (mid 27.1%, far 38.4%) |
| Apart as a melee exchange starts, median | 6.75 bh | 2.5 bh |
| ... 99th percentile | 601 bh | 2.93 bh |
| ... largest | 1,010 bh | 3.36 bh |
| Exchanges starting more than 3.2 bh apart | 64% | 3 of 20,857 |
| Strikes from out of reach | 0 | 0 |
| Time both fighters are locked in an exchange | 55.3% | 45.6% |
| Time in an approach (the rival free) | 0 | 11.2% |
| Approach length: mid, median (p10 to p90) | | 5 ticks (3 to 10) |
| Approach length: far, median (p10 to p90) | | 28 ticks (13 to 90) |
| How far the rival moved while it came, median (p90) | | 1.1 bh (13.8) |
| Melee exchanges a minute | 25.9 | 24.7 |
| Match median | 8:18 | 8:33 |
| KAI | 58% | 59% |
| Civilians lost, mean | 22.3% | 22.7% |
| Structures lost, mean | 38.3% | 40.6% |
| Launch share of exchanges reaching a launch decision | 28.5% | 28.4% |
| Knock-backs a match | 20.7 | 21.7 |
| Ground knock-back at tier 1, median (target 3.5 bh) | 5.0 bh | 3.5 bh |

| What the defender was doing at the start | Before (50 matches) | After |
| :--- | ---: | ---: |
| Nothing (NEUTRAL) | 35.1% | 33.8% |
| Guarding | 22.8% | 23.7% |
| Dodging | 15.9% | 15.8% |
| Pressing (AGGRESSIVE) | 13.7% | 15.6% |
| Escaping | 12.6% | 11.1% |

**Two scripted humans** (P1 presses, P2 answers only once P1 is coming):

| Case | Result |
| :--- | :--- |
| Close, 2 bh | The exchange starts on the press tick; first blow at 15 ticks |
| Mid, 8 bh | A 6-tick lunge; the exchange starts 2.6 bh apart; first blow at 21 ticks |
| Far, 20 bh | A 19-tick flight; first blow at 34 ticks (38 for a heavy) |
| P2 guards once P1 is coming | PRESSURE: GUARD HOLDS |
| P2 sprints away | PURSUIT: CAUGHT |
| P2 presses light | TRADE BLOWS |
| P2 presses heavy against a heavy | HEAVY CLASH |
| P2 dodges as P1 arrives | DODGE: CLEAN |
| P2 fires its signature | P1's approach ends; P2's beam starts |
| P1 dodges on the way | The approach ends; no ki spent |
| P1's hold upgrades the press on the way | The exchange is a heavy |

P2 stayed free through every approach.

## Notes

- **Two earlier measurements were worse and were fixed.** With the charge's flight times on a tap, matches ran 9:40 and structures lost rose to 51%. With the AI still roaming during a rival's approach, KAI fell to 45% and structures lost were 44%.
- **The chain link's catch is unchanged:** a link still closes on a launched rival within 2,500 u in 12 ticks. It is a move inside a string, not a press from range.
- **The upright slide does not stop at an obstacle.** The bump is World's.
- **The AI does not yet use the free time on purpose.** It keeps its stance timer; a rival's approach does not make it guard or dodge more.
- **The perfect block's lockout is as it was:** a guard press during the approach is outside any window and starts the 20-tick lockout.

## Data keys for Tools

| File | Keys |
| :--- | :--- |
| `data/director/interrupts.json` | `bands`: `enabled`, `closeBh`, `midBh`, `engageBh`, `lunge` {`speed`, `minTicks`, `maxTicks`}, `far` {`light`, `heavy`, each {`speed`, `minTicks`, `maxTicks`}}, `_note` |
| `data/director/launch.json` | `knockBack.slideUnderBh`, `knockBack.slideTicks`, `knockBack._slide` |
