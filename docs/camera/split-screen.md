# Orb Combat EX: the dynamic split screen

Owner: Camera and Cinematography. Code: `render/camera/`. Status: design, 2026-09-29. It replaces the wave-1 camera brief; what still fits from that brief is folded in (section 13). Orb's answers are in `docs/ep/vision.md`, "Dynamic split screen".

**Summary**
1. One camera while the fighters are big enough to read; two panes when zooming out further would make either one too small. The test is the fighter's on-screen height as a fraction of the screen height: split under 4.5%, merge above 6.0% (32 and 43 px at 720p).
2. The divider is a straight line through the screen centre. Its normal points from one pane's fighter toward the other's, tilted up to 30° by their height difference. Each fighter sits on its own outer side, so each pane looks toward the opponent.
3. The panes follow the shortest way round the planet. When it flips (near the antipode, or when they pass each other), a hysteresis band and a 1 s dwell keep it from flickering, and the divider swings 0.6 s through the horizontal so the panes trade sides.
4. Merges: a 0.55 s convergence that ends in a dissolve when they fly back together; a 0.14 s slam, timed to land on contact, when one rushes in. Launches are followed by one full-screen camera locked to the launched fighter, then a merge or a split at the landing.
5. A pure, tick-stepped rig (`SplitRig`) decides everything from `S` and never writes it. Compositing needs two world renders, so Rendering must make its view stack instantiable twice (section 11); that is the one cross-owner change.

**Open questions for Orb** (defaults are mine; each is marked "Orb decides" where it appears)
1. Is 4.5% of the screen height (a 32 px fighter at 720p, about 41% of an AI match) the right "too small to read"? A higher number splits more often.
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
z_u  = min(vw / (|d| + 700), 0.8 vh / (|dy| + 500), 1.15) * (1 - 0.06 (max_tier - 1))    the reference formula, unclamped below
r    = 75 * z_u / vh                                                                        fighter height as a fraction of the screen height
```

`d` is the held signed separation of section 5. The rest is the reference camera's own constants, so the merged shot is the shot you had before.

| Rule | Default | Why |
| :--- | :--- | :--- |
| Split when `r` stays below | 0.045 for 0.25 s | 32 px at 720p, 49 at 1080p. A head is 27% of the body, so 9 px at 720p: the least at which the Marked masks' sigils and the head flashes still read |
| Merge when `r` stays above | 0.060 for 0.40 s | 43 px at 720p. The 1.33 ratio is the hysteresis; in separation (16:9, tier 1, level) it is split at 30.2 bh, merge at 20.3 bh |
| Minimum time in a split before a dissolve-merge | 1.2 s | The measured median run under the line is 2.4 s; anything shorter is not worth two transitions |
| Minimum time merged before splitting again | 0.8 s | |
| Closing guard | do not open if `r` predicted 0.4 s ahead (from the closing speed) is at or above the split line | A rush from 30 bh is over before the panes finish opening |
| Beam struggle | merged is allowed down to `r` = 0.030 | The struggle is the picture; section 9 |

Because `r` uses the reference formula, it responds to what the reference camera responds to: separation, height difference and tier. At tier 4 the split line is at 23 bh, not 30 (the aura is bigger). A 21:9 screen splits later (42 bh) and a 4:3 screen sooner. Every number is in `camera_params.gd` as a constant, so tuning does not touch code. **Orb decides** the two thresholds; the table of what they mean in pixels:

| Screen height | 720 | 1080 | 1440 | 2160 |
| :--- | ---: | ---: | ---: | ---: |
| Split under | 32 px | 49 px | 65 px | 97 px |
| Merge over | 43 px | 65 px | 86 px | 130 px |

Below 600 px of screen height the floor `r >= 28 px / vh` applies, so a small window splits earlier instead of showing 20 px fighters.

**Solo against the AI** is a player setting, `camera.solo_split` (default on, **Orb decides**). Off means the camera keeps the player's fighter at `r_pane` (section 4) at all times, never splits, and the opponent is shown by an edge pointer (section 10) and the ring map. In two-player, split is always available.

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
`P_i = c + (0, 0.12 vh) - s_i (n.x * 0.28 vw, n.y * 0.24 vh)`, with `s_A = -1`, `s_B = +1`. At rest and level that is 22% of the screen width from its outer edge and 62% of the way down, leaving 28% of the width of world in front of it toward the opponent (the look-ahead that makes a pane "point toward" the other fighter) and more than one body height of headroom above the head (the flash surges). With the tilt, the higher fighter sits slightly higher.

**Divider drawing** is UI's to style; the rig gives a line (`c`, `n`), a gap width (0.5% of the width, at least 3 px), a feather width for dissolves, and the two ends. The divider stops at the top of the planet strip and the bottom of the toll chip (section 10).

## 4. Pane cameras

Each pane has a camera `(x, y, z)` in the reference camera's terms (pixels per unit at the fighter plane), so the rig, `CameraRig.frame()` and the seam proof are unchanged: a pane camera is what `SimCamera` would have produced for a one-fighter shot placed at `P_i`.

```
cam.z target   = r_pane * vh / 75 * tier_factor * alt_factor       r_pane = 0.065 (47 px at 720p), tier_factor = 1 - 0.06 (tier - 1)
alt_factor     = max(0.69, 1 / (1 + max(0, h - 3 bh) / (40 bh)))   h = fighter y minus the ground height under it; 0.69 keeps r_pane no lower than 0.045
cam.x target   = f.x + f.vx * tau_x - (P_i.x - 0.5 vw) / cam.z     (velocity feed-forward cancels the lag of a first-order filter)
cam.y target   = clamp(f.y + f.vy * tau_y + 38 - (0.7 vh - P_i.y) / cam.z, -180, CEILING - 200)
filters        tau_x 0.10 s, tau_y 0.14 s, tau_z 0.35 s; k = 1 - exp(-dt / tau), stepped once per sim tick with the fixed DT
```

A pane keeps its fighter inside +-6% of the screen width of its anchor in ordinary movement (the lag is the feed-forward's error only), and the ground band of the merged shot is preserved: the fighter plane sits at `0.7 vh` when the anchor's y is `0.7 vh`.

**Continuity by construction.** At the moment of a split both panes are given the merged camera (`x` the midpoint, `z` = `z_u`) and the divider is vertical in the centre, so pane A is exactly the left half of the picture that was on screen. They then move toward their own targets by blending the targets, `target_i = lerp(merged, own_i, ease(sep))`, with `sep` running 0 to 1 over 0.45 s. There is no pop at the cut. Merging is the same run backwards, ending with two identical cameras; at that instant only pane A is rendered and the divider is gone, which is pixel-identical.

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

Flips are also limited to one per 1.0 s and are never started while the layout is opening or closing (`0 < sep < 1`); a flip while merged, or while one pane is expanded past 90%, is instant and unseen. The hysteresis band in arc length is 2 m (6,144 units, 82 bh): a fighter has to cross the antipode by 41 bh and come back 82 bh to flip twice. At the measured 10.8 k units/s median launch speed that is 0.28 s per crossing, and a flat-out dash (about 10 k units/s) takes the same 0.3 s, so the one-second dwell is what stops a second flip, not the margin.

**The swap** is a swing of the divider, 0.60 s (36 ticks), ease-in-out (`smootherstep`). The normal's angle moves from the old rest angle to the new one through the vertical on the higher fighter's side, so the higher fighter's pane passes over the top and the panes are briefly stacked:

```
theta(sigma, phi) = phi >= 0 ? (sigma > 0 ? -phi : -PI + phi) : (sigma > 0 ? -phi : PI + phi)      angle of n; up is -PI/2
swing: theta(t) = lerp(theta(sigma_old, phi), theta(sigma_new, phi), ease(t)),  phi held for the 0.6 s
sweep = PI - 2 |phi|       (180 degrees when level)
```

Both fighters' anchors follow `n` for the whole swing (the formula in section 3), so each fighter glides across the screen inside its pane while the divider turns; the pane camera's look-ahead flips smoothly with no pan. Every pixel belongs to a pane at every instant, so there are no gaps. Both panes are full-screen render targets while a swing runs (section 11). An alternative, "cards passing over each other", needs wider targets and leaves the sides uncovered at the midpoint unless the cards are stretched; **Orb decides** whether that is worth it. The same swing runs for both causes of a flip (antipode and pass-through).

## 6. Opening

When the trigger fires, `sep` runs 0 to 1 over 0.45 s (27 ticks) with `easeOutCubic`; the divider fades in over the first 0.2 s and its feather closes from 48 px to 0. The zoom ramps from `z_u` to `r_pane` at no more than 1.2 e-folds a second (the slowest of the tick filter and this cap wins), so a 0.43 to 0.62 change (0.37 e-folds) takes the opening time. The panes do not shake while opening.

## 7. Merging: a dissolve, or a slam

**Dissolve (fly back together).** Trigger: `r` above 0.060 for 0.40 s, after 1.2 s of split. `sep` runs 1 to 0 over 0.55 s (33 ticks) with `easeInOutCubic`. The divider's feather grows from 0 to 64 px and its line fades over the last 0.25 s, so at the hand-off the seam is a soft 64 px blend between two nearly identical pictures; the hand-off itself (render pane A only) is pixel-identical because the two cameras are equal.

**Slam (one charges in).** Trigger: a fighter's `rush` is set toward the other while split, and its remaining time `rush.end - S.T` is at most 0.8 s (they all are; the longest measured is 0.78 s). The slam is timed to finish on contact, not to start with the rush:
- Until 0.14 s before `rush.end`, the layout stays split, but the pane targets lean in: `sep` is held at `1 - 0.5 * progress` so the fighters' panes drift toward the merged shot.
- Over the last 0.14 s (8 ticks) the divider sweeps sideways toward the defender's side, accelerating (`easeInCubic`), the attacker's pane expanding and covering the defender's, while both pane cameras are pulled to the merged camera with their filters stiffened to a 0.03 s time constant. It reads as a door closing.
- On the closing frame the divider flashes for 0.08 s (UI/VFX style hook `divider_slam`) and the camera takes a shake of `k` = 12 (within the cap of section 13, to align with Controls). Hit-stop is sim-owned; the hit lands in the merged shot.
- After the slam the merged camera holds for at least 0.8 s (the minimum merged time) before it may split again, unless the exchange is over and the fighters flew apart at once.
- Slam is the only place a per-tick screen motion above the ordinary limit is allowed (section 12).

A rush that ends before the slam window (a feint or a dodge that cancels it, `rush` cleared early) cancels the slam: the layout returns to `sep` = 1 over 0.25 s.

## 8. Launch follow

Trigger: a fighter's state becomes `launched` with speed at least 4,000 units per second (about three quarters of the launches; a shove or a short tumble stays in the current layout). The launched fighter's camera:

| Phase | Duration | Camera |
| :--- | :--- | :--- |
| Engage | 0.20 s | If split: the launched fighter's pane expands over the whole screen (`e` 0 to 1, `easeOutCubic`); if merged: the merged camera's target becomes the launch camera. Player control is untouched |
| Follow | until the state leaves `launched`, at most 6 s | Rigid: `cam.x = f.x + f.vx * 0.05`, `cam.y` filtered at 0.10 s, zoom `r_launch` = 0.06 (43 px at 720p), fighter anchored 35% from the trailing edge in the direction of travel so the path ahead shows. At the measured speeds the world streams past; the fighter stays fixed on screen |
| Land | 0.35 s | Hold the landing site. The push-in on impact is 8% of zoom over 0.15 s and back; hit-stop is sim-owned. A knockback slide keeps following while `slide > 0` |
| Settle | 0.60 s | Decide by the trigger at the landing: if `r` is above 0.060, merge (the follow camera eases to the merged camera, no divider ever appears); otherwise split with the launched fighter's pane already expanded, reopening by moving the divider back in over 0.35 s (`e` 1 to 0) so the far fighter's pane wipes in from its side |

Cancel or skip: a KO or a `finisher_start` ends the follow at once (the finisher's own shot takes over); a tier-up or transformation cinematic for either fighter takes precedence (section 9); `camera.launch_follow = "cut"` in reduced motion replaces the Follow with a static shot of the launch position for 0.4 s and a cut to the landing.

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

The HUD is a single `Control` over the composite. The rig gives it, per fighter slot, the same record `anchor_fn` returns today, plus the pane: `{pos, h, visible, pane}`, where `pos` is the chest on screen and `h` is `75 z`. Everything else follows from `docs/ui/hud-spec.md` section 10.

| Piece | In a split |
| :--- | :--- |
| Nameplates | Each fighter's plate at the outer top corner of its own pane (left pane: top left). They swap sides with the swing |
| Fighter-clear zone | Per pane: the pane polygon inset by the safe area on the outer edge and by 2% of the width on the divider side, and the vertical band 17.9% to 80.1% of the height. The anchors of section 3 sit inside it at every tilt and zoom |
| Planet strip and toll chip | The divider stops under the toll chip and above the strip (both edge-anchored). The strip is shared. Bark lanes stay at the outer bottom corners |
| Headroom | At least one body height (`75 z`) between the top of the head and the top of the pane, plus the plate's height where the plate is above it |
| Edge pointer | In each pane, on the divider side, a chip using the strip's circle and diamond shapes, pointing to the opponent (`n`) and showing the distance in fighter heights (UI decides whether to show a number; no "power level" text). It sits in the 24 px reserve band UI keeps around the clear zone. Always on in a split, on in solo without split |
| Ring map | A small ring of the planet with both fighters, each pane's viewed arc, and the held shortest arc highlighted. The rig gives `{angle_A, angle_B, sigma, arc_A, arc_B, swing, sep}` with angles as `x / W * TAU`. UI owns the widget and the size; I recommend it sits at the top of the divider under the toll chip (a 6% of screen height ring), hides during a cinematic, and marks a hidden fighter by its last known angle only |
| Reduced motion | The swing becomes a 0.15 s cross-dissolve, the slam a hard cut with no sweep, the launch follow a cut (section 8) |

## 11. Rendering: how two panes are drawn

A pane is one full render of the world from its camera. The scene is built around one camera at a floating origin: world content is placed at `k W - cam.x` for the camera's x, the fighters, beams and particles are placed by `sdx(cam.x, x)`, and the bend, sky and fog uniforms come from one set of static values in `RenderMats`. Two cameras at different x, zoom and height therefore cannot share one set of nodes and materials. The design is:

- **`PaneWorld`**: everything `main.gd`'s `render_view` drives for one camera (a `CameraRig`, `PlanetView`, the fighter views, `BeamView`, `ParticleView`, a `WorldEnvironment`) inside its own `SubViewport` with its own `World3D`. Meshes, MultiMeshes and the ground data are shared resources, so the cost of a second pane is nodes and draw submission, not memory.
- **Per-pane materials.** The materials that carry per-camera values (`bend`, `cam_dist`, the sky, `fore_cam`, the crowd boost, the fighters' pivot) must not be shared between panes. The clean change, and Rendering's to make, is to turn the static state in `render/core/mats.gd` into an instance owned by each `PaneWorld`. Until then the rig can drive two panes by swapping the static context (`_cache`, `_tracked`, `_bend`, `_dist`, `_sky`) around each pane's update; that stopgap lives in `render/camera/` and touches nothing in Rendering's files.
- **`SplitView`** (mine): a `Control` that owns the two panes and one `ColorRect` with the mask shader. The shader gets both pane textures, the divider (`c`, `n`, `gap`, `feather`), and the expansion, and blends by the signed distance to the divider. When `sep` = 0 only pane A is rendered and drawn unmasked.
- **Cost.** The two panes together have the same fill as one full-screen view if they are sized to their regions (each about 0.63 of the width at the 30° limit, so 1.26x). The first build renders each pane full-screen (2x fill, 2x draw submission) and resizes nothing at run time; the sized version is the optimisation, measured before it is done. Draw calls go from about 80 to about 160 plus the HUD's 230 canvas draws. A split runs about two fifths of a match, so I will measure the desktop and web frame times (section 14) and report before choosing the pane target size. The knobs if it is too heavy on an old laptop: `Viewport.scaling_3d_scale` on the panes (0.75), pane targets sized to their regions, a lower far-ground stride while split.
- **Shake.** `host.jitter` is drawn once a tick from the `camera` cosmetic stream. Each pane takes the jitter scaled by the user's shake scale; the second pane draws from a second derived stream (`camera_b`, `SimRng.deriveSeed(seed, "camera_b")`), so replays show the same shake. Neither stream touches the sim's.

Only `render/camera/` changes for the rig, the composite, the mask shader and the tests. **What Rendering must change** (through the EP): move `render/core/camera_rig.gd` to `render/camera/camera_rig.gd` (keep `class_name CameraRig`, move its `.uid`, and update `main.tscn`'s `ext_resource`); factor a `PaneWorld` out of `main.gd`'s `render_view` and the `_view_cues`; and let `main.gd` ask the rig (`SplitRig.frame(alpha)`) for the pane cameras instead of `host.camera(a)`. `sim/core/view/camera.gd` stays in `SimHost` untouched, as the reference for the goldens.

## 12. Comfort and the no-pop rules

These are the limits the tests enforce (`camera_params.gd`). "Ordinary" means anything that is not an authored cut (the slam, a cinematic hard cut, `cut()`).

| Quantity | Limit |
| :--- | :--- |
| Zoom rate | 1.2 e-folds a second ordinary; 2.0 in a transition; the slam is exempt |
| A fighter's screen motion per tick relative to its pane anchor | 0.02 of the screen width ordinary; 0.05 in a transition |
| Divider angle rate | 120 degrees a second; the swing is exempt (its own curve, about 560 degrees a second at its peak) |
| Divider position | continuous; at most 0.06 of the screen width a tick outside the slam |
| Shake amplitude | capped at 3.0% of the screen height (21 px at 720p; the prototype's largest was 30 px), scaled by the user setting; decay `0.02^dt` as before |
| Mode changes | at most one split-or-merge per 0.8 s and one orientation flip per 1.0 s, whatever the input |

## 13. Carried over from the wave-1 brief

The wave-1 files (`framing-rules.md`, `comfort-limits.md`, `cinematic-moments.md`, `hiding-camera-options.md`) were not written; this document supersedes them. What still fits:
- **User shake scale**: 0 to 100%, default 100%, stored as `camera.shake_scale`; 0 turns shake off. **Reduced motion** (UI's `reduced_motion` option): shake scale 25%, swing and dissolve replaced by 0.15 s cross-dissolves, slam by a cut, launch follow by a cut, tier-up push off.
- **Timing policy**: hit-stop and KO slow motion are sim-owned durations in whole 60 Hz ticks. The camera reads them; presentation transitions run on the fixed `DT` (not the sim's scaled `S.dt`), so a swing or a dissolve is not stretched by the KO slow motion. The rig never changes sim time and never delays input sampling.
- **Shake is cosmetic**: never the sim RNG stream; the `camera` and `camera_b` derived streams above.
- **Shake table**: the ten shake writes in the prototype are `Fx.shake` events with only a `k`. In the port the camera reads the sim event that caused each one (building collapse `k` 10, explosion 16, hit 6, launch 10, guard break 12, clash wave 18, beam fire 14, tier-up 14, impact `min(30, speed * 0.01)`, clash held 7) and applies its own table. The values are to align with Controls, who set the per-impact numbers within this document's cap.
- **Event fields wanted**: `shake` events with the world `x` (so a split shakes the nearer pane fully and the other at 35%), `launch {actor, speed, dir}`, `rush {actor, target, end_tick}` (the field on the fighter works; an event is cleaner for a replay), `cinematic_start`/`cinematic_end {actor, kind, dur_ticks}`, `fold_start {x, y, radius, dur_ticks}` and `unfold`, `relocate {x}` (a hard cut).

## 14. Hiding: the hook, not the feature

On hold while Orb decides whether hiding stays. The rig has one seam for it and nothing else:

```
pane_request(slot) -> {kind: "normal" | "search", search_x, search_y, search_radius}
```

By default every pane is `normal`. If the game asks for `search`, that pane's camera does not follow its fighter's opponent's true position: it centres on `search_x` with a slow drift inside `search_radius` (from the hunter's `lastSeen` and the hunt state) and the edge pointer, ring map and tilt all use the last known position, not the truth. The hider's pane stays normal. Two leaks to design out if it is built: the divider tilt and the ring map must use the last known position (the tilt is computed from `pane_request`, not from `S`), and on a shared screen the hider's normal pane is visible to the hunter; a shroud on the hider's pane (a darkened cover view) is the likely answer and belongs to the same decision.

## 15. Determinism and the test

The rig reads `S` after each tick and never writes it; it draws no sim random numbers; the layout is a pure function of the ticks so far. Rendering-side jitter uses derived cosmetic streams. `render/camera/tests/split_sweep.gd` (headless; numeric; exit 0 or 1) poses fighters by hand like `seam_sweep.gd` and steps the rig 60 times a second, interpolating at 144 Hz to catch per-frame pops. It covers:
- Separations from 0 to 0.998 of the antipode, together and head-on, through the seam, in both directions, at level, at +2,000 and at -2,000 units of height difference.
- Both swap directions at the antipode and the pass-through, with the separation jittering around the flip point by +-0.5 m (it must flip at most once) and around the split and merge lines by +-10% (it must not chatter).
- A dissolve merge and a slam merge (a scripted rush ending in contact), a split from a landing, and a launch at the p10, p50, p90 and maximum measured speeds.
- Checks: every pixel of a 64 by 36 sample grid belongs to one pane (or two whose weights sum to one); every limit of section 12; each fighter's anchor stays inside its pane's clear zone; the unsplit merged frame equals the frame the reference camera gives (within 0.5 px) whenever `sep` = 0; the same run twice gives the same digest; the sim's gameplay hash is the same with the rig on and off.
- An optional `--render` mode renders the composite and reports the mean absolute frame-to-frame pixel difference across every mode change, and saves the before-and-after captures for the deliverable.

## 16. Build order

1. `camera_params.gd`, `split_rig.gd` (the trigger, orientation, layout, pane cameras, launch, cinematics), `split_view.gd` and the mask shader, the test. Report with the exact file list.
2. The demo scene `render/camera/split_demo.tscn` (the sim host, two panes, UI's HUD anchors) so the result can be seen without touching `main.tscn`, with before-and-after captures and frame times on desktop and web.
3. The integration into `main.gd` is Rendering's, on the EP's word.
