# Touch Simple bridge to today's intents

Owner: Controls and Game Feel. Date: 2026-10-01. Status: **code and tests done; the host glue is a ready patch that needs the EP's grant** (it touches `render/core/sim_host.gd` and `render/core/main.gd`); UI draws the buttons. No sim change. The target design is `input-scheme.md` §6.1; this is the part of it that today's director can already play.

## What it does

A phone (or any touch screen) plays a fight with two thumbs, using only today's intent fields (`mx`, `my`, `dash`, `charge`, `light`, `heavy`, `sig`, `stance`):

| Touch | Intent today |
| :--- | :--- |
| Floating stick (left 42% of the screen, below 30% of its height) | `mx`, `my`: dead zone 0.2, full at 90% of a 56 dp radius, steps of 1/16, per axis (so a diagonal matches a keyboard's) |
| **Flick** the stick (drag 70% of the radius within 6 ticks of touching down) | stance EVASIVE for 30 ticks, plus a `dash` for 12 ticks in the flick direction (snapped to eight ways; it holds even if the thumb comes back) |
| **Sprint**: drag beyond 1.3 radii for 6 ticks (ends inside 1.15) | `dash` held |
| **Attack** tap (released before 12 ticks) | `light`, on release |
| **Attack** hold (still down at 12 ticks) | `heavy`, at tick 12 |
| **Attack** swipe up (40 dp or more within 12 ticks) | `sig`, at once (the director refuses it under 45 ki with its NEED 45 KI cue) |
| **Guard** hold | stance DEFENSIVE while held |
| **Power** hold | `charge` while held |
| Context button | nothing yet (no context action exists in the sim); UI should not draw it in this build |
| Pause, feedback | UI's own targets, handled before the controls as today |

Guard outranks the dodge stance; neither is held by a lifted finger. A touch also takes the match over from the demo, like a key does.

**One honest difference from the target design.** The target fires a light **on press** and lets a hold upgrade an unconsumed request. Today's director starts an exchange the moment it gets a request, so a light on press could never become a heavy. The bridge therefore fires the tap **on release** (at most 11 ticks, 183 ms, after the press; a normal tap is 3 to 6 ticks). Stage C's director removes the wait. Everything else fires on its first tick.

## Files

| File | What |
| :--- | :--- |
| `sim/input/touch.gd` | `SimTouch`: pointer events in, one `SimIntent` per tick out, all timers in ticks, no engine input or clock. `layout()` gives the buttons' geometry; `widget_at()` the hit test. The resolved actions (guard, sprint, power, requests) are public fields, so intent v2's adapter reads the same state later and only `build()`'s last step changes |
| `sim/input/test/touch_test.gd` | 154 headless checks: taps, holds, swipes, one finger per button, guard and power, stick dead zone and quantisation, flick, sprint and its hysteresis, the layout on five screens (on screen, not touching, outside the stick zone, 48 dp targets, hit tests), and determinism (a scripted touch session replays to the same hash; the AI-only hash is unchanged) |
| `sim/input/test/touch_glue_test.gd` | the end-to-end check through the main scene with synthetic screen touches: guard, power, tap, hold, swipe, flick, and an open overlay swallowing touches (12 checks) |
| `docs/controls/touch-bridge.patch` | the host glue: 48 changed lines in `render/core/sim_host.gd` and `render/core/main.gd`; `patch -p1 < docs/controls/touch-bridge.patch` from the repo root (checked with `--dry-run` on the working tree) |

## The host glue (what the patch changes, for the EP's grant)

| File | Change |
| :--- | :--- |
| `render/core/sim_host.gd` | `var touch := SimTouch.new()` and `var touch_on`; in `tick()`, the human fighter in slot 0 takes `touch.build()` while `touch_on`, otherwise the keyboard intent as now; `touch.consumed()` next to `edges.clear()` (a request waits through hit-stop as keys do); `touch.release_all()` in `new_match()` and `release_all()` |
| `render/core/main.gd` | `host.touch_on` follows `_touch_last` (set where the device already flips, and at start, with `release_all()` on a flip); `_input()` hands screen touches and drags to the new `_touch_event()`; `touch_layout()` returns `SimTouch.layout(...)` for the viewport, dp and safe margin; `_touch_event()` ignores touches while the How to play card, the feedback panel or the pause menu is open, lets UI's pause and feedback targets win, and otherwise calls `touch_down`, `touch_move` or `touch_up` |

No other file changes. Keyboard, pad and mouse paths are untouched; `touch_on` is false until a touch is the last device.

## What UI needs to build (UI's files)

1. Draw the buttons from `SimTouch.layout(vp.x, vp.y, dp, portrait, left_handed, margin)` with the same inputs as `main.touch_layout()`: `attack` (the largest), `guard`, `power`; skip `context` in this build. Each is a circle `{x, y, r}`; give pressed and idle looks, a hold ring on Attack that fills over 12 ticks, a short "swipe up" hint on first use, and a ring on Power while charging.
2. Retire the stance ring in touch mode (the bridge has no stance taps), keep the pause button.
3. Draw nothing in the stick zone; a floating stick base and thumb appear where the thumb lands (the host can pass the touch point; the zone is `layout()["stick"]`).
4. `left_handed` is read from the option if it exists (default false).

## Acceptance

| Criterion | Result |
| :--- | :--- |
| No sim change | I edited no existing sim file; the bridge adds new files in `sim/input` only (`touch.gd`, `test/`) |
| Determinism check | On a clean export of HEAD plus my files plus the patch: `parity.gd` **passed**, `render/tools/determinism.gd` (60 Hz, 144 Hz, jitter, jitter again) **passed**, `touch_test.gd` 154 of 154, `touch_glue_test.gd` 12 of 12. On the shared working tree `parity.gd` currently fails; the tree holds other directors' uncommitted `sim/world` edits, and nothing in the sim loads my new files, so the clean-export run above is the check of my change |
| Playable on a phone profile in a web export | **Not yet shown.** It needs the patch applied and UI's buttons; then the EP or Rendering exports the web build and opens it in the Browser pane with a phone profile and touch emulation |

## Risks

- Tap-on-release adds up to 183 ms (above). The alternative, tap on press, makes the heavy impossible until Stage C.
- Fighting the browser: a long press can open the context menu or scroll the page on some phones; the web shell must set `touch-action: none` on the canvas and prevent default on `contextmenu` (Rendering; in the plan, `platform-plan.md` §4).
- The flick uses a 6-tick window; a thumb that lands and moves slowly walks, as designed.
- A pad or key press turns touch off and releases everything (`host.touch.release_all()`).
