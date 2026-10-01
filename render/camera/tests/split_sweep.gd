extends SceneTree
## Split sweep: the scripted test of the dynamic split screen (docs/camera/split-screen.md section 15). It poses the
## two fighters by hand, like render/tools/seam_sweep.gd, steps the rig at 60 Hz, reads the frame at 144 Hz (the rate
## that would show a pop) and checks what the design promises:
##   - separations from 0 to 0.998 of the antipode, out and back, through the seam: one split, one merge, no chatter;
##   - the swap at the antipode in both directions, and a jitter around it that must not flip;
##   - the pass-through flip at large height difference, and its dead band;
##   - jitter around the split and merge lines;
##   - a dissolve merge, a slam (a scripted rush that ends in contact), and its feint;
##   - launches at the measured p10, p50, p90 and maximum speeds, landing near (merge) and far (split);
##   - a respected transformation, a tier-up push, the fold, solo-against-AI with the split off, a hard cut;
##   - real AI matches (seeds below), where the comfort limits and the mode-change gaps are checked on live data;
##   - determinism: every scenario twice gives the same digest, and the sim's gameplay hash is unchanged by the rig.
## Per frame: every sample point belongs to a rendered pane; the divider, anchors and cameras move within the
## limits of CamParams; a fighter sits inside its pane and, at rest, inside UI's clear zone.
##
## Usage (from the repo root):
##   godot --headless --path . --script res://render/camera/tests/split_sweep.gd [-- --seeds=3,10,17 --ticks=3600 --size=1280x720]
## Exit 0 on success, 1 on failure.
##   godot --path . --script res://render/camera/tests/split_sweep.gd -- --render [--shots=DIR] [--size=1280x720]
## (a window, not --headless) also draws the composite of stand-in panes (SplitTestPane) for the transition scenarios,
## reads the pixels back at 144 Hz and checks the picture: no frame-to-frame spike beyond an authored cut (a pop or a
## flicker at the divider would show as one), and saves frames around each transition to DIR.

const DISPLAY_HZ: float = 144.0
const GRID_X: int = 32
const GRID_Y: int = 18
const TOL: float = 1.03   # slack on the comfort limits (interpolation at 144 Hz between ticks)
const REPLAYED: Array = ["out and back dy=0", "antipode right", "antipode left", "pass-through", "slam", "slam feint", "launch far 10816", "launch up and down 10816", "transformation"]
const SPIKE: float = 4.0   # a frame-to-frame picture change this many times its neighbours' is a pop

var vw: float = 1280.0
var vh: float = 720.0
var seeds: Array = [3, 10, 17]
var match_ticks: int = 3600
var fails: Array = []
var checks: int = 0
var frames_checked: int = 0
var stats: Dictionary = {}
var digest_acc: int = 0

# per-run tracking, reset by _begin()
var _S: SimState
var _rig: SplitRig
var _tick: int = 0
var _prev_disp: SplitFrame = null
var _prev_g: Array = [Vector2.ZERO, Vector2.ZERO]
var _prev_modes: Array = []
var _label: String = ""
var _sigma_changes: int = 0
var _last_sigma: int = 1
var _swings: int = 0
var _last_swing_on: bool = false
var _mode_seq: Array = []
var _slam_frames: int = 0
var _max: Dictionary = {}
var _disp_t: float = 0.0
var _allow_cut_frames: int = 0
var _last_trans_t: float = -9.0
var _offscreen_t: Array = [0.0, 0.0]
var _maxv: Dictionary = {}
var render_mode: bool = false
var dump_label: String = ""
var dump_from: int = 0
var dump_to: int = 0
var shots_dir: String = ""
var view: SplitView
var stand_in: SplitTestMain
var _queue: Array = []
var _record: bool = false
var render_spikes: Dictionary = {}
var trace_seed: int = -1
var trace_t0: float = 0.0
var trace_t1: float = 0.0


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seeds="):
			seeds = Array(a.substr(8).split(",")).map(func(s): return int(s))
		elif a == "--render":
			render_mode = true
		elif a.begins_with("--dump="):
			var dp: PackedStringArray = a.substr(7).split(":")
			dump_label = dp[0]
			dump_from = int(dp[1])
			dump_to = int(dp[2])
		elif a.begins_with("--shots="):
			shots_dir = a.substr(8)
		elif a.begins_with("--trace="):
			var tp: PackedStringArray = a.substr(8).split(":")
			trace_seed = int(tp[0])
			trace_t0 = float(tp[1])
			trace_t1 = float(tp[2])
		elif a.begins_with("--ticks="):
			match_ticks = int(a.substr(8))
		elif a.begins_with("--size="):
			var wh: PackedStringArray = a.substr(7).split("x")
			vw = float(wh[0])
			vh = float(wh[1])
	_run.call_deferred()


func _run() -> void:
	print("Split sweep  %dx%d%s" % [int(vw), int(vh), "  (with the composite)" if render_mode else ""])
	if render_mode:
		DisplayServer.window_set_size(Vector2i(int(vw), int(vh)))
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
		root.size = Vector2i(int(vw), int(vh))
		stand_in = SplitTestMain.new()
		view = SplitView.new()
		root.add_child(view)
		view.size = Vector2(vw, vh)
		view.attach(stand_in)
		await process_frame
	var W: float = SimConst.W
	var H: float = SimConst.HALF
	var bh: float = CamParams.BODY_H
	var m: float = CamParams.HYST_M * W
	# 1. Out and back: separation from 0 to 0.998 of the antipode across the seam, level and with a height difference.
	await _scenario("out and back dy=0", func(): return _out_and_back(0.0), {"splits": 1, "merges": 1})
	for dy in [2000.0, -2000.0]:
		# a height difference this large keeps the fighters small however close they are: split throughout
		await _scenario("out and back dy=%d" % int(dy), func(): return _out_and_back(dy), {"merges": 0, "swings": 0})
	# 2. The antipode, both ways: B passes it going right, then going left (a swap each time), and a jitter that must not flip.
	await _scenario("antipode right", func(): return _antipode(1.0, 0.0), {"swings": 1, "sigma_changes": 1})
	await _scenario("antipode right reduced motion", func(): return _antipode(1.0, 0.0, true), {"swings": 1, "sigma_changes": 1})
	await _scenario("antipode left", func(): return _antipode(-1.0, 0.0), {"swings": 1, "sigma_changes": 1})
	await _scenario("antipode there and back", func(): return _antipode_round_trip(), {"swings": 2, "sigma_changes": 2})
	await _scenario("antipode jitter 0.5 m", func(): return _antipode_jitter(0.5 * m), {"swings": 0, "sigma_changes": 0})
	await _scenario("antipode jitter 3 m", func(): return _antipode_jitter(3.0 * m), {"max_flips_per_second": 1})
	# 3. Pass-through at large height difference.
	await _scenario("pass-through", func(): return _pass_through(4000.0, 0.0), {"swings": 1, "sigma_changes": 1})
	await _scenario("pass-through dead band", func(): return _pass_through(4000.0, 0.5 * CamParams.HYST_M0), {"swings": 0, "sigma_changes": 0})
	# 4. Jitter around the split and merge lines.
	await _scenario("split line jitter", func(): return _line_jitter(0.90, 1.10, CamParams.R_SPLIT), {"max_changes_per_second": 1.3})
	# 5. Merges and the slam.
	await _scenario("slam", func(): return _slam(false), {"slams": 1})
	await _scenario("slam feint", func(): return _slam(true), {"slams": 0})
	# 6. Launches.
	for sp in [1677.0, 10816.0, 26718.0, 45606.0]:
		await _scenario("launch far %d" % int(sp), func(): return _launch(sp, 20000.0), {"end_mode": "split"})
	await _scenario("launch up and down 10816", func(): return _launch(10816.0, 0.0, true), {"end_mode": "merged"})
	# 7. Cinematics and options.
	await _scenario("transformation", func(): return _transformation(), {})
	await _scenario("tier-up push", func(): return _tier_push(), {})
	await _scenario("fold", func(): return _fold(), {})
	await _scenario("solo follow", func(): return _solo_follow(), {})
	await _scenario("hard cut", func(): return _hard_cut(), {})
	await _scenario("shake per pane", func(): return _shake_panes(), {})
	for row in [[750.0, "foreground"], [-600.0, "front street"], [-1650.0, "mid row"], [-2850.0, "back row"]]:
		await _scenario("depth %s one view" % row[1], func(): return _depth(float(row[0]), 600.0), {})
		await _scenario("depth %s split" % row[1], func(): return _depth(float(row[0]), 9000.0), {})
	_static_equals_reference()
	# 8. Real AI matches, then the determinism of the sim.
	for seed in seeds:
		_real_match(int(seed))
	_sim_unchanged()
	print("frames checked  %d, checks %d" % [frames_checked, checks])
	for k in stats:
		print("%-34s %s" % [k, str(stats[k])])
	if fails.is_empty():
		print("\nsplit sweep passed")
	else:
		for f in fails.slice(0, 30):
			print("FAIL  " + f)
		print("\nsplit sweep FAILED (%d)" % fails.size())
	quit(0 if fails.is_empty() else 1)


# ------------------------------------------------------------------------------------------------ scenario runner

## Run a scenario twice (determinism) and check its expectations. The scenario returns a Dictionary of counts.
func _scenario(label: String, body: Callable, expect: Dictionary) -> void:
	_record = render_mode and label in REPLAYED
	var r1: Dictionary = _run_once(label, body)
	_record = false
	if render_mode and not _queue.is_empty():
		await _replay(label)
	var r2: Dictionary = _run_once(label, body)
	_check(r1["digest"] == r2["digest"], "%s: two runs differ (digest %s vs %s)" % [label, r1["digest"], r2["digest"]])
	for k in expect:
		var want = expect[k]
		match k:
			"splits", "merges", "swings", "sigma_changes", "slams":
				_check(int(r1[k]) == int(want), "%s: %s = %d, want %d" % [label, k, int(r1[k]), int(want)])
			"end_mode":
				_check(r1["end_mode"] == want, "%s: ended in %s, want %s" % [label, r1["end_mode"], want])
			"max_flips_per_second":
				_check(float(r1["max_flips_per_second"]) <= float(want), "%s: %.2f flips a second, limit %.2f" % [label, r1["max_flips_per_second"], want])
			"max_changes_per_second":
				_check(float(r1["max_changes_per_second"]) <= float(want), "%s: %.2f mode changes a second, limit %.2f" % [label, r1["max_changes_per_second"], want])
	stats[label] = "splits %d merges %d swings %d slams %d, %s" % [r1["splits"], r1["merges"], r1["swings"], r1["slams"], r1["modes"]]


func _run_once(label: String, body: Callable) -> Dictionary:
	_begin(label)
	var out: Dictionary = body.call()
	return _finish(out)


func _begin(label: String) -> void:
	_label = label
	if _S != null:
		SimCore.dispose(_S)
	_S = SimCore.createSim()
	SimCore.newMatch(_S, 1, {"p1": true, "p2": true})
	for f in _S.fighters:
		f.vx = 0.0
		f.vy = 0.0
		f.rot = 0.0
		f.state = "free"
		f.hidden = false
	_rig = SplitRig.new()
	_tick = 0
	_prev_disp = null
	_sigma_changes = 0
	_swings = 0
	_last_swing_on = false
	_mode_seq = []
	_slam_frames = 0
	_max = {}
	_disp_t = 0.0
	digest_acc = 0
	_allow_cut_frames = 0
	_last_trans_t = -9.0
	_offscreen_t = [0.0, 0.0]


func _finish(out: Dictionary) -> Dictionary:
	var splits: int = 0
	var merges: int = 0
	var was_split: bool = false
	var last: String = ""
	var change_times: Array = []
	for mc in _rig.mode_change_times():
		change_times.append(float(mc))
	var seq: Array = []
	for ms in _mode_seq:
		var mode: String = ms
		var split_like: bool = mode in ["split", "opening", "swing", "slam", "solo"] and mode != "merged"
		if split_like != was_split:
			if split_like:
				splits += 1
			else:
				merges += 1
			was_split = split_like
		if mode != last:
			seq.append(mode)
			last = mode
	out["splits"] = splits
	out["merges"] = merges
	out["swings"] = _swings
	out["sigma_changes"] = _sigma_changes
	out["slams"] = _slam_frames
	out["digest"] = str(digest_acc)
	out["end_mode"] = _mode_seq[-1] if not _mode_seq.is_empty() else ""
	out["modes"] = " ".join(PackedStringArray(seq))
	# flips (orientation changes) and mode changes per second, over the busiest second
	out["max_flips_per_second"] = _max_per_second(out.get("flip_times", []))
	out["max_changes_per_second"] = _max_per_second(change_times)
	return out


func _max_per_second(times: Array) -> float:
	var best: int = 0
	for i in range(times.size()):
		var n: int = 0
		for j in range(i, times.size()):
			if float(times[j]) - float(times[i]) < 1.0:
				n += 1
		best = maxi(best, n)
	return float(best)


func _check(cond: bool, msg: String) -> void:
	checks += 1
	if not cond:
		fails.append(msg)


## One sim tick of a posed scenario: advance the clock, step the rig, then look at the frame at 144 Hz.
func _tick_rig(events: Array = []) -> void:
	_S.T += SplitRig.DT
	_S.tick += 1
	_S.dt = SplitRig.DT
	_rig.step(_S, vw, vh, events)
	_tick += 1
	_watch()


func _watch() -> void:
	_ft_prev = _ft_cur.duplicate()
	_fz_prev = _fz_cur.duplicate()
	for i in range(2):
		_ft_cur[i] = Vector2(_S.fighters[i].x, _S.fighters[i].y)
		_fz_cur[i] = float(_S.fighters[i].z)
	if _tick <= 1:
		_ft_prev = _ft_cur.duplicate()
		_fz_prev = _fz_cur.duplicate()
	var t_prev: float = float(_tick - 1) * SplitRig.DT
	var t_cur: float = float(_tick) * SplitRig.DT
	while _disp_t <= t_cur - 1e-9:
		var alpha: float = clampf((_disp_t - t_prev) / SplitRig.DT, 0.0, 1.0) if _tick > 1 else 1.0
		var fr: SplitFrame = _rig.frame(alpha)
		_frame_checks(fr, _rig.current(), alpha)
		if _record:
			_queue.append([fr, _fpos(0, alpha), _fpos(1, alpha)])
		_disp_t += 1.0 / DISPLAY_HZ
	var cur: SplitFrame = _rig.current()
	_mode_seq.append(cur.mode)
	if cur.sigma != _last_sigma:
		_sigma_changes += 1
		_last_sigma = cur.sigma
	var on: bool = cur.swing >= 0.0
	if on and not _last_swing_on:
		_swings += 1
	_last_swing_on = on
	if cur.slam:
		_slam_frames += 1
	digest_acc = _fold_digest(digest_acc, cur)


func _fold_digest(acc: int, f: SplitFrame) -> int:
	var v: Array = [f.sep, f.e, f.theta, f.c.x, f.c.y, f.cam_x[0], f.cam_y[0], f.cam_z[0], f.cam_x[1], f.cam_y[1], f.cam_z[1], f.anchor[0].x, f.anchor[1].y, f.feather]
	for x in v:
		acc = (acc * 1099511628211 + int(round(float(x) * 1000.0))) & 0x7FFFFFFFFFFFFFFF
	return acc


# ------------------------------------------------------------------------------------------------ per-frame checks

## A fighter as the host draws it: interpolated between the last two ticks, x along the shortest arc.
func _fz(i: int, alpha: float) -> float:
	return lerpf(_fz_prev[i], _fz_cur[i], alpha)


func _fpos(i: int, alpha: float) -> Vector2:
	var a: Vector2 = _ft_prev[i]
	var b: Vector2 = _ft_cur[i]
	return Vector2(SimWrap.wrap(a.x + SimWrap.sdx(a.x, b.x) * alpha), lerpf(a.y, b.y, alpha))


func _frame_checks(fr: SplitFrame, cur: SplitFrame, alpha: float = 1.0) -> void:
	frames_checked += 1
	var S := _S
	# 1. every sample point belongs to a rendered pane
	var owned: Array = [0, 0]
	for gy in range(GRID_Y):
		for gx in range(GRID_X):
			var p := Vector2((gx + 0.5) / GRID_X * vw, (gy + 0.5) / GRID_Y * vh)
			var w1: float = fr.weight1(p)
			owned[0 if w1 < 0.5 else 1] += 1
			if w1 < 0.999 and not bool(fr.active[0]):
				_fail_once("cover0", "%s: point %s belongs to pane 0, which is not rendered (mode %s)" % [_label, p, fr.mode])
			if w1 > 0.001 and not bool(fr.active[1]):
				_fail_once("cover1", "%s: point %s belongs to pane 1, which is not rendered (mode %s)" % [_label, p, fr.mode])
	# 1b. a fighter whose pane has a real share of the screen is on screen, inside that pane
	for i in range(2):
		var share: float = float(owned[i]) / float(GRID_X * GRID_Y)
		# A single shot on one fighter (a launch follow, a KO dolly) leaves the other out of frame by design.
		var excluded: bool = _rig.solo_kind != "" and _rig.solo_slot != i
		if share < 0.15 or not bool(fr.active[i]) or excluded:
			_offscreen_t[i] = 0.0
			continue
		var fpp: Vector2 = _fpos(i, alpha)
		var pp: Vector2 = fr.screen_pos(i, fpp.x, fpp.y + CamParams.CHEST, _fz(i, alpha))
		var w1i: float = fr.weight1(pp)
		var inside: bool = pp.x >= 0.0 and pp.x <= vw and pp.y >= 0.0 and pp.y <= vh and (w1i >= 0.5 if i == 1 else w1i < 0.5)
		if inside:
			_offscreen_t[i] = 0.0
		else:
			_offscreen_t[i] += 1.0 / DISPLAY_HZ
			_note("fighter_off_pane_s", _offscreen_t[i])
			if _offscreen_t[i] > 0.30:
				_fail_once("offscreen", "%s: fighter %d has been out of its pane for %.2f s (mode %s) at t=%.2f pos %s sep %.3f e %.2f solo %s/%.2f slam %d u %.0f sigma %d/%d n %s" % [_label, i, _offscreen_t[i], fr.mode, float(_tick) / 60.0, pp, fr.sep, fr.e, _rig.solo_kind, _rig.solo_w, _rig._slam_slot, fr.held_u, fr.sigma, _rig.sigma_u, fr.n])
	# 2. the fighter sits in its pane at rest, and in UI's clear zone
	if fr.mode == "split" and fr.swing < 0.0 and fr.e < 0.001:
		for i in range(2):
			var a: Vector2 = fr.anchor[i]
			var w1: float = fr.weight1(a)
			var mine: float = w1 if i == 1 else 1.0 - w1
			if mine < 0.999:
				_fail_once("anchor_pane", "%s: fighter %d anchor %s is not in its own pane (weight %.2f)" % [_label, i, a, mine])
			if a.x < 0.045 * vw or a.x > 0.955 * vw or a.y < 0.179 * vh or a.y > 0.801 * vh:
				_fail_once("clear", "%s: fighter %d anchor %s is outside the clear zone" % [_label, i, a])
			var head: float = a.y - (CamParams.BODY_H * 0.5 + CamParams.BODY_H * 1.0) * fr.cam_z[i]
			if head < 0.0:
				_fail_once("headroom", "%s: fighter %d has less than a body height of headroom" % [_label, i])
	# 3. limits between consecutive display frames
	if _prev_disp != null and not cur.cut:
		var dt: float = 1.0 / DISPLAY_HZ
		var moved_cut: bool = _allow_cut_frames > 0
		var slam_now: bool = fr.mode == "slam" or _prev_disp.mode == "slam"
		var trans: bool = fr.mode in ["opening", "closing", "swing", "solo", "slam"] or _prev_disp.mode in ["opening", "closing", "swing", "solo", "slam"]
		# a transition's tail (the slew limiter finishing a large zoom change) counts as part of it for a second
		if trans:
			_last_trans_t = _disp_t
		trans = trans or _disp_t - _last_trans_t < 1.0
		for i in range(2):
			if not bool(fr.active[i]) or not bool(_prev_disp.active[i]):
				continue
			var dz: float = absf(log(fr.cam_z[i]) - log(_prev_disp.cam_z[i])) / dt
			var zlim: float = CamParams.ZOOM_RATE_TRANS if (trans or fr.mode == "merged") else CamParams.ZOOM_RATE
			_note("zoom_rate", dz)
			if not slam_now and not moved_cut and dz > zlim * TOL + 0.3 * (CamParams.TIER_PUSH if _push_active() else 0.0):
				_fail_once("zoom", "%s: pane %d zoom rate %.2f e-folds a second (limit %.2f) at t=%.2f mode %s sep %.3f e %.2f solo_w %.2f" % [_label, i, dz, zlim, float(_tick) / 60.0, fr.mode, fr.sep, fr.e, _rig.solo_w])
			var da: float = (fr.anchor[i] - _prev_disp.anchor[i]).length() / vw * (60.0 / DISPLAY_HZ)
			var seen: bool = fr.sep > 0.02 and _prev_disp.sep > 0.02
			if seen:
				_note("anchor_step", da)
			if seen and not slam_now and not moved_cut and da > CamParams.ANCHOR_STEP_TRANS * TOL:
				_fail_once("anchor_move", "%s: pane %d anchor moved %.3f of the width in a tick" % [_label, i, da])
		var dc: float = (fr.c - _prev_disp.c).length() / vw * (60.0 / DISPLAY_HZ)
		var divider_seen: bool = bool(fr.active[1]) and bool(_prev_disp.active[1]) and fr.line_alpha > 0.0
		if divider_seen:
			_note("divider_step", dc)
		if divider_seen and not slam_now and not moved_cut and dc > CamParams.DIVIDER_STEP * TOL:
			_fail_once("divider", "%s: the divider moved %.3f of the width in a tick" % [_label, dc])
		var dth: float = absf(angle_difference(_prev_disp.theta, fr.theta)) / dt
		if divider_seen:
			_note("divider_deg_per_s_outside_swing", rad_to_deg(dth) if (fr.swing < 0.0 and _prev_disp.swing < 0.0) else 0.0)
		if divider_seen and fr.swing < 0.0 and _prev_disp.swing < 0.0 and not slam_now and not moved_cut and dth > CamParams.TILT_RATE_MAX * TOL * 1.5:
			_fail_once("tilt", "%s: the divider turned %.0f degrees a second outside a swing" % [_label, rad_to_deg(dth)])
		# the fighter's offset from its anchor must not jump
		for i in range(2):
			if not bool(fr.active[i]) or not bool(_prev_disp.active[i]) or fr.mode == "merged":
				continue
			var fp: Vector2 = _fpos(i, alpha)
			var g: Vector2 = fr.screen_pos(i, fp.x, fp.y + CamParams.CHEST, _fz(i, alpha)) - fr.anchor[i]
			if _prev_g_valid[i]:
				var step_px: float = (g - _prev_g[i]).length() / vw * (60.0 / DISPLAY_HZ)
				# A pop is a camera step the fighter did not make: judge frames where the fighter itself hardly moved.
				var fmove: float = (Vector2(SimWrap.sdx(_prev_fpos[i].x, fp.x), fp.y - _prev_fpos[i].y)).length() * fr.cam_z[i] / vw
				var calm: bool = fmove < 0.004
				var plain: bool = fr.mode in ["split", "merged"] and _prev_disp.mode in ["split", "merged"] and fr.swing < 0.0
				if calm and plain:
					_note("camera_step_when_calm", step_px)
					if step_px > CamParams.ANCHOR_STEP * TOL:
						print("  DBG %s t=%.3f i=%d mode %s/%s sep %.3f prev_g %s g %s cam_x %.1f fx %.1f cam_z %.4f anchor %s prev_anchor %s fmove %.5f" % [_label, _disp_t, i, fr.mode, _prev_disp.mode, fr.sep, _prev_g[i], g, fr.cam_x[i], fp.x, fr.cam_z[i], fr.anchor[i], _prev_disp.anchor[i], fmove])
						_fail_once("calm_step", "%s: fighter %d moved %.3f of the width against its anchor while it barely moved" % [_label, i, step_px])
	if _allow_cut_frames > 0:
		_allow_cut_frames -= 1
	_prev_disp = fr
	for i in range(2):
		var fp2: Vector2 = _fpos(i, alpha)
		_prev_fpos[i] = fp2
		_prev_g[i] = fr.screen_pos(i, fp2.x, fp2.y + CamParams.CHEST, _fz(i, alpha)) - fr.anchor[i]
		_prev_g_valid[i] = bool(fr.active[i])


var _prev_g_valid: Array = [false, false]
var _prev_fpos: Array = [Vector2.ZERO, Vector2.ZERO]
var _fz_prev: Array = [0.0, 0.0]
var _fz_cur: Array = [0.0, 0.0]
var _ft_prev: Array = [Vector2.ZERO, Vector2.ZERO]
var _ft_cur: Array = [Vector2.ZERO, Vector2.ZERO]
var _failed_once: Dictionary = {}


func _push_active() -> bool:
	return _rig._push[0] >= 0.0 or _rig._push[1] >= 0.0


func _fail_once(key: String, msg: String) -> void:
	checks += 1
	var k: String = _label + "|" + key
	if not _failed_once.has(k):
		_failed_once[k] = true
		fails.append(msg)


func _note(key: String, v: float) -> void:
	_max[key] = maxf(float(_max.get(key, 0.0)), v)
	var k: String = "max " + key
	if v > float(_maxv.get(k, 0.0)):
		_maxv[k] = v
		stats[k] = "%.4f  (%s, t=%.2f s)" % [v, _label, float(_tick) / 60.0]


# ------------------------------------------------------------------------------------------------ posing helpers

func _pose(ax: float, ay: float, bx: float, by: float) -> void:
	var A = _S.fighters[0]
	var B = _S.fighters[1]
	A.x = SimWrap.wrap(ax)
	A.y = ay
	B.x = SimWrap.wrap(bx)
	B.y = by


func _seed_rig() -> void:
	_rig.reset(_S, vw, vh)
	_watch_first()
	_last_sigma = _rig.sigma_shown
	_prev_g_valid = [false, false]


func _watch_first() -> void:
	_tick = 1
	_disp_t = float(_tick) * SplitRig.DT
	_mode_seq.append(_rig.current().mode)


# ------------------------------------------------------------------------------------------------ scenarios

## Separation 0 to 0.998 of the antipode and back, across the seam.
func _out_and_back(dy: float) -> Dictionary:
	var W: float = SimConst.W
	var ax: float = W - 3000.0
	_pose(ax, 40.0, ax + 40.0, 40.0 + dy)
	_seed_rig()
	for _i in range(90):
		_tick_rig()
	var secs: float = 30.0 if render_mode else 100.0
	var n: int = int(secs * 60.0)
	var top: float = 0.998 * SimConst.HALF
	for k in range(n):
		# out over the first half, back over the second
		var q: float = float(k) / float(n / 2) if k < n / 2 else 2.0 - float(k) / float(n / 2)
		var sep: float = 40.0 + (top - 40.0) * q * q
		_pose(ax, 40.0, ax + sep, 40.0 + dy)
		_tick_rig()
	for _i in range(200):
		_tick_rig()
	return {}


## B moves through the antipode. dir +1: B keeps going right (u increases through HALF); -1: the other way.
func _antipode(dir: float, wobble: float, reduced: bool = false) -> Dictionary:
	_rig.reduced_motion = reduced
	var H: float = SimConst.HALF
	var ax: float = 30000.0
	var span: float = 12000.0
	var start_u: float = dir * (H - span)
	_pose(ax, 200.0, ax + start_u, 200.0)
	_seed_rig()
	for _i in range(200):
		_tick_rig()
	var n: int = 600
	for k in range(n):
		var u: float = dir * (H - span + 2.0 * span * float(k) / float(n))
		_pose(ax, 200.0, ax + u, 200.0)
		_tick_rig()
	for _i in range(200):
		_tick_rig()
	return {}


func _antipode_round_trip() -> Dictionary:
	var H: float = SimConst.HALF
	var ax: float = 30000.0
	var span: float = 12000.0
	_pose(ax, 200.0, ax + H - span, 200.0)
	_seed_rig()
	for _i in range(200):
		_tick_rig()
	var n: int = 400
	for k in range(n):
		_pose(ax, 200.0, ax + H - span + 2.0 * span * float(k) / float(n), 200.0)
		_tick_rig()
	for _i in range(150):
		_tick_rig()
	for k in range(n):
		_pose(ax, 200.0, ax + H + span - 2.0 * span * float(k) / float(n), 200.0)
		_tick_rig()
	for _i in range(200):
		_tick_rig()
	return {}


## Separation wobbling by +-amp around the antipode.
func _antipode_jitter(amp: float) -> Dictionary:
	var H: float = SimConst.HALF
	var ax: float = 30000.0
	_pose(ax, 200.0, ax + H - 8000.0, 200.0)
	_seed_rig()
	for _i in range(200):
		_tick_rig()
	var flips: Array = []
	var last: int = _rig.sigma_shown
	for k in range(1800):
		var u: float = H + amp * sin(0.05 * maxf(0.0, float(k - 100))) - (1.0 - clampf(float(k) / 100.0, 0.0, 1.0)) * 8000.0
		_pose(ax, 200.0, ax + u, 200.0)
		_tick_rig()
		if _rig.sigma_u != last:
			flips.append(float(_tick) / 60.0)
			last = _rig.sigma_u
	return {"flip_times": flips}


## Fighters at a large height difference passing each other (separation through zero), with a dead band of `amp`.
func _pass_through(dy: float, amp: float) -> Dictionary:
	var ax: float = 40000.0
	_pose(ax, 100.0, ax + 3000.0, 100.0 + dy)
	_seed_rig()
	for _i in range(200):
		_tick_rig()
	var n: int = 600
	for k in range(n):
		var q: float = float(k) / float(n)
		var u: float = 3000.0 - 6000.0 * q if amp == 0.0 else amp * sin(q * 40.0) + 3000.0 * (1.0 - clampf(float(k) / 120.0, 0.0, 1.0)) * (1.0 if k < 120 else 0.0)
		_pose(ax, 100.0, ax + u, 100.0 + dy)
		_tick_rig()
	for _i in range(200):
		_tick_rig()
	return {}


## The separation oscillates +-10% around the split line (in the r metric), slowly and fast.
func _line_jitter(lo: float, hi: float, r_line: float) -> Dictionary:
	var ax: float = 30000.0
	# the separation at which r = r_line (level, tier 1)
	var z: float = r_line * vh / CamParams.BODY_H
	var d_line: float = vw / z - CamParams.REF_MARGIN_X
	_pose(ax, 40.0, ax + d_line * 0.5, 40.0)
	_seed_rig()
	for _i in range(120):
		_tick_rig()
	for k in range(2400):
		var s: float = d_line * (lo + (hi - lo) * (0.5 + 0.5 * sin(float(k) * 0.12)))
		_pose(ax, 40.0, ax + s, 40.0)
		_tick_rig()
	return {}


func _slam(feint: bool) -> Dictionary:
	var ax: float = 50000.0
	var sep: float = 5000.0
	_pose(ax, 40.0, ax + sep, 40.0)
	_seed_rig()
	for _i in range(150):
		_tick_rig()
	var A = _S.fighters[0]
	var B = _S.fighters[1]
	_check(_rig.split_wanted and _rig.sep > 0.99, "%s: not split before the rush" % _label)
	# A rushes at B for 0.6 s, the way stepRush does: a fraction dt / remaining of the gap each tick.
	var r := SimState.Rush.new()
	r.tgt = B
	r.off = -A.face * 60.0
	r.end = _S.T + 0.6
	A.rush = r
	var ticks: int = 0
	while A.rush != null and ticks < 100:
		var rem: float = r.end - _S.T
		var tx: float = B.x + r.off
		if feint and ticks == 12:
			A.rush = null
			break
		if rem <= SplitRig.DT:
			A.x = SimWrap.wrap(tx)
			A.rush = null
		else:
			A.x = SimWrap.wrap(A.x + SimWrap.sdx(A.x, tx) * SplitRig.DT / rem)
		_tick_rig()
		ticks += 1
		if A.rush == null:
			break
	_allow_cut_frames = 0
	for _i in range(150):
		_tick_rig()
	if not feint:
		_check(_rig.sep <= 0.001, "%s: still two panes after the slam" % _label)
	else:
		_check(_rig.sep >= 0.99, "%s: the feint left the panes open" % _label)
	return {}


func _launch(speed: float, dist: float, vertical: bool = false) -> Dictionary:
	var ax: float = 60000.0
	_pose(ax, 40.0, ax + 500.0, 40.0)
	_seed_rig()
	for _i in range(120):
		_tick_rig()
	var B = _S.fighters[1]
	B.state = "launched"
	if vertical:
		# straight up and back down in 0.6 s, so the landing is beside the other fighter
		var T: float = 0.6
		var n: int = int(T * 60.0)
		for k in range(n):
			var t: float = float(k) * SplitRig.DT
			B.y = 40.0 + speed * t * (1.0 - t / T)
			B.vy = speed * (1.0 - 2.0 * t / T)
			_tick_rig()
		B.y = 40.0
		B.vy = 0.0
	else:
		var flight: float = clampf(dist / maxf(speed, 1.0), 0.2, 6.0)
		B.vx = dist / flight
		var n2: int = int(flight * 60.0)
		for k in range(n2):
			B.x = SimWrap.wrap(B.x + B.vx * SplitRig.DT)
			_tick_rig()
	B.state = "down"
	B.vx = 0.0
	for _i in range(360):
		_tick_rig()
	return {}


## A brunt: B is launched toward a building 6,000 units away in the row at depth z, its z eases there, it hits (a
## building_hit event) and eases back. The camera has to keep B on screen at a readable size the whole way.
func _depth(zrow: float, gap: float) -> Dictionary:
	var ax: float = 70000.0
	_pose(ax, 40.0, ax + gap, 40.0)
	_seed_rig()
	for _i in range(200):
		_tick_rig()
	var A = _S.fighters[0]
	var B = _S.fighters[1]
	var ld := SimState.FxEvent.new()
	ld.type = "launch_depth"
	ld.victim = 1.0
	ld.owner = 0.0
	ld.x1 = B.x + 6000.0
	ld.y1 = 300.0
	ld.z = zrow
	ld.dur = 1.0
	var le := SimState.FxEvent.new()
	le.type = "launch"
	le.actor = 1.0
	B.state = "launched"
	B.vx = 5000.0
	var min_px: float = 1e9
	var max_off: float = 0.0
	var total: int = 90
	for k in range(total):
		var t: float = float(k) * SplitRig.DT
		B.x = SimWrap.wrap(B.x + B.vx * SplitRig.DT)
		B.y = 40.0 + 260.0 * smoothstep(0.0, 0.8, t)
		B.z = zrow * smoothstep(0.0, 0.7, t)
		var evs: Array = []
		if k == 0:
			evs = [le, ld]
		if k == 60:
			var bh := SimState.FxEvent.new()
			bh.type = "building_hit"
			bh.victim = 1.0
			bh.link = 1
			evs = [bh]
		if k > 60:
			B.z = zrow * (1.0 - smoothstep(0.0, 0.3, t - 1.0))
		_tick_rig(evs)
		var cur: SplitFrame = _rig.current()
		# The pane that has B: his own while two panes or his expanded pane are up, else the one view (pane 0).
		var pi: int = 1 if cur.shows(1) else 0
		var p: Vector2 = cur.screen_pos(pi, B.x, B.y + CamParams.CHEST, B.z)
		var px: float = CamParams.BODY_H * cur.cam_z[pi] * cur.depth_scale(pi, B.z)
		if cur.mode == "solo" or cur.mode == "split":
			min_px = minf(min_px, px)
			max_off = maxf(max_off, maxf(maxf(-p.x, p.x - vw), maxf(-p.y, p.y - vh)))
	B.state = "down"
	B.vx = 0.0
	B.z = 0.0
	for _i in range(300):
		_tick_rig()
	# The back row can reach about 25 px at the zoom cap (depth-and-chains.md); the others keep their 40 px or so.
	var want: float = 20.0 if zrow < -2000.0 else 28.0
	_check(min_px >= want * vh / 720.0, "%s: the deep fighter shrank to %.1f px (want at least %.0f)" % [_label, min_px, want * vh / 720.0])
	_check(max_off <= 0.0, "%s: the deep fighter left the screen by %.0f px" % [_label, max_off])
	stats["depth min px " + _label] = "%.1f px, worst off-screen %.0f px" % [min_px, max_off]
	return {}


func _transformation() -> Dictionary:
	var ax: float = 20000.0
	_pose(ax, 40.0, ax + 6000.0, 40.0)
	_seed_rig()
	for _i in range(200):
		_tick_rig()
	var ev := SimState.FxEvent.new()
	ev.type = "cinematic_start"
	ev.actor = 0.0
	ev.kind = "transformation"
	ev.dur = 3.0
	_tick_rig([ev])
	for _i in range(120):
		_tick_rig()
	_check(_rig.e > 0.99 and absf(_rig.sliver - CamParams.CINE_SLIVER) < 1e-6, "%s: the transformer's pane did not take the screen" % _label)
	var cur: SplitFrame = _rig.current()
	_check(bool(cur.active[1]), "%s: the opponent's sliver is not rendered" % _label)
	var end := SimState.FxEvent.new()
	end.type = "cinematic_end"
	end.actor = 0.0
	for _i in range(60):
		_tick_rig()
	_tick_rig([end])
	for _i in range(200):
		_tick_rig()
	_check(_rig.e < 0.001, "%s: the pane did not give the screen back" % _label)
	return {}


func _tier_push() -> Dictionary:
	var ax: float = 20000.0
	_pose(ax, 40.0, ax + 400.0, 40.0)
	_seed_rig()
	for _i in range(120):
		_tick_rig()
	var z0: float = _rig.current().cam_z[0]
	var ev := SimState.FxEvent.new()
	ev.type = "tier_up"
	ev.actor = 0.0
	_tick_rig([ev])
	var zmax: float = 0.0
	for _i in range(120):
		_tick_rig()
		zmax = maxf(zmax, _rig.current().cam_z[0])
	_check(zmax > z0 * 1.08, "%s: no push (z %.3f to %.3f)" % [_label, z0, zmax])
	for _i in range(120):
		_tick_rig()
	_check(absf(_rig.current().cam_z[0] / z0 - 1.0) < 0.02, "%s: the push did not come back" % _label)
	return {}


func _fold() -> Dictionary:
	var ax: float = 20000.0
	_pose(ax, 40.0, ax + 6000.0, 40.0)
	_seed_rig()
	for _i in range(200):
		_tick_rig()
	var ev := SimState.FxEvent.new()
	ev.type = "fold_start"
	ev.x = ax + 3000.0
	ev.y = 300.0
	ev.r = 4000.0
	_tick_rig([ev])
	for _i in range(200):
		_tick_rig()
	_check(_rig.sep <= 0.001 and not _rig.split_wanted, "%s: the fold left the panes open" % _label)
	var un := SimState.FxEvent.new()
	un.type = "unfold"
	_tick_rig([un])
	for _i in range(300):
		_tick_rig()
	_check(_rig.split_wanted, "%s: no split after the unfold" % _label)
	return {}


func _solo_follow() -> Dictionary:
	_S.fighters[0].ai = null
	_S.fighters[1].ai = SimState.AiState.new()
	_rig.solo_split = false
	var ax: float = 20000.0
	_pose(ax, 40.0, ax + 500.0, 40.0)
	_seed_rig()
	for _i in range(60):
		_tick_rig()
	for k in range(600):
		_pose(ax, 40.0, ax + 500.0 + float(k) * 12.0, 40.0)
		_tick_rig()
	for _i in range(120):
		_tick_rig()
	var cur: SplitFrame = _rig.current()
	_check(cur.e_slot == 0 and cur.e > 0.99, "%s: the human's pane did not take the screen (e %.2f slot %d)" % [_label, cur.e, cur.e_slot])
	_check(not bool(cur.active[1]), "%s: the AI's pane is still rendered" % _label)
	for k in range(600):
		_pose(ax, 40.0, ax + 7700.0 - float(k) * 12.0, 40.0)
		_tick_rig()
	for _i in range(120):
		_tick_rig()
	_check(_rig.sep <= 0.001, "%s: no merge on the way back" % _label)
	return {}


func _shake_panes() -> Dictionary:
	var ax: float = 20000.0
	_pose(ax, 40.0, ax + 9000.0, 40.0)
	_seed_rig()
	for _i in range(200):
		_tick_rig()
	var ev := SimState.FxEvent.new()
	ev.type = "shake"
	ev.k = 20.0
	ev.x = _S.fighters[0].x
	var tk := SimState.FxEvent.new()
	tk.type = "tick"
	tk.dt = SplitRig.DT
	tk.frozen = false
	_tick_rig([ev, tk])
	var f0: float = _rig.current().shake[0]
	var f1: float = _rig.current().shake[1]
	var decay: float = pow(CamParams.SHAKE_DECAY, SplitRig.DT)
	_check(f0 > 20.0 * decay * 0.8 and f0 <= 20.0 * decay + 1e-9, "%s: near pane shake %.3f, want 80 to 100%% of %.3f (the fighter sits a little off the pane centre)" % [_label, f0, 20.0 * decay])
	_check(f1 < f0 * 0.15 and f1 > 0.0, "%s: far pane shake %.3f is not about 12%% of the near pane's %.3f" % [_label, f1, f0])
	var frozen := SimState.FxEvent.new()
	frozen.type = "tick"
	frozen.dt = SplitRig.DT
	frozen.frozen = true
	_tick_rig([frozen])
	_check(absf(_rig.current().shake[0] - f0) < 1e-9, "%s: shake decayed during a hit-stop freeze" % _label)
	for _i in range(120):
		_tick_rig()
	_check(_rig.current().shake[0] < 0.01, "%s: shake did not die away" % _label)
	return {}


func _hard_cut() -> Dictionary:
	var ax: float = 20000.0
	_pose(ax, 40.0, ax + 400.0, 40.0)
	_seed_rig()
	for _i in range(120):
		_tick_rig()
	_pose(ax + 60000.0, 40.0, ax + 60400.0, 40.0)
	var ev := SimState.FxEvent.new()
	ev.type = "relocate"
	_allow_cut_frames = 3
	_tick_rig([ev])
	_check(_rig.current().cut, "%s: the cut was not flagged" % _label)
	var f = _rig.frame(0.5)
	_check(f.cut, "%s: a cut frame was interpolated" % _label)
	for _i in range(60):
		_tick_rig()
	var fr: SplitFrame = _rig.current()
	var p: Vector2 = fr.screen_pos(0, _S.fighters[0].x, _S.fighters[0].y + CamParams.CHEST)
	_check(absf(p.x - vw * 0.5) < vw * 0.3, "%s: the camera is not on the fighters after the cut" % _label)
	return {}


## With the panes merged and everything at rest, the merged frame is the reference camera's.
func _static_equals_reference() -> void:
	_begin("merged equals the reference camera")
	_pose(20000.0, 60.0, 20400.0, 260.0)
	_seed_rig()
	var ref := SimCamera.new()
	ref.x = _S.fighters[0].x
	ref.y = 100.0
	ref.z = 0.45
	for _i in range(900):
		_S.T += SplitRig.DT
		_rig.step(_S, vw, vh)
		ref.camStep(_S, SplitRig.DT, vw, vh)
	var fr: SplitFrame = _rig.current()
	var dx: float = absf(SimWrap.sdx(fr.cam_x[0], ref.x)) * ref.z
	var dy: float = absf(fr.cam_y[0] - ref.y) * ref.z
	var dz: float = absf(fr.cam_z[0] - ref.z) * vw / ref.z * 0.5
	_check(fr.mode == "merged", "merged equals reference: mode %s" % fr.mode)
	_check(dx < 0.5 and dy < 0.5 and dz < 0.5, "merged camera differs from the reference by %.3f, %.3f px and %.3f px of view width" % [dx, dy, dz])
	stats["merged vs reference camera"] = "%.4f px, %.4f px, zoom %.5f vs %.5f" % [dx, dy, fr.cam_z[0], ref.z]


# ------------------------------------------------------------------------------------------------ real matches

func _real_match(seed: int) -> void:
	_begin("real match %d" % seed)
	SimCore.newMatch(_S, seed, {"p1": true, "p2": true})
	_rig.reset(_S, vw, vh)
	_watch_first()
	_last_sigma = _rig.sigma_shown
	_S.dt = SplitRig.DT
	var t: int = 0
	var modes: Dictionary = {}
	var slams: int = 0
	var launches: int = 0
	var ko_seen: bool = false
	var readable_bad: int = 0
	var counted: int = 0
	var split_ticks: int = 0
	var solo_ticks: int = 0
	var last_change_t: float = -9.0
	var gaps_bad: int = 0
	var ncm: int = 0
	while t < match_ticks and not (_S.game.ko != null and _S.game.koT > 3.0):
		SimCore.step(_S)
		var ev: Array = _S.out.fx.duplicate()
		_S.out.fx.clear()
		_S.out.feed.clear()
		t += 1
		_rig.step(_S, vw, vh, ev)
		_tick += 1
		_watch()
		var cur: SplitFrame = _rig.current()
		if trace_seed == seed and float(t) / 60.0 >= trace_t0 and float(t) / 60.0 <= trace_t1:
			var f0 = _S.fighters[0]
			var f1 = _S.fighters[1]
			var p0: Vector2 = cur.screen_pos(0, f0.x, f0.y + CamParams.CHEST)
			var p1: Vector2 = cur.screen_pos(1, f1.x, f1.y + CamParams.CHEST)
			print("  T %.3f %s sep %.2f e %.2f slam %d rush0 %s rush1 %s p0 (%.0f,%.0f) p1 (%.0f,%.0f) x0 %.0f x1 %.0f vx0 %.0f cam0 %.0f/%.0f/%.3f cam1 %.0f/%.0f/%.3f" % [float(t) / 60.0, cur.mode, cur.sep, cur.e, _rig._slam_slot, f0.rush != null, f1.rush != null, p0.x, p0.y, p1.x, p1.y, f0.x, f1.x, f0.vx, cur.cam_x[0], cur.cam_y[0], cur.cam_z[0], cur.cam_x[1], cur.cam_y[1], cur.cam_z[1]])
		modes[cur.mode] = int(modes.get(cur.mode, 0)) + 1
		if cur.slam:
			slams += 1
		if cur.mode == "split":
			split_ticks += 1
		if cur.mode == "solo":
			solo_ticks += 1
		# readability: a fighter under 0.8 of the split line in a one-view frame, outside launches and cinematics
		if cur.mode == "merged":
			counted += 1
			var z: float = cur.cam_z[0]
			if CamParams.BODY_H * z / vh < CamParams.R_SPLIT * 0.6 and _rig.r_now > 0.0:
				readable_bad += 1
		var mct: Array = _rig.mode_change_times()
		while ncm < mct.size():
			var tt: float = float(mct[ncm])
			var why: String = String(_rig.mode_change_reasons()[ncm])
			# Trigger-driven changes keep the dwell; a shot's ending, a slam and a fighter lost off the edge do not.
			if tt - last_change_t < CamParams.MODE_CHANGE_GAP - 1e-6 and not _rig.launch_decision_at(tt) and not why.contains("slam") and not why.contains("out of frame"):
				gaps_bad += 1
				print("  gap %.2f s at t=%.2f: %s (previous: %s)" % [tt - last_change_t, tt, _rig.mode_change_reasons()[ncm], _rig.mode_change_reasons()[ncm - 1] if ncm > 0 else "-"])
			last_change_t = tt
			ncm += 1
	_check(gaps_bad == 0, "%s: %d layout changes closer than %.1f s" % [_label, gaps_bad, CamParams.MODE_CHANGE_GAP])
	_check(float(readable_bad) / maxf(1.0, float(counted)) < 0.02, "%s: %d of %d merged ticks show a fighter under 60%% of the split line" % [_label, readable_bad, counted])
	var mods: Array = []
	for k in modes:
		mods.append("%s %d" % [k, modes[k]])
	stats[_label] = "%d ticks: %s; layout changes %d, slams %d" % [t, ", ".join(PackedStringArray(mods)), _rig.mode_change_times().size(), slams]
	SimCore.dispose(_S)
	_S = null


## The sim's gameplay hash after a match is the same whether or not the rig ran beside it.
func _sim_unchanged() -> void:
	var seed: int = int(seeds[0]) if not seeds.is_empty() else 3
	var hashes: Array = []
	for with_rig in [false, true]:
		var S := SimCore.createSim()
		SimCore.newMatch(S, seed, {"p1": true, "p2": true})
		var rig := SplitRig.new()
		if with_rig:
			rig.reset(S, vw, vh)
		for _i in range(1800):
			SimCore.step(S)
			var ev: Array = S.out.fx.duplicate()
			S.out.fx.clear()
			S.out.feed.clear()
			if with_rig:
				rig.step(S, vw, vh, ev)
				rig.frame(0.5)
		hashes.append(SimHash.stateHash(S).gameplay)
		SimCore.dispose(S)
	_check(hashes[0] == hashes[1], "the sim's gameplay hash changed with the rig running: %s vs %s" % [hashes[0], hashes[1]])
	stats["sim hash with and without the rig"] = "%s == %s" % [hashes[0], hashes[1]]


# ------------------------------------------------------------------------------------------------ the composite

## Draw the recorded frames through SplitView and the stand-in panes, read the picture back and look for pops.
func _replay(label: String) -> void:
	var diffs: PackedFloat64Array = PackedFloat64Array()
	var modes: Array = []
	var prev: PackedFloat32Array = PackedFloat32Array()
	var shot_at: Dictionary = {}
	var last_mode: String = ""
	for k in range(_queue.size()):
		var fr: SplitFrame = _queue[k][0]
		if fr.mode != last_mode:
			shot_at[k + 3] = fr.mode
			last_mode = fr.mode
	for k in range(_queue.size()):
		var e: Array = _queue[k]
		var fr: SplitFrame = e[0]
		if dump_label == label and k >= dump_from and k <= dump_to:
			print("  DUMP k=%d mode %s cam1 %.3f/%.3f/%.5f f1 %s cam0 %.3f" % [k, fr.mode, fr.cam_x[1], fr.cam_y[1], fr.cam_z[1], e[2], fr.cam_x[0]])
		stand_in.render_frame(fr, [e[1], e[2]])
		await RenderingServer.frame_post_draw
		var img: Image = root.get_texture().get_image()
		if shots_dir != "" and dump_label == label and k >= dump_from and k <= dump_to:
			img.save_png("%s/dump_%s_%04d.png" % [shots_dir, label.replace(" ", "_").replace("=", ""), k])
		if shots_dir != "" and shot_at.has(k):
			img.save_png("%s/split_%s_%03d_%s.png" % [shots_dir, label.replace(" ", "_").replace("=", ""), k, shot_at[k]])
		img.resize(160, 90, Image.INTERPOLATE_BILINEAR)
		var g: PackedFloat32Array = PackedFloat32Array()
		g.resize(160 * 90)
		var data: PackedByteArray = img.get_data()
		var bpp: int = 4 if img.get_format() == Image.FORMAT_RGBA8 else 3
		for q in range(160 * 90):
			g[q] = 0.299 * data[q * bpp] + 0.587 * data[q * bpp + 1] + 0.114 * data[q * bpp + 2]
		if not prev.is_empty():
			var d: float = 0.0
			for q in range(g.size()):
				d += absf(g[q] - prev[q])
			diffs.append(d / float(g.size()))
			modes.append(fr.mode)
		prev = g
	var worst: float = 0.0
	var spikes: int = 0
	for k in range(1, diffs.size() - 1):
		var ratio: float = diffs[k] / (0.5 * (diffs[k - 1] + diffs[k + 1]) + 0.5)
		var authored: bool = modes[k] == "slam" or modes[k - 1] == "slam" or modes[k + 1] == "slam" or modes[k] == "swing"
		if not authored:
			worst = maxf(worst, ratio)
			if ratio > SPIKE:
				spikes += 1
				print("  spike %s frame %d mode %s/%s ratio %.1f diffs %.2f %.2f %.2f sep %.3f" % [label, k, modes[k - 1], modes[k], ratio, diffs[k - 1], diffs[k], diffs[k + 1], _queue[k][0].sep])
	render_spikes[label] = worst
	stats["picture " + label] = "%d frames, worst spike ratio %.2f, spikes over %.0f: %d" % [_queue.size(), worst, SPIKE, spikes]
	_check(spikes == 0, "%s: %d picture spikes (worst ratio %.1f)" % [label, spikes, worst])
	_queue.clear()
