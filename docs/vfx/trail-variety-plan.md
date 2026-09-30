# Trail changes for the variety pass

Owner: VFX Director. 2026-09-30. For `docs/rendering/variety-cues-plan.md`. Plan only; the blink part is implemented when Encounter's `blink_out` and `blink_in` events land, the heavy-tell part when `attack` carries what it needs (it already has `kind`). Both live in `trail_state.gd` and `vfx_hub.gd`, read events and the fighter's state, and never write the sim, so the gameplay hash cannot change (`hash_check.gd` and `effects_check.gd` get a blink and a heavy-attack case).

## 1. Break the trail at a blink

**Problem.** A trail measures speed from displacement per unfrozen tick and keeps 16 points of history. A blink moves a fighter in one tick, so it would read as hundreds of bh/s and draw a ribbon across the gap. Today only a jump over 3,000 units a tick is treated as a teleport; a blink of 500 to 3,000 units would streak.

**Approach.**
- On `blink_out` and `blink_in` (fighter, x, y, in the tick the position jumps) the hub calls `trails[slot].cut()`: clear the history, set the intensity `k` and the smoothed speed to 0, forget the previous position (so the jump is not measured), and start the break-ring cooldown. Wind marks already left in the world stay: they are fixed points, not a path.
- After the cut the ribbon regrows from the arrival point as new points accumulate; nothing draws for the first tick.
- **Fallback that needs no event.** A per-tick displacement over 600 units (about 480 bh/s, above any launch, which tops out near 370) is treated as a cut too, replacing the 3,000-unit rule. A missed or renamed event therefore cannot streak.
- The head of the ribbon is drawn at the interpolated pose. Rendering's blink snap (the one flag in `SimHost` interpolation) must also snap `fighter_pose`, which it does by construction because the trail reads that function; if a frame ever interpolated across the jump, the ribbon has no history to stretch, so nothing shows.
- Blink afterimages and ripples stay Rendering's particles. The trail does not draw at the departure point.

## 2. A trail-strength factor for the heavy-attack tell

**Problem.** `tell_heavy` wants "the trail runs thicker through the approach", but an approach is a rush, which the trail ignores (it has its own afterimages) and is often under 40 bh/s.

**Approach.**
- New per-fighter state `strength` (1.0 normally). The hub sets it from the `attack` event: `kind == "heavy"` sets `heavy_until = S.T + HEAVY_TRAIL_S` (1.0 s: the 0.5 s tell plus the approach) for that actor, and ends it early when the actor's `rush` ends or a `parry` or `chain_end` event names it.
- While `heavy_until` is in the future: the rush gate is off, the on and full thresholds are halved (20 and 55 bh/s), the ribbon is 1.6 times wider (both layers, minimum core width unchanged) and its alpha steps are raised one notch; the wind marks are unchanged so the heavy tell is one thing that gets thicker, not more clutter. It eases in over 0.15 s and out over 0.25 s.
- **Public hook for Rendering and Combat.** `host.vfx.set_trail_strength(slot, factor, seconds)` (factor 1 to 2) does the same for any other tell that wants it. The `attack` path calls it with 1.6 and 1.0.
- Reduced motion halves the extra (1.3 instead of 1.6), and quality low ignores it.

## Constants (VfxLook)

`BLINK_CUT_UNITS` 600, `HEAVY_TRAIL_S` 1.0, `HEAVY_WIDTH` 1.6, `HEAVY_V_SCALE` 0.5, `STRENGTH_IN_S` 0.15, `STRENGTH_OUT_S` 0.25.

## Tests

- `effects_check.gd`: a scripted 1,000-unit jump in one tick leaves no ribbon and no ring on the next tick; a blink event does the same for a 300-unit jump; a heavy `attack` at 25 bh/s draws a ribbon and a light one does not; the strength returns to 1 after `HEAVY_TRAIL_S`.
- `hash_check.gd` with the blink and heavy events fed through the hub (mock events in the tool), as for the other effects.

## Needs

- Encounter: `blink_out` and `blink_in` with the fighter slot, in the tick the position jumps (already in the variety plan).
- Rendering: the interpolation snap for the blinking fighter, and the tell's pose timing, which the 1.0 s window follows.
