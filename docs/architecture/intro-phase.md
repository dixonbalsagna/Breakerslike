# The intro phase: the crater-landing entrance and the staredown

Owner: Simulation and Engine. Status: plan, docs only (2026-10-02). It answers Camera's ask in `docs/camera/rule-of-cool-shots.md` row 7: a skippable window before the clock, with four events.

## 1. What it is

A run of **pre-clock ticks** at the start of a match, built like a pause (`SimPause`): `SimCore.step` returns false, `S.T` stays 0, no input is consumed and nothing else in the sim runs. Inside it the sim plays a fixed timeline: each fighter falls from the sky and lands in a crater, they stare, the clock starts.

- **It is a match setting.** `newMatch`'s setup takes `"intro": true`. Without it a match starts as today, so the goldens, the batch and QA's harness do not change. The setup is in the replay header, so a replay plays the intro it was recorded with.
- **It is scripted, not simulated.** A fall is a closed-form path from `fall_from_y` to the ground over the fall's ticks; no flight physics, no draw. The fighter is in a new state, `intro`, in which `stepFighter` does nothing.
- **The landing is real.** At the touchdown tick the fighter is placed on the ground and World digs the crater (`WorldCrater.dig` with an entrance energy). The spots are the start positions, which are on open ground clear of every town, so there is no collateral.

## 2. The timeline (data, `data/fight/intro.json`, in ticks)

Camera's shot is about 5 s. Its beats become the data's defaults:

| Beat | Tick | Event |
| :--- | ---: | :--- |
| The intro starts; A's fall starts | 0 | `intro_start {dur, skip_ok}`, `entrance_fall {actor, x, y, z, fall_from_y, dur}` |
| A lands | 36 | `entrance_land {actor, x, y, z, fall_from_y, r}` |
| B's fall starts | 84 | `entrance_fall` |
| B lands | 114 | `entrance_land` |
| The staredown | 144 | `staredown_start {dur}` |
| The clock | 300 | `clock_start` |

- `entrance_fall` is an addition to Camera's four: it comes when a fall starts and carries the height and the fall's length, so Camera can frame the sky before the landing and not chase it.
- `r` is the crater's radius, from the dig.
- The file also holds the fall height and the entrance crater's energy. Tools adds the schema; the file joins the replay's data hash.

## 3. Skip

- **Any press skips.** On a pre-clock tick the sim looks at the intents passed to `step`: a press edge on any human slot (light, heavy, signature, guard, dodge, power or transform) skips. The recorder already records intents on every tick, frozen or not, so a skip replays with no change to the replay format. An AI slot never skips; a host showing an AI demo can skip by passing one intent.
- **A skip changes nothing in the fight.** The remaining landings are applied at once, in order (both craters dug, both fighters placed), then `clock_start` is sent. The state at the clock is the same whether the intro ran or was skipped; only the tick count differs.
- `skip_ok` is false for the first few ticks (data), so a press held from the menu does not skip.

## 4. State, hash, events

- `S.intro` (integers, hashed): `left` (ticks to the clock), `t` (ticks played), `landed` (a bit per slot).
- `Fighter.state` gains `intro`.
- Five events: `intro_start`, `entrance_fall`, `entrance_land`, `staredown_start`, `clock_start`.

## 5. Who does what

| Who | What |
| :--- | :--- |
| Simulation | `sim/core/intro.gd` (`SimIntro`), `S.intro`, the check at the top of `SimCore.step` (ahead of the pause), the setup key, the events, the parity checks |
| World | The entrance crater: its energy, and a check that the two spots are open ground. Camera asks for at least 900 units between them; `START_GAP` is 750 today (below) |
| Camera | The shot, from the events. It writes nothing |
| UI | The HUD hidden until `clock_start`; the skip prompt |
| Controls | Confirm "any press skips", and the host passing intents before the clock |
| Tools | The schema for `intro.json` |

## 6. Proof and goldens

- With no `"intro"` in the setup nothing changes: parity on the untouched goldens.
- One golden match and one replay with the intro are added (new vectors; the existing ones do not move), plus forced checks: the timeline's ticks, a skip at several ticks giving the same state at the clock, no input consumed, `S.T` at 0 until the clock.

## 7. Rulings (EP, 2026-10-02)

1. **`START_GAP` goes to 900 for every match,** in the intro slice, with one golden regeneration.
2. **QA's batches run the intro, skipped at once,** when the intro ships, so they measure the same opening as the game.
3. **Either player's press skips for both** (Camera's plan).

Order: after World's ground-contact slices (G2 to G5), before the last stand.

## 8. Prepared (2026-10-02)

Built and proven in a scratch copy of 3fca9ac and parked in `docs/architecture/pending/` (`intro.gd`, `intro.py`; the README has the steps and the proofs). As built: the module is `SimIntro`; the setup's `"intro"` is `true` (play it) or `"skip"` (apply its effects at once, with no pre-clock tick: for batches and probes); a fighter in the intro has the state `intro`; the crater is World's `WorldCrater.dig` with the data's `craterEnergy` (1.5 for now: World's number to tune). The state at the clock is identical whether the intro ran, was skipped at any tick, or was applied by the setup's skip (a parity check).

**The default (EP, 2026-10-02).** A setup without the key gets `"skip"`: the match starts from the intro's end state with no pre-clock tick, so the game, the batches, QA's harness and the goldens share one opening. `"intro": true` plays it (the host passes it once Camera, Animation, Rendering and UI are ready); `"intro": false` is the old flat start. A is the fighter on the left start spot, and the entrance craters have no owner.

**Effects during the intro (Rendering, 2026-10-02).** The `tick` mark on an intro tick says `frozen: false`: effects run at full speed, so the landing's dust settles, while the sim holds exactly as in a pause (no clock, no mood, no cooldowns, no input consumed, `step` returns false). A host tells an intro tick from a live one by the step's return value or by `S.intro.left`.

