# Rule of cool: the camera's rows

Owner: Camera & Cinematography. The camera's side of `docs/design/rule-of-cool.md`. One row per feature the camera has a part in, with what is built, what is planned, what I need from other directors, and the reduced version. Every number is a proposal for `CamParams`. Everything names the events it reads; an event I call "new" does not exist yet and is the owner's to name.

## 0. How a live set piece is shot (the shared grammar)

Nothing in this list pauses the fight, so the fighters move through every shot. That limits what a cut can do. The rules:

1. **At most two cuts in a shot** (in and out), and the first is a cut only when the sim's own action already moves the frame (a launch, a landing). Everything else is a push, a pull or a whip of the follow filter. The out is the ordinary 0.6 s ease back to the framing the fight needs, never a cut, unless the shot was a cut-in.
2. **A shot does not outlive its event.** It ends when the event says so (or at 4 s), then the lag bound and the layout rules take over. No shot can hold a fighter out of the frame: the lag bound (soft 0.06, hard 0.20 of the screen width) stays on during every shot, and a shot that would break it yields.
3. **The camera never rations.** The sim says whether this is the one big live set piece of the 20 s (`big: true` on the event, my ask for every row below). With `big: false` the camera plays the ordinary version: the existing push/impact vocabulary and no new framing. The camera-only cut-ins keep their own 6 s cooldown and 6 a minute, and they are skipped while a big set piece runs.
4. **Reduced version for every row**: no pushes, no shake, no pitch, cuts become the 0.08 s fade. The shot still frames the same thing.
5. **Two humans.** In a split, a shot takes the pane of the fighter it is about, and the other pane keeps its own fight. A shot about both (a clash) takes both panes' framing to the same shared point and merges the layout for its length.
6. **Nothing here is the only cue** (rule 6 of the plan). A pulse, a surge or an answer is also shown and heard by UI, VFX and Audio; the camera adds emphasis and never carries the information.

## 1. Built now (needs no new event)

### Row 8: the winner stands in the wreckage

- **Trigger.** `S.game.ko` set. The loser's close-up (the existing KO dolly) plays first; 1.8 s after the KO (`WRECK_AT`, the sim's slow motion ends at 2.2 s) one cut takes the pane to the winner.
- **Shot.** The winner at 13% of the screen height, pulling back over 3.5 s (eased, `WRECK_T`) to 4% (29 px at 720p), standing in the lower middle of the frame (0.70 of the height). As it pulls back the winner slides sideways to 0.2 of the width off centre, away from the most wreckage, so the damage fills the larger part of the screen.
- **Choosing the side.** `_wreck_scan` sums, on each side of the winner and inside 0.7 of the screen width the pulled-back view will have on that side: craters (radius times depth, doubled for a signature or finisher, nearer counting up to twice as much), buildings lost (face area, scaled by how much is gone, 0.05 weight) and knockback trenches (depth times length). It picks the heavier side if it is at least 15% heavier; under 4,000 total it stays centred. It reads only `S.craters`, `S.buildings` and `S.slides`, once, at the start of the shot, so it is deterministic and the same on replay. Casualties have no position in the state, so civilians are not in the score; the craters and the buildings carry the picture.
- **Ends** when `S.game.ko` clears (the next match). It does not auto-end otherwise: the match-over screen sits on top of it.
- **Reduced.** No cut and no dolly: a fade to the final framing (4%, off centre) in 0.2 s.
- **Tests** (`split_sweep.gd`, "shot winner in the wreckage, right / left / none / reduced motion"): wreckage on the right gives +1 and the winner at 30% of the width; on the left -1 and 70%; no scars gives 0 and 50%; one cut frame (none when reduced); the pull-back goes 100, 74, 29 px at 720p; and the shot ends with the match.
- **For Rendering.** The final view is 3,300 units wide: terrain far LOD and the crater bowls should look right at that zoom. Nothing is needed otherwise.

## 2. Planned, with the shot plan and what it needs

### Row 7: the crater-landing entrance and the staredown (planned; needs a sim intro)

**Today.** A match starts at `S.T = 0` with both fighters standing at y = 60, 600 units apart. There is no pre-clock phase and no entrance state, so the camera has nothing to cut to. The camera can build this the moment the sim gives it a time window and four events.

**The shot (about 6 s, skippable).**

| Beat | Time | Camera |
| :--- | ---: | :--- |
| Sky | 0.0 to 0.6 s | A low wide angle on the empty spot where fighter A will land (pitch -6, 7%, the same low angle as the transformation's break), the sky above. A speck falls into frame |
| A lands | 0.6 s | The touchdown tick: a 6% impact push for 0.1 s, a medium shake (the scale of a tier 2 landing), the crater bowl digs under him. Hold 0.5 s on the crouch |
| B lands | 1.4 to 2.4 s | A hard cut to the same low angle on B's spot, mirrored, the same landing, 0.9 s |
| Staredown | 2.4 to 5.0 s | One cut to a two-shot at fight size (11%) with both craters in frame, then a slow push to 14% over 2.6 s. In a split, no divider: it is one view. Two quick cuts to each face (16%, 0.5 s each) at 3.6 s and 4.3 s if the animation has a face to show |
| Clock | 5.0 s | A 3-tick punch-in (the bell), then the ordinary fight framing with the usual 0.6 s ease. The clock starts at this tick |

**Skip.** Any key (the fight's own start key) jumps to the clock tick: a 0.08 s fade to fight framing, the craters already dug.
**Reduced.** No fall: begin at the landing (a fade), no shake, no push; the staredown is a static two-shot for 1.5 s.
**Players.** The entrance is a presentation of both fighters at once, so it takes the merged single view; the panes appear at the clock.

**What I need.**
- **Simulation.** An intro phase before the clock (`S.T < 0` or a flag), with input locked, skippable, deterministic: events `intro_start {dur, skip_ok}`, `entrance_land {actor, x, y, z, fall_from_y, r}` at the touchdown tick (the crater is dug then: World), `staredown_start {dur}`, `clock_start`. The fall's start height and duration should be in the event so I can frame the sky before the landing, not chase it.
- **World.** The landing spots chosen on open ground (the plan says no collateral), and the two craters real. I want the spots at least 900 units apart so the two-shot fits at 11%.
- **Animation.** A falling pose, a landing crouch (ours: no franchise pose), an idle staredown with the head turned toward the opponent, and a close-up-capable face on both.
- **Rendering.** Nothing new (the -8 degree angle is checked).
- **UI.** The HUD hidden until `clock_start`; a skip prompt.

### Row 19: orbit and re-entry (planned; wave 2)

**Needs** the game to choose the landing spot at launch time, and to tell the camera. That is what lets the camera cut ahead of the victim instead of chasing him back down.

- **Events (new).** `orbit_launch {victim, owner, x, y, apex_y, t_up, t_down, land_x, land_y, land_z, big}` at the launch, and `orbit_land` at the touchdown tick.
- **Shot.**
  1. **Up** (0 to `t_up`). The existing launch rules: the attacker's pane holds, the victim's pane chases. The lag bound already covers the speed. The zoom eases out with altitude (the altitude factor) and the sky darkens (Rendering's call).
  2. **Apex** (about 1 s around it). A hard cut to a wide, high view with the victim a speck and the landing zone in frame: zoom to the floor of the one view, pitch 0, the landing site at the lower third. This is the "planet" beat. It does not wait for the victim to come back.
  3. **Streak** (the last 1.2 s of `t_down`). A push toward the landing site: the zoom rises from the floor to 8%, the streak enters at the top.
  4. **Landing.** The touchdown tick: a 6% push, big shake (scaled by tier), 0.5 s hold, then the crater and the dust cloud for 1.0 s. The camera sits where the plan puts the best view: the landing site's camera is placed low (pitch -6) and wide enough for the bowl (bowl radius over the screen: fit 60% of the screen width).
  5. **Out.** The ordinary ease back to the fight framing; the attacker's pane takes the screen if the victim's is too far.
- **Cuts.** Two (apex, landing), plus the out is an ease.
- **The "most dramatic landing spot".** Chosen by the game, in the sim, at launch (rule 7 of the plan). The camera uses the answer and does not score. I read `land_*` and, to frame the bowl, the planned crater radius from the same event.
- **Reduced.** No apex cut: the chase continues to the landing, no pitch, a 0.2 s fade for the final push.
- **Rationing.** The three planet-scale launches share a budget of 3 a match; each carries `big`.

### Row 18: through the mountain (planned; wave 2)

- **Events (new).** `tunnel_start {victim, x_in, y_in, z, x_out, y_out, t_in, t_out, formation_h}` and `tunnel_end`.
- **Shot.** A hard cut to a wide frame of the formation as the victim reaches it (zoom to fit 70% of its height, as the building-smash cut-in does; the formation low in the frame, the sky above), with the **cut-away request off** so the rock stays whole. He enters the rock and is hidden for the tunnel time. A 3% impact push at the entrance. At the exit tick a medium shake, the dust bursting from the far side, the camera not moving. A second cut back to the chase of the victim as he leaves the rock (he comes out already moving).
- **Mesas** (tier 3 and up) use the same shot with the formation height. **A later launch through an existing tunnel** gets no cut: the ordinary chase, with a 3% push as he passes the mouth.
- **Reduced.** No cut: a chase that holds at the formation (the pane stays at the mouth for the tunnel time, then follows).
- **Rendering.** Please confirm the cut-away request off keeps the rock opaque while the victim is inside it; the victim should not draw through the rock.

### Row 22: the round-the-world hit (planned; wave 3)

The planet wraps, so the victim leaves one side of the screen and returns from the other. The camera uses that: the hit is shown from the attacker's side.
- **Events (new).** `world_hit {victim, owner, t_total, t_back, x_start, dir, big}`.
- **Shot.** (1) Launch: the existing chase of the victim for 0.8 s, so the player sees him go. (2) A cut back to the attacker, widened to 5% with the attacker's side anchored toward the opposite edge, holding while the victim is out of sight. The speed lines and the "world rushing past" are VFX's (an edge effect). (3) The victim re-enters from the far edge `t_back` ticks before the blow; the camera does not move, he streaks across the frame (the lag bound does not matter, the camera is static). (4) The impact: 6% push, the biggest shake, 0.4 s hold, then the ordinary ease.
- **Two cuts** (back to the attacker, and none out).
- **Tier 4 only; the big one.** The camera takes `big` from the event.
- **Reduced.** No chase and no widening: the attacker's framing the whole time, the victim entering from the edge.

### Row 13: the ping-pong rally, and the curved rush it is built on (planned; wave 1; Combat's spec is `docs/combat/pending/wave3-pingpong.md`)

Nothing is built until Encounter's rush has paths and the events exist. This is the plan, so the events can be named once.

**What the camera needs from the sim.**
- `path {actor, shape (spiral, arc, ground), S, I, sigma, plane (up, down or a depth lane), turn or h, start tick, end tick}` at planning, before the first tick of travel (Combat section 2). I can compute the spiral from `S`, `I`, `sigma` and `n` (the formula is in section 2) and the arc from `h`, so the widest offset's side and size are optional extras.
- `rally_start {a, b, pattern (rally, ladder, orbit), centre (x, y, z) and radius for the orbit}`, `rally_bounce {from, to, n, contact tick}` at each knock (the hit-stop tick), and `rally_end {ender}`. The `path` events already say where he arrives, so `rally_bounce` only has to say that the knock happened and which contact comes next.
- `big` on the ender, as for every set piece (rule 2 of the plan), and the ender's own event for what it does next (a crater slam, a long launch, the round-the-world hit).

**The curved rush alone (the spiral entry, the arc dive, the skid).**
1. *Before he leaves (the 4 hit-stop ticks).* The merged target takes the box of: his position `S`, the arrival `I`, the curve's widest point (0.205 of the chord to the bulge side for a spiral; the apex `h` for an arc), and the struck body. The zoom eases out to fit that box with a 15% margin, and the focus eases toward its centre. The look-ahead is the event's, so the camera is in place when he moves; today's rig sees him only as he moves and lags a rush (the lag bound whips it).
2. *In flight (about 24 to 28 ticks, 0.4 s).* The focus aims between his current position and `I`, weighted toward `I` as he nears it (the ease brakes him, so the camera brakes with him); the zoom holds. No cut. A depth-lane bulge needs nothing new: the depth code already scales the zoom by `Fighter.z`, and the back row keeps at least 24 px (the depth tests).
3. *Arrival (the intercept turn, the brake).* A 3% push over 0.1 s and a light shake at the brake tick. For the ground path the dust is VFX's, and the camera stays level with no pitch.
4. *Reduced.* The look-ahead framing stays (it is framing, not motion); the push and the shake go.

**The rally, as a whole.** One shared view for its length: the layout is held (no split flips, no merges) unless the lag bound or the one-view limit would lose a fighter, in which case the split opens as it does now. For two humans in a split the same applies: the panes merge for the rally if the pair is within the one-view limit and each follows its own fighter if not.
- *Framing.* At each knock the target box is {the struck body now, `I` of the next path, the next path's widest point, him}; the zoom goes to fit the chord (typically 7% to 9%; the widest rally chord, about 1,800 units, fits at 5%). It eases back in as the pair converges, so the contact is at fight size (11%). The contact tick is a 3% impact push over 0.1 s and a shake that grows by 1% a bounce (capped at three bounces' worth); the ender is a 6% push.
- *Readability (Legal and the defender's windows).* The attacker must be on screen for the whole 6-tick anticipation of a return blow (the defender's perfect-block window) and at least 4 ticks after contact, and the struck body is always on screen. The test fails a rally in which either is outside the frame at those ticks.
- *The panel.* The ender is an earned hit and takes the panel (shared one in 12 s). Middle bounces do not.
- *Pace.* One big set piece in 20 s: the ender's `big` flag decides whether it is the full ender or the ordinary one; the camera plays the bounces the same either way.

**The three patterns.**

| Pattern | Camera |
| :--- | :--- |
| **Rally** (back and forth on one line) | The shared view pans along the line with the look-ahead above; the horizontal extent is the widest, so it sets the zoom. The ender is *across* (a long launch: the launch follow takes over, below) or the targeted smash (the building-smash cut-in, if it is big enough) |
| **Ladder** (a zigzag that climbs, 30 degrees a knock) | The vertical extent grows with each bounce, so the zoom is set by the height. The focus follows the pair's midpoint with the look-ahead, and the altitude factor eases the zoom out as the pair climbs. The ender is *down* (the drive or the crater slam): at the ender's wind-up the camera drops to ground level ahead of the fall, using the event's landing point |
| **Orbit** (each knock turns 70 degrees; the body circles a point) | "The camera holds one frame": a fixed frame on the orbit's centre with the radius plus a margin, no following, a slow 2% push over the rally. The fighters circle inside the frame; at the ender (*down* onto the point or *across* away) the frame releases into the ender's shot. Needs the centre and radius from the event; without them it falls back to the rally framing |

**Tests when it can be built.** Injected `path` events for the three shapes: the box is framed before the first travel tick, he is never outside the frame, no cut. Rally scenarios for the three patterns: the attacker is on screen for the 6 anticipation ticks and 4 after contact, the body is always on screen, the layout does not change inside a rally except for the one-view limit, the orbit frame does not move, and the impact pushes are 3% and 6%.

### Rows 14, 15, 20, 21: the pulse clashes (planned; wave 1 for the beam struggle, wave 2 for the rest)

All four use the same camera frame, with one change: the clash shot reads `game.clash` for all of them if Simulation keeps one Clash record with a `kind` (`beam`, `fist`, `blur`, `grapple`), pulses, and a score. If it makes separate records, I need one event shape: `clash_start {kind, a, b, x, y, z, big}`, `clash_pulse {n, tick, window}`, `clash_surge {actor, n}`, `clash_end {winner, kind}`.

- **Shared.** A push on the shared view when the clash opens (the existing beam struggle push: in 0.25 s, hold 0.5 s, out 0.6 s). Each **pulse** is a 2% micro-push for 4 ticks at the pulse tick (timed with the sim's pulse, so the push is a cue and not the information), a **surge** a 3% push on the surger, and the **end** a 5% kick outward and the shockwave's shake.
- **Fist clash shockwave.** Both panes merge (one view) and frame the two fists at 13%. At the end, a pull-out kick of 5% outward and a shake. From tier 3 the shockwave's building damage gets the building-smash cut-in if it is big enough (the existing rule).
- **Blur exchange across the sky.** The fighters trade strings at speed. The camera goes to the widest framing the one view allows (the floor, 3.2%), holds the arc of the exchange (the frame centres on the pair's mean, not on either fighter), and does no following of individual blows. The pulses push. The end puts the winner at fight size with a push on him.
- **Mid-air grapple lock.** A close two-shot at 14% as the lock rotates (the pair's centre, the lock's height), then at the slam the ordinary slam rules (the door, the launch follow). Needs the lock's end to be the launch event of the slam.
- **Reduced.** No pushes, no shake, no kick; the framing is the same.

### Row 16: the three beam answers (planned; wave 1)

- **Events (new).** `beam_answer {actor, kind, t0, dur, x, y, z, x1, y1, z1}` where `kind` is `swat`, `split` or `through`, and for a swat the landing point of the knocked-aside beam.
- **Swat it into the scenery.** A 5% push on the answerer for 0.2 s at the swat, then the zoom eases out to include the landing point if it is inside one view's width (otherwise it is not followed: the pane stays on the fighters). The carve is VFX's and the world's.
- **Split it around the body.** The answerer centred (anchor at 0.5), a 3% push, the beam parting round him symmetric in frame; shake from the two scars. The cleanest picture of the three.
- **Walk through it.** A tracking push: the zoom rises from fight size to 14% as he advances through the beam (about 0.7 s), the answerer held in the middle third; at the arrival, a two-shot at 12% for the attacker's 20 recovery ticks.
- **No cuts.** All three are pushes. The cost to the player is zero, so the shot does not take control.
- **Reduced.** Centred framing, no pushes.

### Row 25: the highlight reel (planned; wave 4; needs the replay system)

- **What the camera does.** The reel replays the sim from the seed and the input log and runs the same rig over it, so every shot is re-derived and nothing is recorded by the camera. The reel's camera differs in four ways: it forces a single merged view (no human seats), it uses a slower, slightly wider set (fight 10%, launch 7%), it picks the shot for each clip from the clip's event (a launch gets the chase, a finisher its dolly, a clash its push), and it ends each clip on a 0.3 s cross-fade into the next with no cut.
- **Needs.** Tools: clip selection (3 to 5 clips of 3 to 4 s with 1.0 s of lead-in; the score is theirs), and a seek that calls `rig.cut(S)` and lets the rig run the lead-in so the filters are warm. Simulation: the replay to be exact from the input log. UI: a skip.
- **Reduced.** Static framing and fades between clips.

### Row 11: the panel cut-in (built, 2026-10-04; Orb's pick B)

A slanted close-up strip over the live view. **The main view is untouched: no cut, nothing pauses.** Speed lines are VFX's.

- **What it shows.** A live close-up of one fighter's upper body in a parallelogram strip (56% of the screen width, 20% of the height, ends slanted 22% of the height), with a border in his lane colour and a wipe that opens it along the slant in 0.08 s and shuts it in 0.12 s. It is the real world drawn by a second camera (Rendering's inset pane), so the pose is the pose on the field: the fighter facing into the strip with room in front.
- **Who gets one.** The peaks always play. The hits the player earned share one panel per 12 s. A stronger panel replaces a running weaker one and an equal or weaker one is dropped.

| Kind | Rank | Length | Subject | Driven today by |
| :--- | ---: | ---: | :--- | :--- |
| KO | 5 | 1.4 s | the winner (the main view is on the loser) | `ko` event |
| Finisher | 4 | 1.1 s | the attacker | `finisher_start` event |
| Crippling blow | 3 | 0.8 s | the broken fighter | `region_broken` event |
| Signature | 2 | 0.9 s | the attacker | the `beam_outcome` event (the live, dynamic profile fires it: 4 in a 5-minute AI match, one for each `attack` of kind sig) **or** a new beam in `S.beams`, whichever comes first; the two are the same fire beat and make one panel. The beam is kept as the fallback for the other profile |
| Clash won (earned) | 1 | 0.7 s | the winner | `decisive` with kind `clash` or `beam_clash` |
| Riposte that launches (earned) | 1 | 0.7 s | the riposter | `parry` then `launch` by the same fighter inside 2 s (derived; a `riposte` flag from Combat would be exact) |
| Ping-pong's ender (earned) | 1 | 0.7 s | the ender | **waits** for the rally events (`rally_end {ender}` is assumed in the rig and untested) |

- **Where it sits.** The top band (19% to 39% of the height, under the clear zone's top edge) where UI's HUD leaves it whole, else the bottom band (80% to 100%); and the bottom one too when a fighter's body is in the top one; if both are taken the panel is dropped. UI's `panel_floor_y()` (the lowest edge of the plates, the toll chip and the pause button) goes to `SplitView.set_panel_floor(y)`: the top band starts at the larger of 19% and the floor, and is used only if the 20% strip still ends by 39% (so on desktop at 1920 by 1080, 1280 by 720 and 3840 by 2160, and the bottom band on phones and small windows). The strip is centred, so UI's side face cut-ins (about 22% of the width at each edge) stay clear of it.
- **Reduced motion, or the setting "still".** The strip opens at once, shows a frozen frame (the inset renders twice and is switched off) and shuts at once; no push, no wipe. The setting `off` plays none.
- **Who draws it.** Camera's compositor (`SplitView`, `panel_mask.gdshader`), from `SplitFrame.panel` and Rendering's inset pane. Rendering already had the inset (`make_inset`, and `inset_view` called from `main.render_view`); the compositor makes it at attach so main's `inset` exists before the first strip, switches its updates off when no strip is up and drives its camera from the frame. UI and Rendering do not need to draw anything. I judged Camera should draw it because where the strip may sit depends on where both fighters are on the screen this frame, which only the rig knows.
- **What UI supplies.** The option `camera_panels` (full, still, off; default full), calling `SplitView.set_panel_mode`; the lane colours for the borders (`SplitView.set_panel_colors(a, b)`; the defaults are an orange and a blue); keeping the face cut-ins off the centre 56% of the width; and a check that no HUD plate sits in the strip's bands (the top band is under the plates, the bottom band is over the bark lanes).
- **What Rendering should check.** The strip costs one extra render of the world at 749 by 144 px for under a second; a still strip costs two frames. Worth measuring on the phone budget. The small red diamond at the strip's top edge is the fighter's stance badge (`FighterView.badge`, a 3D mesh above the head). `FighterView.update` sets its visibility every frame, so the compositor cannot hide it from outside: Rendering needs a per-pane flag (for example `PaneWorld.hide_markers`, which `FighterView.update` honours) and the inset sets it. Framing it out is not possible (the head and the badge are 20 units apart and the head needs the room). The strip's camera follows the same convention as the panes (the plane at 0.7 of the viewport's height) and frames the point 60 units above the fighter's feet, which on the real renderer shows the head and chest.
- **Legal (§3b, the face cut-in's rule applies in spirit).** The frame is our own: a plain slanted parallelogram with a thin lane-colour border, no static, no radio-screen look, no portrait layout.
- **Rate today.** In five-minute AI matches the events above give 0.7 to 1.3 panels a minute (mostly clashes won; a few signatures; a crippling blow once). Orb's target of about 2.5 a minute needs the earned hits that have no event yet (the ping-pong's enders) and real play, where the human fires more signatures than the AI demo. The ration and priority are tested; the rate is for QA to tune with the 12 s gap and the lengths.
- **Tests.** `split_sweep.gd`: "panel signature" (54 ticks, wipe open then shut, the subject's upper body in the strip, band 0, and the main view's cameras identical to a run without the strip), "panel ration and priority", "panel riposte", "panel modes", "panel band dx dy" (six poses, the strip never covers a fighter), and the composite picture (`--render --only=panel`). `panel_shot.gd` draws the strip on the real renderer.

## 2b. How the launch follow copes with long knocked-about journeys

World measured that one journey in six goes beyond a normal framing (about 4,000 units; the mean is 34 body heights, about 2,550 units; the 90th percentile 5,638 units). What the camera does with that:
- **The victim is never lost, whatever the distance.** The chase is a solo shot on the launched fighter held by the lag bound (the focus is never more than 20% of the screen width from where he should be, and anything faster than 1.5 screens a tick is a counted cut). The tests fly launches to 10,816 units at 26,000 to 45,000 units a second with zero ticks out of frame; the old rig lost the fighter for 11 to 13 ticks at those speeds. A 5,638 unit journey is inside that range. The follow ends at the landing plus a 0.35 s hold, capped at 6 s.
- **What is lost is the attacker.** On the chase the attacker is off the screen for the journey. The hybrid rule handles it: with one human attacking, the camera holds on him and cuts to the victim for 0.5 s at the impact (so he sees the hit, not the flight); with the human launched, the camera chases him; with two humans the split gives each his own pane; with no human (the demo) it chases.
- **The layout after a long journey.** If the pair end more than the one-view limit apart (the merged view fits about 4,100 units at its widest, 3.2% fighter height), the split opens as the follow ends (the 0.3 s opening), each pane on its own fighter, and merges when the rush closes the gap. So a journey beyond 4,000 units ends in a split, never in a view that cannot hold both.
- **What would help, and is not built.** (1) A direction cue for the off-screen opponent during a long chase: UI's pointer chip is the natural one, and the rig can say when the opponent is more than a screen away. (2) For a journey whose predicted flight is over 1.5 s (the `launch` event has the speed and direction), a cut ahead to the landing site 0.5 s before touchdown, as the orbit plan does, so the player sees the landing and not the tail of the flight. I would build (2) only if Orb finds long flights dull, since the chase is rigid and readable now.
- **A check to add** with the next launch work: the real-match sweep can report, per journey, its length and the ticks the attacker spent off screen, so the one-in-six figure is measured on the camera's side too. The data is in the rig's launch bookkeeping.

## 3. What I need, in one list

| From | Item | For rows |
| :--- | :--- | :--- |
| Simulation | An intro phase before the clock, skippable, with `intro_start`, `entrance_land`, `staredown_start`, `clock_start` | 7 |
| Simulation | `big` on every event of rows 13 to 22 (the sim's own rationing) | all |
| Simulation | `orbit_launch`, `orbit_land`, `tunnel_start`, `tunnel_end`, `world_hit` with the fields above | 18, 19, 22 |
| Simulation, Encounter | `path` (Combat section 2), `rally_start {pattern, centre, radius}`, `rally_bounce`, `rally_end {ender}`; `clash_*` events or a shared Clash record with `kind`, `beam_answer` | 13 to 16, 20, 21 |
| World | Entrance craters on open ground at least 900 units apart; the landing crater radius in the orbit event | 7, 19 |
| Animation | Fall, landing crouch, staredown idle, face close-ups | 7 |
| Rendering | The cut-away request off keeping a rock whole; terrain LOD at a 3,300 unit wide view; the cost of the panel strip's second render on the phone budget | 18, 8, 11 |
| Tools | Clip scoring and the replay seek | 25 |
| UI | `camera_panels` option, the lane colours for the strip borders, the face cut-ins off the centre 56% of the width | 11 |
| Combat | A `riposte` flag on a parry-launch, if the derived one (parry then launch inside 2 s) is not enough; the rally events (`rally_end {ender}`) | 11, 13 |

## 4. Build order for the camera

1. **Now.** Row 8 (built, above).
2. **Wave 1,** with Encounter's events: beam answers (16), the rally (13), the clash push and pulse cues (14), the entrance when the sim has an intro (7).
3. **Wave 2.** Orbit and re-entry (19), through the mountain (18), the fist, blur and grapple shots (15, 20, 21).
4. **Wave 3.** The round-the-world hit (22).
5. **Wave 4.** The highlight reel (25).
