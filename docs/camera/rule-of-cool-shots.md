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

### Row 13: the ping-pong rally (planned; wave 1)

- **Events (new).** `rally_start {a, b}`, `rally_bounce {from, to, n, x, y, z, t_next, x_next, y_next, z_next}` (the target position and time of the next bounce, so the camera can lead), `rally_end {ender}`.
- **Shot.** One shared view for the rally's length (no split flips, no merges: a layout hold, except for the lag bound's safety), zoom pulled out to fit the pair and the next bounce point (the lookahead is the event's `x_next`), a 3% impact push and a small shake at each bounce that grows with `n` (1% a bounce, capped at 3 bounces' worth), no cut. At `rally_end` the ender's own shot takes over (a slam, the round-the-world hit, a launch).
- **Humans.** Two humans in a rally are in one view for its length and split again after the rally's end dwell.
- **Reduced.** No pushes, no shake; the lookahead framing stays.

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

### Panel cut-ins and speed lines (row 11): held

Nothing is planned until Orb picks the pitch (a) in `pitches.md` §8. When he does, a panel is a flat overlay (UI/VFX); the camera's part would be a one-frame hold and a 2% push at the panel's open tick, nothing else.

## 3. What I need, in one list

| From | Item | For rows |
| :--- | :--- | :--- |
| Simulation | An intro phase before the clock, skippable, with `intro_start`, `entrance_land`, `staredown_start`, `clock_start` | 7 |
| Simulation | `big` on every event of rows 13 to 22 (the sim's own rationing) | all |
| Simulation | `orbit_launch`, `orbit_land`, `tunnel_start`, `tunnel_end`, `world_hit` with the fields above | 18, 19, 22 |
| Simulation, Encounter | `rally_start`, `rally_bounce` (with the next bounce's place and time), `rally_end`; `clash_*` events or a shared Clash record with `kind`, `beam_answer` | 13 to 16, 20, 21 |
| World | Entrance craters on open ground at least 900 units apart; the landing crater radius in the orbit event | 7, 19 |
| Animation | Fall, landing crouch, staredown idle, face close-ups | 7 |
| Rendering | The cut-away request off keeping a rock whole; terrain LOD at a 3,300 unit wide view | 18, 8 |
| Tools | Clip scoring and the replay seek | 25 |

## 4. Build order for the camera

1. **Now.** Row 8 (built, above).
2. **Wave 1,** with Encounter's events: beam answers (16), the rally (13), the clash push and pulse cues (14), the entrance when the sim has an intro (7).
3. **Wave 2.** Orbit and re-entry (19), through the mountain (18), the fist, blur and grapple shots (15, 20, 21).
4. **Wave 3.** The round-the-world hit (22).
5. **Wave 4.** The highlight reel (25).
