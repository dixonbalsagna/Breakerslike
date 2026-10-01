# Stage C test scripts (sticky weight and signature intent)

> **Superseded in part by ADR 0008 (2026-09-30):** the weight and signature scripts (C1 to C17) are replaced by the tests in `input-scheme.md` section 10. The holds, the Encore and the acknowledgement scripts (C18 to C22) are adapted there. See [input-scheme.md](input-scheme.md).

Owner: Controls and Game Feel (draft). Audience: QA, Encounter Systems. Date: 2026-09-30. Status: draft skeletons; they run when Stage C exists. Spec: `stage-c-spec.md`. Tests live in `sim/input/test/` (my path) and use the public sim API: `SimCore.createSim`, `SimCore.newMatch(S, seed, ai)`, `SimCore.step(S, inputs)` with `inputs = [SimIntent, SimIntent]`, and `S.fighters[k]`.

## 1. Harness (shared by every script)

```
extends SceneTree
# helper: run n ticks with a per-tick callback that returns [intent0, intent1]
func run(S, n, cb): for t in n: SimCore.step(S, cb.call(t))
func idle(): return SimIntent.new()          # neutral
func press(field): var i := SimIntent.new(); i.set(field, true); return i
```

- Both fighters start with `ai = {}`-less human slots where a script needs to control them, and `SimCore.toggleAI` turns a slot to AI only where noted.
- A script ends with `quit(0)` on pass and `push_error` plus `quit(1)` on fail, and prints one line per assertion, so QA's runner can count them.
- Each script also runs **twice** with the same seed and compares `SimHash.stateHash(S).gameplay` (determinism).

## 2. Scripts

| Id | Name | Setup | Steps | Assertions |
| :--- | :--- | :--- | :--- | :--- |
| C1 | Weight starts light | new match, seed 1 | run 5 idle ticks | `f.weight == 0` for both |
| C2 | Weight sticks | seed 1, slot 0 human | tick 10: heavy pressed; run through three exchanges (the director attacks) | `f.weight == 1` throughout; the feed shows HEAVY strikes for slot 0 only |
| C3 | No-op on the current weight | slot 0 in light | tick 10: light pressed | weight stays 0; `press_ack weight_light` is emitted once |
| C4 | Same-tick tie | slot 0 | tick 10: light and heavy both true | `f.weight == 1` (heavy wins) |
| C5 | Heavy fallback | slot 0 heavy, ki forced to 3 | run until the director attacks | the strike is a light, `press_ack weight_fallback` emitted, `f.weight` still 1, ki unchanged by 4 |
| C6 | Signature queue and cancel | slot 0, ki forced to 10 | tick 10: sig pressed; tick 30: sig pressed | `sigQueued` true after tick 10, false after tick 30; events `sig_queued` then `sig_cancelled`; no ki spent |
| C7 | Unfunded signature waits | ki 0, sig pressed, no charge | run 300 ticks | `sigQueued` still true; no signature fired; `sig_funded` not emitted |
| C8 | Expiry | ki 0, sig pressed, no charge | run 601 ticks | `sigQueued` false at tick 601; `sig_expired` emitted once; clock started at the press |
| C9 | Funded fires within the cap | ki forced to 100, sig pressed, seed set | run 400 ticks | a signature exchange starts within **180 ticks of `sig_funded`** (paused ticks excluded); ki drops by 45 at the fire; `sig_fired` emitted; weight back to the latched value |
| C10 | The cap pauses during charge | ki 100, sig pressed, then hold `charge` from tick 5 to tick 205 | release at 205 | no attack during the hold; the funded clock read at release is under 180, not 200 plus; the signature fires within the remaining cap |
| C11 | Cap pauses in an exchange | ki 100, sig pressed while the opponent's exchange is running | | the clock does not advance until the exchange ends |
| C12 | Signature has no fallback | ki 44, sig pressed, then ki set to 45 at tick 100 | run 400 ticks | no fire before tick 100; a fire after; never a light or heavy in its place |
| C13 | Presses accepted while charging | hold charge; press heavy and sig | | weight 1 and `sigQueued` true while charging; the director makes no attack until release |
| C14 | Cleared events | queue a signature, then a KO or a decisive launch against slot 0 | | `sigQueued` false; no `sig_fired` |
| C15 | Determinism under timing | run the same seed with a heavy press at tick 50 and at tick 51 | | each run reproduces its own hash; the two runs may differ; both are deterministic |
| C16 | AI uses the same path | both slots AI, seed 1..50 | | the AI's weight and signature writes appear as the same fields; the AI's matches contain no direct `requestAttack` from `control()` (search the feed for attack lines started outside the director) |
| C17 | No timing dependence for parry or chain | slot 1 presses light and heavy on every tick for a whole match | | no parry, chain or struggle outcome differs from the same seed with slot 1 idle, except through the weight (compare per-exchange tags with weight fixed) |
| C18 | Holds pause attacks | `special` held for 200 ticks | | no attack by that fighter in that span; the opponent may attack it (the exposed state stays as charging) |
| C19 | Transform confirm | availability granted (a filled transformation, forced) | hold `transform` 29 ticks and release; then 30 ticks | 29: nothing, counter reset; 30: the cinematic starts; state stayed `free` during the hold |
| C20 | Encore offer | force the Empress onto the brink | hold `transform` 18 ticks at tick 100 of the offer; separately never hold | held: Encore starts; not held: the offer lapses at 180 ticks and the AI rule decides for itself |
| C21 | Stance always accepted | press each stance and each cycle step during every state (locked, launched, cinematic) | | `f.stance` follows; debounce 4 and repeat 12 hold on cycle |
| C22 | Latency of acknowledgement | any press | | the `press_ack` event is emitted on the same tick as the intent (0 ticks in the sim; the 2-tick budget is for render) |

## 3. Batch checks (statistics, over seeds)

| Id | Check | Over | Pass |
| :--- | :--- | :--- | :--- |
| B1 | Funded-to-fired distribution | 1,000 seeded matches with a scripted queuer (queue at every ki ≥ 45) | p99 ≤ 180 ticks excluding paused ticks; max ≤ 180 |
| B2 | Queue never wedges | 1,000 matches, random queue and cancel presses | no match with a `sigQueued` older than 600 unfunded ticks or 180 funded ticks |
| B3 | Weight mix | 400 matches per arm with a human-stand-in that toggles weight by a fixed rule | the strike-weight mix follows the latched weight (within fallbacks) |
| B4 | Stance flick arm | forced flicks (QA's arm) | at most 55% win rate (`rulings.md` §12 risk 5, now Q5) |
| B5 | Ki fairness | a sticky heavy versus a sticky light stand-in | neither exceeds 55%; report ki-starved fallbacks per match |
| B6 | Determinism | 100 seeds with random queue presses, run twice | identical hashes |

## 4. Human checks (Controls and QA together)

- **Readability:** after two matches, players say what the next attack will be and why it has not fired: at least 80%.
- **Weightlessness:** in a think-aloud, note the moments a player presses and says "nothing happened"; each is a missing ack.
- **Agency:** a one-question survey, compared against the prototype build's answers as a baseline (a check, not a target; skill balance is 2 of 10).

## 5. Where the scripts go and who runs them

- **Scripts:** `sim/input/test/c01_*.gd` and so on (mine), each a `SceneTree` script runnable with `godot --headless --path . --script res://sim/input/test/<name>.gd`.
- **Runner:** QA adds them to `qa/godot/pending-tests.js` as skeletons that report PENDING until the fx events (`press_ack`, `availability`) exist, then run for real, the same way the Wounds tests do (`docs/qa/README.md`).
- **Order:** C1 to C8 need only Stage C's fighter state; C9 to C12, B1 and B2 need Encounter's opening scheduler and the 180-tick cap.
