# Camera v2: bigger fighters, a lag bound, launch following, cuts and lanes

Owner: Camera and Cinematography. Status: plan, 2026-10-01; sections 12 (Orb's picks) and 13 (what is built) added 2026-10-02. It answers Orb's camera questionnaire (`docs/ep/vision.md`, "Questionnaire 9"), ADR 0009 (fight lanes) and `docs/architecture/fight-lanes.md`, and extends `split-screen.md` and `depth-and-chains.md`. Nothing here is built.

**Summary**
1. **Bigger.** The default fighter is 11% of the screen height in a fight (79 px at 720p, from about 9% today) and 8.5% in a split pane (61 px, from 6.5%). The shared zoom-out never goes below 3.2% (23 px); the split line moves to 3.5% and the merge line to 4.7%. A zoom setting (0 to 10, default 7) scales all of it.
2. **A lag that cannot lose a fighter.** A fighter may sit at most 20% of the width from his anchor; beyond that the camera whips to hold the bound, and past 1.5 screens it cuts. Launch following starts at the launch event with no ramp.
3. **Who the camera follows on a launch is Orb's call**, with a recommended hybrid: stay on the attacker with the launched fighter in an inset when the human is the attacker, chase when the human is launched, split in two-player.
4. **A shot list** for impacts (push-in, not a cut), the chase, and the cuts Orb allowed, each with a duration and whether the sim pauses. Camera cuts never pause the sim; sim-owned cinematics already own the fighters.
5. **Lanes.** The 32-bh band reads: 27 px at the fight zoom at its deepest edge. The cut-away is Rendering's porthole, sized from the fighter. Both angles come on a debug toggle (F6), at a stated cost to fighter size.

**Options for Orb** (section 10 lists them with my pick): launch following, control during cinematics, the default size, the minimum size, the shake default, the cut cap.

## 1. Numbers: how big, how small, and how the split follows

Fighter height is 75 units. Sizes are fractions of the screen height `r = 75 zoom / vh`, so 720p, 1080p and 4K scale together. Today (measured): melee in one view about 9% (66 px), a split pane 6.5%, launch follow 6%.

| Quantity | Today | v2 default (zoom setting 7) | At 720p | Zoom (pixels per unit, 720p) |
| :--- | ---: | ---: | ---: | ---: |
| Fight, one view, at melee range (750 units apart) | 9% | 11% | 79 px | 1.06 |
| Largest allowed (the zoom-in cap) | 12% | 14% | 101 px | 1.34 |
| A split pane, a fighter alone | 6.5% | 8.5% | 61 px | 0.82 |
| Launch chase | 6% | 8% | 58 px | 0.77 |
| Respected transformation close-up | 14% | 14% (cap) | 101 px | 1.34 |
| **Minimum, anywhere (the floor)** | none | **3.2%** | **23 px** | 0.31 |
| Split line (shared zoom-out ends) | 3.0% | 3.5% | 25 px | 0.34 |
| Merge line | 4.0% | 4.7% | 34 px | 0.45 |

- **The one-view framing tightens.** The reference margin (`|d| + 700` in the zoom formula) becomes `|d| + 450` (it is the 11% default). Splits then fall at about 45 fighter heights apart and merges at 32 (from 50 and 35).
- **The floor is also the end of the wide beat.** Orb wants the shared zoom-out to last, and never below a minimum size. The wide hold (1 s while they are still moving apart) stays but now runs only between the split line (3.5%) and the floor (3.2%); below the floor the shared view cannot zoom out further, so a fighter leaving the frame splits at once (the rule already in `split-screen.md` section 2). In practice a fast separation reaches the floor in under a second and the split opens there.
- **The zoom setting** `camera.zoom_pref`, 0 to 10, default 7: every target height above is multiplied by `m = exp(0.08 (pref - 7))` (0.57 at 0, 1.0 at 7, 1.27 at 10). The floor (3.2%) is not scaled, so a player cannot choose an unreadable game; the split and merge lines move with the floor only (they are floored at it), because the split should not depend on taste. At pref 10 the one-view cap would reach 17.8% (128 px); keep it at 16% (115 px).
- **The thresholds stay in `camera_params.gd`** (`R_PANE`, `R_FIGHT`, `R_MAX`, `R_FLOOR`, `R_SPLIT`, `R_MERGE`), so Orb can retune by ear.
- **Time in each mode (estimate, to measure at build).** With the larger default the split opens earlier in the run of play, not later; the wide hold and the floor are what keep the earlier friend feedback ("hold the zoom-out longer") alive. I will re-measure the share of two-pane frames on the live build and report it.

## 2. A catch-up rule that cannot lose a fighter

Orb's complaints: the camera does not catch up; launches leave the view faster than the camera follows. Today the rig has three weak points: the engage ramp of a launch follow (0.32 s) while the fighter flies 10,800 units a second; the one-view camera's 0.26 s time constant; and the pane filter's 0.10 s, which lags a teleport.

**The bound.** For every fighter the camera tracks, let `e` be his screen offset from his anchor (his pane's anchor, or the screen centre in a shot), in screen widths. The rig enforces three zones each tick:

| `e` | Rule |
| :--- | :--- |
| up to 0.06 | The ordinary filter and the measured-velocity lead (smooth, as now). |
| 0.06 to 0.20 | The time constants shrink in proportion: `tau_eff = tau / (1 + 6 (e - 0.06) / 0.14)`, down to `tau / 7`. The camera speeds up the more he is off, never lags unboundedly. |
| above 0.20 | **Hard bound:** the focus is placed so that `e` = 0.20 this tick (a whip). The fighter is at most 20% of the width off his anchor, always on screen. |
| above 1.5 (more than a screen and a half in one tick) | **Cut:** the camera snaps to him (one tick, no ease), with a 0.08 s fade-in from 70% brightness to hide the jump. It is a safety net, not a style: the test counts it. |

- **Look-ahead.** A fast fighter is led by his velocity times 0.15 s, bounded to 18% of the width on screen, so the camera is ahead of a dash, not behind (the lead of `split-screen.md` section 4 is the filter's, this is extra and only above 1,500 units a second).
- **Launch.** On the `launch` event the focus is rigid from tick 0 (`tau` 0.02) and the zoom starts easing toward the chase size at once; the pane switch (`e`, `solo_w`) may take its 0.32 s, but the camera is already on the fighter, so he is never lost in the ramp. In the one view the shared camera's target becomes the launched fighter's lead point immediately (not after the ramp).
- **A teleport** (blink) follows `blinks.md`: held framing, then the catch-up rule above.
- **The test.** `split_sweep` gains a scenario that launches at the p90 and maximum speeds (26,700 and 45,600 units a second), in one view and in a split, and a blink of 8 fighter heights; the check is "the fighter's offset from his anchor never exceeds 0.20 of the width, and the cut count is zero outside a teleport". A real-match run counts whip and cut ticks and reports them.

## 3. Who the camera follows on a launch

Orb: the camera follows the launched fighter, so after knocking the opponent away he cannot tell what his own fighter is doing. Today's launch follow is a solo shot on the launched fighter (`split-screen.md` section 8), on 19.5% of ticks. Launch distances: median 45 fighter heights, 90th percentile 241, so about half the launches end inside the widest shared view (about 50 heights at the floor) and need no following at all.

First, a rule that is not an option: **a launch that ends inside the widest shared view is not followed.** The one view zooms out (down to the floor) and shows both fighters, as the friend's feedback asked. The options below are for launches that leave that view.

| Option | One view | Split | Cost and trade |
| :--- | :--- | :--- | :--- |
| **A. Stay on the attacker, the launched fighter in an inset** | The camera stays on the attacker at his normal size. The launched fighter is in an inset (24% of the width, 24% of the height, at the edge toward his direction, below the HUD plates) with his own chase camera. | Not used: the inset is the second pane. | One small extra render (a pane at a quarter of the area), cheaper than a split. The attacker stays readable; the victim is small (the inset is about 5% fighter height). |
| **B. Split on launch** | The screen opens to two panes at once (0.2 s, not the 0.45 s opening): the attacker's and the launched fighter's, divider tilted by height difference. | Already split: the launched pane gets the chase, the attacker's pane stays normal; no expansion. | Both always visible. The divider churns on short launches (so only for launches predicted beyond the widest view). Costs a two-pane frame. |
| **C. Chase only when the local player is the one launched** | The local player launched: chase solo (today). The local player is the attacker: the camera stays on him, the victim leaves the view and the edge pointer and ring map show where. | Same rule by pane. | Cheapest. In two-player (both local) there is no single local player, so it falls back to B. |

**Recommended hybrid (default):** C for one human against the AI (chase if the human is launched; if the human attacked, stay on him with option A's inset for the victim); B in two-player. Settings expose A, B and C for Orb to pick: `camera.launch_follow = "auto" | "inset" | "split" | "chase"`. In `auto` and the human-attacker case, the inset holds from the launch until the landing plus the land hold, then dissolves (0.3 s).

**What the chase camera is.** Behind the launched fighter along his velocity: in the side view, the camera keeps him at 35% from the trailing edge (as now) and adds a slight roll-free lean ahead; in the three-quarter view (section 8) it is a true trailing camera. It follows the lanes' depth (`depth-and-chains.md`), and ends at the land hold.

## 4. The shot list

Orb allowed cuts for: finishers, transformations, world changes, crippling moments, building smashes and beam struggles; wanted a fast push-in to the point of contact for impacts; wanted close-ups at the match intro, transformations, finishers and the KO.

**Rules for all shots.** A cut is one tick (with the 0.08 s fade-in of section 2 only when it is a safety cut). The camera never pauses the sim and never takes input. **Sim pauses are the sim's:** hit-stop and cinematics are sim-owned durations in whole ticks; the camera shot is timed inside them. Non-sim-owned cuts have a 6 s cooldown and a cap of 6 a minute so they stay events. Every shot returns by cut or by the ordinary ease (named below).

| Shot | Trigger (event) | Camera | Duration | Sim | Control |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **Impact push** (not a cut) | `damage` heavy, `building_hit`, `decisive` | Zoom +10% toward the contact point over 0.08 s, held through the hold, back over 0.4 s | 0.5 s | Hit-stop 0.06 to 0.35 s (sim) | Live |
| **Chase** | `launch` (section 3) | Trailing the launched fighter; ends at the land hold | the flight, max 6 s | Runs | Live |
| **Building smash cut** | `building_hit` first link, tower or skyscraper | Cut to a low wide angle on the building face at the impact point for the sim's 0.35 s hold, then cut back; the fighter leaves frame through the wall | 0.35 s | The hold (sim) | Live |
| **Beam struggle** | `game.clash` set | Cut to a two-shot from the side at the midpoint; a push-in at each reversal keyframe (`clash.shape`); a cut to a close-up of the struggle point for the final pulse | the clash (`dur`) | Runs | Live (it is the minigame) |
| **Crippling moment** | `region_broken` | Close-up on the broken region's fighter, 0.7 s, then ease back | 0.8 s | Optional sim slow (see below) | Live |
| **Finisher** | `finisher_start {dur}` | Wind-up close-up (0.6 s), a low-angle push as the blow lands, a wide hold on the aftermath | the sim's `dur`, 2.5 to 4 s | Sim-owned: the fighters are in the finisher | Locked by the sim |
| **Transformation** | `cinematic_start {transformation}` | Close-up on the face, rise to full body, wide reveal; the opponent's sliver or a cut to him respecting it | the sim's `dur`, 3 to 6 s | Sim-owned, respected, uninterruptible (Orb's earlier ruling) | Locked for the transformer; the opponent waits |
| **World change** | `fold_start` and `unfold` | Wide establishing shot on the fold's centre (section 6 of `split-screen.md`) | the fold | Sim-owned | Locked |
| **Match intro** | match start (`newMatch`) | Close-up on each fighter in turn (1.2 s each), then a pull-back to the fight; skippable by any input | 3 s | Sim holds at tick 0 for the intro, or a camera-only intro over a live fight (see below) | Skip with any key |
| **KO** | `ko`, `finisher_start` | Dolly to a close-up on the loser, hold | the sim's slow motion 2.2 s, then 3 s | Sim-owned slow motion (`game.ts`) | Locked |

**Does the sim pause?** Three options for Orb on what happens during a cinematic moment:
1. **(Recommended) Camera-only cuts, sim-owned cinematics.** The camera shots in the table never pause the sim. The few shots that the sim already owns (finisher, transformation, fold, KO) lock the fighters involved for the sim's `dur`, and the opponent respects it; other input is buffered (stance changes queue) and a stance shown in the HUD. Replay-safe and netcode-safe, because every pause is an integer tick count in the sim.
2. **A freeze-frame for set pieces.** The sim holds for a fixed whole number of ticks on a building smash and a crippling moment (0.35 s and 0.5 s), during which the camera cuts. Same machinery as hit-stop; it costs the fight 1 second a minute of dead time.
3. **Cinematic mode with a skip.** Finisher, transformation and KO are skippable (hold a button) after the first time per match; nothing else pauses. Adds an accessibility benefit and a replay flag. Needs the sim to accept a skip as an input (it is deterministic: the skip is a recorded intent).

I recommend 1, with 3 for repeated cinematics later. Slow motion at 2 of 10: the camera cannot slow the sim (render-only slow motion changes no tick), so the intensity is a sim value (the KO's `game.ts` 0.35 for 2.2 s, and hit-stop lengths), set by a match-header scale (Controls' `hitstopScale` idea); at 2 of 10 it is about 25% of the full effect. That needs the sim (section 9).

## 5. Impacts, in detail

- **Push-in to the contact.** The focus moves toward the contact point `(x, y, z)` by up to 40% of the distance from the camera centre (bounded to 12% of the width), zoom +10%, in 0.08 s (5 ticks); it holds through the sim's hit-stop (0.06 to 0.35 s) and returns over 0.4 s. In a split only the pane that holds the contact pushes. The existing +6% building-hit push (`depth-and-chains.md`) becomes this.
- **Shake.** Controls' per-event `k` table with the new default of 2 of 10: the player's scale 0.2 on a 0 to 1 scale where 1 is the old prototype strength (cap 4.2% of the height, Controls' `k` times 1.4). Against today's default (Controls' table at 100%, cap 3%) that is about 0.28 of what is on screen now. The cap and the far-pane rule stay.
- **The chase** is section 3.

## 6. The lanes: the deepest readable depth

Simulation's band is 32 fighter heights (2,400 units) deep but starts at +5 heights, so its back edge is -27 heights (-2,025 units), not -32. The camera's answer to "the deepest `z` at which a fighter stays readable": **all of it**, with these sizes (a fighter's apparent height at 720p, `75 K / (K / zoom + w)`, `K` = 1,343):

| Depth | w (units) | zoom 0.6 (shared, wide) | zoom 1.0 (fight default) | zoom 1.34 (cap) |
| :--- | ---: | ---: | ---: | ---: |
| Block row 1, -12 bh | 900 | 32 px | 45 px | 53 px |
| Back street, -18 bh | 1,350 | 28 px | 37 px | 43 px |
| **Block row 2, -27 bh: the band's back edge** | 2,025 | 24 px | 30 px | 33 px |
| Scenery row 3, -38 bh (no fighter goes there) | 2,850 | 20 px | 24 px | 26 px |

- Against the 23 px floor: the whole band reads at the fight zoom (30 px at its back edge, -27 heights) and at the cap (33). At the wide shared zoom (0.6) the back edge is 24 px, just above the floor; the shared zoom still adds a rule, **size for the deeper fighter** (zoom up until the smaller fighter's apparent height reaches the floor), so the wide shot never shows a fighter under 23 px.
- **The band stays as planned (Simulation's correction: it ends at -27 heights, which is the worst case above; option 8 is answered).**
- **Two fighters in different lanes in one view.** The camera frames the pair by their screen positions, not their world positions: with perspective scales `s_i` the screen midpoint is zero when `cam.x = (x_i s_i + x_j s_j) / (s_i + s_j)`, and the vertical likewise from `y` and the depth shift. The zoom for the pair is the larger of the separation zoom and the deeper fighter's floor zoom. In a split each pane already frames one fighter with `depth-and-chains.md` section 2.
- **Reads per tick.** I need `z`, `zT` and `ex.z` (fight-lanes.md section 8, Camera 2) and `launch_depth` for every launch (the end depth and the time to it); everything else is in the events I already read. The camera keeps reading only state and events.

**The cut-away (circular).** Rendering's porthole (B3) cuts away whatever of a building lies nearer the camera than the fighter, in a dithered circle around him. The camera's part: the fighter's apparent height and screen position per pane every frame (so the radius follows his size: `radius = max(70 px, 1.6 x his apparent height)`), a request flag when a footprint lies between the camera and either fighter (Rendering has the footprints), and an order for the two panes of a split to use their own fighter. In a shot I may ask for no cut-away (a building-smash cut wants the wall whole). The camera also avoids framing a fighter under UI's edge chips (UI dodges the fighter; Camera keeps him off the clear zone's edge at rest).

## 7. Cuts in a lane world: the occlusion cost

In the prototype a building hid a fighter 35% of the time from the side and 26% from the three-quarter view. So occlusion is not an edge case: the cut-away is on whenever a footprint is in front, and the camera's side of it is cheap (a position and a size per pane per frame). Where a building stays in front for a whole exchange, the choreographer can shift the exchange's depth (Encounter's alignment); the camera never moves the sim.

## 8. Both angles

Orb: not sure; show both. The prototype's side-on view is raised about 11 degrees; the three-quarter view about 49 degrees.

- **The toggle.** `camera.angle` = "side" (default) or "three_quarter", a debug key F6 and a setting. Pitch is a presentation parameter: `CamParams.PITCH_SIDE` = 11 degrees, `PITCH_34` = 49 degrees.
- **What changes.** A fighter is a vertical object, so his apparent height falls by `cos(pitch)`: 0.98 at 11 degrees and 0.66 at 49. To keep the same fighter height the zoom is multiplied by `1 / cos(pitch)` (x1.5 at 49). Depth moves a fighter up the screen by `w sin(pitch) zoom`: at 49 degrees the back edge of the band is 1,800 units up the screen, so the focus and the anchors must include it (the same compensation as section 2 of `depth-and-chains.md` with a pitch term).
- **What it needs from Rendering.** `CameraRig` takes the pitch (a rotation about the x axis) and the plane mapping becomes the true projection; `SplitFrame.screen_pos` and `hud_anchor` then use the 3D camera's unproject (as the one-view path does today) instead of the closed form. The porthole and the shadows already work in 3D. Cost: none in frames; a day of work in `camera_rig.gd` and my mapping.
- **Prototype findings to honour.** Side-on: the genre feel, depth nearly invisible without aids (shadow and lane line). Three-quarter: depth and streets obvious, less occlusion, but smaller fighters and altitude harder to read. So the zoom multiplier above is what lets Orb compare them fairly; and altitude cues (a ground shadow already, an altitude pole as debug) matter more in the three-quarter view.

## 9. Settings, reduced motion, and what I need

- **Settings** (UI): zoom preference (0 to 10, default 7); shake intensity (0 to 10, default 2); slow-motion intensity (0 to 10, default 2, a sim header value); launch following (auto, inset, split, chase); camera angle (side, three-quarter; also F6); reduced motion (existing). All read by the rig through `SplitView`.
- **Reduced motion:** no push-ins, no whips (the lag bound's whip becomes a 0.15 s ease; the cut stays a cut but with a 0.3 s dissolve instead of the 0.08 s fade), no chase lean, cuts of the shot list become dissolves of 0.3 s, shake at a quarter of the player's scale (as now), the intro is a still cut.
- **Rendering needs:** pitch in `CameraRig`; the inset pane (a small pane viewport and the compositor's inset rect, which I build); the porthole's per-pane radius input from my frame (a field, `cutaway[i] = {radius_px, request}`); and a 0.08 s fade layer for the safety cut (mine, in the compositor).
- **Controls needs:** the shake table scaled at the new default; confirm the impact push (+10%, 0.08 s) against their hit-stop table; the cut cooldown (6 s, 6 a minute).
- **Sim needs:** `launch_depth` for every launch (the end depth and time); `z`, `zT`, `ex.z` readable; a match-header slow-motion scale (replay-safe), and if Orb picks option 3 of the pause options a recorded skip intent; the intro hold at tick 0 if Orb wants a paused intro (otherwise camera-only).
- **UI needs:** the inset's position (below the plates, toward the launched fighter's side) in the clear-zone map, and its pointer chip.

## 10. Options that need Orb (my pick first)

1. **Launch following:** hybrid (C for one human, B for two players, with A's inset when the human is the attacker); or A, B or C alone.
2. **Control during cinematic moments:** camera-only cuts with sim-owned cinematics locking the fighters involved (recommended); a freeze-frame for set pieces; or skippable cinematics.
3. **Default size:** 11% in a fight (79 px at 720p), 8.5% in a pane. Say "bigger" or "smaller" and I move the numbers.
4. **The minimum:** 3.2% (23 px at 720p) as the floor, with the split at 3.5%. A higher minimum (4%, 29 px) means more splitting, as the friend's feedback and Orb's earlier note pull in different directions.
5. **Shake default:** 2 of 10 = about 0.28 of what is on screen today. Slow motion at 2 of 10 (about a quarter of the KO's current slow motion).
6. **The cut cap:** 6 camera cuts a minute with a 6 s cooldown; the sim-owned cinematics do not count.
7. **Angle:** side-on by default with the three-quarter view on F6, until Orb picks.
8. **The band:** answered; it stays (back edge -27 heights, 30 px at the fight zoom).

## 11. Build order (when Orb answers)

1. Numbers, the lag bound and the launch-event rigidity (small; the biggest relief for Orb's complaints). Tests as in section 2.
2. Size and zoom setting, the floor, the wide hold's new range.
3. The shot list: impact push, chase, then the cuts in order of how often they fire (building smash, beam struggle, crippling), then the sim-owned shots when their events exist.
4. The inset and the launch-following options.
5. Pitch and the second angle (needs Rendering).

## 12. Orb's picks (2026-10-02)

- **Cinematic moments.** Short ones run live (push-ins, shake, the chase, the quick impact cut); long set pieces pause the fight for both players. Game Design owns the rules and the list of set pieces. For the camera this means: the shots of section 4 that are camera-only stay camera-only and never touch the sim; a set piece that pauses the fight is a sim-owned cinematic (`cinematic_start {dur}`), and the camera shots inside it are timed to its `dur`. The camera does not decide what pauses.
- **Launch following: the hybrid.** When the human launches the opponent, the camera stays with the human's fighter and **cuts to the impact for about half a second** (a push-in and shake), then returns with the opponent framed. When the human is launched, the camera chases. Two humans on one screen use the split. Orb preferred the impact cut to a standing inset, so **the inset (option A) is dropped from the build.**
  - **The impact cut** (`launch_follow = "auto"`): on the `launch` event with the human as the launcher, the shared camera holds the attacker; at the `building_hit` or the landing (whichever comes first, at most 1.5 s after the launch) it cuts to the contact point for 0.5 s (zoom +10% on the push, the shake of Controls' table), then eases back to a framing of the attacker and the opponent (the shared zoom-out, down to the floor, or the split if they are too far apart). A launch that ends inside the widest shared view is not followed at all, as before.
  - **The human is launched:** the chase (section 3), as today but at the new size.
  - **Two humans:** the split opens at the launch (not the solo expansion), each pane on its own fighter; the launched pane chases.
- **Build order** after the lag bound and the size work: (3) the impact cut and the hybrid rule; (4) the shot list in the order of how often each fires, with the sim-owned set pieces as Game Design's list lands; (5) the angle toggle (needs Rendering's pitch).

## 13. What is built (2026-10-02): the lag bound, the size and floor, the settings

In `render/camera/` (`camera_params.gd`, `split_rig.gd`, `split_frame.gd`, `split_view.gd`, tests):

- **Sizes.** The one view's margin is `|d| + 450 / m` (it was 700), so melee is 11%; a split pane is 8.5%; the launch chase 8%; the zoom-in cap 14% (16% at the top of the setting); a close-up (transformation, KO) may go to 20%. The floor is 3.2% and the one view never zooms out past it. The split line is 3.5% and the merge line 4.7%, judged on the size the fight would like, independent of the setting.
- **The zoom setting.** `m = exp(0.08 (pref - 7))`. Option for UI: **`camera_zoom`, an integer slider 0 to 10, default 7**, applied with `SplitView.set_zoom_pref(v)`. The rig's default is 7, so nothing is needed in `main.gd` until UI adds the option; when it does, main's `_sync_split_options` needs `split_view.set_zoom_pref(float(o.get("camera_zoom", 7)))`.
- **Shake.** The strength setting is `camera_shake`, **an integer slider 0 to 10, default 2** (`SplitView.set_shake_pref(v)`); the effective scale is `pref / 10 x 1.4` (10 is the old prototype's strength, cap 4.2% of the height), times the legacy `shake_scale` (1.0), times a quarter in reduced motion. The default is therefore 0.28 of what Controls' table gave before. Likewise main would add `split_view.set_shake_pref(float(o.get("camera_shake", 2)))`. Slow motion is a sim header scale and is not touched.
- **The lag bound** (section 2): between 6% and 20% of the width off his anchor the focus filters speed up to 7x; beyond 20% the focus is held to the bound; beyond 1.5 screens in a tick it cuts, with a 0.08 s fade from 70% brightness (0.3 s in reduced motion, where the whip is also off). The counters `lag_whips` and `lag_cuts` are on the rig.
- **Launch rigidity.** A launch out of the one view takes the screen on the event: the pane's zoom is seeded from the one view's and the anchor from the fighter's screen position, so the take-over is continuous and nothing is lost in a ramp.
- **Measured** (a fighter launched 20,000 units from a merged start 500 units apart, and from a split 9,000 units apart; old rig = commit 9ed784a, new = this work; 1280 by 720):

| Launch speed (units a second) | Old rig: worst offset from anchor; ticks off screen | New rig |
| :--- | :--- | :--- |
| 10,816 (median) | 0.29 of the width; 0 | 0.00; 0 |
| 26,718 (90th percentile) | 0.69; 11 of 104 | 0.00; 0 |
| 45,606 (maximum) | 1.17; 13 of 86 | 0.00; 0 |

  The smallest the chased fighter got was 43 to 44 px in the old rig and 58 to 61 px in the new. The new rig holds the fighter on his anchor exactly because the speed-up zone makes the filter near-instant at launch (the whip and the cut never fire: `lag_whips` 0, `lag_cuts` 0 in the launch tests). A real-game strip of a 26,000-unit launch (seed 4, tick 8152, a melee start), old above and new below, is in `img/fast-launch-before-strip.png`, `img/fast-launch-after-strip.png` and `img/fast-launch.gif` (old left, new right); the fighters are small in both because that launch is a chain inside a rubble field; the table above is the clearer evidence.
- **Share of the run in two panes** (the rig's `split` mode, five AI matches of 4,000 ticks): 4%, 6%, 7%, 6% and 10% (mean about 7%), with the new 3.5% line and the floor. Opening, closing and slam add a few percent more.
- **Checks** on a clean copy of HEAD with these files and a fresh import: `split_sweep` (the earlier scenarios, five new lag-bound launches, seven real matches), the composite picture check (worst frame-to-frame spike 2.9 against a limit of 4), `pane_check`, and `determinism` pass; the sim's gameplay hash is identical with and without the rig.

## 14. What is built (2026-10-03): the pitched mapping, the cut-away request, the hybrid launch rule

- **The mapping through a pitch.** `SplitFrame.project(...)` is the pinhole of Rendering's `CameraRig`: the camera orbits the fighter-plane point at the screen's centre by the pitch, at the distance that gives the zoom there. `screen_pos`, `apparent_height` and `hud_anchor` use it (the old closed form survives only at pitch 0 with no depth, where it is identical). A check in `split_sweep` compares it with `CameraRig.unproject_position` at pitches 0, 11 and 49, three zooms and six points (plane and deep): worst difference 0.001 px. The rig solves each pane's camera so the fighter's chest lands on his anchor with a few Newton steps (exact at pitch 0 in one), and the one view's pair midpoint lands at 0.7 of the height as before. A raised camera foreshortens a standing fighter by cos(pitch), so every size target is multiplied by 1 / cos(pitch). The frame carries `pitch` (degrees) for Rendering's panes. A change of pitch is a cut (one frame, not interpolated).
  - **What it costs.** At 49 degrees a fighter deep in the band is smaller: the back edge of block row 2 (-27 heights) reads 15 px at its best against 24 to 30 px straight on, and the front street 32 px against 39. At 11 degrees it is within a pixel or two of straight on (31 px at the back edge). Three-quarter is a different genre, as the prototype said, and a back-row smash is small in it. That is the number for Orb's comparison on F9 (Alt+F9 on Rendering's key).
- **The cut-away request.** `frame.cutaway[i]` is `{request, radius_px, only}` per pane: the radius is the larger of 70 px and 1.6 times that fighter's apparent height, and `only` is the pane's own fighter while two panes are up (so each pane cuts away for its fighter only) and -1 in one view. The request stays on; a building-smash shot will turn it off for the wall it wants whole.
- **The hybrid launch rule** (Orb's pick, section 12). `rig.launch_follow` = "auto" (default), "chase" or "split"; `SplitView.set_launch_follow(v)`; UI option **`camera_launch_follow`** with the choices auto, chase, split (default auto). In auto:
  - one human who launched the opponent: when the pair no longer fits the shared view (a fighter out of frame, or below the floor), the camera does not split; it takes the human's fighter alone at the pane size (continuous with the one view: same zoom and screen position at the take-over, then easing to a position that leaves room on the side the opponent was thrown to) and **holds on him**. At the impact (a `building_hit` for the victim, the landing, or 1.5 s) it **cuts** to the victim at the push-in size for 0.5 s (a one-frame hard cut; the shake and hit-stop are the sim's and Controls'), then ends the shot and the usual rules put the pair back in the shared view or the split. A launch that stays inside the shared view is not followed at all;
  - one human who was launched: the chase, as before (a solo shot);
  - two humans: no solo shot; the split opens by the ordinary out-of-frame rule and the victim's pane chases (rigid focus, chase size) until a land hold after he lands; a launch while already split does the same;
  - no human (the AI demo): the chase.
  - Tests: the human is held on and never leaves the screen by a pixel; the cut lasts 31 ticks (0.5 s) with exactly one cut frame, the victim on screen throughout it; the split does not open during the hold; two humans get the split and no hold; a launched human is chased. The inset (option A) is not built; the inset pane Rendering made (`make_inset`) stays unused.
- **Checks** (clean HEAD copy plus these files): `split_sweep` including the new scenarios (hybrid, pitch 11 and 49 depth runs, three real matches with a human slot idle and one at pitch 49), the composite picture check, `pane_check` and `determinism` pass; the sim's gameplay hash is identical with and without the rig. A live frame at 49 degrees with the split open is in `img/split-pitch-49.png`.
- **Next:** the set-piece shots of section 4 in the order of how often they fire (the building smash cut, the crippling close-up, then the sim-owned finisher, transformation and KO shots as their events land), with Game Design's list of what pauses the fight.

## 15. The set-piece shots (2026-10-03)

Built against events that exist today. Two kinds: **sim-owned shots** (the fighters are locked by the sim for the event's `dur`; the camera fills it, no cooldown) and **camera-only cut-ins** (they never touch the sim, run in one view only, never over a launch hold or the impact cut, and are held to a 6 s cooldown and 6 a minute).

| Shot | Event (fields read) | What the camera does | Length |
| :--- | :--- | :--- | :--- |
| **Transformation** | `transform {actor, dur}` (also `cinematic_start`) | One hard cut to the transformer, then a dolly: face (14%), body (11%), wide reveal (7%) at 25%, 45% and 70% to 95% of the hold. The opponent keeps the 14% sliver in a split. The tier-up push is part of the shot | the sim's hold |
| **Finisher** | `finisher_start {target, dur}` | One hard cut to the loser at fight size, dolly to 16%; the KO takes over at the end (its dolly and the sim's slow motion) | the sim's `dur` |
| **KO** | `ko` (state) | as before: dolly to a close-up on the loser | the sim's slow motion |
| **Crippling moment** | `region_broken {actor}` | Cut to a close-up of the broken fighter, 11% to 16%, 0.8 s, cut back | 0.8 s |
| **Building smash** | `building_hit {link 1, h >= 300, x, y, z}` | Cut to a wide view of the wall: zoom to fit 70% of its height (down to the floor, up to 11%), the point at the lower middle, the occlusion cut-away off so the wall stays whole; cut back | 0.45 s (the sim's 0.35 s hold and a beat) |
| **Beam struggle** | `game.clash` set | A push on the shared view (the tier push's shape: in 0.25 s, hold 0.5 s, out 0.6 s) | 1.35 s |

- **Cuts.** A cut is one frame (the frame is flagged `cut`, so it is not interpolated); the tests count exactly one at the start of a transformation or a finisher and two (in and out) for a cut-in. The safety cut of the lag bound is separate and counted apart (`lag_cuts`).
- **Settings.** Reduced motion turns every camera-only cut-in off (the sim-owned shots stay but their cut becomes the ordinary pane take-over), as it turns the pushes off.
- **Tests.** Injected events: the transformation goes face, body, reveal (101, 86 and 64 px at 720p) with one cut; the finisher dollies 83 to 111 px with one cut; a crippling cut-in lasts 48 ticks with two cut frames and six more breaks inside the cooldown change nothing; a building smash cut-in lasts 27 ticks with the wall on screen and the cut-away request off; the clash push raises the shared zoom by more than 6%; and in real matches (eight, up to 8,000 ticks, some with a human slot and one at pitch 49) the per-minute cap holds. Real AI matches fired only one cut-in in 8,000 ticks (`region_broken` is rare early); the live rate will be seen in play.

### Orb's later additions (planned, not built)

- **Tumbles, bounces, skips and launches off crater lips** (World and Game Design are planning events `left_ground`, `bounce`, `skip`, `land`). The lag bound and the launch rules already cover the motion. What the camera adds when the events exist: a `bounce` or `skip` is a small impact push (3%, 0.1 s, at the contact point, in the pane that holds it) and no cut; `land` ends a chase's land hold at once instead of waiting for the state change; a launch off a lip is an ordinary launch (the `launch` event's speed gate decides whether it is followed). A tumble slower than 4,000 units a second is not followed; the shared view zooms for it. I need `x`, `y`, `z` and the speed on each event.
- **"On the Chin" (the rival's signature absorb, pitches.md section 7b): a 1.5 s pause with a camera push.** It is a sim-owned shot like the finisher: on its start event (name and fields to come, I assume `absorb_start {actor, dur}`) the camera cuts to the absorber at fight size and pushes in to 16% over the pause, with a short breath of the pair framing at the end; no cooldown. It is built after his first moveset, with the event.

### Which shots pause the fight (against `docs/architecture/q10-pace-acts-pauses.md`)

Orb's pick: the sim pauses for the transformation, the world change and the planet giving way, about 2 s a minute, as `SimPause` versions: **full** (3 s, up to 4 s for a final-form reveal), **short** (1.5 s) and **live** (0.8 s, no pause). Events: `pause_start {kind, actor, version, dur}` and `pause_end {kind}`; `transform` gains `version`. A paused tick is a frozen tick; the rig is still stepped every tick and its shots run in real time on the fixed step, so they play for the pause's length.

| Shot | Sim-owned? | Pauses the fight? | Camera behaviour |
| :--- | :--- | :--- | :--- |
| Transformation, full or short | Yes | **Yes** (3 s or 1.5 s) | The cut, the face-body-reveal dolly over `dur` (the phases are fractions of it, so 1.5 s plays the same shot faster) |
| Transformation, live step | Yes | No (0.8 s hold) | No shot and no cut: the tier-up push only. A hold under 1.2 s with no `version` is read as live |
| World change, planet giving way, time cap (`pause_start` kinds other than transform) | Yes | **Yes** | The shared view pulls out to 75% of its zoom over 0.5 s, holds, and comes back over 0.5 s when the pause ends (a wide establishing beat; the fold's own shot, when it has one, takes priority). Tested |
| Finisher | Yes (the fighters are locked) | Not a `SimPause` in Orb's list | Cut and dolly over `finisher_start.dur`; no cooldown |
| KO | Yes (slow motion) | No | The dolly over the sim's slow motion |
| "On the Chin" absorb | Yes | Yes, 1.5 s (when built) | Cut and push over the pause |
| Impact push, crippling cut-in, building-smash cut-in, beam-struggle push, hybrid impact cut, the chase | **No: camera only** | No | Never touch the sim; cut-ins have the 6 s cooldown and 6 a minute cap |

Over a 3 s pause the host would otherwise release buffered presses all at once (Controls' note in the q10 plan); that is the host's, not the camera's.
