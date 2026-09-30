# Camera: fighters in depth, building hits and chains

Owner: Camera and Cinematography. Status: design note, 2026-09-29, for World's B2 (`docs/world/b2-plan.md`, `buildings-in-depth.md` §4b). Nothing is built; it builds when B2's events and the fighter's `z` land. It extends `split-screen.md`.

**Summary**
1. A fighter at depth is smaller and nearer the screen centre (perspective), so the pane and launch cameras must compensate: zoom in and offset the focus so the fighter still lands on its anchor at a readable size.
2. Depth-aware readability: `s = d / (d + w)` with `d` the camera's distance to the fighter plane and `w` the fighter's depth away from the camera (`w = -z`, `z` positive toward the camera). All screen mapping for a deep fighter goes through `s`.
3. A brunt launch is a solo shot (the launched fighter's pane takes the screen, as now). `launch_depth` gives the first hit point in advance, so the camera leads to it; `building_hit` is an impact push that fits inside the sim's hold; `chain_link` re-aims the lead at the next building.
4. In the widest case (the back row, 38 fighter heights deep) the fighter cannot reach the normal 47 px from the plane's zoom range; the shot accepts about 25 px there for the second or two it lasts.
5. The tick-level work is small: `SplitFrame.screen_pos` and `hud_anchor` take `z`, `_cam_from_focus` and the zoom target take the fighter's depth, three event reads. Tests get a depth sweep.

**Open questions for Orb**: none from Camera. For World and Rendering: see the end. The back-row size risk is World's to fix in B2 step 4.

## 1. Facts from B2

- Rows of buildings sit at +10 (foreground), -8 (front street), -22 (mid) and -38 (back) fighter heights from the plane (+750, -600, -1,650 and -2,850 units; `z` is positive toward the camera, confirmed by World, and `launch_depth.dur` and `chain_link.dur` are seconds of match time); the fighter's `z` follows an eased path from `aimZ0` to `aimZ1` while it flies to its target building (a smoothstep of x progress), so `z` is smooth sim state, 0 when not aimed and easing to 0 in 0.3 s afterwards.
- Events: `launch_depth` {x, y, x1, y1, z, b, dur, n, owner, victim} at the launch beat; `building_hit` {b, x, y, z, damage, ratio, outcome, link, n, spd, ux, uy, kind, w, h, victim} on each hit; `chain_link` {from, to, x, y, z, x1, y1, z1, dur, link, victim} when the fighter bursts through toward the next; `building_fall`.
- Holds: 0.35 s on the first hit, 0.12 s on each further one, capped at 0.8 s in all, taken by the sim (`dirS.stop`). The camera reads them and never sets them.
- The camera's distance to the fighter plane is `d = vh / (2 zoom tan(15 degrees))`, i.e. `K / zoom` with `K = vh / 0.536` (1,343 at 720p). At the usual zoom 0.6 that is 2,240 units, so a fighter 2,850 units behind the plane is at 5,090: it draws at `s = 0.44` of its plane size, and 0.44 of the way from the screen centre to where it would be. A fighter at the foreground row (+750) draws at `s = 1.5` and is pushed outward.

## 2. Mapping a fighter at depth

```
w  = -f.z                          depth away from the camera (negative toward it)
d  = K / zoom
s  = d / (d + w)                   perspective scale of that fighter
screen = C + (p_plane - C) * s     C = (vw / 2, vh / 2), the camera's axis; p_plane = the plane mapping of section 3 of split-screen.md
height = 75 * zoom * s
```

- `SplitFrame.screen_pos(i, wx, wy, wz = 0)` and `hud_anchor(slot, x, y, z)` use it (Rendering's hybrid projection places the fighter's pivot with the same perspective, so the numbers agree; the fighter keeps its own orthographic-style body scale around the pivot).
- **Anchoring.** To put a deep fighter's chest at anchor `P`, aim the plane mapping at `P' = C + (P - C) / s` (it can be far off screen for small `s`), then apply the existing focus offset: `cam.x = focus.x - (P'.x - vw/2) / zoom`, and the same in y. `_cam_from_focus` takes `s`; the follow filters do not change.
- **Zoom target.** For an apparent height `T` (px), the zoom that gives it is `zoom = 1 / (75 / T - w / K)`, capped at `ZOOM_MAX` (1.15) and floored as now. In the back row (`w` = 2,850, `K` = 1,343) the denominator goes to zero at `T` = 35 px: the fighter cannot be made larger than that even with the camera against the plane, and at the zoom cap 1.15 it is 25 px. So the depth shot targets `min(T, what the cap gives)`. The zoom rate cap (2.4 e-folds a second) still applies, and the eased `z` makes the target move smoothly.

## 3. The shots

**Brunt launch (`launch_depth`, then `launch`).** The launched fighter is already a solo shot (`split-screen.md` section 8: its pane takes the screen, the other pane returns after the landing). What depth adds:
1. **Lead to the target.** From `launch_depth` the rig knows the first hit point `(x1, y1, z)` and the time `dur`. The follow anchor's trail (the fighter sits 35% from the trailing edge) turns into a lead toward that point: the focus is `fighter + 0.35 * (hit - fighter)` in x and y, so the building it is about to hit is in frame and the fighter is not lost at the far edge. Zoom targets the apparent height above; the building's top is not required to fit (a tower is 57 fighter heights).
2. **Depth compensation** as in section 2, on the fighter's live `z`.
3. **The impact (`building_hit`).** During the hold the sim has frozen, so the camera adds a push: zoom +6% over the first 0.15 s, holding, returning over 0.4 s after the hold; shake `k` from Controls' table grows per link (the table is theirs). The framing centres on the hit point `(x, y, z)`, not the fighter, for the hold, so the wreck is in view. A collapse (`outcome` collapse) holds the shot on the building until `building_fall` has begun, at most 0.6 s past the hold.
4. **A partial wreck or a crack** ends the shot as an ordinary landing (land hold 0.35 s, then the settle decision).

**Chain (`chain_link`).** Each link moves the lead to the next building: focus lerps to `(x1, y1, z1)`'s pane position over `dur` (at most 0.5 s), zoom eases toward a chain framing that fits the next building's standing height `h` in 70% of the screen height when that keeps the fighter at 22 px or more (`zoom = clamp(0.7 vh / min(h, 2,500), floor, R_LAUNCH zoom)`), so a tall tower is shown wide and a house close. The hold of 0.12 s per further link is short: the push is 3% for links after the first. A chain of four is about 2.5 s of one shot; the 6 s follow cap and the settle decision are unchanged.

**Splits and depth.** The launched fighter's pane expands as in section 8, so depth never has to be shown in two panes at once. If the launcher is the human fighter and the target is the AI's, the same rule holds (the shot follows the launched fighter). The split-or-merge trigger stays on plane separation, with no depth term: a fighter is at depth for at most a few seconds and always inside a solo shot. A deep fighter that is not in a shot (an AI that hides behind a back row and stays) cannot happen in B2: `z` eases to 0 within 0.3 s of the flight's end.

## 4. Reduced motion

The lead and the chain re-aim become cuts to the hit point at each `building_hit` (0.4 s held shot, then the cut), the push is off, and the shake scale applies as elsewhere.

## 5. What to build, and the test

1. `SplitFrame.screen_pos` and `hud_anchor` take `z` (default 0, so nothing changes today); `SplitRig` reads `f.z` if the fighter has one and computes `s` per pane. (~40 lines.)
2. `_cam_from_focus` and `_own_zoom_target` take `s` and the compensated zoom (section 2). (~25 lines.)
3. The three event reads: `launch_depth` (store the hit point and `dur`), `building_hit` (impact push and hold framing), `chain_link` (re-aim). (~60 lines.)
4. `split_sweep.gd` gets a depth scenario: a launched fighter flying from the plane to each of the four rows with `z` easing as B2 specifies, alone and as a chain of four, in a split and in one view. Checks: the fighter is on screen inside its pane at every frame; its apparent height is at least the achievable minimum; the comfort limits of section 12 hold; the stand-in test pane learns the depth mapping so the composite check sees it. Plus: a fighter with `z` and no events (a pure state read) still frames correctly.
5. Tick cost: one extra division per pane; nothing measurable.

## 6. For World, Rendering and the EP

- **World:** `z` on the fighter in `hash` order and as a plain float in the fx `state` the views read. Sign and `dur` units are confirmed (above).
- **Rendering (B3):** the fighter's pivot uses the same perspective factor `s` as above; the ground band must reach `w` = 2,850 behind the plane for the back row to show ground under a building; near-plane clamp when the camera distance `d` falls below the foreground row's +750 (at the zoom cap `d` is 1,168, which clears it).
- **Risk:** at the back row a fighter is 25 px at best, under the 32 px the split line assumes elsewhere, for a second or two. If Orb finds that too small, the answer is to shorten the flight or slow it in the last row (World's tuning), not to move the camera plane.
