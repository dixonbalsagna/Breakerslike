# Agency, slice 9: the wild deflect, the spray cone and mines (the director's side)

Owner: Encounter Systems Director. Date: 2026-10-03. Status: in the tree on HEAD `2af1915`, waiting for the EP's commit. Rules: `docs/design/agency-pass.md` §15.2 (the wild deflect), §15.4 (the spray), §15.5 and §17 (mines). The core's side is Simulation's (`docs/architecture/shots.md` §13 to §18), already in the tree behind its switches.

Everything here runs only in the `dynamic` profile.

## What changed

| Part | Rule | Where |
| :--- | :--- | :--- |
| **A deflect sends the shot wild** | Simulation's switch `deflect.scatter` is on: a deflected shot flies off to a seeded spot and explodes where it lands, and it still belongs to the shooter. The director's deflect calls are unchanged | `data/fight/shots.json` `deflect.scatter` (Simulation's, by the EP's grant: that one value) |
| **The free approach** | A perfect block of a shot gives him 45 ticks to start a charge or a lunge that no shot stops. A shot that meets him on it is shrugged off at half damage, whatever its power, and he keeps coming. It does not count for a barrage and a full charged shot does not knock him back | `blast.gd` `hit`; `bands.gd` `begin`; `interrupts.json` `blast.deflect.freeApproachTicks` |
| **The context deflect** | With guard held, the context press sets a deflect on the shot coming at him for 10 ki, with no timing. It sends the shot off as a perfect block does, with no ki back and no free approach | `blast.gd` `context`, `_contextDeflect`, `hit`; `interrupt.gd` `tick` |
| **The spray cone** | A bolt fired 10 ticks or more after his last seeks, and his spread recovers at 0.5 a second. Each bolt fired sooner adds 0.15 to his spread, up to 1. A bolt then still seeks with a chance of 1 − 0.6 × spread; otherwise it flies straight inside a cone at the rival (6 degrees at no spread, 18 at full) and explodes where it lands. The draw is keyed on the match seed and the shot's id | `blast.gd` `_fire`, `_spray`; `interrupts.json` `blast.spray` |
| **The AI spaces its volley** | The bolts of the AI's volley leave 10 ticks apart (was 6), so they are measured and keep seeking | `blast.gd` `tick`; `interrupts.json` `blast.light.aiGapTicks` |
| **Mines** | With the energy family held, the context press lays a mine where he is for 8 ki: on the ground when his feet are within 0.5 bh of it, else hovering. Within 3 bh of the rival the press is the energy shove's, which is not built: nothing happens. The cap, the gap between mines, the arming, the trigger, the fuse, the blast and the chain are the core's | `blast.gd` `layMine`; `interrupts.json` `blast.mine` |
| **A mine's blast on the rival** | It cannot be dodged or deflected. A held guard takes it at the guard's rate. Unguarded, on a fighter who is up and outside an exchange, it knocks him back from the mine and is decisive (kind `blast`): a set-up on the brink, and a finisher from range on an open rival | `blast.gd` `_mineHit`; `launch.gd` `knock` (a knock-back from a point) |
| **A blow on a mine** | A landed strike whose target's chest is within 60 units of a mine sets it off | `melee.gd` `strike` |
| **The AI lays mines** | In the far band with 40 ki or more, its attack beat is a mine on 2%, 4% or 6% of beats by level. It does not avoid mines | `ai.gd`; `ai.json` `mineShare`, `mineMinKi` |
| **A finisher's volley** | A cue beat that carries `volley` {`dmg`, `shape`, `count`} lands that damage on the other fighter, whatever he holds, and sends the cue `volley_fire`. It is for the rival's barrage beats (Combat's finisher row, not live yet); nothing uses it today | `exchange.gd` `_opCue` |
| **The medium AI, re-tuned** | `barrageGuard` 0.7 to 0.42 (the spray makes a spammer land fewer bolts), `guardRepeat` 5.5 to 5.0, and the firing share `blastShare` 0.18, 0.35, 0.45 to 0.2, 0.4, 0.5 (a deflected shot no longer comes back to hit its shooter, which took blasts to the band's floor) | `ai.json` |

**Not built, by the EP's ruling:** the energy shove. **Cues:** `mine_lay`, `mine_refused`, `context_deflect_set`, `context_deflect`, `volley_fire`. The core sends `shot_deflect` and `mine_trip`. No new decisive kind: a mine's knock-back is `blast`.

**No core lines.** One value of Simulation's data, by grant.

## Results

**Two scripted humans:**

| Case | Result |
| :--- | :--- |
| A bolt; P2 perfect-blocks it | The bolt flies wild, bound 11 bh away; P2 has a free approach for 45 ticks |
| P2 then lunges while P1 keeps firing | The bolt that meets him on the way is shrugged off; the lunge lands |
| A full charged shot; P2 holds guard and presses context | Deflected wild; it costs him 10 ki |
| Bolts every 6 ticks for 120 ticks | 20 fired, 7 sprayed wide, 13 hit; two barrage enders, both the weak one |
| Bolts every 12 ticks | 10 fired, none wide, 10 hit; the ender is the measured one |
| P1 lays a mine and backs off; P2 flies into it | It trips, blows 8 ticks later: 57 damage, a knock-back, decisive |
| The same into a held guard | 19 damage, no knock-back |
| Two mines 1 bh apart, then seven more moving back | The second is refused (too near); the seventh fizzles the oldest; six live |

**QA's harness** (`node qa/run-godot.js`, four arms, 100 matches an arm, the masher rows), on the build before the last two retunes (`barrageGuard` 0.45, `guardRepeat` 5.5):

| Row | Result | Band |
| :--- | ---: | :--- |
| KAI over both slots | 54.0% (51.0% from P1, 57.0% from P2) | 45 to 55% |
| Match length, median | 498.5 s | 360 to 480 s |
| First brink, median | 427.5 s | 270 to 420 s |
| Blasts' share of damage | 11.6% | 10 to 25% |
| Front-row structures lost | 57.0% | 25 to 50% |
| The masher against the easy / hard AI | 100 / 0 of 100 | |

88 bands pass, 18 fail, 22 pending.

**The two retuned rows on the final build,** with QA's scripts, 100 matches each: the masher against the medium AI wins 47 of 100 (band 35 to 50%), and the bolt-only player against the medium AI wins 31 of 100 (band 20 to 40%). On the build of the table above they read 36 of 100 and 23 of 100.

**100 AI matches** (my own probe, seeds 1 to 100; before is slice 8):

| | Before | After |
| :--- | ---: | ---: |
| Match median (mean) | 8:23 (8:17) | 8:19 (8:23) |
| KAI | 54% | 51% |
| Civilians lost, mean | 24.0% | 25.7% |
| Structures lost, mean | 42.8% | 43.6% |
| Blasts' share of damage | 11.1% | 11.6% |
| Craters a match | 29.4 | 37.9 |

In 25 matches: 3,851 bolts, 579 charged shots and 102 mines; 277 deflects; 159 shots ended on a building and 34 mines blew.

**Gates** on a clean copy of HEAD with exactly the tree's changes (parity again in the tree): goldens regenerated (9 matches, 175,559 ticks); parity, the loader check at 200 matches, `npm test` 5 of 5, determinism, seam, the animation check, the cue check, Controls' input tests and its mash probe (6 of 6) pass. The validator shows the keys below as its only errors until Tools' schema script is applied.

## Notes

- **What moved on the way.** With the spray and the wild deflect at slice 8's numbers, blasts fell to 9.4% of damage and the bolt-only player to 4 of 40 against the medium AI. The AI's spaced volley and a step of firing share bring blasts back; the barrage guard brings the bolt-only row back: 0.7 gave 10 of 100, 0.5 gave 20, 0.45 gave 23, 0.4 gave 39, 0.3 gave 50.
- **KAI's share is noisy at this sample.** It read 45% on one build of this slice and 54% on the next, which differed by a step of firing share and of barrage guard; with the wild deflect switched off it read 49.5%.
- **The match median.** It is about 20 s over its band and this slice does not move it (498.5 s; 494.6 s and 504.4 s on the two earlier builds of the slice). The lever in the director's data is the AI's firing share: each 0.1 of it is worth about 10 s of the median (slice 7: 0.2 gave 7:49, 0.35 gave 8:18, 0.5 gave 8:26), and it costs the blasts' share, which sits at 11.6% against a floor of 10. The wear rate k was tried once at +5% (353): the first brink came 23 s sooner (404 s) but the brink to KO was 22 s longer, and the median over two arms was 507.6 s, so it is not a clear lever at 200 matches.

## Data keys for Tools

| File | Keys |
| :--- | :--- |
| `data/director/interrupts.json` | `blast.light.aiGapTicks` (integer); `blast.deflect` {`freeApproachTicks`, `context` {`ki`}, `_note`}; `blast.spray` {`measuredTicks`, `perBolt`, `max`, `missShare`, `slopeMin`, `slopeMax`, `recoverPerSec`, `_note`}; `blast.mine` {`enabled`, `kind`, `ki`, `shoveWithinBh`, `groundWithinBh`, `blowR`, `_note`} |
| `data/director/ai.json` | `mineMinKi`, note `_mine`; per level `mineShare` |
| `data/fight/shots.json` | `deflect.scatter` true (no new key) |

## Left for later

- The energy shove (the context press inside 3 bh with the energy family held).
- A wild shot that meets its own shooter takes the core's plain rule (its damage, and it ends), not the director's.
- The AI avoiding mines, and clearing them by shooting.
- The splitting shot, the rain and the curving shot (§15.5): new kinds in the core first.
