# Orb Combat EX: the dynamic split screen

Owner: Camera and Cinematography. Code: `render/camera/`. Status: built and measured, 2026-09-29 (sections 16 and 17 say what was built, what changed from the first design and what it costs). It replaces the wave-1 camera brief; what still fits from that brief is folded in (section 13). Orb's answers are in `docs/ep/vision.md`, "Dynamic split screen". The EP accepted the defaults below (solo split on, a 14% sliver, the swing, landscape only) and removed hiding from the base game. After playtest feedback the split line was lowered from 4.5% to 3.0% (merge 6.0% to 4.0%) and a wide hold added, so the shared zoom-out lasts longer (section 2).

**Summary**
1. One camera while the fighters are big enough to read; two panes when zooming out further would make either one too small. The test is the fighter's on-screen height as a fraction of the screen height: split under 3.0%, merge above 4.0% (22 and 29 px at 720p), with the shared zoom-out held a second longer while the fighters are still moving apart.
2. The divider is a straight line through the screen centre. Its normal points from one pane's fighter toward the other's, tilted up to 30° by their height difference. Each fighter sits on its own outer side, so each pane looks toward the opponent.
3. The panes follow the shortest way round the planet. When it flips (near the antipode, or when they pass each other), a hysteresis band and a 1 s dwell keep it from flickering, and the divider swings 0.6 s through the horizontal so the panes trade sides.
4. Merges: a 0.55 s convergence that ends in a dissolve when they fly back together; a 0.14 s slam, timed to land on contact, when one rushes in. Launches are followed by one full-screen camera locked to the launched fighter, then a merge or a split at the landing.
5. A pure, tick-stepped rig (`SplitRig`) decides everything from `S` and never writes it. Rendering's `PaneWorld` draws the world once per pane; `SplitView` blends the two textures (section 11). On the desktop a match costs +0.3 ms a frame on average with the split on, and a two-pane frame +0.65 ms over one view (section 17).

**Open questions for Orb** (defaults are mine; each is marked "Orb decides" where it appears)
1. Is 3.0% of the screen height (a 22 px fighter at 720p) the right "too small to read"? Orb's playtest found 4.5% split too soon ("hard to follow when a fighter picks up speed"; a friend liked the wide zoom-out). At 3.0% two full panes are up in 6 to 19% of the frames of an AI match. A higher number splits more often.
2. Solo against the AI: split or single camera with an edge pointer? Recommended default: split.
3. Respected transformation: the transformer takes the screen and the other fighter keeps a 14% sliver (recommended), or takes all of it?
4. Swap style: divider swing (built, gap-free) or the panes passing over each other like cards (needs wider render targets)?
5. Phones in portrait: stacked panes, or landscape only for the split?

---

## 1. What the reference camera does, and what we measured

The reference camera (`sim/core/view/camera.gd`, part of the goldens, so left as it is) frames the midpoint of the shortest arc with `zoom = min(vw / (|d| + 700), 0.8 vh / (|dy| + 500), 1.15) * (1 - 0.06 (tier - 1))`, clamped to 0.006 to 1.15, and eases at `k = 1 - 0.02^dt` (a 0.26 s time constant). A fighter is 75 units tall (`FighterView.HEIGHT`), so its height on screen is `75 z` px.

Two things break it at planet scale: fighters end up 3 px tall; and past half a planet it re-targets the other arc and pans 80 to 180 px a frame. I measured 24 seeds of AI against AI (161,897 ticks, mean match 112 s, run headless on the current sim; the throwaway script is not committed):

| Measure | Result |
| :--- | :--- |
| Separation under 10 / 20 / 30 / 60 / 120 / 400 fighter heights (bh) | 43% / 58% / 64% / 72% / 79% / 93% of ticks |
| Separation over 400 bh (a fifth of the planet) | 6.8% |
| Separation over 90% of half the planet | 0.02% (the antipode is rare in AI play, so it must be proved by test, not by watching) |
| Unsplit fighter height under 16 / 24 / 32 / 40 / 48 px at 1280 by 720 | 28% / 36% / 41% / 47% / 53% of ticks |
| Runs under 32 px | 248 in 24 matches (about 10 a match), median 2.4 s |
| Launches | 303 (12.6 a match); a launched fighter is in the air for 19.5% of ticks |
| Launch initial speed | p10 1,677 / p50 10,816 / p90 26,718 / max 45,606 units per second |
| Launch flight time | p10 0.18 / p50 1.08 / p90 3.37 / max 11.5 s |
| Launch distance (bh) | p10 2 / p50 45 / p90 241 / max 701 (the planet is 2,048 bh around) |
| Separation where a launched fighter comes to rest (bh) | p10 3 / p50 39 / p90 179 / max 873 |
| Rushes (an attacker closing the gap) | 291; 0.17 / 0.45 / 0.72 / 0.78 s (p10 / p50 / p90 / max); gap at the start p50 11 bh, p90 92, max 648 |

Consequences that shape the design:
- Split is the common state, not an exception: roughly two fifths of a match at the default threshold. It has to be comfortable, and the transitions must be quick and quiet.
- Launches are fast. A launched fighter crosses a 1,280 px screen in about a quarter of a second at the p50 speed and a tenth of a second at p90 (at zoom 0.45), so following it needs velocity feed-forward (section 4) and a rigid lock (section 8), not the reference's lagging ease.
- Rushes last under 0.8 s and can start up to 648 bh apart, so the slam (section 7) must be timed to the contact, not to the rush start.

## 2. The trigger: how big is the fighter on screen

```
z_u  = min(vw / (|d| + 700), 0.8 vh / (|dy| + 500), 1.15) * (1 - 0.06 (max_tier - 1))    the reference formula
r    = 75 * z_u / vh                                                                        fighter height as a fraction of the screen height
```

`d` is the held signed separation of section 5. The terms are the reference camera's own, so the merged shot is the shot you had before (the test checks it against `SimCamera` to 0.0000 px at rest). The reference framing puts the fighters up to 44% of the width from the centre, outside UI's fighter-clear zone (51% of the width), and UI's edge pointer chip can then sit on top of a fighter. I tried a fourth term, `0.51 vw / |d|`, that keeps both inside the zone (`CamParams.ZONE_W`); it moved the split line to 20 bh and Orb's playtest preferred the longer shared zoom-out, so it is off (ZONE_W = 0) and the chips are to dodge the fighters instead (UI: `UiSplit.pointers` already receives the anchors). Two differences from the reference: the camera's y floor is -3,200, not -180 (the reference's predates the scaled world, whose sea floor is at -2,810, and it lost fighters swimming below it), and the zoom rate is capped (section 12).

| Rule | Default | Why |
| :--- | :--- | :--- |
| Split when `r` stays below | 0.030 for 0.25 s, plus 1.0 s while the separation is still growing | 22 px at 720p, 32 at 1080p. A head is 27% of the body, so 6 px at 720p: below what the Marked masks' sigils and the head flashes need, which the panes then restore. The extra second is the wide "flying around the world" beat. Was 0.045 (32 px, no hold) until the playtest |
| Merge when `r` stays above | 0.040 for 0.40 s | 29 px at 720p. The 1.33 ratio is the hysteresis; in separation (16:9, tier 1, level) it is split at 49.9 bh, merge at 35.1 bh (it was 30 and 20 at 4.5% and 6.0%) |
| Minimum time in a split before a dissolve-merge | 1.2 s | The measured median run under the line is 2.4 s; anything shorter is not worth two transitions |
| Minimum time merged before splitting again | 0.8 s | |
| Closing guard | do not open if `r` predicted 0.4 s ahead (from the closing speed) is at or above the split line | A rush from 30 bh is over before the panes finish opening |
| Beam struggle | merged is allowed down to `r` = 0.030 | The struggle is the picture; section 9 |
| A fighter already lost | if the one-view camera has a fighter farther than 0.46 of the width from its centre (or off the top or bottom), split at once whatever `r` is: no dwell, and 0.25 s of merged age instead of 0.8 | Found by the real-match run: the reference framing loses the lower fighter once the height difference passes about 1,500 units |
| Zoom-out lookahead | the one-view camera zooms for the separation it will have 0.3 s from now if it is growing | Fighters dashing apart no longer leave the frame before the split opens |

Because `r` uses the reference formula, it responds to what the reference camera responds to: separation, height difference and tier. At tier 4 the split line is earlier still (the aura is bigger). A wider screen splits later and a 4:3 screen sooner. Every number is in `camera_params.gd` as a constant, so tuning does not touch code. **Orb decides** the two thresholds; the table of what they mean in pixels:

| Screen height | 720 | 1080 | 1440 | 2160 |
| :--- | ---: | ---: | ---: | ---: |
| Split under | 22 px | 32 px | 43 px | 65 px |
| Merge over | 29 px | 43 px | 58 px | 86 px |

Below 600 px of screen height the floor `r >= 18 px / vh` applies, so a small window splits earlier instead of showing 20 px fighters.

**Solo against the AI** is a player setting, `camera.solo_split` (default on, **Orb decides**). Off means that where the split would open, the human fighter's pane takes the whole screen instead (the other pane stays unrendered), and the opponent is shown by the edge pointer (section 10) and the ring map; it merges by the same rules. It applies only with exactly one human. Set with `SplitView.set_solo_split(bool)` (the rig's `solo_split`). In two-player, split is always on.

## 3. Divider geometry and the tilt law

Screen coordinates are pixels, x right, y down. `c` is the divider's centre, `(0.5 vw, 0.5 vh)`.

```
u     held signed separation A to B, shortest way (section 5); sigma = sign(u): +1 when B is to A's right
phi   signed tilt, positive when B is higher:  tan(phi) = 0.6 * (yB - yA) / max(|u|, 900)
phi   clamped to +-30 degrees, smoothed with a 0.20 s time constant, at most 120 degrees a second, 3 degree dead band
n     unit normal from A's pane toward B's pane:  (sigma cos phi, -sin phi)
```

Pane B occupies `(p - c) . n > 0`; pane A the rest. The divider line is perpendicular to `n`, so it leans toward the fighter that is lower and the higher fighter's pane gets the taller side. At level height it is vertical. At the 30° limit the divider's ends sit 0.29 vh (0.16 vw) either side of centre, and each pane keeps at least 34% of the screen width, so the fighter anchors below always stay inside their pane.

```
   B higher, to the right (phi = +20 degrees)        level (phi = 0)
   +---------------------+                          +---------+---------+
   |  A pane    \        |                          |         |         |
   |             \  B    |                          |  A      |     B   |
   |      A       \      |                          |         |         |
   |               \     |                          +---------+---------+
   +---------------------+
```

**Anchors.** Each fighter's chest is placed at
`P_i = c + (0, 0.12 vh) + s_i (n.x * 0.28 vw, n.y * 0.24 vh)`, with `s_A = -1`, `s_B = +1` (so each fighter sits on its own side of the divider; the first version of this line had the sign the wrong way round). At rest and level that is 22% of the screen width from its outer edge and 62% of the way down, leaving 28% of the width of world in front of it toward the opponent (the look-ahead that makes a pane "point toward" the other fighter) and more than one body height of headroom above the head (the flash surges). With the tilt, the higher fighter sits slightly higher.

**Divider drawing** is UI's to style (`ui/widgets/ui_split.gd`); the frame gives a line (`c`, `n`), a gap width (0.5% of the width, at least 3 px), a feather width for dissolves, and the line's opacity. The mask shader leaves a thin dark gap under UI's line. The divider stops at the top of the planet strip and the bottom of the toll chip (section 10).

## 4. Pane cameras

Each pane has a camera `(x, y, z)` in the reference camera's terms (pixels per unit at the fighter plane), so the rig, `CameraRig.frame()` and the seam proof are unchanged: a pane camera is what `SimCamera` would have produced for a one-fighter shot placed at `P_i`.

```
cam.z target   = r_pane * vh / 75 * tier_factor * alt_factor       r_pane = 0.065 (47 px at 720p), tier_factor = 1 - 0.06 (tier - 1)
alt_factor     = max(0.69, 1 / (1 + max(0, h - 3 bh) / (40 bh)))   h = fighter y minus the ground height under it; 0.69 keeps r_pane no lower than 0.045
focus point    = the fighter's chest, filtered: tau_x 0.10 s, tau_y 0.14 s, tau_z 0.35 s; k = 1 - exp(-DT / tau), once per sim tick on the fixed DT
lead           = measured velocity * DT (1 - k) / k   the lead that makes the discrete filter track a constant speed with no lag (about tau - DT / 2);
                 measured from the fighter's position change per tick, not the sim's vx, because a rush moves the fighter without setting vx
cam.x          = focus.x - (P_i.x - 0.5 vw) / cam.z
cam.y          = clamp(focus.y - (0.7 vh - P_i.y) / cam.z, -3200, CEILING - 200)
```

In ordinary movement the fighter stays at its anchor to within the feed-forward's error (the test measures the camera's own steps against a barely-moving fighter at 0.002 of the width a tick at most), and the ground band of the merged shot is preserved: the fighter plane sits at `0.7 vh` when the anchor's y is `0.7 vh`. The drawn zoom passes through one last slew limiter (2.4 e-folds a second; the slam is exempt), so whatever the blends do it never changes faster than the comfort limit.

**Continuity by construction.** At the moment of a split both panes are given the merged camera (`x` the midpoint, `z` = `z_u`) and the divider is vertical in the centre, so pane A is exactly the left half of the picture that was on screen. They then move toward their own cameras by blending, `out_i = blend(own_i, merged, 1 - smootherstep(sep))`, with `sep` running 0 to 1 over 0.45 s. The merged camera is a shadow that is stepped every tick and snapped to its target while two full panes are up, so it is ready when a merge starts. There is no pop at the cut. Merging is the same run backwards, ending with two identical cameras; at that instant only pane A is rendered and the divider is gone, which is pixel-identical.

## 5. Orientation, the antipode and the swap

The shortest arc from A to B flips at exactly half the planet (`sdx` jumps from +HALF to -HALF). Research measured that a camera that follows it pans half the planet in about 0.5 s with both fighters out of frame. The split has no such pan, because each pane follows its own fighter and only the *lead direction* flips. That flip is what needs hysteresis.

The rig keeps a held signed separation `u` that is continuous, not wrapped to +-HALF:

```
each tick:  u += wrapdelta(sdx(A.x, B.x) - previous sdx)          wrapdelta undoes a jump of +-W
            if u > HALF + m:   u -= W          (B is now nearer the other way round)
            if u < -(HALF + m): u += W
            sigma flips only when u crosses zero by more than m0
m  = 0.02 W = 3,072 units (41 bh)         the antipode hysteresis: the flip happens m past the antipode, and back only m past it the other way
m0 = 3 bh = 225 units                      the pass-through dead band, for fighters that pass at large height difference
```

Flips are also limited to one per 1.0 s and are never started while the layout is opening or closing (`0 < sep < 1`); a flip while merged, or while one pane is expanded past 90%, is instant and unseen. A pair that is close enough to merge again (`r` above the merge line) does not swing: the flip waits and is instant once they are one view. The case that showed this was two fighters 4 bh apart swinging for no reason just before their merge. The hysteresis band in arc length is 2 m (6,144 units, 82 bh): a fighter has to cross the antipode by 41 bh and come back 82 bh to flip twice. At the measured 10.8 k units/s median launch speed that is 0.28 s per crossing, and a flat-out dash (about 10 k units/s) takes the same 0.3 s, so the one-second dwell is what stops a second flip, not the margin.

**The swap** is a swing of the divider, 0.60 s (36 ticks), ease-in-out (`smootherstep`). The normal's angle moves from the old rest angle to the new one through the vertical on the higher fighter's side, so the higher fighter's pane passes over the top and the panes are briefly stacked:

```
theta(sigma, phi) = phi >= 0 ? (sigma > 0 ? -phi : -PI + phi) : (sigma > 0 ? -phi : PI + phi)      angle of n; up is -PI/2
swing: theta(t) = lerp(theta(sigma_old, phi), theta(sigma_new, phi), ease(t)),  phi held for the 0.6 s
sweep = PI - 2 |phi|       (180 degrees when level)
```

Both fighters' anchors follow `n` for the whole swing (the formula in section 3), so each fighter glides across the screen inside its pane while the divider turns; the pane camera's look-ahead flips smoothly with no pan. Every pixel belongs to a pane at every instant, so there are no gaps. Both panes are full-screen render targets while a swing runs (section 11). An alternative, "cards passing over each other", needs wider targets and leaves the sides uncovered at the midpoint unless the cards are stretched; **Orb decides** whether that is worth it. The same swing runs for both causes of a flip (antipode and pass-through).

## 6. Opening

When the trigger fires, `sep` runs 0 to 1 over 0.45 s (27 ticks) with a smootherstep; the divider fades in over the first 45% and its feather closes from 64 px to 0. The zoom ramps from `z_u` to `r_pane` (1.2 e-folds a second ordinarily, 2.4 in a transition), so a 0.43 to 0.62 change (0.37 e-folds) fits the opening time.

## 7. Merging: a dissolve, or a slam

**Dissolve (fly back together).** Trigger: `r` above 0.040 for 0.40 s, after 1.2 s of split. `sep` runs 1 to 0 over 0.55 s (33 ticks) with `easeInOutCubic`. The divider's feather grows from 0 to 64 px and its line fades over the last 0.25 s, so at the hand-off the seam is a soft 64 px blend between two nearly identical pictures; the hand-off itself (render pane A only) is pixel-identical because the two cameras are equal.

**Slam (one charges in).** Trigger: a fighter's `rush` is set toward the other while split, and its remaining time `rush.end - S.T` is at most 0.8 s (they all are; the longest measured is 0.78 s). The slam is timed to finish on contact, not to start with the rush:
- Until 0.14 s before `rush.end` the panes hold (`SLAM_LEAN` is 0). A first version leaned the panes toward the merged shot during the rush; in the real-match run that pulled the defender's pane off its fighter, because a far rush has a merged shot of dots.
- Over the last 0.14 s (8 ticks) the divider sweeps sideways toward the defender's side, accelerating (`easeInCubic`), the attacker's pane expanding and covering the defender's, while both pane cameras are pulled to the merged camera with their filters stiffened to a 0.03 s time constant. It reads as a door closing.
- On the closing frame the frame's `slam` flag is set and the divider flashes for 0.08 s (the record's `slam` key, drawn by UI); the shake for the hit is the fx consumer's, within the cap of section 12 and to align with Controls. Hit-stop is sim-owned; the hit lands in the merged shot. Reduced motion shortens the door to 0.04 s (a near-cut).
- After the slam the merged camera holds for at least 0.8 s (the minimum merged time) before it may split again, unless the exchange is over and the fighters flew apart at once.
- Slam is the only place a per-tick screen motion above the ordinary limit is allowed (section 12).

A rush that is cleared early (a feint or a dodge that cancels it: `rush` gone with more than two ticks to run) cancels the slam: the layout returns to two panes. The slam is an event of the fight and skips the merged/split dwell; the test holds only trigger-driven changes to 0.8 s.

## 8. Launch follow

Trigger: a fighter's state becomes `launched` with speed at least 4,000 units per second (about three quarters of the launches; a shove or a short tumble stays in the current layout). The launched fighter's camera:

| Phase | Duration | Camera |
| :--- | :--- | :--- |
| Engage | 0.32 s | If split: the launched fighter's pane expands over the whole screen (`e` 0 to 1, `easeOutCubic`); if merged: the merged camera's target becomes the launch camera. Player control is untouched |
| Follow | until the state leaves `launched`, at most 6 s | Rigid: the focus filter's time constant is 0.02 s with the measured-velocity lead of section 4, `cam.y` filtered at 0.10 s, zoom `r_launch` = 0.06 (43 px at 720p), fighter anchored 35% from the trailing edge in the direction of travel so the path ahead shows. At the measured speeds the world streams past; the fighter stays fixed on screen |
| Land | 0.35 s | Hold the landing site. The push-in on impact is 8% of zoom over 0.15 s and back; hit-stop is sim-owned. A knockback slide keeps following while `slide > 0` |
| Settle | 0.60 s | Decide by the trigger at the landing: if `r` is above the merge line, merge (the follow camera eases to the merged camera, no divider ever appears); otherwise split with the launched fighter's pane already expanded, reopening by moving the divider back in over 0.35 s (`e` 1 to 0) so the far fighter's pane wipes in from its side |

Cancel or skip: a KO or a `finisher_start` ends the follow at once (the finisher's own shot takes over); a tier-up or transformation cinematic for either fighter takes precedence (section 9); reduced motion replaces the Follow with a held shot of the launch position and a cut to the landing.

A follow longer than 6 s (the longest measured is 11.5 s) leaves rigid follow and becomes an ordinary split, with the launched fighter's pane at its own target, so a long haul across half the planet never becomes a 10 s single shot.

## 9. Cinematics, respected transformations and the fold

Cinematics are shots the camera takes for a reason; none takes control from a player (the camera only ever moves the view). Precedence, highest first: fold, KO or finisher, respected transformation, tier-up push, launch follow, beam shot, ordinary.

| Moment | Trigger (sim) | In a merged view | In a split view | Duration | Shake (to align with Controls) | Cancel |
| :--- | :--- | :--- | :--- | :--- | :--- | :--- |
| Respected transformation | `cinematic_start {actor, kind: transformation or revision, dur}` (asked for below) | Push to `r` = 0.14 on the transformer, the opponent stays in frame if within 25 bh | The transformer's pane expands to 86%; the opponent keeps a 14% sliver on the far edge (**Orb decides**: sliver or 100%) | the sim's `dur`, in whole ticks | 6 at the moment of change | Uninterruptible; ends at `cinematic_end` |
| Tier-up push | `tier_up {actor, tier, onGround}` | 12% zoom in over 0.25 s, hold 0.5 s, back over 0.6 s | The same on that fighter's pane only | 1.35 s (81 ticks) | 14 at the change (`onGround`: 18) | New event of higher precedence |
| Beam shot | `beam` start (from `S.beams`) | Merged is kept only while `r` is at least 0.030 | Stay split; the divider tilts to the beam's height difference and a glow marks the point where the beam crosses it | the beam's life | 14 at fire, then 4 held | Beam end |
| Beam struggle | `game.clash` set | Wide shot, merged down to `r` = 0.030, centred on the struggle point | The struggle converts a split to a merged wide shot when `r` would be at least 0.030, otherwise stays split with both panes showing the struggle glow | `clash.dur` | 18 at the clash, 7 held | Struggle end |
| KO and finisher | `finisher_start`, `ko` | Slow dolly to `r` = 0.16 on the loser over 1.5 s while the sim's own slow motion runs (`game.ts`); UI adds letterbox | A finisher is always in contact, so a split never exists here; if one does, slam-merge first | KO: the sim's 2.2 s of slow motion, 3 s hold | 16 on the blow | None |
| Fold | `fold_start {x, y, radius, dur}` (asked for below) | Merged wide shot on the fold's centre, `z` from the radius; the ring map and strip hide | Divider dissolves (0.55 s) into the fold shot; split is disabled until `unfold` | the sim's `dur` | none | Uninterruptible |

The camera reads these; it never changes sim time. Slow motion and hit-stop are sim durations in whole ticks (Netcode's contract, pending). Camera-only slow motion is a render effect that changes neither the number of sim steps nor when input is sampled. **Respected** here means the camera does what the rule says and nothing hurries it: the transformation's shot cannot be preempted by a lower-precedence event, and nothing about a pane change can interrupt the transformer's shot.

## 10. HUD and UI anchors per pane

The HUD is a single `Control` over the composite. `SplitFrame.hud_anchor(slot, x, y)` gives, per fighter slot, the record `anchor_fn` returns, plus the pane: `{pos, h, visible, pane}`, where `pos` is the chest in that fighter's own pane and `h` is `75 z` (main calls it while a compositor is attached). Everything else follows from `docs/ui/hud-spec.md` section 10.

| Piece | In a split |
| :--- | :--- |
| Nameplates | Each fighter's plate at the outer top corner of its own pane (left pane: top left). They follow `sigma`, so they swap once at the flip, not at each opening (UI's ruling, agreed) |
| Fighter-clear zone | Per pane: the pane polygon inset by the safe area on the outer edge and by 2% of the width on the divider side, and the vertical band 17.9% to 80.1% of the height. The anchors of section 3 sit inside it at every tilt and zoom |
| Planet strip and toll chip | The divider stops under the toll chip and above the strip (both edge-anchored). The strip is shared. Bark lanes stay at the outer bottom corners |
| Headroom | At least one body height (`75 z`) between the top of the head and the top of the pane, plus the plate's height where the plate is above it |
| Edge pointer | In each pane, on the divider side, a chip using the strip's circle and diamond shapes, pointing to the opponent (`n`) and showing the distance in fighter heights (UI decides whether to show a number; no "power level" text). It sits in the 24 px reserve band UI keeps around the clear zone. Always on in a split, on in solo without split |
| Ring map | A small ring of the planet with both fighters, each pane's viewed arc, and the held shortest arc highlighted. The frame's `split_record()` gives UI what `UiSplit` reads: `sep`, `c`, `n`, `gap`, `fade`, `slam`, `sigma`, `dist_bh`, `pointer` ("split" when two panes are up, "always" otherwise) and `ring {angle_A, angle_B, sigma, arc_A, arc_B, swing, sep, W}`, angles as `x / W * TAU`, arcs as the full width in radians of planet angle that each pane shows (`arc_A` = `arc_B` in one view, and UI draws a single arc at the midpoint). UI owns the widget and the size |
| Reduced motion | The swing takes 0.15 s, the slam is a 0.04 s near-cut, the launch follow a held shot and a cut, the tier-up push off, and shake a quarter of the player's scale (section 13) |

## 11. Rendering: how two panes are drawn

A pane is one full render of the world from its camera; the scene is built around one camera at a floating origin, and the bend, sky and fog uniforms are per camera, so two cameras cannot share nodes and materials. Rendering built that (commit e8173b7, `docs/rendering/README.md`, "Panes and the split screen"): a `PaneWorld` per camera in its own `SubViewport` and `World3D`, sharing the ground data, meshes and props, with `RenderMats` an instance per pane; main owns and steps the `SplitRig` while a compositor is attached, draws pane 0 always and pane 1 while `frame.shows(1)`, and calls the compositor's `pane_jitter(i)` and `present(frame)`. `SplitView` is that compositor.

- **`SplitView.attach(main)`** moves pane 0 into a SubViewport (`main.move_pane0`), makes pane 1 (`main.make_pane`), sets `main.compositor`, and sizes both to the screen. `detach()` goes back to one view.
- **`present(frame)`** switches pane 1's viewport off while nobody sees it, and pane 0's GPU frame off while pane 1 has the whole screen (its CPU update still runs: it applies the world's changes). With one pane showing, that pane's texture is drawn as it is (a `TextureRect`, no mask pass). With two, one `ColorRect` runs `split_mask.gdshader`: `mix(tex0, tex1, w1)` with `w1` from the signed distance to the divider, a soft blend across the feather for a dissolve, and a thin dark gap under UI's line.
- **Shake.** Each pane has its own amount and its own cosmetic stream. The rig reads the tick's `shake` events {k, x} (Controls' shake pass, `docs/controls/shake-pass.md`): an event reaches a pane scaled by `clamp(1 - d / 4000, 0.35, 1)`, d being the wrapped distance from the pane's view centre, and with two panes up the one farther from the event gets 35% of that. The amount decays at the fx consumer's 0.02 per second and holds through hit-stop freezes (the tick event's `frozen`). `SplitView` draws each pane's jitter from `PaneShake` streams `camera` (pane 0) and `camera_b` (pane 1), derived from the match seed and advanced once a tick from the host's `ticked` signal, so replays show the same shake. Both are capped at 3% of the screen height and scaled by the player's shake scale (quartered in reduced motion). Neither touches the sim's stream.
- **Pixels.** Panes are full-screen render targets in this build (so a two-pane frame fills the screen twice). The alternative, targets sized to their region (about 0.63 of the width each at the 30 degree limit, 1.26x), needs a resize whenever a pane takes the whole screen, which happens all the time (launch follow is a third of the frames in an AI match); it is not built. The knobs if a low-end GPU needs them: `scaling_3d_scale` on the pane viewports, and the far-ground stride while split.
- **Entry.** The split is on by default in the one main scene (commit 88e01a7): `main.gd` creates the `SplitView` and attaches it, F9 toggles it, `--nosplit` starts with one view, F10 flips solo against the AI and F11 reduced motion, and UI's options feed the same settings. `split_main` was retired. The tools get one view unless they attach a compositor themselves.

`sim/core/view/camera.gd` stays in `SimHost` untouched, as the reference for the goldens; with a compositor attached the reference camera is simply not used.

## 12. Comfort and the no-pop rules

These are the limits the tests enforce (`camera_params.gd`). "Ordinary" means anything that is not an authored cut (the slam, a cinematic hard cut, `cut()`).

| Quantity | Limit |
| :--- | :--- |
| Zoom rate | 1.2 e-folds a second in two panes at rest; 2.4 in a transition and in one view; the slam is exempt. A last slew limiter enforces 2.4 on the drawn zoom |
| A fighter's screen motion per tick relative to its pane anchor | 0.02 of the screen width ordinary; 0.05 in a transition |
| Divider angle rate | 120 degrees a second (the test allows 1.5x for the interpolation); the swing is exempt (its own curve, about 560 degrees a second at its peak; 0.6 s, or 0.15 s in reduced motion) |
| Divider position | continuous; at most 0.06 of the screen width a tick outside the slam |
| Shake amplitude | capped at 3.0% of the screen height (21 px at 720p; the prototype's largest was 30 px), scaled by the user setting; decay `0.02^dt` as before |
| Mode changes | trigger-driven split or merge at most once per 0.8 s (a shot's ending, a slam and a fighter lost off the edge are events and skip the dwell), and one orientation flip per 1.0 s, whatever the input |

## 13. Carried over from the wave-1 brief

The wave-1 files (`framing-rules.md`, `comfort-limits.md`, `cinematic-moments.md`, `hiding-camera-options.md`) were not written; this document supersedes them. What still fits:
- **User shake scale**: 0 to 100%, default 100%, stored as `camera.shake_scale`; 0 turns shake off. **Reduced motion** (UI's `reduced_motion` option, `SplitView.set_reduced_motion`): shake at 25% of the player's scale, the swing 0.15 s, the slam a 0.04 s near-cut, the launch follow a held shot and a cut, the tier-up push off, opens and merges 1.5x faster.
- **Timing policy**: hit-stop and KO slow motion are sim-owned durations in whole 60 Hz ticks. The camera reads them; presentation transitions run on the fixed `DT` (not the sim's scaled `S.dt`), so a swing or a dissolve is not stretched by the KO slow motion. The rig never changes sim time and never delays input sampling.
- **Shake is cosmetic**: never the sim RNG stream; the `camera` and `camera_b` derived streams above.
- **Shake table**: the ten shake writes in the prototype are `Fx.shake` events with only a `k`. In the port the camera reads the sim event that caused each one (building collapse `k` 10, explosion 16, hit 6, launch 10, guard break 12, clash wave 18, beam fire 14, tier-up 14, impact `min(30, speed * 0.01)`, clash held 7) and applies its own table. The values are to align with Controls, who set the per-impact numbers within this document's cap.
- **Event fields wanted**: `shake` events with the world `x` (so a split shakes the nearer pane fully and the other at 35%), `launch {actor, speed, dir}`, `rush {actor, target, end_tick}` (the field on the fighter works; an event is cleaner for a replay), `cinematic_start`/`cinematic_end {actor, kind, dur_ticks}`, `fold_start {x, y, radius, dur_ticks}` and `unfold`, `relocate {x}` (a hard cut).

## 14. Hiding: the hook, not the feature

Orb has removed hiding from the base game (parked for a future fighter), so there is no hiding pane mode. The rig keeps one unused seam for it and nothing else:

```
pane_request(slot) -> {kind: "normal" | "search", search_x, search_y, search_radius}
```

By default every pane is `normal`. If the game asks for `search`, that pane's camera does not follow its fighter's opponent's true position: it centres on `search_x` with a slow drift inside `search_radius` (from the hunter's `lastSeen` and the hunt state) and the edge pointer, ring map and tilt all use the last known position, not the truth. The hider's pane stays normal. Two leaks to design out if it is built: the divider tilt and the ring map must use the last known position (the tilt is computed from `pane_request`, not from `S`), and on a shared screen the hider's normal pane is visible to the hunter; a shroud on the hider's pane (a darkened cover view) is the likely answer and belongs to the same decision.

## 15. Determinism and the test

The rig reads `S` after each tick and never writes it; it draws no sim random numbers; the layout is a pure function of the ticks so far. Rendering-side jitter uses derived cosmetic streams. `render/camera/tests/split_sweep.gd` poses fighters by hand like `seam_sweep.gd`, steps the rig 60 times a second and reads the frame at 144 Hz (the rate that shows a pop):

```
godot --headless --path . --script res://render/camera/tests/split_sweep.gd [-- --seeds=3,10,17 --ticks=6000 --size=1280x720]
godot --path . --script res://render/camera/tests/split_sweep.gd -- --render [--shots=DIR]      (a window: also draws the composite)
```

- **Posed scenarios (24, each run twice; the two digests must match):** separation from 0 to 0.998 of the antipode and back across the seam, level and at +-2,000 units of height difference; the antipode passed going right, going left, and there and back (one swing each way), a jitter of 0.5 m around it (no flip) and of 3 m (at most one flip a second); the pass-through at 4,000 units of height difference and inside its dead band; jitter of +-10% around the split line; a slam and a feint; launches at the measured p10, p50, p90 and maximum speeds, far and straight up and down; a respected transformation; a tier-up push; the fold; solo against the AI; a hard cut; and the reduced-motion swing. A separate check that the one-view frame equals `SimCamera`'s at rest.
- **Real matches:** AI against AI, seeds 3, 10, 17, 24, 31, 38, 45, 52 and 4, up to 6,000 ticks each, on live sim data.
- **Checks on every frame:** every sample point of a 32 by 18 grid belongs to a rendered pane; a fighter whose pane has a real share of the screen is on screen inside it (never out for 0.3 s); at rest the anchors sit inside their pane and UI's clear zone with a body height of headroom; the zoom, anchor, divider and tilt limits of section 12; and, for a fighter that barely moved, the camera's own step against its anchor. Layout changes keep their spacing, and a fighter under 60% of the split line is not shown in a one-view frame for more than 2% of the merged ticks.
- **Determinism:** the sim's gameplay hash after a match is identical with the rig running and not.
- **`--render`:** the real `SplitView` composites two stand-in panes (`SplitTestPane`, flat worlds drawn with the reference camera's mapping) for nine transition scenarios; the picture is read back at 144 Hz and a frame-to-frame change more than 4 times its neighbours' would be a pop or a flicker. Worst measured: 1.9.

Two bugs the test found in my own first versions are worth recording: a lead of `tau` instead of `DT (1 - k) / k` left a camera one tick ahead of a rushing fighter (a 700 px error at rush speed), and a camera floor of -180 lost fighters in the sea.

## 16. What was built

| File | Role |
| :--- | :--- |
| `render/camera/camera_params.gd` | Every number of this document (class `CamParams`) |
| `render/camera/split_rig.gd` | `SplitRig`: the trigger, orientation, swing, opening and merging, slam, launch follow, cinematics, pane cameras. Pure, tick-stepped |
| `render/camera/split_frame.gd` | `SplitFrame`: one presentation frame, its interpolation, `hud_anchor`, `split_record` |
| `render/camera/split_view.gd`, `split_mask.gdshader` | The compositor and its mask |
| `render/camera/pane_shake.gd` | Pane 1's cosmetic shake stream and the shake cap |
| `render/camera/tests/split_sweep.gd`, `split_test_pane.gd`, `split_test_main.gd` | The scripted test and its stand-in panes |
| `docs/camera/img/` | The captures below |

`camera_rig.gd` in the same folder is Rendering's move. The entry point is Rendering's `main.gd` (split on by default; the benchmark there reports frame times split by pane count). Settings live on the rig and the view: `SplitRig.solo_split` and `reduced_motion` (through `SplitView.set_solo_split` and `set_reduced_motion`) and `SplitView.shake_scale`.

## 17. Before and after, and what it costs

Captures from the real game (Compatibility renderer, 1280 by 720, seed 4, `--fixed-fps 60`; taken with the first entry scene, which is now the default main scene: `--nosplit` gives the left column). Left: one view from the reference camera. Right: the split.

| Tick | Before | After |
| :--- | :---: | :---: |
| 250 (4.2 s): fighters 137 bh apart | ![before 250](img/before_t250.png) | ![after 250](img/after_t250.png) |
| 352 (5.9 s): a rush is about to close | ![before 352](img/before_t352.png) | ![after 352](img/after_t352.png) |
| 630 (10.5 s): a launch | ![before 630](img/before_t630.png) | ![after 630](img/after_t630.png) |
| 2994 (49.9 s): a swing | ![before 2994](img/before_t2994.png) | ![after 2994](img/after_t2994.png) |

Frame time, wall clock per frame with vsync off (seed 4 unless noted; Ryzen 7 9800X3D, RTX 5070 Ti; a high-end machine, so treat these as a floor):

| Build | One view | Split on, all frames | Two full panes only |
| :--- | :--- | :--- | :--- |
| Desktop 1280 by 720, mean / p50 / p95 / p99 (ms), rerun with the clear-zone term on a clean copy of HEAD | 1.41 / 1.25 / 1.95 / 2.48 | 1.70 / 1.52 / 2.42 / 3.01 | 1.98 / 1.83 / 2.79 / 3.58 (14% of frames) |
| Desktop 1920 by 1080 | 1.40 / 1.22 / 1.96 / 2.51 | 1.74 / 1.55 / 2.45 / 3.06 | 2.09 / 1.93 / 3.09 / 3.68 |
| Desktop 1280 by 720, seeds 12345 and 7 | | 1.83 and 1.74 | 2.00 and 1.91 (12% and 15%) |
| Web 1280 by 720 (Chrome 154, ANGLE D3D11, single thread) | 2.82 / 2.14 / 3.53 / 4.61 | 3.39 / 2.63 / 4.80 / 6.72 | 3.96 / 3.90 / 5.20 / 6.30 (10% of frames) |

Two full panes are up in 6%, 13% and 19% of the frames of seeds 4, 12345 and 7 at the 3.0% line with the wide hold (they were 11%, 21% and 23% at 4.5% with no hold, measured the same day on the same tree), so a match spends about 45% fewer frames with two panes. The frame-time rows above were measured at 4.5% and weigh less in a match now. Draw calls: 154 with one view, 191 on average with the split, 232 at the 95th percentile. The gameplay hash after 4,800 ticks (desktop) and 2,400 (web) is the same with and without the split (`2251e5c11e4c12c3`, `51bca31f196043ee`). Not measured: minimum-spec hardware (an old laptop, an integrated GPU, a phone). The split adds about 0.3 ms even with one pane showing (the world now draws to a SubViewport and is copied to the screen, and the rig steps each tick at about 0.05 ms), and about 0.65 ms while two panes are up; a slower CPU multiplies those, and an integrated GPU pays the doubled fill. The web frame time holds on this machine (3.4 ms mean, 6.7 ms p99 against a 16.7 ms budget). The web run's max of 634 ms is the first-use shader compile Rendering already documents.

### The split line, after two playtests

First playtest (mine, on the live build at 4.5%): the size was fine but the reference framing put fighters outside UI's clear zone, under its edge chip. Second (Orb and a friend): the split came too soon, was "hard to follow when a fighter picks up speed", and the friend liked the earlier wide zoom-out. So the line is now 3.0% (merge 4.0%), the clear-zone term is off, and the split waits a second longer while the fighters are still moving apart. The two frames below, at 4.5% with the zone term, show what the chip overlap looked like and the 20 bh split it caused; they are kept as evidence.

| One view, 20 bh apart | Split, 25 bh apart |
| :---: | :---: |
| ![tick 95](img/line_t95.png) | ![tick 120](img/line_t120.png) |

Still for Orb, on a pad: whether 50 bh feels right for the split, whether the wide beat reads as "flying around the world", and whether the chips need to dodge the fighters (UI).

## 18. Open

- Pane targets sized to their region (1.26x fill instead of 2x): built only if a low-end machine needs it, since panes take the whole screen too often for a resize to be cheap.
- Hidden information: the hook is `SplitRig.pane_request_fn` and nothing else; hiding is out of the base game.
- Portrait: landscape only.
- The fold and the cinematic events are read from `fold_start`, `unfold`, `cinematic_start`, `cinematic_end` and `relocate`; Encounter and World add them (S2, W1). Until then the launch follow polls the fighters' state, and a transformation is not yet a shot.


## 19. Long matches: three defects found at full length (2026-10-04)

Matches now run 7 to 10 minutes; the old sweep ran 60 s each. Runs of 30,000 ticks (8 minutes) on four seeds, flat, with a human slot and raised to 49 degrees, found three things that only show late. The standard sweep now plays three full-length matches (36,000 ticks or to the KO): one flat, one at 49 degrees, one with a human slot. The whole sweep runs in about 2.6 minutes.

1. **A transformation that takes over from another fighter's shot (a real bug, fixed).** At 244 s of one match a launch chase on fighter A was running when fighter B transformed. My new transformation shot began with an ease instead of a cut, so the pane's owner changed in a single tick: the anchor moved 0.06 of the width and the divider 0.15 of the width with no cut flagged. The transformation now takes over with a cut when another fighter's shot is running (`_begin_solo(..., cut_in = solo_kind != "" and solo_slot != ta)`).
2. **The live transformation's punch-in (a test gap).** The 8% punch-in in 6 ticks (1.6 e-folds a second) is authored, but the zoom-rate check only allowed the tier push. The check now allows the punch and the 0.2 s after it.
3. **A pair that passes each other while the split is opening (two parts).**
   - *The flip is instant and invisible but was interpolated.* When the layout flips sides at a separation of 0.02 or less, the frame was blended with the one before it, so the divider swept 73 degrees in a tick while it was nearly invisible. The flip now marks the frame as a cut (no blending). That removed the divider turn (10,500 degrees a second) and the anchor jump at 345 s.
   - *The opening before the flip is by design.* If the pair crosses while the layout is merging and the split opens again before it was one view (a fighter was about to leave the merged frame), the flip cannot happen: it waits for the dwell, for them to stop being merge-close, and for the panes to be one view or full apart. The split opens with the fighters on their old sides for about 0.3 s and swings when it can. I tried flipping at once when the split opens below a separation of 0.15; it works but makes the divider turn and the anchors jump where they can be seen (up to 10,600 degrees a second and 0.097 of the width), so I took it out. The off-pane check now excludes an "opening" with a flip pending (`SplitRig.orientation_pending()`), and the exclusion is the only place the pass is allowed to show.

Also added: the trace line (`--trace=seed:t0:t1`) now prints the orientation, the flip age, the metric and the cut flag, and the failure messages carry the time and the mode on both sides of the jump.
