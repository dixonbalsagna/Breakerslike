# What the director owes the first real moveset (M0), and what fits before it

Owner: Encounter Systems Director. Date: 2026-10-02. Status: plan only. Sources: Combat's `docs/combat/m0-rich.md`, `wave1-strikes.md` §6 and `wave2-entries.md`; Animation's `docs/animation/review-plan.md`; QA's reach row; Game Design's `moveset-rules.md` §11.

Each row says where it lands: **step 3** (the control-scheme slice now parked in `pending/step3/`), a **small slice** of its own that needs no composer, or **M0** (with the composer and Combat's pieces).

## 1. From QA

| Item | Plan | Lands |
| :--- | :--- | :--- |
| One strike in 16,670 beyond reach: a PURSUIT — CAUGHT heavy at 688 u (`738add7`) | The placement limit is 3 reaches plus two ticks of the target's flight. A sprinting target is not "in flight", so its speed is not counted today. When QA names the seed I replay it; the likely fix is to count the target's speed in any state, not only when launched. The OUT OF REACH feed line should already name this strike | Small slice |

## 2. From Combat

| # | Need | What the director does | Needs from others | Lands |
| ---: | :--- | :--- | :--- | :--- |
| 1 | A `path` on the `rush` op: **arc** (apex a quarter of the distance, at most 4 bh), **ground** (the last 30% a slide) and **spiral** (the blitz, and the ping-pong's intercept) | The op passes the shape and its numbers to the move; `sideOff` and the contact placement are unchanged, because a path changes how a move travels and not where it ends | Simulation: the move's stepper is `SimFighter.stepRush` and `SimState.Rush`, which are straight lines today. The shapes need fields there (shape, start, apex) and the stepping. Camera has framing plans for the curved rush | M0. The arc alone could come earlier if Simulation has the slot |
| 2 | Per-strike contact distance from the filling piece: three bands (58 u, 50 to 54, 32 to 38), with `contact.clinch` 32 u as the floor for clinch pieces and `minSeparation` 45 u for every other move | `_contact` places the striker at the strike's own offset (`o.offset`) when the piece gives one, else `contact.offset`. `sideOff` and `contactTick` use `clinch` as the floor while a clinch piece is running and `minSeparation` otherwise. The reach check compares against the strike's band | Combat: `o.offset` (or the band) on the strike, `contact.clinch` in the block. Tools: schema | Small slice: reading `o.offset` and `clinch` needs no composer |
| 3 | The limb filter and the alternate-limb rule | The composer drops pieces whose limb is broken and takes the alternate under a break (`spec-wounds.md` §1d). The same choice fixes the wound region at plan time (`contact-plan.md`, last section) | Simulation: the region accepted from the strike | M0 |
| 4 | Six new beat ops: `pulse`, `hold`, `throw`, `answer`, `meter`, `stance` | `pulse`: a clash pulse (window, surge, lockout; `tech-and-pulse-input.md` §2). `hold` and `throw`: the held state and its release (the turning throw, grabs). `answer`: the beam answer's look by the direction held. `meter`: a fighter meter change on a beat. `stance`: a held-state change inside a phrase | Simulation: the held state (item 7) and the clash state (item 5). Controls: `hub.set_clash` | M0. `answer` can come with step 3's DEFLECT if Game Design confirms the direction is sampled at contact |
| 5 | The clash score as readable state | Today a clash is decided when it starts (`S.game.clash.aw`). With pulses the two scores live in the clash state and change on each surge; the winner is read at the resolve tick. The tie rule is `moveset-rules.md` §11(c): a tie only when the scores differ by less than 10 | Simulation: two score fields and the pulse index in `SimState.Clash`, hashed. Controls: the pulse windows as data | M0, with `pulse` |
| 6 | The composer's join rule: a phrase changes range band at most once | A check when pieces are joined: count the band changes along the phrase and reject a second one | | M0 |
| 7 | The `return` strike class (ruled, §11(b)) | Step 3 already reads the window per class from data, and `return` is in it (6 ticks, no early tolerance). The ×0.6 damage is the piece's | | Step 3 has the window; the blow itself is M0 |
| 8 | The turning throw (ruled, §11(d)) | The planner offers a brunt target behind the launcher only as a turning throw: after a heavy, an ender, a guard break or a finisher strike, scored above every target in front after the turn's penalty. 10 ticks held, no ki | Simulation: the held state. World: the brunt aim from the release point | M0 |

## 3. From Animation

| Need | Plan | Lands |
| :--- | :--- | :--- |
| A `react` field (0 to 1.6): how hard the body reacts to a blow | The cheap form is `o.react` on the strike beat: the director copies it from the piece (or from the template's strike until pieces exist), and the animator reads the beat as it already does. No sim change and no new event. On the `damage` event it would be Simulation's line | Small slice, as soon as Combat has the numbers. Until then force from damage stays |
| A `held` state for throws: holder, socket and release tick | A fighter state, set by the `hold` op and cleared by `throw` or by a break-out. The held fighter can't act, and its position follows the holder's socket each tick | M0, with `hold` and `throw`. It is Simulation's state |

## 4. What step 3 already carries toward M0

- The window per strike class, as data, including `return`.
- Staleness, the riposte, the punish window, and the AI's levels (`ai.json`).
- `DirBeam.inClash(S, f)`: the "slot is in a live clash" read for Controls, and clash presses no longer queue as attacks.
- A per-fighter integer array for the director (`act.dirI`, Simulation's two lines), which the pulse lockout and the held state's timers can also use.

## 5. Order I would take

1. Step 3, the slam lever and the queue tie-break (parked, in that order).
2. The small slices: the reach fix when QA names the seed, `o.offset` and `clinch`, `o.react`.
3. With Simulation's slot: the arc path, the clash state, the held state.
4. M0: the composer (limb filter, join rule, region at plan time), the six ops, the turning throw.
