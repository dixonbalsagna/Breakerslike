class_name SplitRig
extends RefCounted
## The dynamic split screen's brain (docs/camera/split-screen.md). It reads the sim state once per tick and produces a
## SplitFrame: whether the screen is one view or two panes, where the divider is, and each pane's camera. It never
## writes the sim, draws no sim random numbers and runs on the fixed DT, so it is a pure function of the ticks so far.
##
## Call step(S, vw, vh, events) after each SimCore.step (events: that tick's S.out.fx, before it is cleared), and
## frame(alpha) once per displayed frame for the interpolated result.

const DT: float = 1.0 / 60.0

# --- settings (the player's) ---
var solo_split: bool = true            # against the AI: split like two players (false: follow the human fighter alone when far)
var reduced_motion: bool = false
var pitch_deg: float = 0.0               # the cameras' pitch (Rendering's debug toggle sets it); 0 is straight on
var launch_follow: String = "auto"    # "auto" (the hybrid), "chase" or "split" (camera-v2.md section 3)
var zoom_pref: float = CamParams.ZOOM_PREF_DEFAULT   # the player's zoom setting, 0 to 10 (default 7)
var pane_request_fn: Callable = Callable()   # (slot) -> {"kind": "normal" | "search", ...}: the hiding hook, unused

# --- view ---
var vw: float = 1280.0
var vh: float = 720.0

# --- orientation (section 5) ---
var u: float = 0.0                     # held signed separation slot 0 to slot 1, shortest way, hysteretic
var sigma_u: int = 1                   # the sign the held separation asks for
var sigma_shown: int = 1               # the layout on screen
var phi: float = 0.0                   # smoothed tilt
var theta: float = 0.0                 # angle of the divider normal
var swing_t: float = -1.0
var _swing_th0: float = 0.0
var _swing_th1: float = 0.0
var _swing_dur: float = CamParams.T_SWING
var _flip_age: float = 99.0
var _prev_d: float = 0.0
var _prev_ad: float = 0.0
var _sep_rate: float = 0.0             # d|u|/dt, units a second (positive while they move apart)

# --- trigger and layout (sections 2, 6, 7) ---
var split_wanted: bool = false
var _view_lost: bool = false             # a fighter is outside the shared view as it is now (the split opens fast)
var sep: float = 0.0
var _below_t: float = 0.0
var _above_t: float = 0.0
var _layout_age: float = 99.0          # time since split_wanted last changed
var r_now: float = 1.0
var _slam_slot: int = -1
var _slam_sep0: float = 1.0
var _slam_last_rem: float = 9.0
var _flash: float = 0.0
var _slam_done: bool = false
var _mode_changes: Array = []          # times of split/merge decisions, for the tests
var _mode_reasons: Array = []          # why, in step with _mode_changes
var time: float = 0.0

# --- expansion and solo shots (sections 8 and 9) ---
var e: float = 0.0
var e_slot: int = -1
var e_target: float = 0.0
var e_hold: bool = false               # keep the pane expanded until the panes have merged
var sliver: float = 0.0
var solo_kind: String = ""
var solo_slot: int = -1
var solo_prio: int = 0
var solo_w: float = 0.0
var solo_target: float = 0.0
var solo_phase: String = ""
var solo_t: float = 0.0
var _solo_dur: float = 0.0
var _land_t: float = 0.0
var _launch_anchor_x: float = 0.5
var _prev_state: Array = ["free", "free"]
var _push: Array = [-1.0, -1.0]
var _shk: PackedFloat64Array = PackedFloat64Array([0.0, 0.0])   # per-pane shake from the shake events {k, x}
var _aim: Array = [null, null]          # per fighter: the (x, y) of the building a brunt is aimed at (launch_depth, chain_link)
var _hit_t: Array = [-1.0, -1.0]        # seconds since this fighter's last building_hit, or -1
var _hit_amp: Array = [0.0, 0.0]
var _hit_hold: Array = [0.0, 0.0]
var _bounce_t: Array = [-1.0e9, -1.0e9]
var _journey_end_evt: Array = [false, false]   # World's journey_end this tick: the chase's follow is over (the state follows it the same tick)
var bounce_pushes: int = 0
var _launch_anchor_y: float = 0.62
var chase_slot: int = -1                # a split pane that chases a launched fighter (no solo shot)
var _chase_land_t: float = 0.0
var _launch_victim: int = -1            # a launched fighter the hybrid rule may hold on the attacker for
var _impact_evt: Array = [false, false]
var _last_pitch: float = 0.0
var _pitch_now: float = 0.0              # the pitch in use: the player's plus a shot's (the transformation's low break)
var _shot_pitch: float = 0.0
var _tf_ver: String = ""                 # the transformation shot's version: full, short ("" for a bare cinematic)
var _tf_phase: String = ""               # gather, break or settle
var _tf_g: int = 0                       # the beats in ticks (docs/design/moveset-rules.md 10.8)
var _tf_b: int = 0
var _tf_s: int = 0
var intro_active: bool = false           # between intro_start and clock_start (docs/architecture/intro-phase.md)
var last_stand_shots: int = 0              # last-stand shots started (counted for the tests)
var intro_cuts: int = 0                  # the intro's hard cuts (counted for the tests)
var _in_phase: String = ""               # fall, land, stare or face
var _in_slot: int = -1
var _in_t: int = 0                       # rig ticks since intro_start
var _in_crater_r: float = 0.0
var _in_fall_h: float = 6000.0           # the fall's height, from the event
var _in_stare_t: int = -1                # ticks since the staredown began, -1 before it
var _in_stare_dur: int = 0
var _in_clock_t: float = -1.0            # seconds since the clock started (the push eases out), -1 when not
var _punch_amp: float = CamParams.LIVE_PUNCH
var _punch_len: float = CamParams.LIVE_PUNCH_LEN
var panel_mode: String = "full"          # the player's setting: "full", "still" (a frozen strip) or "off"; reduced motion means still
var panels: int = 0                      # panel cut-ins started (counted for the tests and QA)
var panels_dropped: int = 0              # panel requests refused: the ration, a stronger panel running, no free band
var panel_log: Array = []                # [match time, kind, slot] of each panel started
var _pn: Dictionary = {}                 # the running panel: kind, slot, prio, dur, t, band
var _pn_earned_t: float = -1.0e9
var _sig_t: Array = [-1.0e9, -1.0e9]    # when each fighter's last signature fire beat asked for a panel
var panel_floor: float = 0.0              # UI's lowest HUD edge at the top, px (UiHud.panel_floor_y()); the top band starts below it
var _beams_seen: Dictionary = {}         # instance ids of the beams already counted (a new one is a signature's fire beat)
var _parry_t: Array = [-1.0e9, -1.0e9]   # when each fighter last parried, for the riposte
var _stiff_w: float = 0.0               # 0..1: how far the slam's stiff filters have come in
var wreck_dir: int = 0                   # the winner's shot: +1 wreckage on the right of him, -1 on the left, 0 none to speak of
var wreck_score: float = 0.0             # the wreckage in view, summed (craters, ruined buildings, slide trenches)
var _live_punch_at: float = -1.0         # the live version: when the 6-tick punch-in starts (rig time)
var _punch_t: float = -1.0
var _ov_kind: String = ""               # a camera-only cut-in (building smash, crippling moment); "" when none
var _ov_t: float = 0.0
var _ov_dur: float = 0.0
var _ov_slot: int = -1
var _ov_pt: Vector3 = Vector3.ZERO
var _ov_r0: float = 0.11
var _ov_r1: float = 0.11
var _ov_times: Array = []               # start times of recent cut-ins, for the cooldown and the per-minute cap
var _clash_prev: bool = false
var _wide_t: float = -1.0                # a world-change or time-cap pause: the shared view pulls out and returns
var _wide_dur: float = 0.0
var cut_ins: int = 0                    # camera-only cut-ins started (counted for the tests)
var _cut_fade: float = 0.0              # seconds left of a safety cut's fade-in
var _cut_now: bool = false              # a safety cut happened this tick: the frame is a cut
var lag_whips: int = 0                  # ticks the hard bound had to pull a focus (counted for the tests)
var lag_cuts: int = 0                   # safety cuts (a fighter more than 1.5 screens off in one tick)
var _launch_evt: Array = [false, false]   # a `launch` event arrived for this fighter this tick
var fold_active: bool = false
var _fold: Vector3 = Vector3.ZERO

# --- cameras (section 4) ---
var _fx: PackedFloat64Array = PackedFloat64Array([0.0, 0.0])    # focus point per pane (the fighter's chest, filtered)
var _fy: PackedFloat64Array = PackedFloat64Array([0.0, 0.0])
var _zo: PackedFloat64Array = PackedFloat64Array([0.5, 0.5])    # own zoom per pane
var _mx: float = 0.0
var _my: float = 0.0
var _mz: float = 0.5
var _ppx: PackedFloat64Array = PackedFloat64Array([0.0, 0.0])   # last tick's fighter positions, for measured velocities
var _ppy: PackedFloat64Array = PackedFloat64Array([0.0, 0.0])
var _pmx: float = 0.0
var _pmy: float = 0.0
var _solo_decisions: Array = []

var _cur: SplitFrame = SplitFrame.new()
var _prev: SplitFrame = SplitFrame.new()
var _started: bool = false


# ---------------------------------------------------------------------------------------------------- public

func reset(S: SimState, p_vw: float, p_vh: float) -> void:
	vw = p_vw
	vh = p_vh
	var A = S.fighters[0]
	var B = S.fighters[1]
	u = SimWrap.sdx(A.x, B.x)
	_prev_d = u
	_prev_ad = absf(u)
	sigma_u = 1 if u >= 0.0 else -1
	sigma_shown = sigma_u
	phi = _phi_target(A, B)
	theta = _theta_of(sigma_shown, phi)
	swing_t = -1.0
	_flip_age = 99.0
	split_wanted = false
	sep = 0.0
	e = 0.0
	e_slot = -1
	e_target = 0.0
	e_hold = false
	sliver = 0.0
	solo_kind = ""
	solo_slot = -1
	solo_prio = 0
	solo_w = 0.0
	solo_target = 0.0
	solo_phase = ""
	_slam_slot = -1
	_flash = 0.0
	_push = [-1.0, -1.0]
	_pn = {}
	intro_active = false
	_in_phase = ""
	_in_stare_t = -1
	_in_clock_t = -1.0
	_beams_seen = {}
	_sig_t = [-1.0e9, -1.0e9]
	_pn_earned_t = -1.0e9
	_parry_t = [-1.0e9, -1.0e9]
	_shk = PackedFloat64Array([0.0, 0.0])
	_aim = [null, null]
	_hit_t = [-1.0, -1.0]
	fold_active = false
	_below_t = 0.0
	_above_t = 0.0
	_layout_age = 99.0
	_mode_changes.clear()
	_mode_reasons.clear()
	_solo_decisions.clear()
	time = 0.0
	_prev_state = [A.state, B.state]
	r_now = _metric(S)
	split_wanted = r_now < _r_split()
	sep = 1.0 if split_wanted else 0.0
	_snap_cameras(S)
	_started = true
	_cur = _make_frame(S)
	_cur.cut = true
	_prev = _cur


## Advance one sim tick. `events` are that tick's fx events (tier_up, cinematic_start, cinematic_end, fold_start,
## unfold, relocate are read; the rest ignored).
func step(S: SimState, p_vw: float, p_vh: float, events: Array = []) -> void:
	if not _started or p_vw != vw or p_vh != vh:
		reset(S, p_vw, p_vh)
		return
	time += DT
	_layout_age += DT
	_flip_age += DT
	var cut: bool = false
	for ev in events:
		if String(_ef(ev, "type", "")) == "relocate":
			cut = true
	_read_events(S, events)
	_update_shake(events)
	_flash = maxf(0.0, _flash - DT)
	_update_orientation(S)
	r_now = _metric(S)
	_update_solo(S)
	_update_panel(S)
	_update_intro(S)
	_impact_evt = [false, false]
	_journey_end_evt = [false, false]
	var clash_now: bool = S.game.clash != null
	if clash_now and not _clash_prev and not reduced_motion:
		_push = [0.0, 0.0]   # the beam struggle opens with the tier push's shape: in, hold, out
	_clash_prev = clash_now
	_pitch_now = pitch_deg + _shot_pitch
	if absf(_pitch_now - _last_pitch) > 0.01:
		_last_pitch = _pitch_now
		_cut_now = true
	_update_trigger(S)
	_update_layout()
	_update_pushes()
	_update_cameras(S)
	if cut:
		_snap_cameras(S)
	_cut_fade = maxf(0.0, _cut_fade - DT)
	_prev = _cur
	_cur = _make_frame(S)
	_cur.cut = cut or _cut_now
	_cut_now = false
	for i in range(2):
		_prev_state[i] = S.fighters[i].state


## The frame to draw, interpolated between the last two ticks (alpha in 0..1).
func frame(alpha: float) -> SplitFrame:
	return SplitFrame.lerp_frames(_prev, _cur, clampf(alpha, 0.0, 1.0))


## The frame as of the last tick, uninterpolated.
func current() -> SplitFrame:
	return _cur


func mode_change_times() -> Array:
	return _mode_changes


func mode_change_reasons() -> Array:
	return _mode_reasons


## Whether the layout change at `t` was a shot's ending (a launch settling, a cinematic ending): those skip the dwell.
func launch_decision_at(t: float) -> bool:
	return _solo_decisions.has(t)


## Re-seat everything on the fighters at once (a relocation or a replay seek).
func cut(S: SimState) -> void:
	_snap_cameras(S)
	_cur.cut = true


# ---------------------------------------------------------------------------------------------------- trigger

## The one view's zoom for two fighters ad apart in x and dy in height (pixels per unit). m is the zoom setting's
## multiplier; with `floored` the camera never zooms out past the floor (the size it is aiming at), without it the
## number is the size the fight would like, which is what the split trigger judges.
static func zoom_u(vw_: float, vh_: float, ad: float, dy: float, tier: float, m: float = 1.0, floored: bool = false) -> float:
	var span_x: float = ad + CamParams.FIT_MARGIN_X / m
	var span_y: float = dy + CamParams.REF_MARGIN_Y
	var zcap: float = CamParams.R_MAX * m * vh_ / CamParams.BODY_H
	var z: float = minf(vw_ / span_x, vh_ * 0.8 / span_y)
	if CamParams.ZONE_W > 0.0:
		z = minf(z, CamParams.ZONE_W * vw_ / maxf(ad, 1.0))
	z = minf(z, zcap)
	z *= 1.0 - CamParams.REF_TIER * (tier - 1.0)
	if floored:
		z = maxf(z, CamParams.R_FLOOR * vh_ / CamParams.BODY_H)
	return clampf(z, CamParams.ZOOM_MIN, zcap)


## The zoom setting's multiplier on every size target.
func _m() -> float:
	return exp(CamParams.ZOOM_PREF_K * (zoom_pref - CamParams.ZOOM_PREF_DEFAULT))


func _zcap() -> float:
	return CamParams.R_MAX * _m() * vh / CamParams.BODY_H


## The vertical extent of the pair on the screen, in world units: their height difference, and at a pitch their depth
## difference too (a fighter 1,000 units farther back stands higher on the screen by 1,000 sin(pitch); the sweep found a
## pair 1,098 units apart in depth at 49 degrees, one in view and one below the screen, in a merged view that fitted them
## by height alone).
func _pair_dy(A, B) -> float:
	var pr: float = pitch_deg + _shot_pitch
	if pr == 0.0:
		return absf(A.y - B.y)
	return absf((A.y - B.y) * cos(deg_to_rad(pr)) - (float(A.z) - float(B.z)) * sin(deg_to_rad(pr)))


## r: a fighter's height as a fraction of the screen height in the one-view (reference) framing.
func _metric(S: SimState) -> float:
	var A = S.fighters[0]
	var B = S.fighters[1]
	var z: float = zoom_u(vw, vh, minf(absf(u), SimConst.HALF), _pair_dy(A, B), maxf(A.tier, B.tier))
	return CamParams.BODY_H * z / vh


func _r_split() -> float:
	return maxf(CamParams.R_SPLIT, CamParams.MIN_PX / vh)


func _r_merge() -> float:
	return maxf(CamParams.R_MERGE, CamParams.MIN_PX * CamParams.R_MERGE / CamParams.R_SPLIT / vh)


func _update_trigger(S: SimState) -> void:
	var A = S.fighters[0]
	var B = S.fighters[1]
	var ad: float = absf(u)
	var rs: float = _r_split()
	var rm: float = _r_merge()
	if S.game.clash != null:
		rs = minf(rs, maxf(CamParams.R_BEAM_MIN, CamParams.MIN_PX * 0.66 / vh))
		rm = minf(rm, rs * 1.15)
	# The closing guard: fighters that will be back over the split line soon do not open a split.
	var closing: float = (_prev_ad - ad) / DT
	# Smoothed: the raw rate spikes to +-24,000 units a second in a rush and its recoil, and the one view zooms out for
	# the separation it will have soon, so a spike was a zoom pulse (the sweep's jolt scan found 300 to 490 in a match).
	_sep_rate += (-closing - _sep_rate) * (1.0 - exp(-DT / CamParams.SEP_RATE_TAU))
	var guard_ok: bool = true
	if closing > 0.0:
		var z_pred: float = zoom_u(vw, vh, maxf(0.0, ad - closing * CamParams.CLOSING_LOOKAHEAD), _pair_dy(A, B), maxf(A.tier, B.tier))
		guard_ok = CamParams.BODY_H * z_pred / vh < rs
	_prev_ad = ad
	if fold_active:
		_set_split(false, "fold")
		_slam_slot = -1
		return
	if solo_kind != "":
		# The dwell timers wait while a shot has the screen; its end decides.
		return
	if _slam_slot >= 0 or _slam_step(S):
		return
	_view_lost = _outside_one_view(S) if sep < 0.5 else false
	if _ov_kind != "":
		# A cut-in draws the same camera in both panes and a divider through its centre; the layout waits for it to end.
		_below_t = 0.0
		_above_t = 0.0
		_apply_solo_follow(S)
		return
	if not split_wanted:
		_below_t = _below_t + DT if r_now < rs else 0.0
		var out_of_frame: bool = _view_lost
		# The hybrid launch rule: when the human knocked the opponent out of the shared view, stay with the human instead
		# of splitting; the impact cut follows (camera-v2.md section 3).
		if _launch_victim >= 0 and (out_of_frame or r_now <= maxf(CamParams.R_FLOOR, CamParams.MIN_PX / vh)) and S.fighters[_launch_victim].state == "launched":
			_begin_solo("hold", 1 - _launch_victim, 2, 0.0, S)
			return
		# A fighter already lost off the edge of the one view does not wait out the dwell or the full merged age.
		var age_ok: bool = _layout_age >= CamParams.MIN_MERGED_AGE or (out_of_frame and _layout_age >= CamParams.MIN_OUT_OF_FRAME_AGE)
		# A fighter knocked out of the shared view that is still flying apart (two humans: each on his own pane): no
		# waiting for the layout's age. Right after a slam closed the split the age was 0, so the split opened 0.25 s after
		# he left, with him 9,000 units away and out of his pane for the opening (the jolt scan's remaining failures).
		var knocked_apart: bool = chase_slot >= 0 and (out_of_frame or _sep_rate > CamParams.KNOCK_APART_RATE)
		if knocked_apart:
			age_ok = true
		# While they are still moving apart the shared zoom-out holds a little longer (a wide "flying around the world" beat).
		# It runs only between the split line and the floor: below the floor the shared view cannot zoom out any more.
		var floor_r: float = maxf(CamParams.R_FLOOR, CamParams.MIN_PX / vh)
		var dwell: float = CamParams.SPLIT_DWELL + (CamParams.WIDE_HOLD if _sep_rate > 500.0 and r_now > floor_r else 0.0)
		if r_now <= floor_r:
			dwell = 0.0
		if (_below_t >= dwell or out_of_frame or knocked_apart) and age_ok and (guard_ok or out_of_frame or knocked_apart):
			_set_split(true, "out of frame" if (_below_t < dwell or _layout_age < CamParams.MIN_MERGED_AGE) else "trigger")
	else:
		_above_t = _above_t + DT if (r_now > rm and chase_slot < 0) else 0.0   # not while one is being chased
		if _above_t >= CamParams.MERGE_DWELL and _layout_age >= CamParams.MIN_SPLIT_AGE:
			_set_split(false)
	_apply_solo_follow(S)


## Solo against the AI with the split off: the human's pane takes the screen instead of two panes.
func _solo_follow(S: SimState) -> bool:
	return not solo_split and _human_slot(S) >= 0


func _apply_solo_follow(S: SimState) -> void:
	if not _solo_follow(S) or solo_kind != "" or _slam_slot >= 0:
		return
	if split_wanted:
		e_slot = _human_slot(S)
		sliver = 0.0
		e_target = 1.0
		e_hold = false


## Whether the one-view camera, as it is now, has lost a fighter off its edge: the split opens without waiting.
func _outside_one_view(S: SimState) -> bool:
	for i in range(2):
		var f = S.fighters[i]
		var px: float = absf(SimWrap.sdx(_mx, f.x)) * _mz
		var py: float = vh * CamParams.PLANE_Y - (f.y + CamParams.CHEST - _my) * _mz
		if px > CamParams.FRAME_MARGIN * vw or py < 0.04 * vh or py > 0.96 * vh:
			return true
	return false


func _human_slot(S: SimState) -> int:
	var h: int = -1
	for i in range(2):
		if S.fighters[i].ai == null:
			if h >= 0:
				return -1
			h = i
	return h


func _set_split(want: bool, why: String = "trigger") -> void:
	if want == split_wanted:
		return
	split_wanted = want
	if not want and e_target > 0.5 and solo_kind == "":
		e_hold = true   # a pane that has the screen keeps it until the panes are one
	_layout_age = 0.0
	_below_t = 0.0
	_above_t = 0.0
	_mode_changes.append(time)
	_mode_reasons.append(("split " if want else "merge ") + why)


## The slam: a rush toward the other fighter, seen while split, starts a lean, then a 0.14 s door-shut timed to the
## contact. Returns true while a slam owns the layout.
func _slam_step(S: SimState) -> bool:
	if not split_wanted or sep < 0.5 or _solo_follow(S):
		return false
	# Not while a pane still holds the screen (e above 0.05, the ease back from a shot): the door sets e from its own clock,
	# so starting it then moved the divider 0.4 of the width in a tick (found by the jolt scan).
	if e > 0.05 and _slam_slot < 0:
		return false
	# Nor when one view cannot hold the pair (their size on the screen below the floor: a pair 2,600 units apart in depth
	# at 49 degrees): the door would shut on a view with one of them off the bottom of the screen for the dwell.
	if r_now < maxf(CamParams.R_FLOOR, CamParams.MIN_PX / vh) and _slam_slot < 0:
		return false
	for k in range(2):
		var f = S.fighters[k]
		if f.rush != null and f.rush.tgt != null:
			var rem: float = f.rush.end - S.T
			if rem <= CamParams.SLAM_WINDOW and rem >= -DT:
				_slam_slot = k
				_slam_sep0 = sep
				_slam_last_rem = rem
				return true
	return false


func _slam_run(S: SimState) -> void:
	var f = S.fighters[_slam_slot]
	var window: float = CamParams.SLAM_WINDOW
	var slam_time: float = CamParams.SLAM_TIME_REDUCED if reduced_motion else CamParams.SLAM_TIME   # reduced motion: a near-cut
	var rem: float = _slam_last_rem
	var alive: bool = f.rush != null and f.rush.tgt != null
	if alive:
		rem = f.rush.end - S.T
		_slam_last_rem = rem
	elif _slam_last_rem > 2.0 * DT + 0.0001:
		# Feint or cancel: back to two panes.
		_slam_slot = -1
		e_target = 0.0
		return
	else:
		rem = 0.0   # the rush ended on contact this tick
	if rem > slam_time:
		var pr: float = clampf(1.0 - (rem - slam_time) / maxf(window - slam_time, 0.001), 0.0, 1.0)
		sep = move_toward(sep, 1.0 - CamParams.SLAM_LEAN * pr, DT / 0.3)
		_slam_sep0 = sep
		return
	var p: float = clampf(1.0 - rem / slam_time, 0.0, 1.0)
	e_slot = _slam_slot
	sliver = 0.0
	e = p * p * p
	e_target = 1.0
	sep = lerpf(_slam_sep0, 0.0, smoothstep(0.0, 1.0, p))
	if p >= 1.0 or rem <= 0.0:
		_slam_slot = -1
		sep = 0.0
		e = 0.0
		e_target = 0.0
		e_slot = -1
		split_wanted = false
		_layout_age = 0.0
		_mode_changes.append(time)
		_mode_reasons.append("merge slam")
		_flash = CamParams.SLAM_FLASH
		_slam_done = true


# ---------------------------------------------------------------------------------------------------- orientation

func _phi_target(A, B) -> float:
	var dy: float = B.y - A.y
	return clampf(atan(CamParams.TILT_K * dy / maxf(absf(u), CamParams.TILT_FLOOR)), -CamParams.PHI_MAX, CamParams.PHI_MAX)


## Angle of the divider normal (screen, y down) for a layout: sigma +1 puts slot 1 on the right, and the tilt phi is
## positive when slot 1 is higher. The normal stays in the upper half plane when slot 1 is higher, so the panes swing
## through the vertical on the higher fighter's side.
static func _theta_of(sigma: int, ph: float) -> float:
	if ph >= 0.0:
		return -ph if sigma > 0 else -PI + ph
	return -ph if sigma > 0 else PI + ph


## Whether the pair has passed each other since the layout was set: the held separation says the sides are the other way
## round. The flip waits (for the dwell, for the pair to stop being merge-close, and for the panes to be one view or full
## apart), so a split that opens meanwhile opens with the fighters on the old sides and swings when it can.
func orientation_pending() -> bool:
	return (sigma_u > 0 and u < -CamParams.HYST_M0) or (sigma_u < 0 and u > CamParams.HYST_M0)


func _update_orientation(S: SimState) -> void:
	var A = S.fighters[0]
	var B = S.fighters[1]
	var d: float = SimWrap.sdx(A.x, B.x)
	var delta: float = d - _prev_d
	if delta > SimConst.HALF:
		delta -= SimConst.W
	elif delta < -SimConst.HALF:
		delta += SimConst.W
	_prev_d = d
	u += delta
	var m: float = CamParams.HYST_M * SimConst.W
	if u > SimConst.HALF + m:
		u -= SimConst.W
	elif u < -(SimConst.HALF + m):
		u += SimConst.W
	if swing_t >= 0.0:
		swing_t += DT / _swing_dur
		if swing_t >= 1.0:
			swing_t = -1.0
			sigma_shown = sigma_u
			theta = _theta_of(sigma_shown, phi)
		else:
			var s: float = swing_t * swing_t * swing_t * (swing_t * (swing_t * 6.0 - 15.0) + 10.0)
			theta = lerpf(_swing_th0, _swing_th1, s)
		return
	# The tilt follows the height difference, smoothed, rate limited and with a dead band.
	var target: float = _phi_target(A, B)
	var diff: float = target - phi
	if absf(diff) > CamParams.TILT_DEAD * 0.5:
		var step_: float = diff * (1.0 - exp(-DT / CamParams.TILT_TAU))
		var cap: float = CamParams.TILT_RATE_MAX * DT
		phi += clampf(step_, -cap, cap)
	# The layout flips when the held separation asks for it, at most once a second, never while opening or closing.
	var cand: int = 0
	if sigma_u > 0 and u < -CamParams.HYST_M0:
		cand = -1
	elif sigma_u < 0 and u > CamParams.HYST_M0:
		cand = 1
	# A pair that is close enough to merge again does not swing: the flip waits and is unseen once they are one view.
	var merging: bool = split_wanted and r_now > _r_merge() and swing_t < 0.0
	if cand != 0 and _flip_age >= CamParams.FLIP_DWELL and not merging:
		var hidden: bool = (e >= CamParams.INSTANT_SWAP_E and sliver <= 0.0) or solo_w >= CamParams.INSTANT_SWAP_E
		var full: bool = sep >= 0.999 and _slam_slot < 0
		if sep <= 0.02 or hidden:
			sigma_u = cand
			sigma_shown = cand
			_flip_age = 0.0
			theta = _theta_of(sigma_shown, phi)
			_cut_now = true   # the divider is all but invisible here: the frame is not interpolated into the new sides
		elif full:
			sigma_u = cand
			_flip_age = 0.0
			_swing_th0 = _theta_of(sigma_shown, phi)
			_swing_th1 = _theta_of(cand, phi)
			_swing_dur = CamParams.T_SWING_REDUCED if reduced_motion else CamParams.T_SWING
			swing_t = 0.0
		else:
			theta = _theta_of(sigma_shown, phi)
			return
	theta = _theta_of(sigma_shown, phi)


# ---------------------------------------------------------------------------------------------------- shots

func _read_events(S: SimState, events: Array) -> void:
	for ev in events:
		match String(_ef(ev, "type", "")):
			"last_stand_ready":
				# The first brink of a fighter's match: his one free signature is open. Live, so nothing pauses: in one view a
				# 0.7 s cut-in on him (a close-up, then back), in a split a push on his pane; the face cut-in and the line are
				# UI's and Narrative's. Not in reduced motion (the HUD and the face carry it), not over a sim-owned shot.
				var lsa: int = int(_ef(ev, "actor", -1))
				if lsa >= 0 and lsa < 2 and not reduced_motion and not intro_active and solo_kind == "":
					last_stand_shots += 1
					if sep < 0.5 and not fold_active:
						_start_overlay("last_stand", lsa, Vector3.ZERO, CamParams.R_FIGHT, CamParams.R_FINISH, CamParams.LAST_STAND_DUR, false)
					else:
						_push[lsa] = 0.0
			"intro_start":
				intro_active = true
				_in_t = 0
				_in_phase = ""
				_in_stare_t = -1
				_in_clock_t = -1.0
				_pn = {}
			"entrance_fall":
				_intro_fall(S, int(_ef(ev, "actor", -1)), float(_ef(ev, "y", 0.0)), float(_ef(ev, "y1", 0.0)))
			"entrance_land":
				_intro_land(S, int(_ef(ev, "actor", -1)), float(_ef(ev, "r", 0.0)))
			"staredown_start":
				_intro_stare(S, int(float(_ef(ev, "dur", 2.5)) * 60.0 + 0.5))
			"clock_start":
				_intro_clock(S, String(_ef(ev, "kind", "full")))
			"beam_outcome":
				_panel_request(S, "signature", int(_ef(ev, "actor", -1)))   # the signature's fire beat (the dynamic profile, the live one)
			"ko":
				_panel_request(S, "ko", int(_ef(ev, "winner", -1)))
			"decisive":
				var dk: String = String(_ef(ev, "kind", ""))
				if dk == "clash" or dk == "beam_clash":
					_panel_request(S, "clash", int(_ef(ev, "winner", -1)))
			"parry":
				var pa: int = int(_ef(ev, "actor", -1))
				if pa >= 0 and pa < 2:
					_parry_t[pa] = time
			"rally_end":
				_panel_request(S, "rally", int(_ef(ev, "ender", -1)))   # the ping-pong's ender (event shape assumed; not in the sim yet)
			"tier_up":
				if not reduced_motion:
					var a: int = int(_ef(ev, "actor", -1))
					if a >= 0 and a < 2 and not (solo_kind == "transform" and solo_slot == a):
						_push[a] = 0.0
			"bounce", "land":
				# World's ground contact (docs/world/ground-contact.md section 4). The first contact of a journey is the
				# impact the human-attacker hold waits for; every bounce gets a small impact push on the pane that has him.
				var ca: int = int(_ef(ev, "actor", -1))
				if ca >= 0 and ca < 2:
					_impact_evt[ca] = true
					if String(_ef(ev, "type", "")) == "bounce" and not reduced_motion and (_hit_t[ca] < 0.0 or _hit_amp[ca] < CamParams.BOUNCE_PUSH):
						_hit_t[ca] = 0.0
						_hit_amp[ca] = CamParams.BOUNCE_PUSH
						_hit_hold[ca] = CamParams.BOUNCE_HOLD
						_bounce_t[ca] = time
						bounce_pushes += 1
			"journey_end":
				var ja: int = int(_ef(ev, "actor", -1))
				if ja >= 0 and ja < 2:
					_journey_end_evt[ja] = true
			"launch":
				var lb: int = int(_ef(ev, "target", -1))
				if lb >= 0 and lb < 2 and time - float(_parry_t[lb]) <= CamParams.PANEL_RIPOSTE_WINDOW:
					_panel_request(S, "riposte", lb)   # his parry, then his launch: a riposte
				# Encounter's S2 event (actor = the launched fighter): the follow starts on it. The state poll below stays
				# as the fallback for callers that pass no events.
				var la: int = int(_ef(ev, "actor", -1))
				if la >= 0 and la < 2:
					_launch_evt[la] = true
			"launch_depth", "chain_link":
				# B2: the launched fighter (victim) is aimed at a building at (x1, y1): the focus leads toward it.
				var v: int = int(_ef(ev, "victim", -1))
				if v >= 0 and v < 2:
					_aim[v] = Vector2(float(_ef(ev, "x1", 0.0)), float(_ef(ev, "y1", 0.0)))
			"building_hit":
				# B2: an impact push, inside the sim's hold (0.35 s on the first hit, 0.12 s on each further one).
				var hv: int = int(_ef(ev, "victim", -1))
				if hv >= 0 and hv < 2:
					_impact_evt[hv] = true
					# The building-smash cut: the first hit on a building of some size cuts to a wide, low view of the wall.
					if int(_ef(ev, "link", 1)) <= 1 and float(_ef(ev, "h", 0.0)) >= 300.0:
						var bh: float = float(_ef(ev, "h", 0.0))
						var r_fit: float = clampf(0.7 * CamParams.BODY_H / minf(bh, 2500.0), CamParams.R_FLOOR, CamParams.R_FIGHT)
						_start_overlay("smash", -1, Vector3(float(_ef(ev, "x", 0.0)), float(_ef(ev, "y", 0.0)), float(_ef(ev, "z", 0.0))), r_fit, r_fit * 1.08, CamParams.OV_SMASH_DUR)
				if hv >= 0 and hv < 2 and not reduced_motion:
					var link: int = int(_ef(ev, "link", 1))
					_hit_t[hv] = 0.0
					_hit_amp[hv] = CamParams.HIT_PUSH if link <= 1 else CamParams.HIT_PUSH_LATER
					_hit_hold[hv] = CamParams.HIT_HOLD_FIRST if link <= 1 else CamParams.HIT_HOLD_LATER
					_aim[hv] = null
			"transform":
				# A transformation (I2b): the shot is a close-up on the face, the body, then a wide reveal over the sim's hold.
				var ta: int = int(_ef(ev, "actor", -1))
				var tdur: float = float(_ef(ev, "dur", 0.0))
				var tver: String = String(_ef(ev, "version", ""))
				if tver == "":
					tver = "full" if tdur >= 2.5 else ("short" if tdur >= CamParams.LIVE_STEP_MAX else "live")
				# SimPause (q10 plan) and Game Design's staging (moveset-rules.md 10.8): beats in ticks, full 60 / 30 / 90,
				# short 24 / 18 / 48, live 10 / 14 / 24. Full: a push in on the gather, one hard cut to a low wide angle on
				# the break, a hold on the pose and a pull back to frame both on the settle. Short: half the push, a snap
				# zoom out on the break (no cut), a straight pull back. Live: no shot; a 6-tick punch-in at the break.
				if tver == "live":
					if not reduced_motion:
						_punch_amp = CamParams.LIVE_PUNCH
						_punch_len = CamParams.LIVE_PUNCH_LEN
						_live_punch_at = time + float(CamParams.LIVE_PUNCH_AT) * DT
				elif ta >= 0 and ta < 2 and not fold_active:
					_push[ta] = -1.0   # the tier-up push is part of this shot
					# A shot already running on the other fighter (a launch chase) hands over with a cut: no ease between the two.
					_begin_solo("transform", ta, 3, CamParams.CINE_SLIVER, S, solo_kind != "" and solo_slot != ta)
					if solo_kind == "transform" and solo_slot == ta:
						_solo_dur = tdur
						_tf_ver = tver
						_tf_phase = "gather"
						_tf_g = 60 if tver == "full" else 24
						_tf_b = 30 if tver == "full" else 18
						_tf_s = 90 if tver == "full" else 48
			"pause_start":
				# A pausing set piece the sim runs (SimPause): the world change, the planet giving way, the time cap. The
				# transformation's shot comes from its own `transform` event. These get a slow pull-out of the shared view.
				var pk: String = String(_ef(ev, "kind", ""))
				if pk != "transform" and not reduced_motion:
					_wide_t = 0.0
					_wide_dur = maxf(float(_ef(ev, "dur", 0.0)), 0.5)
			"pause_end":
				if _wide_t >= 0.0 and _wide_t < _wide_dur:
					_wide_dur = _wide_t
			"finisher_start":
				# A finisher: the fighters are in contact and locked by the sim for `dur`; cut to the loser and dolly in.
				var ft: int = int(_ef(ev, "target", -1))
				_panel_request(S, "finisher", int(_ef(ev, "actor", -1)))
				if ft >= 0 and ft < 2 and not fold_active:
					_begin_solo("finisher", ft, 4, 0.0, S, true)
					if solo_kind == "finisher" and solo_slot == ft:
						_solo_dur = float(_ef(ev, "dur", 0.0))
			"region_broken":
				# A crippling moment: a quick cut to a close-up on the fighter who was broken.
				var ra: int = int(_ef(ev, "actor", -1))
				if ra >= 0 and ra < 2:
					_start_overlay("cripple", ra, Vector3.ZERO, CamParams.R_FIGHT, CamParams.R_FINISH, CamParams.OV_CRIPPLE_DUR)
					_panel_request(S, "crippling", ra)
			"cinematic_start":
				var kd: String = String(_ef(ev, "kind", ""))
				if kd == "transformation" or kd == "revision":
					_begin_solo("transform", int(_ef(ev, "actor", -1)), 3, CamParams.CINE_SLIVER)
					_solo_dur = float(_ef(ev, "dur", 0.0))
			"cinematic_end":
				if solo_kind == "transform":
					_end_solo(S)
			"fold_start":
				fold_active = true
				_fold = Vector3(float(_ef(ev, "x", 0.0)), float(_ef(ev, "y", 0.0)), float(_ef(ev, "r", 1.0)))
				_begin_solo_clear()
			"unfold":
				fold_active = false


## An event field from an FxEvent or a Dictionary.
static func _ef(ev, k: String, d):
	if ev is Dictionary:
		return ev.get(k, d)
	var v = ev.get(k)
	return d if v == null else v


## Each pane's shake from the tick's shake events {k, x} (Controls' shake pass, docs/controls/shake-pass.md): an event
## reaches a pane scaled by clamp(1 - d / 4000, 0.35, 1), d being the wrapped distance from the pane's view centre; with
## two panes the one farther from the event gets 35% of that. The amount decays as the fx consumer's does, 0.02 per
## second, and holds through a hit-stop freeze (the tick event's `frozen`).
func _update_shake(events: Array) -> void:
	var dt: float = DT
	var frozen: bool = false
	for ev in events:
		match String(_ef(ev, "type", "")):
			"shake":
				var k: float = float(_ef(ev, "k", 0.0))
				var x: float = float(_ef(ev, "x", _cur.cam_x[0]))
				var f: Array = [0.0, 0.0]
				for i in range(2):
					f[i] = clampf(1.0 - absf(SimWrap.sdx(_cur.cam_x[i], x)) / CamParams.SHAKE_FALLOFF, CamParams.SHAKE_FAR, 1.0)
				if sep > 0.5:
					var near: int = 0 if absf(SimWrap.sdx(_cur.cam_x[0], x)) <= absf(SimWrap.sdx(_cur.cam_x[1], x)) else 1
					f[1 - near] *= CamParams.SHAKE_FAR
				for i in range(2):
					_shk[i] = maxf(_shk[i], k * f[i])
			"tick":
				dt = float(_ef(ev, "dt", DT))
				frozen = bool(_ef(ev, "frozen", false))
	if not frozen:
		var d: float = pow(CamParams.SHAKE_DECAY, dt)
		_shk[0] *= d
		_shk[1] *= d


func _begin_solo_clear() -> void:
	solo_kind = ""
	solo_slot = -1
	solo_prio = 0
	solo_target = 0.0
	e_target = 0.0
	e_hold = false
	_slam_slot = -1


func _begin_solo(kind: String, slot: int, prio: int, sl: float, S: SimState = null, cut_in: bool = false) -> void:
	if slot < 0 or slot > 1 or fold_active:
		return
	if solo_kind != "" and prio < solo_prio:
		return
	# A shot that takes the screen from another fighter's pane while that pane still holds it (a launch chase ending
	# has e_hold keeping its pane up for the ease back; a transformation then begins on the other fighter) hands over
	# with a cut: easing from one fighter's pane to the other's moved the divider 0.4 of the width in a tick.
	if not cut_in and S != null and e > 0.02 and e_slot >= 0 and e_slot != slot:
		cut_in = true
		if reduced_motion:
			_cut_fade = CamParams.REDUCED_CUT_FADE   # a cut is a dissolve in reduced motion
	solo_kind = kind
	solo_slot = slot
	solo_prio = prio
	solo_t = 0.0
	_tf_phase = ""
	_tf_ver = ""
	_shot_pitch = 0.0
	solo_phase = "follow"
	_solo_dur = 0.0
	solo_target = 1.0
	e_target = 1.0
	e_slot = slot
	sliver = sl
	e_hold = false
	_slam_slot = -1
	_launch_anchor_x = 0.5
	_launch_anchor_y = 0.62
	# A launch out of the one view takes the screen at once, from where the fighter is in that view: the same zoom, the
	# same screen position, then it eases to the chase size and the trailing anchor. No ramp in which he can be lost.
	if cut_in and S != null:
		# A cut to the shot: the pane takes the screen at once, on the fighter, at the shot's first size.
		solo_w = 1.0
		e = 1.0
		_snap_focus(S, slot)
		_zo[slot] = _own_zoom_target(S, slot)
		_cut_now = true
	elif (kind == "launch" or kind == "hold") and S != null and sep < 0.5:
		var lf = S.fighters[slot]
		solo_w = 1.0
		var pi: int = slot if (_cur != null and _cur.shows(slot)) else 0
		if _cur != null and _cur.shows(pi):
			# From what is on the screen: the zoom of the pane that draws him and where he is in it (at any separation, pitch
			# and depth; the flat merged formula put him 0.2 of the width off at 49 degrees).
			_zo[slot] = _cur.cam_z[pi]
			var sp: Vector2 = _cur.screen_pos(pi, lf.x, lf.y + CamParams.CHEST, float(lf.z))
			_launch_anchor_x = clampf(sp.x / vw, 0.2, 0.8)
			_launch_anchor_y = clampf(sp.y / vh, 0.2, 0.85)
		else:
			_zo[slot] = _mz
			_launch_anchor_x = clampf(0.5 + SimWrap.sdx(_mx, lf.x) * _mz / vw, 0.2, 0.8)
			_launch_anchor_y = clampf(CamParams.PLANE_Y - (lf.y + CamParams.CHEST - _my) * _mz / vh, 0.2, 0.85)


## The shot's end: the layout the fighters need now, chosen at once (no dwell).
func _end_solo(S: SimState) -> void:
	var rm: float = _r_merge()
	if solo_kind == "":
		return
	var solo_kind_ended: String = solo_kind
	solo_kind = ""
	_tf_phase = ""
	_tf_ver = ""
	_shot_pitch = 0.0
	solo_prio = 0
	solo_phase = ""
	solo_target = 0.0
	if r_now >= rm:
		_set_split(false, "%s ended" % solo_kind_ended)
		e_hold = true
		e_target = 1.0
	else:
		if solo_w >= 0.99 and sep < 0.5:
			sep = 1.0
			e = maxf(e, 1.0)
		_set_split(true, "%s ended" % solo_kind_ended)
		e_hold = false
		e_target = 0.0
	_below_t = 0.0
	_above_t = 0.0
	_layout_age = 0.0
	_solo_decisions.append(time)


func _update_solo(S: SimState) -> void:
	# Polling the sim for launches until Encounter's launch event exists (S2).
	for i in range(2):
		var f = S.fighters[i]
		if f.state == "launched" and (_prev_state[i] != "launched" or _launch_evt[i]):
			var sp: float = sqrt(f.vx * f.vx + f.vy * f.vy)
			if sp >= CamParams.LAUNCH_MIN_SPEED and not fold_active:
				var lmode: String = _launch_mode(S, i)
				if lmode == "hold":
					_launch_victim = i
				elif lmode == "split":
					chase_slot = i
					_chase_land_t = 0.0
				elif solo_kind == "launch" and solo_slot == i:
					solo_phase = "follow"
					solo_t = 0.0
				elif solo_kind == "":
					_begin_solo("launch", i, 2, 0.0, S)
	_launch_evt = [false, false]
	if _launch_victim >= 0 and S.fighters[_launch_victim].state != "launched" and solo_kind != "hold" and solo_kind != "cut":
		_launch_victim = -1
	if chase_slot >= 0:
		if S.fighters[chase_slot].state != "launched":
			_chase_land_t += DT
			if _chase_land_t > CamParams.LAND_HOLD:
				chase_slot = -1
		else:
			_chase_land_t = 0.0
	for ai in range(2):
		if _aim[ai] != null and S.fighters[ai].state != "launched":
			_aim[ai] = null
	if S.game.ko != null and solo_kind != "ko" and solo_kind != "wreck" and not fold_active:
		var loser: int = 0 if S.fighters[0] == S.game.ko else 1
		_begin_solo("ko", loser, 4, 0.0)
	if solo_kind == "ko" and S.game.ko != null and S.game.koT >= CamParams.WRECK_AT:
		# After the loser's close-up: the winner, small, with the match's damage round him.
		var winner: int = 1 if S.fighters[0] == S.game.ko else 0
		_wreck_scan(S, winner)
		_begin_solo("wreck", winner, 4, 0.0, S, not reduced_motion)
	if (solo_kind == "ko" or solo_kind == "wreck") and S.game.ko == null:
		_end_solo(S)
	if solo_kind == "":
		return
	solo_t += DT
	var f = S.fighters[solo_slot]
	match solo_kind:
		"launch":
			if solo_phase == "follow":
				if f.state != "launched" or _journey_end_evt[solo_slot]:
					solo_phase = "land"
					_land_t = 0.0
					if reduced_motion:
						_snap_focus(S, solo_slot)
				elif solo_t >= CamParams.MAX_FOLLOW:
					_end_solo(S)
			elif solo_phase == "land":
				_land_t += DT
				if f.state == "launched":
					solo_phase = "follow"
					solo_t = 0.0
				elif _land_t >= CamParams.LAND_HOLD and f.slide <= 0.0:
					_end_solo(S)
		"hold":
			# On the attacker until the impact (a building hit, or the landing, or the cap), then the cut to the victim.
			var v: int = _launch_victim
			if v < 0 or _impact_evt[v] or S.fighters[v].state != "launched" or solo_t >= CamParams.HOLD_MAX:
				if v >= 0:
					_start_cut(S, v)
				else:
					_end_solo(S)
		"cut":
			if solo_t >= CamParams.CUT_SHOT:
				_launch_victim = -1
				_end_solo(S)
		"transform":
			_transform_beats(S)
			if solo_kind == "transform" and _solo_dur > 0.0 and solo_t >= _solo_dur + 0.05:
				_end_solo(S)
		"finisher":
			if _solo_dur > 0.0 and solo_t >= _solo_dur + 0.05:
				_end_solo(S)
		"ko", "wreck":
			pass


## A panel cut-in (Orb's pick B): a slanted close-up strip over the live view, drawn by the compositor from an inset
## pane. The main view is untouched: no cut, nothing pauses. The peaks (a signature's fire beat, a finisher, a crippling
## blow, the KO) always play; the hits the player earned (a clash won, a riposte that launches, a ping-pong's ender) share
## one panel per PANEL_EARNED_GAP seconds. A stronger panel replaces a running weaker one; an equal or weaker one is
## dropped. `slot` is whose close-up it is: the attacker for a signature, a finisher and an earned hit, the broken
## fighter for a crippling blow, the winner for the KO (the main view is on the loser then).
func _panel_request(S: SimState, kind: String, slot: int) -> void:
	if panel_mode == "off" or slot < 0 or slot > 1 or fold_active or solo_kind == "transform" or intro_active:
		return
	var k: Dictionary = CamParams.PANEL_KINDS[kind]
	if kind == "signature":
		# The event and the new beam are the same fire beat: one request from either.
		if time - float(_sig_t[slot]) < 0.5:
			return
		_sig_t[slot] = time
	if bool(k["earned"]) and time - _pn_earned_t < CamParams.PANEL_EARNED_GAP:
		panels_dropped += 1
		return
	if not _pn.is_empty() and int(k["prio"]) <= int(_pn["prio"]):
		panels_dropped += 1
		return
	var band: int = _panel_band(S)
	if band < 0:
		panels_dropped += 1
		return
	_pn = {"kind": kind, "slot": slot, "prio": int(k["prio"]), "dur": float(k["dur"]), "t": 0.0, "band": band}
	if bool(k["earned"]):
		_pn_earned_t = time
	panels += 1
	panel_log.append([time, kind, slot])


func _update_panel(S: SimState) -> void:
	# A signature's fire beat is a new beam in the state (the beam_outcome event only exists in the dynamic profile).
	var live: Dictionary = {}
	for b in S.beams:
		var id: int = b.get_instance_id()
		live[id] = true
		if not _beams_seen.has(id):
			_panel_request(S, "signature", S.fighters.find(b.A))
	_beams_seen = live
	if _pn.is_empty():
		return
	_pn["t"] = float(_pn["t"]) + DT
	if float(_pn["t"]) >= float(_pn["dur"]):
		_pn = {}


func _panel_rect(band: int) -> Rect2:
	var pw: float = vw * CamParams.PANEL_W
	var ph: float = vh * CamParams.PANEL_H
	var wb: float = pw + ph * CamParams.PANEL_SLANT
	var y0: float = maxf(vh * CamParams.PANEL_TOP_Y, panel_floor) if band == 0 else vh * CamParams.PANEL_BOTTOM_Y
	return Rect2((vw - wb) * 0.5, y0, wb, ph)


## The top band holds the strip only where UI's HUD leaves it the whole band (the plates, the toll chip and the pause
## button end above it); on phones and small windows they reach into it and the bottom band is the usual one.
func _top_band_fits() -> bool:
	return maxf(vh * CamParams.PANEL_TOP_Y, panel_floor) + vh * CamParams.PANEL_H <= vh * (CamParams.PANEL_TOP_Y + CamParams.PANEL_H) + 0.5


## The band the strip takes: the top one, or the bottom one when a fighter is in the top one; -1 when both are taken.
## Judged on the last frame's screen positions of both fighters (head to feet, a little wider than the body).
func _panel_band(S: SimState) -> int:
	if _cur == null:
		return 0
	for band in [0, 1]:
		if band == 0 and not _top_band_fits():
			continue
		var r: Rect2 = _panel_rect(band).grow(8.0)
		var free: bool = true
		for k in range(2):
			var f = S.fighters[k]
			var pi: int = k if _cur.shows(k) else 0
			var feet: Vector2 = _cur.screen_pos(pi, f.x, f.y, float(f.z))
			var head: Vector2 = _cur.screen_pos(pi, f.x, f.y + CamParams.BODY_H, float(f.z))
			var fh: float = absf(feet.y - head.y)
			if Rect2(feet.x - fh * 0.4, minf(head.y, feet.y), fh * 0.8, fh).intersects(r):
				free = false
		if free:
			return band
	return -1


## The panel in the frame: where the strip is and the inset's camera, in the inset viewport's own pixels. The camera
## frames the subject's upper body, with room to look into.
func _panel_frame(S: SimState) -> Dictionary:
	if _pn.is_empty():
		return {}
	var still: bool = reduced_motion or panel_mode == "still"
	var t: float = float(_pn["t"])
	var dur: float = float(_pn["dur"])
	var open: float = 1.0
	if not still:
		open = smoothstep(0.0, CamParams.PANEL_OPEN, t) * (1.0 - smoothstep(dur - CamParams.PANEL_CLOSE, dur, t))
	var slot: int = int(_pn["slot"])
	var rect: Rect2 = _panel_rect(int(_pn["band"]))
	var ph: float = rect.size.y
	var f = S.fighters[slot]
	var z: float = CamParams.PANEL_FILL * ph / CamParams.PANEL_BODY
	if not still:
		z *= 1.0 + CamParams.PANEL_PUSH * clampf(t / dur, 0.0, 1.0)
	var w: float = -float(f.z)
	if absf(w) > 1.0:
		var den: float = 1.0 / z - w / (CamParams.K_FACTOR * ph)
		if den > 1e-6:
			z = 1.0 / den
	var fx: float = 0.40 if f.face >= 0.0 else 0.60   # room in front of him
	return {
		"kind": _pn["kind"], "slot": slot, "open": open, "still": still, "band": int(_pn["band"]),
		"rect": rect, "slant": (1.0 if slot == 0 else -1.0) * ph * CamParams.PANEL_SLANT,
		"size": Vector2i(int(ceil(rect.size.x)), int(ceil(ph))),
		"cam_x": SimWrap.wrap(f.x - (fx - 0.5) * rect.size.x / z),
		"cam_y": clampf((f.y + CamParams.PANEL_FOCUS) - (ph * CamParams.PLANE_Y - ph * 0.5) / z, CamParams.CAM_Y_MIN, SimConst.CEILING - CamParams.CAM_Y_TOP),
		"cam_z": z,
	}


## Which side of the winner holds more wreckage: the craters (area times depth, a signature's double), the buildings
## lost (their face area, scaled by how much is gone) and the knockback trenches, inside the part of the screen that side
## will have, nearer counting more. Sets wreck_dir (+1 right, -1 left, 0 when little is in view) and wreck_score.
func _wreck_scan(S: SimState, w: int) -> void:
	var wf = S.fighters[w]
	var zf: float = CamParams.R_WRECK * _m() * vh / CamParams.BODY_H
	var reach: float = CamParams.WRECK_REACH * vw / maxf(zf, 0.01)
	var side: Array = [0.0, 0.0]   # [left, right]
	for c in S.craters:
		var d: float = SimWrap.sdx(wf.x, c.x)
		if absf(d) > reach + c.r:
			continue
		var wt: float = c.r * c.depth * (1.0 + c.special) * (1.0 - 0.5 * minf(1.0, absf(d) / reach))
		side[1 if d >= 0.0 else 0] += wt
	for b in S.buildings:
		if b.maxhp <= 0.0:
			continue
		var lost: float = 1.0 if not b.alive else 1.0 - clampf(b.hp / b.maxhp, 0.0, 1.0)
		if lost < 0.2:
			continue
		var d: float = SimWrap.sdx(wf.x, b.x)
		if absf(d) > reach:
			continue
		side[1 if d >= 0.0 else 0] += lost * b.w * b.h * CamParams.WRECK_BUILDING_W * (1.0 - 0.5 * absf(d) / reach)
	for sl in S.slides:
		var mid: float = SimWrap.wrap((sl.x0 + sl.x1) * 0.5)
		var d: float = SimWrap.sdx(wf.x, mid)
		if absf(d) > reach:
			continue
		side[1 if d >= 0.0 else 0] += sl.depth * absf(sl.x1 - sl.x0) * 0.5
	wreck_score = side[0] + side[1]
	wreck_dir = 0
	if wreck_score >= CamParams.WRECK_MIN and absf(side[1] - side[0]) >= 0.15 * wreck_score:
		wreck_dir = 1 if side[1] > side[0] else -1


## Who follows a launched fighter i: "chase" (a solo shot on him), "hold" (stay with the human attacker, then the impact
## cut) or "split" (a pane chases him, no solo). The hybrid of Orb's pick: one human who launched the opponent holds; one
## human who was launched chases; two humans use the split; no human (the demo) chases.
func _launch_mode(S: SimState, i: int) -> String:
	if launch_follow == "chase":
		return "chase"
	var humans: int = 0
	var h: int = -1
	for k in range(2):
		if S.fighters[k].ai == null:
			humans += 1
			h = k
	if launch_follow == "split" or humans >= 2:
		return "split"
	if humans == 1 and i != h:
		return "hold" if sep < 0.5 else "split"
	return "chase"


## The cut to the impact: a hard cut to the launched fighter v at the push-in size, for CUT_SHOT seconds.
func _start_cut(S: SimState, v: int) -> void:
	solo_kind = "cut"
	solo_slot = v
	solo_prio = 2
	solo_t = 0.0
	solo_phase = "cut"
	solo_target = 1.0
	solo_w = 1.0
	e_target = 1.0
	e = 1.0
	e_slot = v
	sliver = 0.0
	_launch_anchor_x = 0.5
	_launch_anchor_y = 0.62
	_snap_focus(S, v)
	_zo[v] = _own_zoom_target(S, v)
	_cut_now = true


## A camera-only cut-in (a building smash, a crippling moment): a hard cut to a fixed or followed view for `dur` seconds,
## then a hard cut back. It runs in one view only, never over a launch hold, a cut or a sim-owned shot, with a cooldown
## and a per-minute cap so cuts stay events (docs/camera/camera-v2.md section 4).
func _start_overlay(kind: String, slot: int, pt: Vector3, r0: float, r1: float, dur: float, rationed: bool = true) -> void:
	if _ov_kind != "" or fold_active or sep >= 0.5 or reduced_motion or intro_active:
		return
	if solo_kind != "" and solo_kind != "launch":
		return
	if rationed and not _ov_times.is_empty() and time - float(_ov_times[-1]) < CamParams.OV_COOLDOWN:
		return
	var recent: int = 0
	for t0 in _ov_times:
		if time - float(t0) < 60.0:
			recent += 1
	if rationed and recent >= CamParams.OV_MAX_PER_MIN:
		return
	_ov_kind = kind
	_ov_t = 0.0
	_ov_dur = dur
	_ov_slot = slot
	_ov_pt = pt
	_ov_r0 = r0
	_ov_r1 = r1
	if rationed:
		_ov_times.append(time)
		if _ov_times.size() > 12:
			_ov_times.pop_front()
		cut_ins += 1
	_cut_now = true


func _overlay_cam(S: SimState) -> Vector3:
	var p: float = clampf(_ov_t / maxf(_ov_dur, 0.01), 0.0, 1.0)
	var r: float = lerpf(_ov_r0, _ov_r1, smoothstep(0.0, 1.0, p)) * _m()
	var z: float = clampf(r * vh / CamParams.BODY_H / cos(deg_to_rad(_pitch_now)), CamParams.ZOOM_MIN, _zcap() * 1.5)
	var fx: float = _ov_pt.x
	var fy: float = _ov_pt.y
	var fz: float = _ov_pt.z
	if _ov_slot >= 0:
		var f = S.fighters[_ov_slot]
		fx = f.x
		fy = f.y + CamParams.CHEST
		fz = float(f.z)
	return _cam_at(fx, fy, fz, z, Vector2(vw * 0.5, vh * 0.62))


## The transformation shot's three beats. Full: the break is a hard cut to a low wide angle (the pitch drops, the fighter
## sits low in the frame against the sky), the settle cuts back to the pose and, halfway through, the shot ends and the
## camera pulls back to frame both. Short: the break is a snap zoom out, the settle a straight pull back.
func _transform_beats(S: SimState) -> void:
	if _tf_phase == "":
		return
	var ti: int = int(solo_t / DT + 0.5)
	var ph: String = "gather" if ti < _tf_g else ("break" if ti < _tf_g + _tf_b else "settle")
	if ph != _tf_phase:
		_tf_phase = ph
		if _tf_ver == "full":
			_cut_now = true
			_snap_focus(S, solo_slot)
			_zo[solo_slot] = _own_zoom_target(S, solo_slot)
			_shot_pitch = _break_pitch() if ph == "break" else 0.0
		else:
			_zo[solo_slot] = _own_zoom_target(S, solo_slot)
	if _tf_ver == "full" and ti >= _tf_g + _tf_b + _tf_s / 2:
		_end_solo(S)
	elif _tf_ver == "short" and ti >= _tf_g + _tf_b:
		_end_solo(S)


## The break's pitch: BREAK_PITCH, limited so the camera stays above the ground at the fighter's feet. The camera orbits
## the plane point at the screen's centre at distance K vh / zoom, so with the chest `off` pixels below the centre it is
## CHEST + (off + K vh sin(pitch)) / zoom units above his feet (Rendering's rule, docs/rendering/README.md). The anchor
## is fixed (0.74 vh), so a low zoom setting, which makes `zoom` small, is what pulls the angle back toward 0.
func _break_pitch() -> float:
	return _low_pitch(CamParams.BREAK_PITCH, 0.74)


## The low angle `deg` (negative), limited so the camera stays above the ground at the fighter's feet when his chest is
## at `anchor_y` of the screen height (the rule above).
func _low_pitch(deg: float, anchor_y: float) -> float:
	var z: float = maxf(_zo[solo_slot], 0.01)
	var off: float = vh * (anchor_y - 0.5)
	var lim: float = ((CamParams.BREAK_CAM_MIN_H - CamParams.CHEST) * z - off) / (CamParams.K_FACTOR * vh)
	var total_min: float = rad_to_deg(asin(clampf(lim, -1.0, 1.0)))
	return minf(0.0, maxf(deg, total_min - pitch_deg))


# ---------------------------------------------------------------------------------------------------- the opening

## The sim's intro (docs/architecture/intro-phase.md) in the camera's shots: each fighter falls from the sky (the camera
## falls with him), lands in a crater (a cut to a low, wide angle, a push and a shake), then the staredown (a two-shot
## pushing in, two face cuts before the clock) and the clock (a 3-tick punch-in, then the ordinary framing). A press that
## skips it ends the shot in a 0.08 s fade. Reduced motion: no fall and no faces, no pitch, shake or punch, and each cut
## is a 0.3 s dissolve.
func _intro_cut(S: SimState, slot: int) -> void:
	_cut_now = true
	intro_cuts += 1
	if reduced_motion:
		_cut_fade = CamParams.REDUCED_CUT_FADE
	if slot >= 0:
		_snap_focus(S, slot)
		_zo[slot] = _own_zoom_target(S, slot)


func _intro_fall(S: SimState, a: int, ground_y: float, top_y: float) -> void:
	if a < 0 or a > 1:
		return
	intro_active = true
	if reduced_motion:
		# The camera does not fall with him: it waits, level and still, on the spot he will land on, and he drops into frame.
		var f = S.fighters[a]
		_ov_kind = "intro"
		_ov_t = 0.0
		_ov_dur = 5.0
		_ov_slot = -1
		_ov_pt = Vector3(f.x, ground_y + 45.0, float(f.z))
		_ov_r0 = CamParams.INTRO_R_LAND_MIN
		_ov_r1 = CamParams.INTRO_R_LAND_MIN
		_intro_cut(S, -1)
		return
	_in_phase = "fall"
	_in_slot = a
	_in_fall_h = maxf(top_y - ground_y, 1.0)
	_begin_solo("intro", a, 5, 0.0, S, true)
	_shot_pitch = 0.0
	_intro_cut(S, a)


func _intro_land(S: SimState, a: int, crater_r: float) -> void:
	if a < 0 or a > 1:
		return
	intro_active = true
	_in_phase = "land"
	_in_slot = a
	_in_crater_r = crater_r
	if _ov_kind == "intro":
		_ov_kind = ""
	_begin_solo("intro", a, 5, 0.0, S, true)
	_shot_pitch = 0.0
	_zo[a] = _own_zoom_target(S, a)
	_shot_pitch = 0.0 if reduced_motion else _low_pitch(CamParams.INTRO_LAND_PITCH, CamParams.INTRO_LAND_ANCHOR_Y)
	_intro_cut(S, a)
	if not reduced_motion:
		_hit_t[a] = 0.0
		_hit_amp[a] = CamParams.INTRO_LAND_PUSH
		_hit_hold[a] = 0.1
		_shk[a] = maxf(_shk[a], CamParams.INTRO_SHAKE)
		_shk[1 - a] = maxf(_shk[1 - a], CamParams.INTRO_SHAKE * 0.5)


## One view at once: the shot's end normally lets the solo pane keep the screen until the panes are one (e_hold), which
## showed the staredown's two-shot with the last pane's camera for about 24 ticks, one fighter off the screen's edge.
func _force_merged(S: SimState) -> void:
	r_now = _metric(S)
	_end_solo(S)
	_shot_pitch = 0.0
	sep = 0.0
	e = 0.0
	e_target = 0.0
	e_hold = false
	e_slot = -1
	sliver = 0.0
	solo_w = 0.0
	solo_target = 0.0
	split_wanted = false
	_snap_merged(S)


func _intro_to_two_shot(S: SimState) -> void:
	_force_merged(S)
	_in_phase = "stare"
	_intro_cut(S, -1)
	_snap_cameras(S)


func _intro_stare(S: SimState, dur_ticks: int) -> void:
	intro_active = true
	_in_stare_t = 0
	_in_stare_dur = dur_ticks
	_intro_to_two_shot(S)


func _intro_clock(S: SimState, kind: String) -> void:
	if not intro_active:
		return
	intro_active = false
	var was_solo: bool = solo_kind == "intro"
	if was_solo or kind == "skip" or _in_phase != "stare":
		_force_merged(S)
		_snap_cameras(S)
		_cut_now = true
		_cut_fade = CamParams.REDUCED_CUT_FADE if reduced_motion else CamParams.CUT_FADE
	_in_phase = ""
	if kind == "skip":
		_in_stare_t = -1
		_in_clock_t = -1.0
		return
	_in_clock_t = 0.0
	if not reduced_motion:
		_punch_amp = CamParams.INTRO_BELL
		_punch_len = CamParams.INTRO_BELL_LEN
		_live_punch_at = time


## The two-shot's push, easing out after the clock.
func _intro_mult() -> float:
	if _in_stare_t < 0 or reduced_motion:
		return 1.0
	var p: float = smoothstep(0.0, 1.0, clampf(float(_in_stare_t) / maxf(float(_in_stare_dur), 1.0), 0.0, 1.0))
	var out: float = 1.0 if _in_clock_t < 0.0 else 1.0 - smoothstep(0.0, CamParams.INTRO_EASE_OUT, _in_clock_t)
	return 1.0 + CamParams.INTRO_STARE_PUSH * p * out


func _update_intro(S: SimState) -> void:
	if intro_active:
		_in_t += 1
	if _in_clock_t >= 0.0:
		_in_clock_t += DT
		if _in_clock_t > CamParams.INTRO_EASE_OUT:
			_in_clock_t = -1.0
			_in_stare_t = -1
	if not intro_active or _in_stare_t < 0:
		return
	_in_stare_t += 1
	if not CamParams.INTRO_FACES or reduced_motion:
		return
	var left: int = _in_stare_dur - _in_stare_t
	if _in_phase == "stare" and left == CamParams.INTRO_FACE_LEAD:
		_in_phase = "face"
		_in_slot = 0
		_begin_solo("intro", 0, 5, 0.0, S, true)
		_shot_pitch = 0.0
		_intro_cut(S, 0)
	elif _in_phase == "face" and _in_slot == 0 and left == CamParams.INTRO_FACE_LEAD - CamParams.INTRO_FACE_TICKS:
		_in_slot = 1
		_begin_solo("intro", 1, 5, 0.0, S, true)
		_intro_cut(S, 1)
	elif _in_phase == "face" and _in_slot == 1 and left == CamParams.INTRO_FACE_LEAD - 2 * CamParams.INTRO_FACE_TICKS:
		_intro_to_two_shot(S)


func _punch_mult() -> float:
	if _punch_t < 0.0:
		return 1.0
	return 1.0 + _punch_amp * (1.0 - absf(2.0 * _punch_t / _punch_len - 1.0))


func _wide_mult() -> float:
	if _wide_t < 0.0:
		return 1.0
	var a: float = smoothstep(0.0, CamParams.WIDE_IN, _wide_t)
	var b: float = smoothstep(_wide_dur, _wide_dur + CamParams.WIDE_IN, _wide_t)
	return lerpf(1.0, CamParams.WIDE_PULL, a - b)


func _update_pushes() -> void:
	if _live_punch_at >= 0.0 and time >= _live_punch_at:
		_live_punch_at = -1.0
		_punch_t = 0.0
	if _punch_t >= 0.0:
		_punch_t += DT
		if _punch_t > _punch_len:
			_punch_t = -1.0
	if _wide_t >= 0.0:
		_wide_t += DT
		if _wide_t > _wide_dur + CamParams.WIDE_IN:
			_wide_t = -1.0
	if _ov_kind != "":
		_ov_t += DT
		if _ov_t >= _ov_dur:
			_ov_kind = ""
			_cut_now = true
	for i in range(2):
		if _hit_t[i] >= 0.0:
			_hit_t[i] += DT
			if _hit_t[i] > maxf(CamParams.HIT_UP, _hit_hold[i]) + CamParams.HIT_DOWN:
				_hit_t[i] = -1.0
		if _push[i] >= 0.0:
			_push[i] += DT
			if _push[i] > CamParams.TIER_PUSH_IN + CamParams.TIER_PUSH_HOLD + CamParams.TIER_PUSH_OUT:
				_push[i] = -1.0


func _hit_mult(i: int) -> float:
	var t: float = _hit_t[i]
	if t < 0.0:
		return 1.0
	var end: float = maxf(CamParams.HIT_UP, _hit_hold[i])
	return 1.0 + _hit_amp[i] * (smoothstep(0.0, CamParams.HIT_UP, t) - smoothstep(end, end + CamParams.HIT_DOWN, t))


func _push_mult(i: int) -> float:
	var t: float = _push[i]
	if t < 0.0:
		return 1.0
	var a: float = smoothstep(0.0, CamParams.TIER_PUSH_IN, t)
	var b: float = smoothstep(CamParams.TIER_PUSH_IN + CamParams.TIER_PUSH_HOLD, CamParams.TIER_PUSH_IN + CamParams.TIER_PUSH_HOLD + CamParams.TIER_PUSH_OUT, t)
	return 1.0 + CamParams.TIER_PUSH * (a - b)


# ---------------------------------------------------------------------------------------------------- layout

func _update_layout() -> void:
	var slam_active: bool = _slam_slot >= 0
	if slam_active:
		pass   # _slam_run drives sep and e; it needs S, so it is called from _update_cameras' caller below
	else:
		var target: float = 1.0 if split_wanted else 0.0
		if fold_active:
			target = 0.0
		# A split that opens because a fighter has left the shared view, or because one was knocked away, opens fast: at
		# the normal rate the fighter was off the screen for most of it (0.3 s at 10,000 units a second is 3,000 units).
		var t_open: float = CamParams.T_OPEN_URGENT if (_view_lost or chase_slot >= 0) else CamParams.T_OPEN
		var rate: float = 1.0 / (t_open if target > sep else CamParams.T_CLOSE)
		if reduced_motion:
			rate *= 1.5
		sep = move_toward(sep, target, rate * DT)
		# e follows its target unless a slam owns it.
		var er: float = 1.0 / (CamParams.T_ENGAGE if e_target > e else CamParams.T_REVEAL)
		e = move_toward(e, e_target, er * DT)
		if e_hold and sep <= 0.001:
			e = 0.0
			e_target = 0.0
			e_hold = false
		if e <= 0.0 and e_target <= 0.0 and solo_kind == "":
			e_slot = -1
	var sr: float = 1.0 / (CamParams.T_ENGAGE if solo_target > solo_w else CamParams.T_SETTLE)
	solo_w = move_toward(solo_w, solo_target, sr * DT)
	if solo_w <= 0.0 and solo_target <= 0.0 and solo_kind == "":
		solo_slot = -1 if e <= 0.0 else solo_slot


# ---------------------------------------------------------------------------------------------------- cameras

func _snap_focus(S: SimState, i: int) -> void:
	var f = S.fighters[i]
	_fx[i] = f.x
	_fy[i] = f.y + CamParams.CHEST
	_ppx[i] = f.x
	_ppy[i] = f.y


func _snap_cameras(S: SimState) -> void:
	_oz_valid = false
	for i in range(2):
		_snap_focus(S, i)
		_zo[i] = _own_zoom_target(S, i)
	_snap_merged(S)
	_outputs(S)


func _merged_target(S: SimState) -> Vector3:
	if fold_active:
		var fit: float = minf(vw, vh) / (CamParams.FOLD_FIT * maxf(_fold.z, 1.0))
		return Vector3(_fold.x, _fold.y, clampf(fit, CamParams.ZOOM_MIN, _zcap()))
	var A = S.fighters[0]
	var B = S.fighters[1]
	var d: float = SimWrap.sdx(A.x, B.x)
	var mx: float = A.x + d * 0.5
	var my: float = clampf((A.y + B.y) * 0.5 + 40.0, CamParams.CAM_Y_MIN, SimConst.CEILING - CamParams.CAM_Y_TOP)
	var ahead: float = minf(SimConst.HALF, absf(d) + maxf(0.0, _sep_rate) * CamParams.ZOOM_OUT_LOOKAHEAD)
	var z: float = zoom_u(vw, vh, ahead, _pair_dy(A, B), maxf(A.tier, B.tier), _m(), true)
	var mult: float = maxf(_push_mult(0), _push_mult(1)) * _intro_mult()
	if solo_kind == "ko":
		pass
	var pz: float = 1.0 / cos(deg_to_rad(_pitch_now))
	z = clampf(z * mult * pz * _wide_mult(), maxf(CamParams.ZOOM_MIN, CamParams.R_FLOOR * vh / CamParams.BODY_H * pz), _zcap() * pz * (1.0 + CamParams.TIER_PUSH))
	if _pitch_now != 0.0:
		# Put the pair's chest midpoint at 0.7 of the height, as the straight-on camera does: a few Newton steps on cam_y.
		var cwx: float = SimWrap.wrap(mx)
		var chest_y: float = (A.y + B.y) * 0.5 + CamParams.CHEST
		var zmid: float = (float(A.z) + float(B.z)) * 0.5
		var cy: float = my
		for it in range(3):
			var s0: float = SplitFrame.project(cwx, cy, z, _pitch_now, vw, vh, cwx, chest_y, zmid).y
			var s1: float = SplitFrame.project(cwx, cy + 25.0, z, _pitch_now, vw, vh, cwx, chest_y, zmid).y
			var slope: float = (s1 - s0) / 25.0
			if absf(slope) < 1e-9:
				break
			cy += (vh * CamParams.PLANE_Y - s0) / slope
		my = clampf(cy, CamParams.CAM_Y_MIN, SimConst.CEILING - CamParams.CAM_Y_TOP)
	return Vector3(SimWrap.wrap(mx), my, z)


func _snap_merged(S: SimState) -> void:
	var t: Vector3 = _merged_target(S)
	_mx = t.x
	_my = t.y
	_mz = t.z
	_pmx = t.x
	_pmy = t.y


func _own_zoom_target(S: SimState, i: int) -> float:
	var f = S.fighters[i]
	var m: float = _m()
	var r: float = CamParams.R_PANE * m
	var pz: float = 1.0 / cos(deg_to_rad(_pitch_now))   # a pitched camera foreshortens a standing fighter by cos(pitch)
	if chase_slot == i:
		r = CamParams.R_LAUNCH * m
	var tier_f: float = 1.0 - CamParams.REF_TIER * (f.tier - 1.0)
	var alt_f: float = 1.0
	var h: float = (f.y - WorldTerrain.groundY(S, f.x)) / CamParams.BODY_H
	alt_f = maxf(CamParams.ALT_FLOOR, 1.0 / (1.0 + maxf(0.0, h - CamParams.ALT_START) / CamParams.ALT_SCALE))
	if solo_kind != "" and solo_slot == i:
		match solo_kind:
			"launch":
				r = CamParams.R_LAUNCH * m
				alt_f = 1.0
			"cut":
				r = CamParams.R_LAUNCH * m * (1.0 + CamParams.CUT_PUSH)
				alt_f = 1.0
			"transform":
				r = CamParams.R_CINE * m
				if _tf_phase != "":
					match _tf_phase:
						"gather":
							var pg: float = clampf(solo_t / (float(_tf_g) * DT), 0.0, 1.0)
							var close: float = CamParams.TRANSFORM_R0 if _tf_ver == "full" else CamParams.TRANSFORM_R0_SHORT
							r = lerpf(CamParams.R_FIGHT, close, smoothstep(0.0, 1.0, pg)) * m
						"break":
							r = CamParams.TRANSFORM_R2 * m
						_:
							r = CamParams.R_FIGHT * m
				elif _solo_dur > 0.0:
					var tp: float = clampf(solo_t / _solo_dur, 0.0, 1.0)
					r = lerpf(CamParams.TRANSFORM_R0, CamParams.TRANSFORM_R1, smoothstep(0.25, 0.45, tp))
					r = lerpf(r, CamParams.TRANSFORM_R2, smoothstep(0.7, 0.95, tp)) * m
				alt_f = 1.0
			"finisher":
				var fp: float = clampf(solo_t / maxf(_solo_dur, 0.1), 0.0, 1.0)
				r = lerpf(CamParams.R_FIGHT, CamParams.R_FINISH, smoothstep(0.0, 1.0, fp)) * m
				alt_f = 1.0
			"ko":
				r = CamParams.R_KO * m
				alt_f = 1.0
			"intro":
				alt_f = 1.0
				match _in_phase:
					"fall":
						r = CamParams.INTRO_R_FALL * m
					"face":
						r = CamParams.INTRO_FACE_R * m
					_:
						var zf: float = CamParams.INTRO_LAND_FIT * vw / (2.0 * maxf(_in_crater_r, 60.0))
						r = clampf(zf * CamParams.BODY_H / vh, CamParams.INTRO_R_LAND_MIN, CamParams.INTRO_R_LAND_MAX) * m
			"wreck":
				var wp: float = 1.0 if reduced_motion else clampf(solo_t / CamParams.WRECK_T, 0.0, 1.0)
				r = lerpf(CamParams.R_WRECK_0, CamParams.R_WRECK, smoothstep(0.0, 1.0, wp)) * m
				alt_f = 1.0
	var z: float = r * vh / CamParams.BODY_H * tier_f * alt_f
	z *= _push_mult(i) * _hit_mult(i)
	if solo_kind == "launch" and solo_slot == i and solo_phase == "land":
		z *= 1.0 + CamParams.LAND_PUSH * sin(PI * clampf(_land_t / 0.3, 0.0, 1.0))
	var zmax: float = _zcap() * (1.0 + CamParams.TIER_PUSH)
	if solo_kind == "transform" or solo_kind == "ko" or solo_kind == "finisher" or solo_kind == "wreck" or solo_kind == "intro":
		zmax = maxf(zmax, CamParams.R_CLOSE * m * vh / CamParams.BODY_H)   # a close-up may go past the cap
	# A fighter in depth (Fighter.z, positive toward the camera) draws at s = d / (d + w) of his plane size, d = K / zoom.
	# The zoom that gives the apparent height the plane zoom z would have is 1 / (1/z - w / K); where that cannot be
	# reached (the back row) the cap is used, the biggest he can be.
	var w: float = -float(f.z)
	if absf(w) > 1.0:
		var k: float = CamParams.K_FACTOR * vh
		var den: float = 1.0 / z - w / k
		z = zmax if den <= 1.0 / zmax else 1.0 / den
	return clampf(z * pz, CamParams.ZOOM_MIN, zmax * pz)


func _anchor_rest(i: int) -> Vector2:
	var n: Vector2 = Vector2(cos(theta), sin(theta))
	var s: float = -1.0 if i == 0 else 1.0
	return Vector2(vw * 0.5, vh * 0.5 + CamParams.ANCHOR_DROP * vh) + s * Vector2(n.x * CamParams.ANCHOR_LX * vw, n.y * CamParams.ANCHOR_LY * vh)


func _half_extent_along_n(n: Vector2) -> float:
	return 0.5 * (absf(n.x) * vw + absf(n.y) * vh)


func _anchor(S: SimState, i: int) -> Vector2:
	var rest: Vector2 = _anchor_rest(i)
	var n: Vector2 = Vector2(cos(theta), sin(theta))
	var q: float = 0.0
	var target: Vector2 = rest
	var solo_pt: Vector2 = Vector2(vw * 0.5, vh * 0.62)
	if (solo_kind == "launch" or solo_kind == "hold") and solo_slot == i:
		var f = S.fighters[i]
		var want: float = CamParams.LAUNCH_TRAIL if f.vx >= 0.0 else 1.0 - CamParams.LAUNCH_TRAIL
		if solo_kind == "hold" and _launch_victim >= 0:
			# The attacker stands on the side away from where the opponent was thrown, so the throw has room.
			var to_v: float = SimWrap.sdx(f.x, S.fighters[_launch_victim].x)
			want = 0.4 if to_v >= 0.0 else 0.6
		_launch_anchor_x += (want - _launch_anchor_x) * (1.0 - exp(-DT / 0.25))
		_launch_anchor_y += (0.62 - _launch_anchor_y) * (1.0 - exp(-DT / 0.25))
		solo_pt.x = vw * _launch_anchor_x
		solo_pt.y = vh * _launch_anchor_y
	if solo_kind == "intro" and solo_slot == i:
		match _in_phase:
			"fall":
				solo_pt = Vector2(vw * 0.5, vh * CamParams.INTRO_FALL_ANCHOR_Y)
			"face":
				solo_pt = Vector2(vw * (0.42 if S.fighters[i].face >= 0.0 else 0.58), vh * 0.66)
			_:
				solo_pt = Vector2(vw * 0.5, vh * (CamParams.INTRO_LAND_ANCHOR_Y if not reduced_motion else 0.62))
	if solo_kind == "wreck" and solo_slot == i:
		var ap: float = 1.0 if reduced_motion else smoothstep(0.0, 1.0, clampf(solo_t / CamParams.WRECK_T, 0.0, 1.0))
		solo_pt = Vector2(vw * (0.5 - CamParams.WRECK_ANCHOR_X * float(wreck_dir) * ap), vh * 0.70)
	if solo_kind == "transform" and solo_slot == i and _tf_phase == "break" and _tf_ver == "full":
		solo_pt.y = vh * 0.74   # low in the frame, the sky above him
	if e_slot >= 0:
		if i == e_slot:
			q = maxf(e, solo_w if solo_slot == i else 0.0)
			target = solo_pt
		elif sliver > 0.0:
			q = e
			var s: float = -1.0 if i == 0 else 1.0
			var hn: float = _half_extent_along_n(n)
			var delta: float = hn * (1.0 - 2.0 * sliver) * (1.0 if e_slot == 0 else -1.0)
			var mid: Vector2 = Vector2(vw * 0.5, vh * 0.5) + n * (delta + s * hn) * 0.5
			target = Vector2(mid.x, vh * 0.62)
	elif solo_slot == i and solo_w > 0.0:
		q = solo_w
		target = solo_pt
	return rest.lerp(target, smoothstep(0.0, 1.0, q))


func _cam_from_focus(i: int, z: float, p: Vector2, fz: float = 0.0) -> Vector3:
	return _cam_at(_fx[i], _fy[i], fz, z, p)


## The camera (x, y, zoom) that puts the world point (fx, fy) at depth fz on the screen point p.
func _cam_at(fx: float, fy: float, fz: float, z: float, p: Vector2) -> Vector3:
	# A deep fighter lands at C + (plane point - C) * s, so aim the plane mapping at C + (p - C) / s.
	var target: Vector2 = p
	if fz != 0.0:
		var d: float = CamParams.K_FACTOR * vh / z
		var s: float = maxf(d / maxf(d - fz, 1.0), CamParams.DEPTH_S_MIN)
		var c0 := Vector2(vw * 0.5, vh * 0.5)
		p = c0 + (p - c0) / s
	var x: float = SimWrap.wrap(fx - (p.x - vw * 0.5) / z)
	var y: float = clampf(fy - (vh * CamParams.PLANE_Y - p.y) / z, CamParams.CAM_Y_MIN, SimConst.CEILING - CamParams.CAM_Y_TOP)
	if _pitch_now == 0.0:
		return Vector3(x, y, z)
	return _refine_cam(Vector3(x, y, z), fx, fy, fz, target)


## With a pitch the plane mapping is a projection: refine the straight-on guess with Newton steps (a numerical Jacobian)
## until the fighter's chest lands on `target`.
func _refine_cam(cam: Vector3, fx: float, fy: float, fz: float, target: Vector2) -> Vector3:
	var cx: float = cam.x
	var cy: float = cam.y
	for it in range(3):
		var s0: Vector2 = SplitFrame.project(cx, cy, cam.z, _pitch_now, vw, vh, fx, fy, fz)
		var er: Vector2 = target - s0
		if er.length() < 0.2:
			break
		var sx: Vector2 = (SplitFrame.project(cx + 25.0, cy, cam.z, _pitch_now, vw, vh, fx, fy, fz) - s0) / 25.0
		var sy: Vector2 = (SplitFrame.project(cx, cy + 25.0, cam.z, _pitch_now, vw, vh, fx, fy, fz) - s0) / 25.0
		var det: float = sx.x * sy.y - sy.x * sx.y
		if absf(det) < 1e-12:
			break
		cx = SimWrap.wrap(cx + (sy.y * er.x - sy.x * er.y) / det)
		cy += (-sx.y * er.x + sx.x * er.y) / det
	return Vector3(cx, clampf(cy, CamParams.CAM_Y_MIN, SimConst.CEILING - CamParams.CAM_Y_TOP), cam.z)


## The perspective scale of fighter i at the depth he has now, for the pane's current zoom.
func _depth_s(S: SimState, i: int, z: float) -> float:
	var zz: float = float(S.fighters[i].z)
	if zz == 0.0:
		return 1.0
	var d: float = CamParams.K_FACTOR * vh / z
	return maxf(d / maxf(d - zz, 1.0), CamParams.DEPTH_S_MIN)


static func _blend_cam(a: Vector3, b: Vector3, w: float) -> Vector3:
	if w <= 0.0:
		return a
	if w >= 1.0:
		return b
	return Vector3(SimWrap.wrap(a.x + SimWrap.sdx(a.x, b.x) * w), lerpf(a.y, b.y, w), exp(lerpf(log(a.z), log(b.z), w)))


var _oz: PackedFloat64Array = PackedFloat64Array([0.5, 0.5])
var _oz_valid: bool = false
var _outs: Array = [Vector3.ZERO, Vector3.ZERO]
var _anchors: Array = [Vector2.ZERO, Vector2.ZERO]
var _owns: Array = [Vector3.ZERO, Vector3.ZERO]


func _update_cameras(S: SimState) -> void:
	if _slam_slot >= 0:
		_slam_run(S)
	var stiff: bool = _slam_slot >= 0 and e > 0.0
	# The slam's stiff filters come in over SLAM_STIFF_RAMP, not in one tick: a filter that goes from 0.14 s to 0.03 s at
	# once shoves the camera up to 0.3 of the screen width (the jolt scan's biggest ordinary one).
	_stiff_w = clampf(_stiff_w + DT / CamParams.SLAM_STIFF_RAMP, 0.0, 1.0) if stiff else 0.0
	var sw: float = smoothstep(0.0, 1.0, _stiff_w)
	var transition: bool = (sep > 0.001 and sep < 0.999) or e > 0.001 or solo_kind != "" or solo_w > 0.001 or stiff
	var zrate: float = CamParams.ZOOM_RATE_TRANS if transition else CamParams.ZOOM_RATE
	for i in range(2):
		var f = S.fighters[i]
		var tau_x: float = CamParams.TAU_X
		var tau_y: float = CamParams.TAU_Y
		var freeze: bool = false
		if (solo_kind == "launch" and solo_slot == i and solo_phase == "follow") or chase_slot == i:
			tau_x = CamParams.LAUNCH_TAU
			tau_y = CamParams.TAU_Y * 0.7
			freeze = reduced_motion
		if stiff:
			tau_x = lerpf(tau_x, CamParams.SLAM_TAU, sw)
			tau_y = lerpf(tau_y, CamParams.SLAM_TAU, sw)
		# The follow point leads the fighter by its measured velocity times the filter's time constant, which cancels
		# the filter's lag at constant speed. Measured, not the sim's vx: a rush moves the fighter without setting vx.
		var vxm: float = SimWrap.sdx(_ppx[i], f.x) / DT
		var vym: float = (f.y - _ppy[i]) / DT
		_ppx[i] = f.x
		_ppy[i] = f.y
		var zc: float = maxf(_zo[i], 0.001)
		# A body low over the ground (a bounce, a lip flight, a tumble) is not followed up: the focus stays at the ground
		# level until he is above LOW_AIR_DEAD, so a half-body-height bounce moves on the screen as it does in the world
		# (the chase otherwise follows each rise and the bounce nearly vanishes: 5 to 20 px for 1 to 2 body heights).
		var fy_ref: float = f.y + CamParams.CHEST
		var lead_w: float = 1.0
		if solo_kind == "intro" and _in_phase == "fall" and solo_slot == i and not reduced_motion:
			# The camera falls a little slower than he does, so he drops through the frame (INTRO_FALL_DROP units from the
			# top at the start to the anchor at the touchdown) and the ground comes up: pinned on him, the sky shows no fall.
			var kf: float = clampf(1.0 - CamParams.INTRO_FALL_DROP / _in_fall_h, 0.0, 1.0)
			var gf: float = WorldTerrain.groundY(S, f.x)
			fy_ref = gf + CamParams.CHEST + kf * (f.y - gf)
			lead_w = kf
		elif f.state == "launched" and not stiff and CamParams.LOW_AIR_DEAD > 0.0:
			var gnd: float = WorldTerrain.groundY(S, f.x)
			lead_w = smoothstep(CamParams.LOW_AIR_DEAD * 0.5, CamParams.LOW_AIR_DEAD * 1.5, f.y - gnd)
			fy_ref = lerpf(gnd + CamParams.CHEST, f.y + CamParams.CHEST, lead_w)
		if not freeze:
			# The lag bound (camera-v2.md section 2). e is the fighter's offset from where the camera is aiming, in screen
			# widths: ordinary up to LAG_SOFT, the filters speed up to 7x by LAG_HARD, the focus is held to LAG_HARD beyond
			# it (a whip), and farther than LAG_CUT it jumps (a counted safety cut with a short fade).
			var rx: float = SimWrap.sdx(_fx[i], f.x) * zc
			var ry: float = (fy_ref - _fy[i]) * zc
			var e_w: float = sqrt(rx * rx + ry * ry) / vw
			if e_w > CamParams.LAG_SOFT:
				var gain: float = 1.0 + CamParams.LAG_GAIN * (minf(e_w, CamParams.LAG_HARD) - CamParams.LAG_SOFT) / (CamParams.LAG_HARD - CamParams.LAG_SOFT)
				if reduced_motion:
					gain = minf(gain, 3.0)
				tau_x /= gain
				tau_y /= gain
			if e_w > CamParams.LAG_CUT:
				_fx[i] = f.x
				_fy[i] = f.y + CamParams.CHEST
				lag_cuts += 1
				_cut_now = true
				_cut_fade = CamParams.REDUCED_CUT_FADE if reduced_motion else CamParams.CUT_FADE
			var kx: float = 1.0 - exp(-DT / tau_x)
			var ky: float = 1.0 - exp(-DT / tau_y)
			# The lead that makes the discrete filter track a constant speed exactly: DT (1 - k) / k, about tau - DT / 2.
			var tx: float = f.x + vxm * DT * (1.0 - kx) / kx
			var ty: float = fy_ref + vym * lead_w * DT * (1.0 - ky) / ky
			# Aimed at a building (B2): the focus leads toward it, a bounded distance on screen, so it is in frame.
			if _aim[i] != null and f.state == "launched":
				var zz: float = maxf(_zo[i], 0.001)
				tx += clampf(CamParams.LEAD_FRAC * SimWrap.sdx(f.x, _aim[i].x), -CamParams.LEAD_MAX_X * vw / zz, CamParams.LEAD_MAX_X * vw / zz)
				ty += clampf(CamParams.LEAD_FRAC * (_aim[i].y - f.y), -CamParams.LEAD_MAX_Y * vh / zz, CamParams.LEAD_MAX_Y * vh / zz)
			_fx[i] = SimWrap.wrap(_fx[i] + SimWrap.sdx(_fx[i], tx) * kx)
			_fy[i] += (ty - _fy[i]) * ky
			if not reduced_motion:
				var qx: float = SimWrap.sdx(_fx[i], f.x) * zc
				var qy: float = (f.y + CamParams.CHEST - _fy[i]) * zc
				var q_w: float = sqrt(qx * qx + qy * qy) / vw
				if q_w > CamParams.LAG_HARD:
					var back: float = (q_w - CamParams.LAG_HARD) / q_w   # hold him at the bound: move the focus the excess toward him
					_fx[i] = SimWrap.wrap(_fx[i] + SimWrap.sdx(_fx[i], f.x) * back)
					_fy[i] += (f.y + CamParams.CHEST - _fy[i]) * back
					lag_whips += 1
		# own zoom: first-order filter, then the rate cap
		var zt: float = _own_zoom_target(S, i)
		var tau_z: float = CamParams.TAU_Z
		if (solo_kind == "ko" or solo_kind == "finisher") and solo_slot == i:
			tau_z = CamParams.KO_DOLLY / 3.0
		if solo_kind == "wreck" and solo_slot == i:
			tau_z = 0.2 if reduced_motion else CamParams.WRECK_TAU
		if solo_kind == "intro" and solo_slot == i:
			tau_z = 0.12
		if solo_kind == "transform" and solo_slot == i and _tf_phase != "":
			tau_z = 0.12   # the beats are on a clock: the push has to land by the break
		if stiff:
			tau_z = lerpf(tau_z, CamParams.SLAM_TAU, sw)
		var kz: float = 1.0 - exp(-DT / tau_z)
		var dz: float = (log(zt) - log(_zo[i])) * kz
		var cap: float = (CamParams.SLAM_ZOOM_RATE if stiff else zrate) * DT
		dz = clampf(dz, -cap, cap)
		_zo[i] = exp(log(_zo[i]) + dz)
	# the merged shadow camera: the reference camera's ease, snapped while two full panes are up
	var mt: Vector3 = _merged_target(S)
	if sep >= 0.999 and _slam_slot < 0 and solo_kind == "":
		_mx = mt.x
		_my = mt.y
		_mz = mt.z
	else:
		var tau_m: float = lerpf(CamParams.MERGED_TAU, CamParams.SLAM_TAU, sw) if stiff else CamParams.MERGED_TAU
		var edge: float = 0.0
		for fi in range(2):
			edge = maxf(edge, absf(SimWrap.sdx(_mx, S.fighters[fi].x)) * _mz / vw)
		if edge > 0.30:
			tau_m /= 1.0 + CamParams.LAG_GAIN * (minf(edge, 0.46) - 0.30) / 0.16
		var km: float = 1.0 - exp(-DT / tau_m)
		var vmx: float = SimWrap.sdx(_pmx, mt.x) / DT
		var vmy: float = (mt.y - _pmy) / DT
		if absf(vmx * DT) > 1500.0:
			vmx = 0.0   # the midpoint's target flipped across the antipode: not a motion
		_mx = SimWrap.wrap(_mx + SimWrap.sdx(_mx, mt.x + vmx * DT * (1.0 - km) / km) * km)
		_my += (mt.y + vmy * DT * (1.0 - km) / km - _my) * km
		var dzm: float = (log(mt.z) - log(_mz)) * km
		var capm: float = (CamParams.SLAM_ZOOM_RATE if stiff else CamParams.ZOOM_RATE_TRANS) * DT
		dzm = clampf(dzm, -capm, capm)
		_mz = exp(log(_mz) + dzm)
	_pmx = mt.x
	_pmy = mt.y
	_outputs(S)


func _outputs(S: SimState) -> void:
	for i in range(2):
		_anchors[i] = _anchor(S, i)
		_owns[i] = _cam_from_focus(i, _zo[i], _anchors[i], float(S.fighters[i].z))
	var shared: Vector3 = Vector3(_mx, _my, _mz)
	if solo_slot >= 0 and solo_w > 0.0:
		shared = _blend_cam(shared, _owns[solo_slot], smoothstep(0.0, 1.0, solo_w))
	var w: float = 1.0 - _smootherstep(sep)
	var slam_now: bool = _slam_slot >= 0 and e > 0.0
	for i in range(2):
		var o: Vector3 = _blend_cam(_owns[i], shared, w)
		var fz_i: float = float(S.fighters[i].z)
		if w > 0.0 and w < 1.0 and (_pitch_now != 0.0 or absf(fz_i) > 1.0) and solo_kind == "" and _ov_kind == "":
			# At a pitch or in depth the screen is not linear in the camera's y: blending the cameras let the fighter
			# leave the screen mid-blend (a pair 2,600 units apart in depth at 49 degrees: fighter 0 190 px below the
			# bottom while the split opened). Blend where he is on the screen instead: the camera that puts him at
			# the mix of his place in the shared view and his anchor, at the blended zoom.
			var f_i = S.fighters[i]
			var ps: Vector2 = SplitFrame.project(shared.x, shared.y, shared.z, _pitch_now, vw, vh, f_i.x, f_i.y + CamParams.CHEST, fz_i)
			o = _cam_at(f_i.x, f_i.y + CamParams.CHEST, fz_i, o.z, ps.lerp(_anchors[i], 1.0 - w))
		# Whatever the blends do, the drawn zoom never changes faster than the comfort limit; the slam's door gets the
		# higher SLAM_ZOOM_RATE (it was exempt: 0.2 of a log unit in one tick, the largest jolt in the sweep's scan).
		if _oz_valid:
			var cap: float = (CamParams.SLAM_ZOOM_RATE if slam_now else CamParams.ZOOM_RATE_TRANS) * DT
			o.z = exp(log(_oz[i]) + clampf(log(o.z) - log(_oz[i]), -cap, cap))
		_outs[i] = o
		_oz[i] = o.z
	if _ov_kind != "":
		var oc: Vector3 = _overlay_cam(S)
		_outs[0] = oc
		_outs[1] = oc
		_oz[0] = oc.z
		_oz[1] = oc.z
	_oz_valid = true


static func _smootherstep(t: float) -> float:
	t = clampf(t, 0.0, 1.0)
	return t * t * t * (t * (t * 6.0 - 15.0) + 10.0)


# ---------------------------------------------------------------------------------------------------- frame

func _mode_name() -> String:
	if fold_active or _ov_kind != "":
		return "solo"
	if _slam_slot >= 0:
		return "slam"
	if swing_t >= 0.0:
		return "swing"
	if solo_kind != "" or (e > 0.001 and sep > 0.001):
		return "solo"
	if sep >= 0.999:
		return "split"
	if sep <= 0.001:
		return "merged"
	return "opening" if split_wanted else "closing"


func _make_frame(S: SimState) -> SplitFrame:
	var f := SplitFrame.new()
	f.vw = vw
	f.vh = vh
	f.mode = _mode_name()
	f.sep = sep
	f.e = e
	f.e_slot = e_slot
	f.sliver = sliver if e_slot >= 0 else 0.0
	f.theta = theta
	f.n = Vector2(cos(theta), sin(theta))
	var hn: float = _half_extent_along_n(f.n)
	var delta: float = 0.0
	if e_slot >= 0:
		delta = e * hn * (1.0 - 2.0 * sliver) * (1.0 if e_slot == 0 else -1.0)
	f.c = Vector2(vw * 0.5, vh * 0.5) + f.n * delta
	var ss: float = _smootherstep(sep)
	f.gap = maxf(CamParams.GAP_MIN_PX, CamParams.GAP_FRAC * vw)
	f.feather = CamParams.FEATHER_FRAC * vw * (1.0 - ss) if swing_t < 0.0 else 0.0
	f.line_alpha = smoothstep(0.0, 0.45, sep)
	for i in range(2):
		f.cam_x[i] = _outs[i].x
		f.cam_y[i] = _outs[i].y
		f.cam_z[i] = _outs[i].z * _punch_mult()   # after the filters: a 6-tick punch would be smoothed away
		f.anchor[i] = _anchors[i]
		f.ring[i] = SimWrap.wrap(S.fighters[i].x) / SimConst.W * TAU
		if pane_request_fn.is_valid():
			var req = pane_request_fn.call(i)
			if req is Dictionary and req.has("kind"):
				f.kind[i] = String(req["kind"])
	f.swing = swing_t
	f.sigma = sigma_shown
	f.held_u = u
	f.flash = _flash
	f.slam = _slam_done
	f.shake = _shk.duplicate()
	f.pitch = _pitch_now
	f.panel = _panel_frame(S)
	f.fade = clampf(_cut_fade / (CamParams.REDUCED_CUT_FADE if reduced_motion else CamParams.CUT_FADE), 0.0, 1.0) if _cut_fade > 0.0 else 0.0
	_slam_done = false
	# Which panes must be rendered.
	var show0: bool = true
	var show1: bool = sep > 0.001
	if show1 and e >= 0.999 and sliver <= 0.0:
		if e_slot == 0:
			show1 = false
		elif e_slot == 1:
			show0 = false
	f.active = [show0, show1]
	var two_up: bool = show0 and show1
	for ci in range(2):
		var cf = S.fighters[ci]
		var h_px: float = f.apparent_height(ci, cf.x, cf.y, float(cf.z))
		var rad: float = maxf(CamParams.CUTAWAY_MIN_PX, CamParams.CUTAWAY_K * h_px)
		if solo_kind == "transform" and _tf_phase == "break" and _tf_ver == "full":
			rad = maxf(rad, CamParams.CUTAWAY_BREAK_R * vh)   # keep the silhouette against the sky clear of a house in front
		f.cutaway[ci] = {"request": _ov_kind != "smash", "radius_px": rad, "only": ci if two_up else -1}
	f.cut = false
	return f
