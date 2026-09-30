# Stage C spec: sticky weight and the signature intent

Owner: Controls and Game Feel. Date: 2026-09-30. Status: **final spec, no sim edits yet.** Source: Game Design's Q4 redesign (`docs/design/stance-matrix.md` §4b R9, R4, R5; `docs/design/spec-wounds.md` §1 and §8 to 9). It supersedes the option space in `intent-queue-plan.md`, which is kept as the record.

## 1. What the player does, and what the director does

| The player | The director |
| :--- | :--- |
| Sets the **weight** (light or heavy), sticky | Decides **when** to attack, from stance, ki, mood and openings |
| Queues the **signature** as a one-shot intent | Fires it at its next opening once the fighter has 45 ki |
| Holds **charge**, **special**, **transform**; picks **stance**; moves | Parries, chains, the struggle, all by state. **No timing press exists anywhere** |

The three attack buttons keep their bindings. Their meaning changes, the keys do not.

## 2. Weight (sticky)

| Rule | Value |
| :--- | :--- |
| Start of a match | **light** |
| Light button | sets the weight to light (pressing it while light is a no-op, and it is still acknowledged) |
| Heavy button | sets the weight to heavy |
| Both on the same tick | heavy (the sim tests light first, then heavy, so the later wins; deterministic) |
| Lifetime | until the player changes it; survives exchanges and signatures; reset to light at match start only |
| Heavy cost | 4 ki per heavy strike (unchanged). **Below 4 ki the strike falls back to light for that strike only; the mode stays heavy.** A `weight_fallback` mark shows |
| Where it shows | on the **stance ring** (Game Design): a light or heavy mark beside the current stance |
| Latch options | none needed: it already latches. There is no hold variant |

## 3. Signature (one-shot intent)

| Rule | Value |
| :--- | :--- |
| Press | sets `sigQueued`. Pressing again while queued **cancels** it |
| Fires | at the director's **next opening**, once ki ≥ 45 |
| Unfunded | stays queued while ki builds; the plate shows `NEED 45 CHARGE` and a fill toward 45 |
| Unfunded expiry | **600 ticks (10 s)** after the press, so a stale intent does not fire minutes later (my value; Game Design may overrule) |
| Maximum wait once funded | **180 ticks (3 s)**, overriding the stance's cadence if it must, **at the next exchange boundary** (Game Design) |
| Clock pauses while | the fighter is charging, using a special, holding transform, in a cinematic, or (director rule) under a running exchange. It does not run down while attacks are paused |
| After it fires | the mode returns to the latched weight; `sigQueued` clears |
| Cleared by | firing, cancelling, expiry, KO, and the fighter being launched by a decisive exchange |
| Cost | 45 ki, taken when it fires, not when queued. No fallback: it waits for the ki |
| Never | parries or chains (nothing does) |

## 4. State that pauses attacks

Game Design: charging and specials pause the director's attacks until they end. For the intent layer that means:
- while `charge`, `special` (a real hold) or a `transform` confirm-hold is active, the director makes no attack for this fighter;
- weight and signature presses are still accepted and acknowledged (the player can prepare while charging);
- stance presses are accepted always.

## 5. Sim shape (for Stage C)

| Item | Where | Detail |
| :--- | :--- | :--- |
| `SimIntent` | `sim/input/intent.gd` | `light`, `heavy`, `sig` stay edges. Stage A adds `special`, `transform`, `stanceStep` |
| Fighter state | new ints on the fighter | `weight` (0 light, 1 heavy), `sigQueued` (bool), `sigQueuedTick`, `sigFundedTick`, `sigCapUsed` (ticks counted, pausable) |
| `control()` | `sim/input/control.gd` | An edge writes state. It no longer calls `requestAttack`, no longer stamps `lastAtkT` |
| Director | Encounter's `dirUpdate` | Reads `weight` and `sigQueued` when it plans an attack for that fighter; owns the opening and the cadence. The 180-tick cap is a hard rule it enforces. **This is Encounter's slice; I specify only what it reads** |
| AI | `sim/director/ai.gd` | Writes the same `weight` and `sigQueued` through the same path (stance choice stays its own). One code path for human and AI |
| Events | `SimFx` | `press_ack {actor, kind}` with `kind` in `weight_light`, `weight_heavy`, `weight_fallback`, `sig_queued`, `sig_cancelled`, `sig_funded`, `sig_expired`, `sig_fired`; plus `availability` for transform and Encore (`prompt-glyphs.md` §5) |
| Determinism | | Every value is an integer tick or a bool. No RNG. Press order within a tick is fixed (light, heavy, then sig) |
| Data | `data/input/feel.json` | Draft in section 7 |

## 6. Feel, tests and risks

| Test | Pass |
| :--- | :--- |
| Ack latency: a press to the ring's weight mark or the plate's signature chip | within 2 ticks |
| Weight sticks: press heavy, play three exchanges, weight still heavy; a signature fires, then the mode is heavy again | assertion in a scripted match |
| Fallback: heavy at 3 ki | a strike falls to light, the mark shows, the mode stays heavy |
| Signature cap: funded and queued, over 1,000 seeded matches | p99 of (funded to fired) at most 180 ticks, excluding paused ticks |
| Signature expiry: queued at 0 ki with no charge | expires at 600 ticks, `sig_expired` emitted |
| Pause: queue a signature, hold charge for 200 ticks, release | the 180 clock did not run while charging |
| No timing dependence: shift a weight press by 1 to 30 ticks in a replay | the match may diverge (the director sees a different weight) but always deterministically; the same input log gives the same hash |
| Readability (human): after 2 matches, say what the next attack will be and why it has not fired | at least 80% |

| Risk | Mitigation |
| :--- | :--- |
| A sticky heavy drains ki silently (4 per strike) and the fighter drifts to light | the fallback mark, and the ring shows the effective weight when ki is short |
| The player queues a signature, then spends ki on heavies and never reaches 45 | the plate's `NEED 45 CHARGE` fill; the 600-tick expiry |
| The director's cadence, not the button, decides everything, so presses feel weightless | instant acknowledge on the ring and chip; the feed names why the director attacked (Encounter) |
| Stance flicking becomes the fast input | R8 stands; QA's forced-flick arm (at most 55%) |

## 7. Draft data (`data/input/feel.json`, replaces the earlier `parry`, `chain`, `struggle` and `attackBuffer` blocks)

```json
{
  "schema": "input.feel/2",
  "ticksPerSecond": 60,
  "weight": { "start": "light", "heavyKi": 4 },
  "signature": { "ki": 45, "maxWaitFunded": 180, "unfundedExpiry": 600,
                 "clockPausedBy": ["charge", "special", "transform", "cinematic", "exchange"] },
  "stance": { "cycleRepeat": 12, "cycleDebounce": 4 },
  "hitstopTicks": { "light": 4, "chain": 5, "tradeFinal": 6, "heavy": 7, "guardBreak": 8, "parry": 9,
                    "clashWave": 7, "impact": 4, "explosion": 5, "beamConnect": 9,
                    "beamClash": 10, "finisherHit1": 4, "finisherHit2": 7, "finalBlow": 18 },
  "hold": { "confirmTicks": 30, "encoreConfirm": 18, "encoreOffer": 180,
            "stickDeadzone": 0.2, "stickQuant": 16, "triggerOn": 0.35, "triggerOff": 0.25 }
}
```

The `parry` hit-stop stays: it is the freeze on a director-resolved parry, not a press window. The `clean` parry value is dropped.

## 8. Stage plan (final)

| Stage | Content | Behaviour | When |
| :--- | :--- | :--- | :--- |
| **A** | Integer hit-stop counter (today's effective ticks); `SimIntent` gains `special`, `transform`, `stanceStep` (unused until later); no press ticks | bit-identical goldens, with QA's proof | after S3b, S4 and World's collateral window; waits for the tree |
| **B** | Hit-stop values (`rulings.md` §5), shake decay hold, diagonal normalisation; **no stray lockout (withdrawn)** | goldens regenerate | after A |
| **C** | Sticky weight, signature intent, `press_ack`, the special and transform holds wired to fighter kits | behaviour change; needs Encounter's opening scheduler | after Game Design's director redesign lands in Encounter |

## 9. Needs

- **Encounter Systems:** the director reads `weight` and `sigQueued`; the opening and cadence per stance; the 180-tick cap at the next exchange boundary; the AI writes the same fields.
- **Game Design:** confirm the 600-tick unfunded expiry, the no-op on pressing the current weight, and that a signature has no fallback.
- **UI/UX:** the weight mark on the stance ring; the signature chip with the `NEED 45 CHARGE` fill; `press_ack` marks (`prompt-glyphs.md`).
- **Combat:** none new; the wind-up beats stay as poses only.
