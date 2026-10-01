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
const REPLAYED: Array = ["out and back dy=0", "antipode right", "antipode left", "pass-through", "slam", "slam feint", "launch far 10816", "launch up and down 10816", "transformation", "panel signature", "panel modes"]
const SPIKE: float = 4.0   # a frame-to-frame picture change this many times its neighbours' is a pop

var vw: float = 1280.0
var vh: float = 720.0
var seeds: Array = [3, 10, 17]
var match_ticks: int = 3600
const FULL_TICKS: int = 36000   # ten minutes
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
var only: String = ""
var _contact: Dictionary = {}
var _bn: Array = []             # bounces being watched: how far the fighter moves in the world and on the screen after one
var _bn_done: Array = []
var _intro_ref: Array = []
var _jr: Array = [null, null]            # a launched fighter's journey in progress, by victim slot
var _jr_done: Array = []                 # the journeys that ended, for the match's summary
var _jr_lay: UiLayout = null             # UI's layout, to ask whether it would draw an edge pointer
var _punch_seen_t: float = -9.0
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
		elif a.begins_with("--only="):
			only = a.substr(7)
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
	for sp2 in [26718.0, 45606.0]:
		await _scenario("launch split %d" % int(sp2), func(): return _launch(sp2, 20000.0, false, 9000.0), {})
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
	for pitch in [11.0, 49.0]:
		for row in [[-600.0, "front street"], [-2025.0, "block row 2"]]:
			await _scenario("depth %s at pitch %d one view" % [row[1], int(pitch)], func(): return _depth(float(row[0]), 600.0, float(pitch)), {})
			await _scenario("depth %s at pitch %d split" % [row[1], int(pitch)], func(): return _depth(float(row[0]), 9000.0, float(pitch)), {})
	for iv in ["full", "humans", "reduced", "skip"]:
		await _scenario("intro %s" % iv, func(): return _intro_run(iv), {})
	await _scenario("panel signature", func(): return _panel_basic(), {})
	await _scenario("panel ration and priority", func(): return _panel_ration(), {})
	await _scenario("panel event and beam are one", func(): return _panel_dedupe(), {})
	await _scenario("panel riposte", func(): return _panel_riposte(), {})
	for fl in [[0.156, 0], [0.19, 0], [0.209, 1], [0.269, 1]]:
		await _scenario("panel floor %.3f" % float(fl[0]), func(): return _panel_floor(float(fl[0]), int(fl[1])), {})
	await _scenario("panel modes", func(): return _panel_modes(), {})
	for pose in [[400.0, 0.0], [400.0, 700.0], [1500.0, 1200.0], [400.0, 2000.0], [6000.0, 0.0], [1500.0, 3500.0]]:
		await _scenario("panel band dx %d dy %d" % [int(pose[0]), int(pose[1])], func(): return _panel_band_pose(float(pose[0]), float(pose[1])), {})
	for wk in [["right", 1, false], ["left", -1, false], ["none", 0, false], ["reduced motion", 1, true]]:
		await _scenario("shot winner in the wreckage, %s" % wk[0], func(): return _shot_wreck(int(wk[1]), bool(wk[2])), {})
	await _scenario("shot transformation full", func(): return _shot_transform_full(), {})
	for pref in [0.0, 3.0, 10.0]:
		await _scenario("shot transformation low angle, zoom setting %d" % int(pref), func(): return _shot_transform_limit(pref), {})
	await _scenario("shot transformation short", func(): return _shot_transform_short(), {})
	await _scenario("shot live transformation step", func(): return _shot_live_step(), {})
	await _scenario("shot world pause pull-out", func(): return _shot_world_pause(), {})
	await _scenario("shot finisher", func(): return _shot_finisher(), {})
	await _scenario("shot crippling cut-in and cooldown", func(): return _shot_cripple(), {})
	await _scenario("shot building smash cut-in", func(): return _shot_smash(), {})
	await _scenario("shot beam struggle push", func(): return _shot_clash(), {})
	await _scenario("hybrid hold and cut", func(): return _hybrid(1, 20000.0), {})
	await _scenario("hybrid launched human chases", func(): return _hybrid_chased(), {})
	await _scenario("hybrid two humans split", func(): return _hybrid(2, 20000.0), {})
	_static_equals_reference()
	await _projection_matches_the_rig()
	# 8. Real AI matches (and a few with a human fighter idle, or a raised camera), then the determinism of the sim.
	for seed in seeds:
		_real_match(int(seed))
	for k in range(mini(3, seeds.size())):
		_real_match(int(seeds[k]), 1 - (k % 2), 0.0)
	if not seeds.is_empty():
		_real_match(int(seeds[0]), -1, 49.0)
		# Matches now run 7 to 10 minutes: one full-length match flat and one raised, and one with a human slot, to the KO
		# or ten minutes (QA found three defects only after 230 s).
		_real_match(int(seeds[seeds.size() - 1]), -1, 0.0, FULL_TICKS)
		_real_match(int(seeds[0]), -1, 49.0, FULL_TICKS)
		_real_match(int(seeds[mini(1, seeds.size() - 1)]), 1, 0.0, FULL_TICKS)
		_real_match(int(seeds[0]), -1, 0.0, FULL_TICKS, 0)
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
	if only != "" and not label.contains(only):
		return
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
	_probe_max = 0.0
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
		# A shot on one fighter (a launch, a cut-in), its ease back to the pair (solo_w), and an expanded pane (e) leave the
		# other fighter out of the picture by design.
		var excluded: bool = (_rig.solo_kind != "" and _rig.solo_slot != i) or (_rig._ov_kind != "" and _rig._ov_slot != i) or _rig.solo_w > 0.001 or fr.e > 0.001
		# A pair that has just passed each other and whose split opens before the flip can happen (the flip waits for the
		# dwell, for them to stop being merge-close and for the panes to be one view or full apart) opens with the old sides.
		excluded = excluded or ((fr.mode == "opening" or fr.mode == "closing") and _rig.orientation_pending())
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
			if _offscreen_t[i] > (0.60 if _label == "fold" else 0.30):   # the fold's wide shot is an authored transition
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
			if _rig._punch_t >= 0.0:
				_punch_seen_t = _disp_t
			var punching: bool = _disp_t - _punch_seen_t < 0.2
			if not slam_now and not moved_cut and dz > zlim * TOL + 0.3 * (CamParams.TIER_PUSH if _push_active() else 0.0) + (2.0 * CamParams.LIVE_PUNCH / CamParams.LIVE_PUNCH_LEN if punching else 0.0):
				_fail_once("zoom", "%s: pane %d zoom rate %.2f e-folds a second (limit %.2f) at t=%.2f mode %s sep %.3f e %.2f solo_w %.2f" % [_label, i, dz, zlim, float(_tick) / 60.0, fr.mode, fr.sep, fr.e, _rig.solo_w])
			var da: float = (fr.anchor[i] - _prev_disp.anchor[i]).length() / vw * (60.0 / DISPLAY_HZ)
			var seen: bool = fr.sep > 0.02 and _prev_disp.sep > 0.02
			if seen:
				_note("anchor_step", da)
			if seen and not slam_now and not moved_cut and da > CamParams.ANCHOR_STEP_TRANS * TOL:
				_fail_once("anchor_move", "%s: pane %d anchor moved %.3f of the width in a tick at t=%.2f mode %s/%s sep %.3f solo %s" % [_label, i, da, float(_tick) / 60.0, _prev_disp.mode, fr.mode, fr.sep, _rig.solo_kind])
		var dc: float = (fr.c - _prev_disp.c).length() / vw * (60.0 / DISPLAY_HZ)
		var divider_seen: bool = bool(fr.active[1]) and bool(_prev_disp.active[1]) and fr.line_alpha > 0.0 and _prev_disp.line_alpha > 0.0
		if divider_seen:
			_note("divider_step", dc)
		if divider_seen and not slam_now and not moved_cut and dc > CamParams.DIVIDER_STEP * TOL:
			_fail_once("divider", "%s: the divider moved %.3f of the width in a tick at t=%.2f mode %s/%s sep %.3f c %s -> %s" % [_label, dc, float(_tick) / 60.0, _prev_disp.mode, fr.mode, fr.sep, str(_prev_disp.c), str(fr.c)])
		var dth: float = absf(angle_difference(_prev_disp.theta, fr.theta)) / dt
		if divider_seen:
			_note("divider_deg_per_s_outside_swing", rad_to_deg(dth) if (fr.swing < 0.0 and _prev_disp.swing < 0.0) else 0.0)
		if divider_seen and fr.swing < 0.0 and _prev_disp.swing < 0.0 and not slam_now and not moved_cut and dth > CamParams.TILT_RATE_MAX * TOL * 1.5:
			_fail_once("tilt", "%s: the divider turned %.0f degrees a second outside a swing at t=%.2f mode %s/%s sep %.3f theta %.3f -> %.3f" % [_label, rad_to_deg(dth), float(_tick) / 60.0, _prev_disp.mode, fr.mode, fr.sep, _prev_disp.theta, fr.theta])
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
var _probe_max: float = 0.0
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
	var d_line: float = vw / z - CamParams.FIT_MARGIN_X
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


## The launched fighter's offset from where the camera means him to be, in screen widths (the lag bound's number).
func _probe(slot: int) -> void:
	var cur: SplitFrame = _rig.current()
	var f = _S.fighters[slot]
	var pi: int = 1 if cur.shows(1) else 0
	var off: float = (cur.screen_pos(pi, f.x, f.y + CamParams.CHEST, float(f.z)) - cur.anchor[slot]).length() / vw
	_probe_max = maxf(_probe_max, off)


func _launch(speed: float, dist: float, vertical: bool = false, gap: float = 500.0) -> Dictionary:
	var ax: float = 60000.0
	_pose(ax, 40.0, ax + gap, 40.0)
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
			_probe(1)
	B.state = "down"
	B.vx = 0.0
	for _i in range(360):
		_tick_rig()
	if not vertical and speed >= CamParams.LAUNCH_MIN_SPEED:
		_check(_probe_max <= CamParams.LAG_HARD + 0.01, "%s: the launched fighter was %.3f of the width from his anchor (bound %.2f)" % [_label, _probe_max, CamParams.LAG_HARD])
		_check(_rig.lag_cuts == 0, "%s: %d safety cuts in a launch" % [_label, _rig.lag_cuts])
		stats["lag bound " + _label] = "worst %.3f of the width, whips %d, cuts %d" % [_probe_max, _rig.lag_whips, _rig.lag_cuts]
	return {}


## A brunt: B is launched toward a building 6,000 units away in the row at depth z, its z eases there, it hits (a
## building_hit event) and eases back. The camera has to keep B on screen at a readable size the whole way.
func _depth(zrow: float, gap: float, pitch: float = 0.0) -> Dictionary:
	_rig.pitch_deg = pitch
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
		var px: float = cur.apparent_height(pi, B.x, B.y, B.z)
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
	if pitch > 0.0:
		want *= 0.7   # a raised camera sees a deep standing fighter smaller (docs/camera/camera-v2.md section 8)
	_check(min_px >= want * vh / 720.0, "%s: the deep fighter shrank to %.1f px (want at least %.0f)" % [_label, min_px, want * vh / 720.0])
	_check(max_off <= 0.0, "%s: the deep fighter left the screen by %.0f px" % [_label, max_off])
	stats["depth min px " + _label] = "%.1f px, worst off-screen %.0f px" % [min_px, max_off]
	return {}


## The hybrid launch rule. humans = 1: the human is slot 0, who launches slot 1 (AI) 20,000 units away: the camera stays on
## the human, cuts to the impact for 0.5 s, then returns. humans = 2: both are human, so the split opens and a pane chases.
func _hybrid(humans: int, dist: float) -> Dictionary:
	var ax: float = 70000.0
	_S.fighters[0].ai = null
	if humans >= 2:
		_S.fighters[1].ai = null
	_pose(ax, 40.0, ax + 600.0, 40.0)
	_seed_rig()
	for _i in range(200):
		_tick_rig()
	var B = _S.fighters[1]
	var A = _S.fighters[0]
	B.state = "launched"
	var flight: float = 1.0
	B.vx = dist / flight
	var max_human_off: float = 0.0
	var holds: int = 0
	var cuts: int = 0
	var cut_visible: bool = true
	var saw_split: bool = false
	for k in range(60):
		B.x = SimWrap.wrap(B.x + B.vx * SplitRig.DT)
		B.y = 40.0 + 200.0 * smoothstep(0.0, 0.7, float(k) * SplitRig.DT)
		_tick_rig()
		var cur: SplitFrame = _rig.current()
		if _rig.solo_kind == "hold":
			holds += 1
		if _rig.solo_kind == "cut":
			cuts += 1
			var pv: Vector2 = cur.screen_pos(1 if cur.shows(1) else 0, B.x, B.y + CamParams.CHEST, B.z)
			cut_visible = cut_visible and pv.x >= 0.0 and pv.x <= vw and pv.y >= 0.0 and pv.y <= vh
		if cur.mode == "split" or cur.mode == "opening":
			saw_split = true
		if _rig.solo_kind == "hold":
			var ph: Vector2 = cur.screen_pos(0, A.x, A.y + CamParams.CHEST, A.z)
			max_human_off = maxf(max_human_off, maxf(maxf(-ph.x, ph.x - vw), maxf(-ph.y, ph.y - vh)))
	B.state = "down"
	B.vx = 0.0
	var cut_frames: int = 0
	var end_modes: Array = []
	for _i in range(150):
		_tick_rig()
		if _rig.solo_kind == "cut":
			cuts += 1
		if _rig.current().cut:
			cut_frames += 1
	if humans == 1:
		_check(holds > 0, "%s: the camera never held on the attacker" % _label)
		_check(cuts > 0 and cuts <= int(CamParams.CUT_SHOT * 60.0) + 2, "%s: the impact cut lasted %d ticks (want about %d)" % [_label, cuts, int(CamParams.CUT_SHOT * 60.0)])
		_check(cut_visible, "%s: the victim was off screen during the impact cut" % _label)
		_check(max_human_off <= 0.0, "%s: the human fighter left the screen by %.0f px while the camera held on him" % [_label, max_human_off])
		_check(not saw_split, "%s: the split opened although the human was held on" % _label)
		_check(_rig.solo_kind == "", "%s: the shot did not end" % _label)
	else:
		_check(holds == 0 and cuts == 0, "%s: two humans got a hold or a cut (holds %d cuts %d)" % [_label, holds, cuts])
		_check(saw_split, "%s: the split did not open for the launch" % _label)
	stats["hybrid " + _label] = "holds %d, cut ticks %d, cut frames %d, human off %.0f px, split %s" % [holds, cuts, cut_frames, max_human_off, str(saw_split)]
	return {}


## The human is launched: the chase, as before.
func _hybrid_chased() -> Dictionary:
	var ax: float = 70000.0
	_S.fighters[1].ai = null
	_pose(ax, 40.0, ax + 600.0, 40.0)
	_seed_rig()
	for _i in range(200):
		_tick_rig()
	var B = _S.fighters[1]
	B.state = "launched"
	B.vx = 20000.0
	var chased: bool = false
	for k in range(60):
		B.x = SimWrap.wrap(B.x + B.vx * SplitRig.DT)
		_tick_rig()
		if _rig.solo_kind == "launch" and _rig.solo_slot == 1:
			chased = true
	B.state = "down"
	B.vx = 0.0
	for _i in range(150):
		_tick_rig()
	_check(chased, "%s: the launched human was not chased" % _label)
	return {}


func _apparent_px(slot: int, fr: SplitFrame) -> float:
	var f = _S.fighters[slot]
	var pi: int = slot if fr.shows(slot) else 0
	return fr.apparent_height(pi, f.x, f.y, float(f.z))


func _shot_events(type: String, fields: Dictionary) -> SimState.FxEvent:
	var ev := SimState.FxEvent.new()
	ev.type = type
	for k in fields:
		ev.set(k, fields[k])
	return ev


## A finisher: cut to the loser and dolly in over the sim's lock.
func _shot_finisher() -> Dictionary:
	var ax: float = 20000.0
	_pose(ax, 40.0, ax + 300.0, 40.0)
	_seed_rig()
	for _i in range(200):
		_tick_rig()
	var dur: float = 3.0
	_tick_rig([_shot_events("finisher_start", {"actor": 0.0, "target": 1.0, "dur": dur})])
	var cut_frames: int = 1 if _rig.current().cut else 0
	var first: float = _apparent_px(1, _rig.current())
	var last: float = first
	for k in range(int(dur * 60.0)):
		_tick_rig()
		if _rig.current().cut:
			cut_frames += 1
		last = _apparent_px(1, _rig.current())
	for _i in range(200):
		_tick_rig()
	_check(cut_frames == 1, "%s: %d cut frames at the start of a finisher (want one)" % [_label, cut_frames])
	_check(last > first * 1.2, "%s: no dolly: %.0f px to %.0f px" % [_label, first, last])
	_check(_rig.solo_kind == "", "%s: the shot did not end" % _label)
	stats["shot finisher sizes (px)"] = "%.0f to %.0f" % [first, last]
	return {}


## A crippling moment: a 0.8 s cut-in on the broken fighter, then back; further breaks inside the cooldown change nothing.
func _shot_cripple() -> Dictionary:
	var ax: float = 20000.0
	_pose(ax, 40.0, ax + 500.0, 40.0)
	_seed_rig()
	for _i in range(200):
		_tick_rig()
	var cuts: int = 0
	_tick_rig([_shot_events("region_broken", {"actor": 1.0, "region": "arms"})])
	if _rig.current().cut:
		cuts += 1
	var overlay_ticks: int = 0
	for k in range(120):
		var evs: Array = []
		if k % 20 == 5:
			evs = [_shot_events("region_broken", {"actor": 0.0, "region": "legs"})]
		_tick_rig(evs)
		if _rig.current().cut:
			cuts += 1
		if _rig._ov_kind != "":
			overlay_ticks += 1
	_check(_rig.cut_ins == 1, "%s: %d cut-ins inside the cooldown (want one)" % [_label, _rig.cut_ins])
	_check(cuts == 2, "%s: %d cut frames (want two: in and out)" % [_label, cuts])
	_check(absi(overlay_ticks - int(CamParams.OV_CRIPPLE_DUR * 60.0)) <= 2, "%s: the cut-in lasted %d ticks" % [_label, overlay_ticks])
	# after the cooldown a second one is allowed, and the per-minute cap holds
	for _i in range(int(CamParams.OV_COOLDOWN * 60.0)):
		_tick_rig()
	_tick_rig([_shot_events("region_broken", {"actor": 1.0, "region": "head"})])
	_check(_rig.cut_ins == 2, "%s: no cut-in after the cooldown (%d)" % [_label, _rig.cut_ins])
	for _round in range(10):
		for _i in range(int(CamParams.OV_COOLDOWN * 60.0) + 60):
			_tick_rig()
		_tick_rig([_shot_events("region_broken", {"actor": 1.0, "region": "head"})])
	_check(_rig.cut_ins <= CamParams.OV_MAX_PER_MIN + 4, "%s: %d cut-ins in %.0f s" % [_label, _rig.cut_ins, _rig.time])
	return {}


## A building smash: the first hit on a building of size cuts to a wide view of the wall for the sim's hold and a beat.
func _shot_smash() -> Dictionary:
	var ax: float = 20000.0
	_pose(ax, 40.0, ax + 500.0, 40.0)
	_seed_rig()
	for _i in range(200):
		_tick_rig()
	var cuts: int = 0
	var request_off: bool = false
	var hit := _shot_events("building_hit", {"victim": 1.0, "link": 1, "x": ax + 2500.0, "y": 300.0, "z": -600.0, "h": 1200.0})
	_tick_rig([hit])
	var overlay_ticks: int = 0
	var on_screen: bool = true
	for k in range(60):
		_tick_rig()
		if _rig.current().cut:
			cuts += 1
		if _rig._ov_kind != "":
			overlay_ticks += 1
			request_off = request_off or (not bool(_rig.current().cutaway[0]["request"]))
			var pt: Vector2 = _rig.current().screen_pos(0, ax + 2500.0, 300.0, -600.0)
			on_screen = on_screen and pt.x >= 0.0 and pt.x <= vw and pt.y >= 0.0 and pt.y <= vh
	_check(_rig.cut_ins == 1, "%s: %d cut-ins (want one)" % [_label, _rig.cut_ins])
	_check(absi(overlay_ticks - int(CamParams.OV_SMASH_DUR * 60.0)) <= 2, "%s: the cut-in lasted %d ticks" % [_label, overlay_ticks])
	_check(request_off, "%s: the cut-away stayed on during the smash cut (the wall should stay whole)" % _label)
	_check(on_screen, "%s: the wall was not in the cut-in" % _label)
	_check(cuts >= 1, "%s: no cut frames" % _label)
	return {}


## A beam struggle opens with a push on the shared view.
func _shot_clash() -> Dictionary:
	var ax: float = 20000.0
	_pose(ax, 40.0, ax + 1200.0, 40.0)
	_seed_rig()
	for _i in range(240):
		_tick_rig()
	var z0: float = _rig.current().cam_z[0]
	var c := SimState.Clash.new()
	c.A = _S.fighters[0]
	c.D = _S.fighters[1]
	c.t0 = _S.T
	c.dur = 2.0
	_S.game.clash = c
	var zmax: float = z0
	for _i in range(120):
		_tick_rig()
		zmax = maxf(zmax, _rig.current().cam_z[0])
	_S.game.clash = null
	_check(zmax > z0 * 1.06, "%s: no push at the clash (z %.3f to %.3f)" % [_label, z0, zmax])
	return {}


func _panel_ground() -> void:
	var ax: float = 20000.0
	_pose(ax, 0.0, ax + 600.0, 0.0)
	_seed_rig()
	for _i in range(200):
		_tick_rig()


## A signature fires: a new beam in the state for the tick.
func _fire(slot: int) -> void:
	var b := SimState.Beam.new()
	b.A = _S.fighters[slot]
	_S.beams.append(b)
	_tick_rig()
	_S.beams.clear()


func _panel_now() -> Dictionary:
	return _rig.current().panel


## A signature's fire beat opens a strip for the subject: about 54 ticks, wiped open then shut, in the top band, with
## the subject's upper body inside it, and the main view exactly as it would have been without it.
func _panel_basic() -> Dictionary:
	var ticks: Array = []
	var cams: Array = []
	for with_panel in [false, true]:
		_panel_ground()
		var cz: Array = []
		var n: int = 0
		var opens: Array = []
		var body_ok: bool = true
		var cuts: int = 0
		for k in range(120):
			if k == 10:
				if with_panel:
					_fire(0)
				else:
					_tick_rig([_shot_events("decisive", {"winner": 0.0, "loser": 1.0, "kind": "launch"})])
			else:
				_tick_rig()
			var fr: SplitFrame = _rig.current()
			cz.append([fr.cam_x[0], fr.cam_y[0], fr.cam_z[0]])
			if not fr.panel.is_empty():
				n += 1
				opens.append(float(fr.panel["open"]))
				if cuts == 0 and fr.cut:
					cuts += 1
				var p: Dictionary = fr.panel
				if n == 25:
					var f = _S.fighters[int(p["slot"])]
					var ph: float = float(p["size"].y)
					var z: float = float(p["cam_z"])
					var sy_head: float = ph * CamParams.PLANE_Y - ((f.y + 75.0) - float(p["cam_y"])) * z
					var sy_chest: float = ph * CamParams.PLANE_Y - ((f.y + 32.0) - float(p["cam_y"])) * z
					var sx: float = (SimWrap.sdx(float(p["cam_x"]), f.x)) * z + float(p["size"].x) * 0.5
					body_ok = sy_head >= 0.0 and sy_chest <= ph and sx > 0.2 * float(p["size"].x) and sx < 0.8 * float(p["size"].x)
					_check(p["band"] == 0 and p["kind"] == "signature" and int(p["slot"]) == 0, "%s: panel %s" % [_label, str(p)])
		ticks.append(n)
		cams.append(cz)
		if with_panel:
			_check(absi(n - 54) <= 2, "%s: the strip lasted %d ticks (want 54)" % [_label, n])
			_check(body_ok, "%s: the subject's upper body is not in the strip" % _label)
			_check(float(opens[0]) < 0.5 and float(opens[opens.size() / 2]) > 0.99 and float(opens[-1]) < 0.5, "%s: the wipe is not open, full, shut: %s" % [_label, str([opens[0], opens[opens.size() / 2], opens[-1]])])
			_check(cuts == 0, "%s: the strip cut the main view" % _label)
	var same: bool = true
	for k in range(120):
		for q in range(3):
			if absf(float(cams[0][k][q]) - float(cams[1][k][q])) > 1e-9:
				same = false
	_check(same, "%s: the main view changed while the strip was up" % _label)
	return {}


## Earned hits share one strip per 12 s; peaks always play; a stronger strip replaces a running weaker one.
func _panel_ration() -> Dictionary:
	_panel_ground()
	var clash := {"winner": 0.0, "loser": 1.0, "kind": "clash"}
	_tick_rig([_shot_events("decisive", clash)])
	_check(_rig.panels == 1, "%s: the first earned panel did not play" % _label)
	for _i in range(5 * 60):
		_tick_rig()
	_tick_rig([_shot_events("decisive", clash)])
	_check(_rig.panels == 1 and _rig.panels_dropped == 1, "%s: a second earned panel inside 12 s played (%d)" % [_label, _rig.panels])
	for _i in range(8 * 60):
		_tick_rig()
	_tick_rig([_shot_events("decisive", clash)])
	_check(_rig.panels == 2, "%s: the earned panel 13 s later was refused (%d)" % [_label, _rig.panels])
	# peaks: a signature, then another a second later (the first is shut by then): both play, whatever the ration
	for _i in range(90):
		_tick_rig()
	_fire(1)
	_check(_rig.panels == 3, "%s: the signature panel was refused" % _label)
	for _i in range(60):
		_tick_rig()
	_fire(0)
	_check(_rig.panels == 4, "%s: the second signature panel was refused" % _label)
	# an earned hit during a strip is dropped; a KO replaces the running signature
	_tick_rig([_shot_events("decisive", clash)])
	_check(_rig.panels == 4, "%s: an earned panel replaced a running signature" % _label)
	_tick_rig([_shot_events("ko", {"winner": 1.0, "loser": 0.0})])
	_check(_rig.panels == 5 and _panel_now()["kind"] == "ko" and int(_panel_now()["slot"]) == 1, "%s: the KO did not replace the signature (%s)" % [_label, str(_panel_now())])
	_fire(0)
	_check(_panel_now()["kind"] == "ko", "%s: a signature replaced the running KO strip" % _label)
	return {}


## A signature's `beam_outcome` event and its beam in the same tick make one panel.
func _panel_dedupe() -> Dictionary:
	_panel_ground()
	var b := SimState.Beam.new()
	b.A = _S.fighters[0]
	_S.beams.append(b)
	_tick_rig([_shot_events("beam_outcome", {"actor": 0.0, "target": 1.0, "kind": "HIT"})])
	_S.beams.clear()
	_check(_rig.panels == 1 and _rig.panels_dropped == 0, "%s: %d panels, %d refused" % [_label, _rig.panels, _rig.panels_dropped])
	_panel_ground()
	var before: int = _rig.panels
	_tick_rig([_shot_events("beam_outcome", {"actor": 1.0, "target": 0.0, "kind": "HIT"})])
	_check(_rig.panels == before + 1 and int(_panel_now()["slot"]) == 1, "%s: the event alone made no panel" % _label)
	return {}


## A launch within 2 s of the launcher's own parry is a riposte (earned); otherwise it is no panel.
func _panel_riposte() -> Dictionary:
	_panel_ground()
	_tick_rig([_shot_events("launch", {"actor": 1.0, "target": 0.0, "amount": 800.0, "face": 1.0})])
	_check(_rig.panels == 0, "%s: a plain launch made a strip" % _label)
	for _i in range(180):
		_tick_rig()
	_tick_rig([_shot_events("parry", {"actor": 0.0, "target": 1.0})])
	for _i in range(40):
		_tick_rig()
	_tick_rig([_shot_events("launch", {"actor": 1.0, "target": 0.0, "amount": 800.0, "face": 1.0})])
	_check(_rig.panels == 1 and _panel_now()["kind"] == "riposte" and int(_panel_now()["slot"]) == 0, "%s: no riposte strip (%d, %s)" % [_label, _rig.panels, str(_panel_now())])
	for _i in range(15 * 60):
		_tick_rig()
	_tick_rig([_shot_events("parry", {"actor": 0.0, "target": 1.0})])
	for _i in range(3 * 60):
		_tick_rig()
	_tick_rig([_shot_events("launch", {"actor": 1.0, "target": 0.0, "amount": 800.0, "face": 1.0})])
	_check(_rig.panels == 1, "%s: a launch 3 s after the parry made a strip" % _label)
	return {}


## UI's floor decides the band: on the top where the strip fits under the HUD, else on the bottom.
func _panel_floor(frac: float, band: int) -> Dictionary:
	_panel_ground()
	_rig.panel_floor = frac * vh
	_fire(0)
	var p: Dictionary = _panel_now()
	_check(not p.is_empty() and int(p["band"]) == band, "%s: band %s (want %d)" % [_label, str(p.get("band", "none")), band])
	if not p.is_empty() and band == 0:
		var r: Rect2 = p["rect"]
		_check(r.position.y >= frac * vh - 0.5, "%s: the strip starts at %.0f, over the HUD (floor %.0f)" % [_label, r.position.y, frac * vh])
	_rig.panel_floor = 0.0
	return {}


## Still (reduced motion or the setting): the strip is open at once, with no push; off: nothing.
func _panel_modes() -> Dictionary:
	_panel_ground()
	_rig.reduced_motion = true
	_fire(0)
	var p: Dictionary = _panel_now()
	_check(not p.is_empty() and bool(p["still"]) and float(p["open"]) > 0.99, "%s: reduced motion did not give a still strip at once (%s)" % [_label, str(p)])
	var z0: float = float(p["cam_z"])
	for _i in range(30):
		_tick_rig()
	_check(absf(float(_panel_now()["cam_z"]) / z0 - 1.0) < 0.01, "%s: a still strip pushed" % _label)
	_rig.reduced_motion = false
	_panel_ground()
	var before: int = _rig.panels
	_rig.panel_mode = "off"
	_fire(0)
	_check(_rig.panels == before and _panel_now().is_empty(), "%s: a strip played with the setting off" % _label)
	_rig.panel_mode = "still"
	_fire(0)
	_check(_rig.panels == before + 1 and bool(_panel_now()["still"]), "%s: the still setting did not give a still strip" % _label)
	_rig.panel_mode = "full"
	return {}


## At a pose, the strip's band never covers a fighter; when both bands would, there is no strip.
func _panel_band_pose(dx: float, dy: float) -> Dictionary:
	var ax: float = 20000.0
	_pose(ax, 0.0, ax + dx, dy)
	_seed_rig()
	for _i in range(240):
		_tick_rig()
	_fire(0)
	var p: Dictionary = _panel_now()
	var bad: int = 0
	if not p.is_empty():
		var fr: SplitFrame = _rig.current()
		var r: Rect2 = p["rect"]
		for k in range(2):
			var f = _S.fighters[k]
			var pi: int = k if fr.shows(k) else 0
			var feet: Vector2 = fr.screen_pos(pi, f.x, f.y, float(f.z))
			var head: Vector2 = fr.screen_pos(pi, f.x, f.y + CamParams.BODY_H, float(f.z))
			if r.intersects(Rect2(feet.x - 6.0, minf(head.y, feet.y), 12.0, absf(feet.y - head.y))):
				bad += 1
	_check(bad == 0, "%s: the strip covered a fighter" % _label)
	stats["panel band %s" % _label] = "none" if p.is_empty() else ("top" if int(p["band"]) == 0 else "bottom")
	return {}


## The opening, against the sim's timeline (data/fight/intro.json: A falls at 0 and lands at 36, B falls at 84 and lands at
## 114, the staredown at 144, the clock at 300; the fall is 6,000 units): injected intro events, the fighters moved as the
## sim moves them. Variants: the full shot; two humans (the same cameras); reduced motion; a skip at tick 20.
func _intro_run(mode: String) -> Dictionary:
	var ax: float = 20000.0
	var top: float = 6000.0
	_pose(ax, top, ax + 900.0, top)
	_S.fighters[0].face = 1.0
	_S.fighters[1].face = -1.0
	for f in _S.fighters:
		f.state = "intro"
		if mode == "humans":
			f.ai = null
	_rig.reduced_motion = mode == "reduced"
	_seed_rig()
	var fall: Array = [0, 84]
	var land: Array = [36, 114]
	var landed: Array = [false, false]
	var cuts: Array = []
	var cam_log: Array = []
	var off: Array = [0, 0]
	var sizes: Dictionary = {}
	var pitch_at: Dictionary = {}
	var max_pitch_dev: float = 0.0
	var shake_max: float = 0.0
	var zbump: float = 0.0
	var skipped: bool = false
	var fade_at_cut: float = 0.0
	for t in range(0, 360):
		var evs: Array = []
		if t == 0:
			evs.append(_shot_events("intro_start", {"dur": 5.0, "delay": 0.5}))
		if mode == "skip" and t == 20:
			for k in range(2):
				if not landed[k]:
					landed[k] = true
					evs.append(_shot_events("entrance_land", {"actor": float(k), "x": _S.fighters[k].x, "y": 0.0, "z": 0.0, "y1": top, "r": 150.0}))
			evs.append(_shot_events("clock_start", {"kind": "skip"}))
			skipped = true
		if not skipped:
			for k in range(2):
				if t == fall[k]:
					evs.append(_shot_events("entrance_fall", {"actor": float(k), "x": _S.fighters[k].x, "y": 0.0, "y1": top, "dur": float(land[k] - fall[k]) / 60.0}))
				if t == land[k]:
					landed[k] = true
					evs.append(_shot_events("entrance_land", {"actor": float(k), "x": _S.fighters[k].x, "y": 0.0, "z": 0.0, "y1": top, "r": 150.0}))
			if t == 144:
				evs.append(_shot_events("staredown_start", {"dur": 156.0 / 60.0}))
			if t == 300:
				evs.append(_shot_events("clock_start", {"kind": "full"}))
		# the fighters, as the sim moves them: B waits in the sky until his fall; a fall is a closed-form path
		for k in range(2):
			var f = _S.fighters[k]
			if landed[k]:
				f.y = 0.0
			elif t >= fall[k]:
				var q: float = float(t - fall[k] + 1) / float(land[k] - fall[k])
				f.y = top * (1.0 - q * q)
		if skipped or t >= 300:
			for f in _S.fighters:
				f.state = "free"
		_tick_rig(evs)
		var cur: SplitFrame = _rig.current()
		cam_log.append([cur.cam_x[0], cur.cam_y[0], cur.cam_z[0]])
		if cur.cut:
			cuts.append(t)
			if t == 20:
				fade_at_cut = cur.fade
		max_pitch_dev = maxf(max_pitch_dev, absf(cur.pitch))
		pitch_at[t] = cur.pitch
		shake_max = maxf(shake_max, maxf(_rig._shk[0], _rig._shk[1]))
		if t == 40:
			zbump = cur.cam_z[0]
		# the fighter the shot is on stays on the screen
		if mode == "full" or mode == "humans":
			var who: int = -1
			if t > 0 and t < 144:
				who = 0 if t < 84 else 1
			if who >= 0 and not _on_screen(cur, who):
				off[who] += 1
		if t in [30, 100, 110, 150, 235, 299, 301, 302, 303, 304, 306, 359]:
			sizes[t] = [_apparent_px(0, cur), cur.cam_z[0], cur.cam_x[0], cur.mode, _rig.solo_kind]
	var stat: String = "cuts %s" % str(cuts)
	match mode:
		"full", "humans":
			var want: Array = [0, 36, 84, 114, 144, 240, 264, 288]
			var ok: bool = cuts.size() == want.size()
			if ok:
				for q in range(want.size()):
					ok = ok and absi(int(cuts[q]) - int(want[q])) <= 1
			_check(ok, "%s: cuts at %s (want %s)" % [_label, str(cuts), str(want)])
			_check(off[0] == 0 and off[1] == 0, "%s: the faller left the screen for %d and %d ticks" % [_label, off[0], off[1]])
			_check(float(pitch_at[40]) < -3.0 and float(pitch_at[120]) < -3.0, "%s: no low angle at the landings (%.1f, %.1f)" % [_label, pitch_at[40], pitch_at[120]])
			_check(float(pitch_at[30]) == 0.0 and float(pitch_at[150]) == 0.0 and float(pitch_at[235]) == 0.0, "%s: the fall and the staredown are not level" % _label)
			_check(shake_max >= CamParams.INTRO_SHAKE * 0.5, "%s: no shake at the touchdown (%.1f)" % [_label, shake_max])
			_check(sizes[235][0] > sizes[150][0] * 1.05, "%s: the two-shot did not push in (%.0f px to %.0f px)" % [_label, sizes[150][0], sizes[235][0]])
			_check(_rig.solo_kind == "" and not _rig.intro_active, "%s: the intro did not end" % _label)
			var punch: float = float(sizes[302][1]) / float(sizes[299][1])
			_check(punch > 1.02, "%s: no bell punch at the clock (%.3f)" % [_label, punch])
			_check(absf(float(sizes[359][1]) / float(sizes[306][1]) - 1.0) < 0.12, "%s: the push does not ease out after the clock" % _label)
			_check(_rig.panels == 0, "%s: a panel played during the intro" % _label)
			stat += ", sizes %.0f / %.0f / %.0f px, bell x%.3f, shake %.1f" % [sizes[150][0], sizes[235][0], sizes[359][0], punch, shake_max]
			if mode == "full":
				_intro_ref = cam_log
			else:
				var same: bool = _intro_ref.size() == cam_log.size()
				if same:
					for q in range(cam_log.size()):
						for c in range(3):
							if absf(float(cam_log[q][c]) - float(_intro_ref[q][c])) > 1e-9:
								same = false
				_check(same, "%s: two humans got other cameras than the AI" % _label)
		"reduced":
			var want_r: Array = [0, 36, 84, 114, 144]
			var ok_r: bool = cuts.size() == want_r.size()
			if ok_r:
				for q in range(want_r.size()):
					ok_r = ok_r and absi(int(cuts[q]) - int(want_r[q])) <= 1
			_check(ok_r, "%s: cuts at %s (want %s)" % [_label, str(cuts), str(want_r)])
			_check(max_pitch_dev == 0.0 and shake_max == 0.0, "%s: pitch %.1f or shake %.1f in reduced motion" % [_label, max_pitch_dev, shake_max])
			_check(float(sizes[302][1]) / float(sizes[299][1]) < 1.01, "%s: a bell punch in reduced motion" % _label)
			_check(_rig.intro_cuts == 5, "%s: %d intro cuts" % [_label, _rig.intro_cuts])
		"skip":
			_check(cuts.size() == 2 and absi(int(cuts[0]) - 0) <= 1 and int(cuts[1]) == 20, "%s: cuts at %s (want 0 and 20)" % [_label, str(cuts)])
			_check(fade_at_cut > 0.7, "%s: no fade at the skip (%.2f)" % [_label, fade_at_cut])
			_check(_rig.solo_kind == "" and not _rig.intro_active, "%s: the intro did not end at the skip" % _label)
			_check(_on_screen(_rig.current(), 0) and _on_screen(_rig.current(), 1), "%s: a fighter is off the screen after the skip" % _label)
			stat += ", fade %.2f" % fade_at_cut
	stats["intro shots " + mode] = stat
	_rig.reduced_motion = false
	return {}


## The KO, then the winner small against the damage: the pull-back goes to the side with the most wreckage.
func _shot_wreck(side: int, reduced: bool) -> Dictionary:
	var ax: float = 20000.0
	_pose(ax, 0.0, ax + 500.0, 0.0)
	_S.craters.clear()
	_S.buildings.clear()
	_S.slides.clear()
	if side != 0:
		var big := SimState.Crater.new()
		big.x = ax - 300.0 + 1500.0 * side
		big.r = 260.0
		big.depth = 90.0
		big.special = 1.0
		_S.craters.append(big)
		var small := SimState.Crater.new()
		small.x = ax - 300.0 - 900.0 * side
		small.r = 60.0
		small.depth = 15.0
		_S.craters.append(small)
	_rig.reduced_motion = reduced
	_seed_rig()
	for _i in range(120):
		_tick_rig()
	# the winner is slot 0 (the loser, slot 1, was knocked out), standing at ax
	_S.game.ko = _S.fighters[1]
	_S.game.koT = 0.0
	var cut_frames: int = 0
	var size_first: float = 0.0
	var size_mid: float = 0.0
	var sizes_end: float = 0.0
	var x_end: float = 0.0
	var on_wreck: int = 0
	for k in range(1, 541):
		_S.game.koT += SplitRig.DT
		_tick_rig()
		if _rig.solo_kind == "wreck":
			on_wreck += 1
			if _rig.current().cut:
				cut_frames += 1
			if on_wreck == 3:
				size_first = _apparent_px(0, _rig.current())
			if on_wreck == 100:
				size_mid = _apparent_px(0, _rig.current())
			if on_wreck == 400:
				sizes_end = _apparent_px(0, _rig.current())
				var fr: SplitFrame = _rig.current()
				x_end = fr.screen_pos(0, _S.fighters[0].x, _S.fighters[0].y + CamParams.CHEST, 0.0).x
	_check(_rig.wreck_dir == side, "%s: the wreckage side is %d (want %d, score %.0f)" % [_label, _rig.wreck_dir, side, _rig.wreck_score])
	_check(on_wreck > 400, "%s: the wreck shot ran %d ticks" % [_label, on_wreck])
	_check(cut_frames == (0 if reduced else 1), "%s: %d cut frames (want %d)" % [_label, cut_frames, 0 if reduced else 1])
	_check(absf(sizes_end - CamParams.R_WRECK * vh) < 0.2 * CamParams.R_WRECK * vh, "%s: the winner is %.0f px at the end (want about %.0f)" % [_label, sizes_end, CamParams.R_WRECK * vh])
	if not reduced:
		_check(size_first > sizes_end * 2.2, "%s: no pull-back (%.0f px to %.0f px)" % [_label, size_first, sizes_end])
		_check(size_mid < size_first and size_mid > sizes_end, "%s: the pull-back is not smooth (%.0f, %.0f, %.0f)" % [_label, size_first, size_mid, sizes_end])
	var want_x: float = vw * (0.5 - CamParams.WRECK_ANCHOR_X * float(side))
	_check(absf(x_end - want_x) < 0.03 * vw, "%s: the winner is at x %.0f (want %.0f)" % [_label, x_end, want_x])
	stats["shot wreck %s" % _label] = "dir %d, score %.0f, sizes %.0f / %.0f / %.0f px, x %.0f" % [_rig.wreck_dir, _rig.wreck_score, size_first, size_mid, sizes_end, x_end]
	# a new match ends the shot
	_S.game.ko = null
	for _i in range(5):
		_tick_rig()
	_check(_rig.solo_kind == "", "%s: the shot did not end with the match" % _label)
	_rig.reduced_motion = false
	return {}


## Full (3 s: gather 60, break 30, settle 90 ticks): a push in, one hard cut to a low wide angle, a cut back, then the pull back.
func _shot_transform_full() -> Dictionary:
	var ax: float = 20000.0
	_pose(ax, 40.0, ax + 600.0, 40.0)
	_seed_rig()
	for _i in range(200):
		_tick_rig()
	_tick_rig([_shot_events("transform", {"actor": 0.0, "tier": 2.0, "source": "x", "dur": 3.0})])
	var cut_ticks: Array = []
	var size_gather_end: float = 0.0
	var size_break: float = 0.0
	var size_settle: float = 0.0
	var pitch_in_break: float = 0.0
	var ended_at: int = -1
	var first: float = _apparent_px(0, _rig.current())
	for k in range(1, 181):
		_tick_rig()
		if _rig.current().cut:
			cut_ticks.append(k)
		if k == 58:
			size_gather_end = _apparent_px(0, _rig.current())
		if k == 80:
			size_break = _apparent_px(0, _rig.current())
			pitch_in_break = _rig.current().pitch
		if k == 128:
			size_settle = _apparent_px(0, _rig.current())
		if ended_at < 0 and _rig.solo_kind == "":
			ended_at = k
	for _i in range(200):
		_tick_rig()
	_check(cut_ticks.size() == 2 and absi(cut_ticks[0] - 60) <= 2 and absi(cut_ticks[1] - 90) <= 2, "%s: cuts at %s (want at the break, tick 60, and the settle, tick 90)" % [_label, str(cut_ticks)])
	_check(size_gather_end > first * 1.15, "%s: the gather did not push in (%.0f to %.0f px)" % [_label, first, size_gather_end])
	_check(size_break < size_gather_end * 0.65, "%s: the break is not wide (%.0f px after %.0f)" % [_label, size_break, size_gather_end])
	_check(pitch_in_break < -5.0, "%s: no low angle at the break (pitch %.1f)" % [_label, pitch_in_break])
	_check(_rig.current().pitch == 0.0, "%s: the pitch did not return" % _label)
	_check(size_settle > size_break * 1.3, "%s: the settle is not back to the pose (%.0f px)" % [_label, size_settle])
	_check(ended_at >= 130 and ended_at <= 140, "%s: the shot ended at tick %d (want about 135)" % [_label, ended_at])
	stats["shot transformation full"] = "cuts %s, sizes %.0f / %.0f / %.0f / %.0f px, end tick %d" % [str(cut_ticks), first, size_gather_end, size_break, size_settle, ended_at]
	return {}


## The break's low angle keeps the camera above the ground at every zoom setting (Rendering's rule), and the cut-away
## hole opens wide during the break.
func _shot_transform_limit(pref: float) -> Dictionary:
	var ax: float = 20000.0
	_pose(ax, 0.0, ax + 600.0, 0.0)
	_rig.zoom_pref = pref
	_seed_rig()
	for _i in range(200):
		_tick_rig()
	_tick_rig([_shot_events("transform", {"actor": 0.0, "tier": 2.0, "source": "x", "dur": 3.0, "version": "full"})])
	for k in range(1, 100):
		_tick_rig()
		if k == 75:
			var fr: SplitFrame = _rig.current()
			var f = _S.fighters[0]
			var z: float = fr.cam_z[0]
			var pt: Vector2 = fr.screen_pos(0, f.x, f.y + CamParams.CHEST, 0.0)
			var off: float = pt.y - vh * 0.5
			var height: float = CamParams.CHEST + (off + CamParams.K_FACTOR * vh * sin(deg_to_rad(fr.pitch))) / z
			_check(float(fr.cutaway[0]["radius_px"]) >= CamParams.CUTAWAY_BREAK_R * vh - 0.5, "%s: the hole is %.0f px in the break" % [_label, float(fr.cutaway[0]["radius_px"])])
			_check(height >= CamParams.BREAK_CAM_MIN_H - 3.0, "%s: the camera is %.1f units above his feet (pitch %.1f)" % [_label, height, fr.pitch])
			stats["shot low angle, setting %d" % int(pref)] = "pitch %.1f, zoom %.2f, camera %.1f units above his feet" % [fr.pitch, z, height]
	_rig.zoom_pref = CamParams.ZOOM_PREF_DEFAULT
	return {}


## Short (1.5 s: 24, 18, 48): half the push, a snap zoom out at the break and no cut, a straight pull back.
func _shot_transform_short() -> Dictionary:
	var ax: float = 20000.0
	_pose(ax, 40.0, ax + 600.0, 40.0)
	_seed_rig()
	for _i in range(200):
		_tick_rig()
	_tick_rig([_shot_events("transform", {"actor": 0.0, "tier": 2.0, "source": "x", "dur": 1.5})])
	var cuts: int = 0
	var first: float = _apparent_px(0, _rig.current())
	var s_break: float = 0.0
	var ended_at: int = -1
	for k in range(1, 91):
		_tick_rig()
		if _rig.current().cut:
			cuts += 1
		if k == 34:
			s_break = _apparent_px(0, _rig.current())
		if ended_at < 0 and _rig.solo_kind == "":
			ended_at = k
	_check(cuts == 0, "%s: %d cuts in the short version (want none)" % [_label, cuts])
	_check(s_break < first * 0.8, "%s: no snap zoom out at the break (%.0f px from %.0f)" % [_label, s_break, first])
	_check(ended_at >= 40 and ended_at <= 44, "%s: the shot ended at tick %d (want about 42)" % [_label, ended_at])
	return {}


## The live version of a transformation step (0.8 s, no pause) plays no shot: no solo, no cut.
func _shot_live_step() -> Dictionary:
	var ax: float = 20000.0
	_pose(ax, 40.0, ax + 600.0, 40.0)
	_seed_rig()
	for _i in range(200):
		_tick_rig()
	var cuts: int = 0
	var z_before: float = _rig.current().cam_z[0]
	var z_peak: float = z_before
	var peak_tick: int = -1
	_tick_rig([_shot_events("transform", {"actor": 0.0, "tier": 2.0, "source": "x", "dur": 0.8, "version": "live"})])
	if _rig.current().cut:
		cuts += 1
	for k in range(1, 121):
		_tick_rig()
		if _rig.current().cut:
			cuts += 1
		if _rig.current().cam_z[0] > z_peak:
			z_peak = _rig.current().cam_z[0]
			peak_tick = k
	var punched: bool = z_peak > z_before * 1.03 and peak_tick >= 10 and peak_tick <= 22
	_check(cuts == 0 and _rig.solo_kind == "", "%s: a live step got a shot (cuts %d, solo %s)" % [_label, cuts, _rig.solo_kind])
	_check(punched, "%s: no punch-in at the break (z %.3f to %.3f)" % [_label, z_before, z_peak])
	return {}


## A world-change pause: the shared view pulls out to 75% of its zoom over half a second and comes back after.
func _shot_world_pause() -> Dictionary:
	var ax: float = 20000.0
	_pose(ax, 40.0, ax + 900.0, 40.0)
	_seed_rig()
	for _i in range(240):
		_tick_rig()
	var z0: float = _rig.current().cam_z[0]
	_tick_rig([_shot_events("pause_start", {"kind": "world", "actor": 0.0, "dur": 2.0})])
	var zmin: float = z0
	for _i in range(150):
		_tick_rig()
		zmin = minf(zmin, _rig.current().cam_z[0])
	for _i in range(200):
		_tick_rig()
	_check(zmin < z0 * 0.85, "%s: no pull-out (z %.3f to %.3f)" % [_label, z0, zmin])
	_check(absf(_rig.current().cam_z[0] / z0 - 1.0) < 0.03, "%s: the view did not come back" % _label)
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


## SplitFrame.project is the pinhole of Rendering's CameraRig: the same pixel for the same point, at every pitch.
func _projection_matches_the_rig() -> void:
	var vpn := SubViewport.new()
	vpn.size = Vector2i(int(vw), int(vh))
	root.add_child(vpn)
	var rig := CameraRig.new()
	vpn.add_child(rig)
	await process_frame
	var worst: float = 0.0
	var pts: Array = [Vector3(0, 0, 0), Vector3(300, 120, 0), Vector3(-800, 400, -1650), Vector3(1500, 60, 750), Vector3(-200, 900, -2850), Vector3(2400, 30, -600)]
	for pitch in [0.0, 11.0, 49.0]:
		for zoom in [0.35, 0.8, 1.3]:
			var cx: float = 91234.5
			var cy: float = 220.0
			rig.frame(cy, zoom, Vector2.ZERO, vh, pitch)
			for q in pts:
				var wx: float = cx + q.x
				var mine: Vector2 = SplitFrame.project(cx, cy, zoom, pitch, vw, vh, wx, q.y, q.z)
				var theirs: Vector2 = rig.unproject_position(Vector3(q.x, q.y, q.z))
				if not rig.is_position_behind(Vector3(q.x, q.y, q.z)):
					worst = maxf(worst, mine.distance_to(theirs))
	rig.queue_free()
	vpn.queue_free()
	stats["projection vs CameraRig"] = "worst %.4f px over 3 pitches, 3 zooms, 6 points" % worst
	_check(worst < 0.05, "SplitFrame.project differs from CameraRig by %.4f px" % worst)


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

func _real_match(seed: int, human: int = -1, pitch: float = 0.0, ticks: int = -1, rig_human: int = -1) -> void:
	var limit: int = ticks if ticks > 0 else match_ticks
	_begin("real match %d%s%s%s%s" % [seed, (" human %d" % human) if human >= 0 else "", (" pitch %d" % int(pitch)) if pitch > 0.0 else "", " full" if ticks > 0 else "", " (rig sees slot %d as the human)" % rig_human if rig_human >= 0 else ""])
	SimCore.newMatch(_S, seed, {"p1": human != 0, "p2": human != 1})
	_rig.pitch_deg = pitch
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
	_jr = [null, null]
	_jr_done = []
	_contact = {}
	_bn = []
	_bn_done = []
	while t < limit and not (_S.game.ko != null and _S.game.koT > 3.0):
		SimCore.step(_S)
		var ev: Array = _S.out.fx.duplicate()
		_S.out.fx.clear()
		_S.out.feed.clear()
		t += 1
		# A test-only trick: the sim is stepped with both fighters on AI, the rig sees one of them without it (a human), so the
		# hybrid launch rule's hold can be exercised in a long match.
		var saved_ai = null
		if rig_human >= 0:
			saved_ai = _S.fighters[rig_human].ai
			_S.fighters[rig_human].ai = null
		_rig.step(_S, vw, vh, ev)
		_tick += 1
		_watch()
		var cur: SplitFrame = _rig.current()
		_journey_tick(cur, ev)
		for e in ev:
			var et: String = String(e.type)
			if et in ["bounce", "left_ground", "land", "tumble_end", "journey_end"]:
				_contact[et] = int(_contact.get(et, 0)) + 1
			if et == "bounce" and int(e.actor) >= 0 and int(e.actor) < 2:
				var bf = _S.fighters[int(e.actor)]
				_bn.append({"a": int(e.actor), "n": 0, "wy0": 1.0e9, "wy1": -1.0e9, "sy0": 1.0e9, "sy1": -1.0e9, "mode": cur.mode, "solo": _rig.solo_kind, "z0": cur.cam_z[0]})
		var bi: int = 0
		while bi < _bn.size():
			var b = _bn[bi]
			var bf2 = _S.fighters[int(b["a"])]
			var pi2: int = int(b["a"]) if cur.shows(int(b["a"])) else (0 if cur.shows(0) else 1)
			var sp2: Vector2 = cur.screen_pos(pi2, bf2.x, bf2.y + CamParams.CHEST, float(bf2.z))
			b["wy0"] = minf(float(b["wy0"]), bf2.y)
			b["wy1"] = maxf(float(b["wy1"]), bf2.y)
			b["sy0"] = minf(float(b["sy0"]), sp2.y)
			b["sy1"] = maxf(float(b["sy1"]), sp2.y)
			b["n"] = int(b["n"]) + 1
			if int(b["n"]) >= 40:
				_bn_done.append(b)
				_bn.remove_at(bi)
			else:
				bi += 1
		if rig_human >= 0:
			_S.fighters[rig_human].ai = saved_ai
		if trace_seed == seed and float(t) / 60.0 >= trace_t0 and float(t) / 60.0 <= trace_t1:
			var f0 = _S.fighters[0]
			var f1 = _S.fighters[1]
			var p0: Vector2 = cur.screen_pos(0, f0.x, f0.y + CamParams.CHEST, float(f0.z))
			var p1: Vector2 = cur.screen_pos(1, f1.x, f1.y + CamParams.CHEST, float(f1.z))
			print("  [%s] T %.3f th %.3f sig %d/%d u %.0f solo %s/%d chase %d anc %.3f/%.3f/%.3f/%.3f c %.0f/%.0f cut %s fa %.2f sw %s r %.4f/%.4f %s sep %.2f e %.2f slam %d rush0 %s rush1 %s p0 (%.0f,%.0f) p1 (%.0f,%.0f) x0 %.0f x1 %.0f y0 %.0f y1 %.0f z0 %.0f z1 %.0f st %s/%s vx0 %.0f cam0 %.0f/%.0f/%.3f cam1 %.0f/%.0f/%.3f" % [_label, float(t) / 60.0, cur.theta, _rig.sigma_shown, _rig.sigma_u, _rig.u, _rig.solo_kind, _rig.solo_slot, _rig.chase_slot, cur.anchor[0].x, cur.anchor[0].y, cur.anchor[1].x, cur.anchor[1].y, cur.c.x, cur.c.y, cur.cut, _rig._flip_age, _rig.split_wanted, _rig.r_now, _rig._r_merge(), cur.mode, cur.sep, cur.e, _rig._slam_slot, f0.rush != null, f1.rush != null, p0.x, p0.y, p1.x, p1.y, f0.x, f1.x, f0.y, f1.y, float(f0.z), float(f1.z), f0.state, f1.state, f0.vx, cur.cam_x[0], cur.cam_y[0], cur.cam_z[0], cur.cam_x[1], cur.cam_y[1], cur.cam_z[1]])
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
	stats[_label] = "%d ticks: %s; layout changes %d, slams %d, cut-ins %d, panels %d (%.1f a minute, %d refused) %s" % [t, ", ".join(PackedStringArray(mods)), _rig.mode_change_times().size(), slams, _rig.cut_ins, _rig.panels, float(_rig.panels) * 3600.0 / float(maxi(t, 1)), _rig.panels_dropped, str(_rig.panel_log.map(func(e): return e[1]))]
	_check(float(_rig.cut_ins) <= float(CamParams.OV_MAX_PER_MIN) * (float(t) / 3600.0) + 2.0, "%s: %d camera-only cut-ins in %.0f s (cap %d a minute)" % [_label, _rig.cut_ins, float(t) / 60.0, CamParams.OV_MAX_PER_MIN])
	_journey_summary()
	if not _bn_done.is_empty():
		var rise: float = 0.0
		var scr: float = 0.0
		var big: int = 0
		var seen: int = 0
		for b in _bn_done:
			var wr: float = float(b["wy1"]) - float(b["wy0"])
			var sr: float = float(b["sy1"]) - float(b["sy0"])
			rise += wr
			scr += sr
			if wr >= 0.4 * CamParams.BODY_H:
				big += 1
				if sr >= 0.5 * wr * float(b["z0"]):
					seen += 1
		stats["bounce reading " + _label] = "%d bounces watched for 40 ticks: world rise mean %.0f u (%.2f bh), screen excursion mean %.0f px (%.2f of the screen height); of %d with a rise over 0.4 bh, %d moved on the screen at least half as much as the world did" % [_bn_done.size(), rise / float(_bn_done.size()), rise / float(_bn_done.size()) / CamParams.BODY_H, scr / float(_bn_done.size()), scr / float(_bn_done.size()) / vh, big, seen]
	if ticks > 0 and human < 0 and rig_human < 0 and _bn_done.size() >= 10:
		var sc: float = 0.0
		for b in _bn_done:
			sc += float(b["sy1"]) - float(b["sy0"])
		_check(sc / float(_bn_done.size()) >= 30.0, "%s: bounces move %.0f px on the screen on average (want at least 30)" % [_label, sc / float(_bn_done.size())])
	stats["contact " + _label] = "%s; %d bounce pushes" % [str(_contact), _rig.bounce_pushes]
	if ticks > 0 and human < 0 and rig_human < 0:
		_check(int(_contact.get("bounce", 0)) > 0 and _rig.bounce_pushes > 0, "%s: no bounce in a full-length match (%s)" % [_label, str(_contact)])
	SimCore.dispose(_S)
	_S = null


## Whether fighter i is on the screen this tick, in his own pane when two are shown.
func _on_screen(cur: SplitFrame, i: int) -> bool:
	var f = _S.fighters[i]
	var pi: int = i if cur.shows(i) else (0 if cur.shows(0) else 1)
	var pos: Vector2 = cur.screen_pos(pi, f.x, f.y + CamParams.CHEST, float(f.z))
	if pos.x < 0.0 or pos.x > vw or pos.y < 0.0 or pos.y > vh:
		return false
	if cur.shows(0) and cur.shows(1):
		var w1: float = cur.weight1(pos)
		return w1 >= 0.5 if i == 1 else w1 < 0.5
	return true


## Whether UI would draw an edge pointer at fighter `who` this tick (the chip of the other slot points at him).
func _pointed(cur: SplitFrame, who: int) -> bool:
	if _jr_lay == null:
		_jr_lay = UiLayout.new()
		_jr_lay.compute(Vector2(vw, vh), false)
	var anchors: Array = []
	for k in range(2):
		var f = _S.fighters[k]
		anchors.append(cur.hud_anchor(k, f.x, f.y, float(f.z)))
	for ch in UiSplit.pointers(_jr_lay, cur.split_record(), anchors, _jr_lay.s):
		if int(ch["slot"]) == 1 - who:
			return true
	return false


## A launched fighter's journey, from the tick he is launched to the tick he is not: its length along the path, and the
## ticks the launcher and the launched were off the screen, with whether UI would have pointed at them.
func _journey_tick(cur: SplitFrame, ev: Array) -> void:
	for v in range(2):
		var f = _S.fighters[v]
		if f.state == "launched" and _jr[v] == null:
			var att: int = 1 - v
			for e in ev:
				if String(e.type) == "launch" and int(e.actor) == v and int(e.target) >= 0:
					att = int(e.target)
			_jr[v] = {"t0": float(_tick) / 60.0, "v": v, "att": att, "x0": f.x, "px": f.x, "py": f.y, "len": 0.0, "ticks": 0, "att_off": 0, "vic_off": 0, "att_nop": 0, "vic_nop": 0, "mode_chase": 0}
		var j = _jr[v]
		if j == null:
			continue
		var dx: float = SimWrap.sdx(float(j["px"]), f.x)
		var dy: float = f.y - float(j["py"])
		j["len"] = float(j["len"]) + sqrt(dx * dx + dy * dy)
		j["px"] = f.x
		j["py"] = f.y
		j["ticks"] = int(j["ticks"]) + 1
		if _rig.solo_kind == "launch" or _rig.chase_slot == v:
			j["mode_chase"] = int(j["mode_chase"]) + 1
		var a: int = int(j["att"])
		if not _on_screen(cur, a):
			j["att_off"] = int(j["att_off"]) + 1
			if not _pointed(cur, a):
				j["att_nop"] = int(j["att_nop"]) + 1
		if not _on_screen(cur, v):
			var settling: bool = not _rig._solo_decisions.is_empty() and _rig.time - float(_rig._solo_decisions[-1]) < 0.8   # the ease back after a shot
			if settling or _rig.solo_kind in ["hold", "cut", "transform", "finisher", "ko", "wreck", "intro"] or _rig._ov_kind != "" or ((cur.mode == "opening" or cur.mode == "closing") and _rig.orientation_pending()):
				j["vic_design"] = int(j.get("vic_design", 0)) + 1   # a shot that is not on him by design (the hold, a set piece)
			else:
				j["vic_off"] = int(j["vic_off"]) + 1
				if not j.has("vic_first"):
					j["vic_first"] = float(_tick) / 60.0
				j["vic_last"] = float(_tick) / 60.0
				j["vic_info"] = "%s/%d %s sep %.2f e %.2f chase %d" % [_rig.solo_kind, _rig.solo_slot, cur.mode, cur.sep, cur.e, _rig.chase_slot]
			if not _pointed(cur, v):
				j["vic_nop"] = int(j["vic_nop"]) + 1
		if f.state != "launched":
			j["net"] = absf(SimWrap.sdx(float(j["x0"]), f.x))
			_jr_done.append(j)
			_jr[v] = null


func _journey_summary() -> void:
	var n: int = _jr_done.size()
	if n == 0:
		return
	var lens: Array = []
	var over4k: int = 0
	var att_any: int = 0
	var vic_any: int = 0
	var att_off: int = 0
	var vic_off: int = 0
	var att_nop: int = 0
	var vic_nop: int = 0
	var ticks: int = 0
	var worst_att: int = 0
	var worst_vic: int = 0
	var vic_design: int = 0
	for j in _jr_done:
		lens.append(float(j["len"]))
		if float(j["len"]) > 4000.0:
			over4k += 1
		att_off += int(j["att_off"])
		vic_off += int(j["vic_off"])
		att_nop += int(j["att_nop"])
		vic_nop += int(j["vic_nop"])
		ticks += int(j["ticks"])
		if int(j["att_off"]) >= 6:
			att_any += 1
		if int(j["vic_off"]) >= 6:
			vic_any += 1
			print("  victim lost: %s journey from t=%.2f s, victim slot %d, %d ticks off the screen of %d, path %.0f u, off from t=%.2f to %.2f (%s)" % [_label, float(j["t0"]), int(j["v"]), int(j["vic_off"]), int(j["ticks"]), float(j["len"]), float(j.get("vic_first", 0.0)), float(j.get("vic_last", 0.0)), str(j.get("vic_info", ""))])
		worst_att = maxi(worst_att, int(j["att_off"]))
		worst_vic = maxi(worst_vic, int(j["vic_off"]))
		vic_design += int(j.get("vic_design", 0))
	var nets: Array = []
	var net_over: int = 0
	for j in _jr_done:
		nets.append(float(j["net"]))
		if float(j["net"]) > 4000.0:
			net_over += 1
	nets.sort()
	var net_mean: float = 0.0
	for q in nets:
		net_mean += float(q)
	net_mean /= float(n)
	lens.sort()
	var mean: float = 0.0
	for l in lens:
		mean += float(l)
	mean /= float(n)
	var p90: float = float(lens[mini(n - 1, int(0.9 * float(n)))])
	stats["journeys net " + _label] = "end to end: mean %.0f u (%.0f bh), median %.0f u, 90th %.0f u, %d (%.0f%%) over 4,000 u; %.1f s long on average" % [net_mean, net_mean / CamParams.BODY_H, float(nets[n / 2]), float(nets[mini(n - 1, int(0.9 * float(n)))]), net_over, 100.0 * float(net_over) / float(n), float(ticks) / 60.0 / float(n)]
	stats["journeys " + _label] = "%d launches, path mean %.0f u (%.0f bh), 90th %.0f u, longest %.0f u, %d (%.0f%%) over 4,000 u; attacker off screen %d of %d ticks (%d journeys over 0.1 s, worst %d ticks), victim lost %d ticks (%d journeys, worst %d) and %d off by design (the hold, set pieces); no UI pointer on %d attacker and %d victim off ticks" % [
		n, mean, mean / CamParams.BODY_H, p90, float(lens[n - 1]), over4k, 100.0 * float(over4k) / float(n), att_off, ticks, att_any, worst_att, vic_off, vic_any, worst_vic, vic_design, att_nop, vic_nop]


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
	var panel_shots: int = 0
	for k in range(_queue.size()):
		var fr: SplitFrame = _queue[k][0]
		if fr.mode != last_mode:
			shot_at[k + 3] = fr.mode
			last_mode = fr.mode
		if not fr.panel.is_empty() and float(fr.panel["open"]) > 0.97 and panel_shots < 2 and (panel_shots == 0 or k > int(shot_at.keys().max()) + 20):
			shot_at[k] = "panel"
			panel_shots += 1
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
		for dk in [-1, 0, 1]:
			if not _queue[clampi(k + dk, 0, _queue.size() - 1)][0].panel.is_empty():
				authored = true   # a strip wiping open or shut is a new thing on the screen on purpose
		if not authored:
			worst = maxf(worst, ratio)
			if ratio > SPIKE:
				spikes += 1
				print("  spike %s frame %d mode %s/%s ratio %.1f diffs %.2f %.2f %.2f sep %.3f" % [label, k, modes[k - 1], modes[k], ratio, diffs[k - 1], diffs[k], diffs[k + 1], _queue[k][0].sep])
	render_spikes[label] = worst
	stats["picture " + label] = "%d frames, worst spike ratio %.2f, spikes over %.0f: %d" % [_queue.size(), worst, SPIKE, spikes]
	_check(spikes == 0, "%s: %d picture spikes (worst ratio %.1f)" % [label, spikes, worst])
	_queue.clear()
