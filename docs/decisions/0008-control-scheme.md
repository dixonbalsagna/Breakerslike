# ADR 0008: control scheme, layouts and simple mobile mode

Status: accepted, 2026-09-30. Decided by Orb after friends' playtest feedback (vision.md, questionnaire 8). Work is on hold until Orb gives the go; Orb may want more consulting first.

## Context

Friends found that automatic counter-attacks, especially auto-fired beams, took away their agency. They wanted manual blocking, dodging and cancelling. On phones they couldn't play at all. Orb proposed an Xbox-layout scheme with four shoulder and four face buttons, and the EP suggested simplifications.

## Decision

1. **Stances become held states.** Attacking is Press. Holding guard is Guard, with a well-timed tap as a perfect block. Tapping dodge is Dodge. Holding dodge and moving away (sprint) is Escape. The director reads what each fighter is doing at exchange start, as now. The 1-to-4 stance keys go.
2. **Defence and agency:**
   - the director counters only when the defender's stance calls for it, and never fires a beam on its own;
   - a dodge tap cancels anything mid-exchange, for an energy cost and with a cooldown;
   - a burst (tap) is everyone's answer to pressure, for an energy cost and with a cooldown;
   - the perfect-block window opens only during a visible wind-up, and a mistimed tap still blocks.
3. **Inputs are intents.** Each attack press is one exchange request, and repeated presses queue a short combo. Only dodge, perfect block, burst and reversal act inside an exchange, at defined windows.
4. **Modifiers, not fixed moves:**
   - the mode (physical or energy) swaps the piece family;
   - the direction held (toward, neutral or away) swaps the entry (rush, stand, retreat);
   - the button sets the weight;
   - the defender's held state picks the outcome.
5. **The power layer:** hold the power trigger, then a face button fires one of the 3 loadout specials, or the signature. Releasing without a face button channels or charges. Holding both triggers for 0.5 s transforms.
6. **The context button,** by priority:
   - the opponent within grab range: grab and throw;
   - a liftable object: pick it up;
   - civilians: the fighter's own action;
   - otherwise a fallback per mode (provoke or feint in physical, energy shove in energy).
   - Modifiers: in guard it's a reversal close up or a deflect at range; while sprinting, a tackle; in the air, a dive grab.
   - An on-screen icon shows what it will do, and extra presses are ignored during recovery.
7. **Three controller layouts ship, plus full remapping.** Arena (the default), Brawler (attacks on the shoulders) and Simple (six buttons; the director picks mode, bursts and specials). Every layout produces the same actions.
8. **Simple mobile mode ships.** Two thumbs only:
   - a floating move stick (flick to dodge, hold to sprint);
   - Attack (tap light, hold heavy, swipe up for the signature);
   - Guard (hold, a timed tap is a perfect block);
   - Power (hold to charge, tap to burst; while Power is held, Attack fires the specials);
   - a context button that appears only when relevant;
   - automatic mode switching.

   A Full touch preset is for tablets.
9. **Fewer beams, more ordinary energy blasts.** Each fighter gets their own beam style.

## Consequences

- Controls redesigns Stages A to C (weight is no longer a latch).
- Encounter revises the Q4 plan (attack requests, defender states, interrupt windows, AI use of the new inputs).
- Combat adds energy-mode piece families and the context actions.
- UI builds the touch layout, the settings and remap screens, the mode chip and the context icon.
- Animation authors energy-mode variants, mostly hand, aura and effect changes on shared poses.
- Tools updates the input schemas.
- Online ranked play may separate assisted players later.
