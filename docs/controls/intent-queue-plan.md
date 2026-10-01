# Plan: input map revision for intent queuing (no timing presses)

> **Superseded in part by ADR 0008 (2026-09-30):** kept as history only. See [input-scheme.md](input-scheme.md).

> **Superseded 2026-09-30 by [stage-c-spec.md](stage-c-spec.md)**, after Game Design's answers (`stance-matrix.md` R9). Weight is a sticky mode (light or heavy, starting light), not a one-shot queue; the signature is the one-shot; there is no timing press anywhere; the 180-tick cap is confirmed. Kept as the record of the options.

Owner: Controls and Game Feel. Date: 2026-09-30. Status: **plan only, no sim edits.** Trigger: Orb's questionnaire 4 (`docs/ep/vision.md`): the player controls stance, movement and positioning, attack weight, charging, transform timing and specials, but **not when to attack and not timing presses** (parry, the finisher struggle). Those go to the director. Skill balance is 2 of 10. Game Design is redesigning parry and the struggle as director outcomes driven by strategy.

## 1. What is held, what stands

| Item | Status | Why |
| :--- | :--- | :--- |
| Parry window widths, clean parry, 4-tick parry buffer (`rulings.md` §3) | **HELD** | Parry becomes a director outcome; there is no press to time |
| Anti-mash stray lockout and ki tax (§3.4, §16) | **HELD** | Nothing to mash |
| Finisher struggle beats, ±4 and assist ±8, scoring (§8) | **HELD** | Becomes a director outcome; Game Design decides what the player influences |
| Chain window as a press (§4) | **HELD** | "When to attack again" is the director's |
| Attack buffer of 6 ticks and the light > heavy > sig press priority (§6) | **REPLACED** by the weight queue (section 2) | A press no longer asks for an attack now |
| `f.pressTick` replacing `lastAtkT` | **HELD** | It existed for press timing; Stage A no longer needs it |
| Hit-stop table, integer ticks, Stage A and B values (§5) | **STANDS** | Impact feel does not depend on timed presses |
| Shake pass (`shake-pass.md`) | **STANDS** | Same |
| Stance switching: free, instant, feedback (§7), direct and cycle inputs | **STANDS, and matters more** | Stance is now the player's main strategic input |
| Special and transform holds, confirm-hold, Encore prompt (`input-map.md` §4) | **STANDS** | Transform timing and specials stay with the player; holds are not timing presses |
| Movement, dash, charge, stick and trigger handling, device layers, rebinding, web and desktop plans | **STANDS** | Unchanged |
| Latency budget (§10) | **STANDS, narrower** | Still applies to movement, stance, the weight queue and holds. Parry-press latency drops out |
| Diagonal normalisation (Stage B) | **STANDS** | |
| Struggle timing offset; the `press_ack` `early` and `locked` results | **HELD / change** | See section 2.1 |

## 2. The revised model: intent queuing

The three attack buttons stop being "attack now" and become "what kind of attack I want".

### 2.1 Weight queue
- **Light, heavy and signature set the weight of this fighter's next attack.** The director decides *when* it fires. Pressing heavy queues "next strike heavy"; pressing signature queues "next strike signature".
- **State:** one integer slot on the fighter, `nextWeight` in {none, light, heavy, sig}, plus `queuedTick`. The newest press replaces the older one; pressing the queued weight again **cancels** it (back to none). Priority no longer matters because only the last press stays.
- **Default with nothing queued:** the director's choice (light unless it judges otherwise), or a stance-derived default. Game Design decides which.
- **Lifetime (proposal, data values):** one-shot, consumed by the fighter's next attack; **expires after 240 ticks (4 s)** so a stale queue does not fire minutes later; cleared on KO, on an incoming decisive exchange, and when the fighter is launched.
- **Cost gating at consumption, not at press:** heavy needs 4 ki and signature 45. If short when the director wants to fire, it **falls back** down the ladder (signature to heavy to light) with a visible "fallback" mark on the queue chip, so the player is never surprised silently. `NEED 45 CHARGE` shows when a signature is queued under 45 and stays queued while ki builds, until it expires.
- **Signature guarantee (needs Game Design and Encounter):** a queued signature with enough ki should fire within a bounded time (proposal: 180 ticks, 3 s) unless the director has a stated reason (no line, cooldown). A player who queues the big move must not wait forever.
- **Hold variant (option):** holding a weight button **latches** that weight until released or changed ("keep throwing heavies"). Off by default; offered as a comfort and accessibility option.
- **Sim shape:** a raw press is an edge in `SimIntent` (`light`, `heavy`, `sig` keep their fields); `control()` turns an edge into a queue write. The director reads `nextWeight` when it plans an attack. AI fighters write the same slot through the same path, so AI and human are one code path.
- **Acknowledge:** the press shows a chip on the plate (weight glyph, expiry ring) within 2 ticks: `press_ack {kind: weight_queued | weight_cancelled | fallback}`. This replaces the parry `early` and `locked` marks.

### 2.2 What the player can still influence about parry, chain and struggle
Not by timing. Candidate levers for Game Design to choose from; I only map inputs:
1. **Stance** (existing): GUARD raises parry odds, and so on. No new input.
2. **A held guard or focus** on an existing slot (`special`, or a bumper): "brace" as a held state that raises defence and drains ki. It is a hold, not a timed press. Cost: another slot.
3. **Ki reserve** as a resource: the struggle chance rises with ki the player kept in reserve, built earlier with the charge hold. No new input.
4. **A held "resist"** during the finisher's wind-up, draining ki: strategy (keep a reserve) rather than rhythm.
5. **Pace intent** (Orb: "the player is in charge of macro strategy, pacing and positioning"): a hold or toggle for "press the attack" or "hold back" that biases the director's aggression. Stance covers most of this; a dedicated input is optional.

I recommend 1 and 3 first (no new inputs), 5 only if Game Design wants a pacing control, and 2 or 4 only if playtests show players want agency over defence.

### 2.3 The map, revised

| Action | Keyboard P1 / P2 | Pad | Meaning now |
| :--- | :--- | :--- | :--- |
| Light | F / comma | X | queue "next strike light" (or cancel) |
| Heavy | G / period | Y | queue "next strike heavy" |
| Signature | R / slash | B | queue "next strike signature" |
| Stance (direct, cycle) | 1 to 4, 5 and ` / 7 to 0, 6 and - | D-pad, LB, RB | unchanged, and the primary strategic input |
| Dash, charge, special, transform | unchanged | unchanged | unchanged (holds) |
| Parry, chain, struggle | no key | no button | removed as inputs |

Bindings do not move, so muscle memory and the How-to-play card stay valid; only the meaning of three buttons changes. That is deliberate: no rebinding pain from the changed model.

## 3. Consequences for the other documents (to update when Game Design reports)

- **`rulings.md`:** sections 3, 4, 6 (the buffer table) and 8 become "superseded" and are kept for the record. In section 12, risks 1, 2, 3, 4 and 7 drop and new ones are added (section 5 below). Sections 5, 7, 9 (except attack gating), 10 and 11 stay; the data block loses `parry`, `chain`, `struggle` and `attackBuffer`, and gains `weightQueue`.
- **`input-map.md`:** the intent record is unchanged; §5 (actions used by the exchange) is rewritten; parity rule 4 loses "timing rules".
- **`prompt-glyphs.md`:** the parry ring, chain chevrons and struggle beat rings lose their **press** glyphs. The tells stay as pure readability cues (Combat's wind-up stays a pose; a ring can remain as a non-interactive read of what the director is about to do). New: the **queue chip** (weight glyph and expiry ring) and the fallback mark.
- **`platform-plan.md`:** mobile scheme B's single Attack button (tap = light, hold = heavy) already fits a queue model; the "parry, chain and struggle press" row goes. Scheme A keeps three weight buttons. The assists that widened windows (parry ×2, struggle ±8) are **moot**; their replacement is Game Design's outcome tuning.
- **Struggle timing offset:** goes. `hitstopScale` stays.

## 4. Stage plan, revised

| Stage | Content | Behaviour | Status |
| :--- | :--- | :--- | :--- |
| **A** | Integer hit-stop counter (effective ticks); `SimIntent` gains `special`, `transform`, `stanceStep` (unused until B); **no press ticks** | bit-identical goldens | ready when the tree is handed; smaller than before |
| **B** | Hit-stop values (§5), shake decay hold, diagonal normalisation | goldens regenerate | unchanged |
| **C** | Intent queue: `nextWeight`, expiry, fallback, signature guarantee, `press_ack` | behaviour change; needs Game Design's director redesign for the "when" | plan; waits for Game Design |
| Dropped | press ticks, stray lockout, struggle scoring, parry and chain windows | | held until Game Design reports; they return only if a timing input survives |

## 5. New risks and tests

| # | Risk | Mitigation | Test |
| :-: | :--- | :--- | :--- |
| Q1 | The player cannot tell what is queued, or why the fighter has not attacked yet | queue chip within 2 ticks, expiry ring, `NEED 45 CHARGE` | New players, after 2 matches, say what the next attack will be at least 80% of the time |
| Q2 | A silent fallback (signature becomes light) feels like a dropped input | visible fallback mark and feed line | Scripted: queue a signature at 30 ki, check the mark and the event |
| Q3 | A queue that never fires (the director waits) | signature guarantee, 240-tick expiry | Over 1,000 matches, p95 of queue-to-fire at most 180 ticks for a funded signature |
| Q4 | Loss of agency with no timing presses ("did I do that?") | stance and weight are visible causes in the feed; the director explains why it attacked | Playtest: an agency question at or above baseline. Skill balance is 2 of 10, so this is a check, not a target to raise |
| Q5 | Stance flicking becomes the whole game, as the only fast input left | R8 stays; the freeze-multiplier ask; QA's forced-flick arm | Forced-flick AI arm at most 55% win rate |
| Q6 | The three weight buttons feel dead because a press shows nothing for seconds | acknowledge instantly; show the intent on the fighter (a pose hint, the director's call) | Latency harness on the chip, and a think-aloud check |

## 6. Questions for Game Design (through the EP)

1. Queue semantics: one-shot with a 4 s expiry, or latching? What fires when nothing is queued?
2. Is any timing press left at all (the chain follow-up, the beam clash)? If none, I remove those rows.
3. Which lever, if any, does the player get over parry and the struggle (section 2.2)? Is there a pacing input?
4. The signature guarantee: how long may the director make a funded, queued signature wait?
5. Do the transform confirm-holds and the Encore prompt (holds, not timing presses) stay as designed? I assume yes.
