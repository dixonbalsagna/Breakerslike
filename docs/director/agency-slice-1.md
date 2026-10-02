# Agency, slice 1: the earned launch, the knock-back, the attacker's cancel and the press log

Owner: Encounter Systems Director. Date: 2026-10-02. Status: in the tree on HEAD `9a0b207`; goldens regenerated on a clean copy of that HEAD with only this slice's files (Controls has input work in progress in the tree). Rules: `docs/design/agency-pass.md` §1 to §3 and Orb's questionnaire 14.

Everything here runs only in a profile with a contact block (`dynamic`). The old profiles are unchanged.

## What changed

| Part | Rule | Where |
| :--- | :--- | :--- |
| **The earned launch** | A launch beat launches only when earned, by Orb's four: a held heavy that lands; a heavy after four or more of the string's strikes landed; a heavy pressed with a stick direction that lands clean (the striker has taken at most one blow in the exchange); a clash won. A guard break and a riposte end in a knock-back. Signatures, finishers and break launches are outside it | `launch.gd` `earned`; `melee.gd` `launchBeat`; `launch.json` `earned` |
| **Not earned** | A heavy gives the knock-back. A light leaves both fighters in reach, and the chain window still opens: the brawl goes on | `launchBeat` |
| **An earned launch always launches** | With the gate on, "no launch" no longer competes against an earned launch. With the gate off it competes at a score in data, as the planner's NONE did | `launch.gd` `chooseLaunch`; `knockBack.score` |
| **The stick picks the direction** | For a human's blow, only launch candidates within 45 degrees of the stick's tilt at the press compete, and the planner picks the most dramatic of them. A tilt back through the launcher keeps only its up or down part. With no tilt, or for the AI, the planner is free | `chooseLaunch` |
| **The knock-back** | 3.5, 5, 6.5 and 8 bh by the striker's tier. On the ground it is a low send with no travel boost that the ground-contact model skids, so it leaves dust and a trench. In the air or over the sea the rival is carried back that far over 20 ticks, upright. No chain window opens after it | `launch.gd` `knock`; `launch.json` `knockBack` |
| **The attacker's free cancel** | His dodge-cancel costs nothing until his first wind-up starts; it starts a 30-tick gap in place of the 3 s cooldown | `interrupt.gd` `dodgeCancel`; `interrupts.json` |
| **The arrival side** | A human who holds the stick up or down as he presses comes in over (or under) the rival and lands on the far side | `melee.gd` `approachOver`; `interrupts.json` `arrival` |
| **The press log** | Every attack press of each fighter, with its weight, family, direction, tilt and rhythm (held, mashed, timed), in a ring of 20. The window is the last five, each alive for 90 ticks. A feed line as each exchange starts shows both windows. No string is chosen from it; the earned launch reads how the phrase's own press was made | `alchemy.gd` (new) |
| **The AI's presses** | The AI's stick is its flight path, so its launch intent is a number: the chance its heavy is thrown to launch, and the chance it charges one. Its chain press is a heavy once four of the string have landed. Every press the director makes for it goes through the log | `ai.json` `launchIntent`, `heldHeavy` |
| **QA's far strikes** | A body that came to rest on the strike's own tick (it hit a wall) is still a catch: the striker is placed | `melee.gd` `_contact` |
| **Combat's hooks** | Beat ops `knockBack` and `stagger`. A launch beat's `ends: "level"` never sends the rival away, and `sends` keeps only the launch candidates in that direction | `exchange.gd` `runBeat`; `launch.gd` `SENDS` |

**Names.** The planner's "no launch" is now `KNOCK BACK` in the `launch_plan` event (it was `NONE`), and a launch beat that keeps the brawl going sends `STAY`. Both are not launches.

## Results

100 AI matches, seeds 1 to 100. Before is HEAD `8fd6aba`.

| Of the exchanges that reach a launch decision | Target | Before | After |
| :--- | :--- | ---: | ---: |
| End in a launch | about 30% | 74.2% | **28.6%** |
| End in a knock-back | | 25.8% | 22.4% |
| Stay in reach | | 0 | 49.0% |

| | Before | After |
| :--- | ---: | ---: |
| Launches per exchange, QA's way (planner launches over all exchanges; band 25 to 35%) | 52% | 23% |
| Launch events a minute | 13.0 | 7.6 |
| Knock-backs a match | 31.1 (shoves) | 22.5 (6.2 skids on the ground, 16.3 in the air) |
| Exchanges that stay in reach, a match | 0 | 68.7 |
| Melee exchanges a minute | 23.3 | 26.1 |
| Match median | 7:12 | 7:58 |
| KAI | 51% | 49% |
| Civilians lost, mean | 17.7% | 20.0% |
| Structures lost, mean | 29.7% | 36.4% |
| Craters a match | 38.5 | 29.4 |
| World's slides a match | 50.4 | 30.3 |
| Impact's share of damage | 14.5% | 10.9% |

| Knock-back distance, bh | Tier 1 | Tier 2 | Tier 3 | Tier 4 |
| :--- | ---: | ---: | ---: | ---: |
| Target | 3.5 | 5 | 6.5 | 8 |
| On the ground, median (p10 to p90) | 5.1 (2.0 to 6.4) | 5.7 (2.6 to 11.6) | 6.8 (2.8 to 14.5) | 8.6 (3.5 to 14.6) |
| In the air | 3.5 | 5.0 | 6.5 | 8.0 |

**A scripted human** (in the tree):
- *The cancel:* a dodge 3 to 7 ticks into a ranged approach ended the exchange 4 times in 4. Three cost nothing; the fourth had already begun its wind-up and paid 15 ki.
- *The arrival:* with the stick held up, 3 approaches of 3 ended on the far side, in reach.
- *The stick and the launch:* a heavy with the stick up and toward the rival, pressed every 40 ticks for a minute in 12 matches: 57 launches earned (47 by the stick, 10 by a clash), sent as UPPERCUT 33, SMASH ACROSS 15, MOUNTAINSIDE 4 and BUILDING SMASH 2, and none downward; 41 knock-backs (guard breaks, and heavies that were not clean).

**QA's far strikes:** its three default-arm seeds (31, 449, 721) show none now, and a scan of 150 matches shows none.

## Notes

- **The AI is at full launch intent** (medium 1.0) and still lands under the band by QA's count (23% against 25 to 35%). The rules are for a player's choice; what is left to tune is how clean the heavy has to land (`cleanTaken`), the ender's count (`enderAfter`), and the AI's share of heavies, which I did not touch because QA is measuring wounds.
- **Launch wear.** Launches are fewer, so impact fell from 14.5% to 10.9% of damage even with the earned launch's force at ×1.6 (`earned.forceMul`). The wear per impact is World's number (`contact.json` `wear.perSpeed`); QA sizes it.
- **Structures lost rose** to 36.4%: the launches that remain are harder, and matches are 46 s longer.
- **The ground skid runs long at tier 1** (5.1 bh against 3.5): the contact model skids only above a speed of 900. Game Design's upright slide under 4 bh is a director-moved slide, which this slice has only in the air.
- **Matches are 46 s longer.** QA re-tunes k.

## What it covers of Combat's brawl data

| Combat's ask (`docs/combat/pending/brawl-endings-and-trades.md`) | This slice |
| :--- | :--- |
| Chain links that do not launch by themselves | Yes: a link's launch beat goes through the gate |
| The `knockBack` op | Yes, with the distance by tier. Not yet its four kinds (short slide, long slide, bump, drift) or their timings |
| The `stagger` op | Yes |
| `ends` and `sends` | `ends: "level"` and the `sends` filter are read at a launch beat |
| `hold`, `drop` | No (M0) |
| The seven strike arguments | `o.react` passes through untouched. The rest no |
| Two strikes on one tick | No |
| The `knockback` event | No: Simulation's. Today a ground knock-back sends `launch_plan` with `KNOCK BACK` and then a `launch` event |
