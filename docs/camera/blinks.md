# Camera: blinks and blink clashes

Owner: Camera and Cinematography. Status: design note, 2026-09-30, for the variety pass (`docs/combat/variety-pass.md` §2.2, `docs/rendering/variety-cues-plan.md`). No code until the `blink_out`, `blink_in` and `blink_meet` events land. It extends `split-screen.md`.

**Summary**
1. **A blink is not camera motion. The view holds.** The world stays put while the fighter vanishes and reappears; the camera then eases to the new framing with its ordinary filter. No cut, no fast pan. The air-ripple tell reads best against a still background.
2. Today the rig would get this wrong: it reads a teleport as speed, and the merged camera jumps the whole midpoint shift in one tick (measured: a 300-unit blink moves the picture 166 px in one tick; 150 units, 83 px; 600 units, 332 px). The fix is to zero the velocity feed-forward for a blinking fighter on the tick of the event.
3. **A blink clash never opens the split.** Its fighters are in melee range, so the pair is in the one view. While blinks are running the layout is held (no opening, no orientation swing), except for a fighter genuinely lost off the frame.
4. **A blink approach from far while split is a slam.** If a fighter blinks in beside the other while the panes are open and the pair is then close enough to merge, the door closes at the arrival (0.14 s, the same slam), timed to `blink_in`, not to a rush end.
5. Small additions: a catch-up gain so a fighter that lands far from its anchor is pulled in quickly, no shake or push on a blink (Controls' shake pass owns `blink_meet` if it wants one), and a depth-free rule (blinks stay on the plane).

**Open questions for Orb**: none.

## 1. What the variety pass gives the camera

- Blinks happen inside an exchange. Both fighters are airborne (low or high air, not underwater); slots are relative to the other fighter (`above`, `behind`, `below`, `front`, or both at the `meet` midpoint), so a blink moves a fighter a few fighter heights, not across the map. The heavy-clash style is three meets and a decisive one; trade blows is four blink positions and a decider.
- The one exception is the *approach*: a blink may replace the first rush, so an attacker can vanish at any range and reappear beside the defender.
- Events (from `variety-cues-plan.md`): `blink_out` and `blink_in` {fighter, x, y}, emitted in the tick the position jumps; `blink_meet` {both fighters, contact x, y}. Render snaps the fighter's interpolation for that tick so it never slides.
- Each blink shows a ripple at departure and arrival, the body hidden for the gap.

## 2. How the view follows a blink: hold, then ease

Three options were weighed.

| Option | What the viewer sees | Verdict |
| :--- | :--- | :--- |
| Cut (snap the camera to the new framing in the tick) | The whole picture jumps 80 to 330 px in one frame | What the rig does today by accident. Reads as a glitch, and it hides the tell |
| Fast pan | The world streaks while the fighter is not there | Motion with no cause; worse in a blink clash (four to eight blinks in two seconds) |
| **Hold, then ease** | The world stays; the fighter pops elsewhere in the frame; the camera glides after them at the ordinary 0.1 to 0.26 s filter | **Chosen.** The teleport is the fighter's, not the camera's |

**Rule.** On a `blink_out` or `blink_in` for slot `i`, in that tick: the follow filter for `i` takes no velocity feed-forward (`v` is set to 0 and the stored previous position is re-based to the new one), and the one-view camera's midpoint feed-forward is skipped the same way. The camera's target moves by the jump at once (it is the fighter's new position), but the filters approach it with their time constants, so the picture eases over about 0.3 s instead of jumping. In the heavy clash the fighters meet at the midpoint, so the merged camera's target hardly moves and the view is nearly still, which is the effect wanted.

**Catch-up gain (new, small).** A blink can put a fighter further from its anchor than the follow filter should be trusted with. If a fighter's screen offset from its pane anchor exceeds 25% of the width, the follow time constants shrink in proportion (down to a quarter), so a blink of 10 fighter heights in a pane is recovered within about 0.15 s and never leaves the pane. This also helps dashes and other jumps; it does not touch launches (rigid follow) or slams (already stiff).

**Depth and heights.** Blinks stay on the plane, so nothing from `depth-and-chains.md` applies. `above` and `below` change the height difference by a few fighter heights; the tilt filter (0.2 s, 3 degree dead band) absorbs it without a jolt.

**Reduced motion.** Unchanged: the hold has no motion to reduce, and the ease is the same as any follow.

## 3. Can a blink clash open the split?

No, by these rules, all within the split and merge rules of `split-screen.md` §2:
1. **By geometry.** A blink clash needs both fighters in melee range at its start, so `r` is well above the split line; blink slots are a few fighter heights, which keeps it there.
2. **By an explicit hold.** While a blink has fired within the last 1.5 s (each blink refreshes it) the split dwell does not run and the orientation swing is deferred. The one thing that overrides it is a fighter lost off the one-view frame (`out of frame`), which splits as always. The dissolve merge is not held, so a clash that ends far apart still recovers normally.
3. **A blink approach.** The exception that matters: an attacker blinks in from far while the panes are open. The panes are two views of two distant fighters, then one fighter is beside the other. Rule: on a `blink_in` while `sep >= 0.5` and no shot is running, if the pair's `r` after the arrival is at or above the merge line, start the **slam** now, with the arrival as the contact. The door closes in 0.14 s (0.04 s in reduced motion), the merged camera is stiffened as in the slam, and the divider flashes. If the arrival is still far (a long blink that ends at 20 fighter heights, say), nothing special happens and the ordinary rules apply. The blink's departure (`blink_out` far away) needs no reaction: the pane holds where the fighter vanished, the ripple plays there, and the door closes a few ticks later at the arrival.
4. **Never a shot of its own.** No solo expansion, push or shake for a blink. `blink_meet`'s spark is VFX's, and any shake is Controls' (their table has no blink row; propose none).

## 4. What to build, and the tests

1. `SplitRig`: read `blink_out` / `blink_in` (actor slot from `actor` or `fighter`, whichever the event uses; I will accept both) into a per-slot `_blink_tick`; in `_update_cameras` use zero velocity and re-base `_pp*` for a slot with `_blink_tick == this tick`; the same for the one-view camera's midpoint velocity. (~20 lines.)
2. The catch-up gain in the focus filters (~10 lines) with `CamParams.CATCH_UP_OFFSET = 0.25`, `CATCH_UP_MIN_TAU = 0.25` (a fraction of tau).
3. `_blink_hold` timer (1.5 s, refreshed by each blink) that gates the split dwell and the swing (~10 lines).
4. The blink-approach slam: a `_blink_slam` path that starts the existing slam sequence from an event rather than a rush (~25 lines); the slam already accepts an external contact time.
5. `split_sweep.gd`: (a) a heavy-clash scenario: a merged pair, three meets and a decider, blinks of 2 to 8 fighter heights with events; assertions: no camera step above the calm limit (`ANCHOR_STEP`), the fighter is on screen every frame, no split opens, no swing. (b) The same without the events (jumps only) as a documented failing baseline, so the test proves the event is what fixes it. (c) A far blink approach from a split pair: the panes close in 8 ticks with `slam` set once, and a blink that ends far away leaves the panes. (d) The catch-up: a 12 fighter-height blink inside a pane. The picture check (`--render`) gets a blink scenario with the same 4x spike limit.

## 5. For Encounter, Rendering and the EP

- **Encounter / Simulation:** `blink_out` and `blink_in` must carry the slot (`actor` please, to match `damage` and `tier_up`) and be emitted in the tick the position jumps; `blink_meet` carries both slots. If an approach blink is a single beat, one `blink_in` after the `blink_out` is enough; if the gap is more than 6 ticks, tell me: the pane holds for it, but a gap over 0.3 s should keep the panes from dissolving mid-gap (the hold in §3.2 covers it).
- **Rendering:** nothing new; the interpolation snap for the tick is in their plan. The camera's hold means the fighter appears at its new place against a still background, which is what their ripple wants.
- **VFX:** break the trail at a blink (their plan already does); the camera does not move at a blink, so no streak is produced by camera motion.
- **Risk:** four to eight blinks in two seconds mean the merged camera's target moves at each one; with the hold-and-ease each is a 0.3 s glide, so a fast run of blinks can keep the picture in constant slow drift. If that reads as unsteady, raise the merged filter's time constant during a blink clash (a 0.4 s tau) so the view averages over the meets; it is one constant to try.
