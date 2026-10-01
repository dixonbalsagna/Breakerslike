# The last stand: a free signature at the first brink

Owner: Simulation and Engine. Status: plan, docs only (2026-10-02). It builds Game Design's rule in `docs/design/spec-wounds.md` section 1b, point 7 (Orb's pick; Legal's re-screen is pending).

## 1. The rule

The first time a fighter reaches the brink in a match, his signature is free and off cooldown for 20 s. The rival answers it like any signature, and a signature that lands is a decisive win. A second brink (after a Rally) gives nothing.

## 2. In the sim

**State (per fighter, hashed):**
- `lastStandUsed: bool`: he has had his last stand this match.
- `lastStandLeft: int`: live ticks left in the window (0 when closed).

**Where it opens:** `wounds.gd`, where the brink is entered (the `brink_enter` event). If `lastStandUsed` is false: set it, set `lastStandLeft` to the window, and send `last_stand_ready {actor, dur}`.

**Where it counts down:** `stepFighter`, one a live tick in which he is free or charging (ruling 2). It does not run during a pause or a hit-stop. At 0: `last_stand_end {actor, kind: "expired"}`.

**One reader:** `SimFighter.sigFree(f) -> bool` (`lastStandLeft > 0`).

**The window closes when he fires.** One free signature, not as many as fit in 20 s: firing sends `last_stand_end {actor, kind: "used"}` and sets `lastStandLeft` to 0. The ordinary cooldown starts from that signature as from any other. (If Game Design wants the window to stay open after a use, it is one line.)

**Data:** `lastStand.windowS` (20) in each fighter's `wounds.json`, with Tools' schema in the same commit. 0 switches it off.

## 3. Encounter's lines

The signature's gates are in the director. Each needs the free case:

| Where | Today | With the last stand |
| :--- | :--- | :--- |
| `exchange.gd` `_start`: `A.ki < 45` | dropped, "NEED 45 KI" | not when `sigFree(A)` |
| `exchange.gd` `_start`: `S.T < A.sigReadyT` | dropped, "SIGNATURE RECHARGING" | not when `sigFree(A)` |
| `exchange.gd` `_start`: `A.ki -= 45`, `sigReadyT = ...` | the cost and the cooldown | when free: no cost; the cooldown still starts; call `SimFighter.lastStandUse(S, A)` |
| `beam.gd`: the answered signature (`canSig`, the queue's SIG at lines 35 and 95) | needs 45 ki and the cooldown | the same three changes |
| `ai.gd`: the AI's signature pick (`ki >= 50`, the cooldown) | | the AI takes its last stand: pick when `sigFree(f)` |

Camera's cut, the face cut-in and the line read `last_stand_ready`. Narrative asked for `actor` on that event; it has it.

## 4. Proof and goldens

- **Neutral first:** the code with `windowS` 0 passes parity on the untouched goldens.
- **Then the flip** to 20: a behaviour change, one golden regeneration. QA's signature band becomes 2 to 5 a match (Game Design), and brink-to-KO and finisher survival will move.
- **Checks:** the window opens once per fighter per match, not on a second brink; it counts live ticks only; a free signature costs no ki and ignores the cooldown; it closes on use.

## 5. Rulings (EP, 2026-10-02)

1. **One free signature.** The window closes when he fires (section 2 as written).
2. **The 20 s start when he is next free.** If he reaches the brink launched, stunned or locked in an exchange, the count waits: `lastStandLeft` is set at the brink, and it counts down only on live ticks in which he is free or charging.
3. **Legal has cleared it** (`docs/legal/rule-of-cool-screen.md`, the follow-ups), so it lands when its turn comes: after World's ground-contact slices and the intro phase.

## 6. Prepared (2026-10-02)

Built and proven in a scratch copy of 3fca9ac and parked in `docs/architecture/pending/` (`laststand.py`; the README has the steps and the proofs). The AI takes its last stand at its first attack beat inside the window (Encounter's line to tune). In 100 matches: 1.45 last stands a match, 141 of 145 used, 3.38 signatures a match.

## 7. As built (2026-10-02, on 15be796)

`Fighter.lastStandUsed` and `lastStandLeft` (hashed), `SimFighter.lastStandOpen`, `sigFree` and `lastStandUse`, the count in `stepFighter`, `lastStand.windowS` 20 in both fighters' `wounds.json` with Tools' schema, the two events. Encounter's gates, by grant: `exchange.gd` (the ki gate, the cooldown gate, the cost), `beam.gd` (the AI's answer and the queued answer), `ai.gd` (the AI takes its last stand at its first attack beat in the window).

**Proofs, in the tree:** with the window at 0 and the gates in, parity matches every match on the goldens before it (only the roster data hash differs); hashed, the light digests are identical; then the window goes to 20 s. The parity check "the last stand" runs the rules and one free signature end to end through the director.

**100 matches** (default arm, with the whole slice): 1.45 last stands a match, 142 of 145 used; 3.66 signatures a match (band 2 to 5).

