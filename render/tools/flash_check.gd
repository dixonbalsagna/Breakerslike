extends SceneTree
## Flash check: the head-flash state machine (render/core/flash_view.gd) against Art's spec
## (docs/art/flash-prototype-spec.md section 11), headless, one 60 Hz frame at a time on a standalone view with a
## crown it controls, and then real matches through the full scene:
## 1. rest: nothing drawn before a flash;
## 2. timing: each flash in the data shows from the frame after it fires and is gone by its total time (plus its
##    sequence delay), within a frame; its pulses have a beat of nothing between them; with reduced motion it is one
##    pulse; the data's `total` agrees with its pulses;
## 2b. keep-out: every layout shape, as drawn in every family (Legal's rules applied, danger turned to any bearing),
##    sits in the data's keep-out zone, ground shards excepted;
## 3. arbitration: a heavy hit during a taunt cancels the taunt in FLASH_OUT; a flash due while the crown is up is
##    dropped after the default wait; a crown coming up fades the flash; the surge preempts everything and ignores the
##    crown; Resolve starts its delay after the crown goes down, waits past lower flashes, and gives up after wait_max;
##    the same flash firing again extends its hold; cooldowns hold; info flashes obey the setting; a hidden fighter
##    shows none;
## 4. the gameplay hash of a match is the same with the flashes on and off (seeds 12345 and 4).
##   godot --headless --path . --script res://render/tools/flash_check.gd [-- --ticks=3600]

const DT := 1.0 / 60.0

var fails: Array = []
var checks: int = 0
var crown: bool = false
var info_on: bool = true
var max_ticks: int = 3600


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--ticks="):
			max_ticks = int(a.substr(8))
	_run.call_deferred()


func _view() -> FlashView:
	var v := FlashView.new()
	v.set_head(10.0)
	v.crown_fn = func(_a): return crown
	v.info_fn = func(): return info_on
	root.add_child(v)
	crown = false
	info_on = true
	return v


## Step a view from T0 to T1, one frame at a time; returns [first frame shown, frame it ended] (-1 if never). A flash
## is showing from its start to its end, through the beats of nothing between its pulses.
func _run_view(v: FlashView, T0: float, T1: float, at: Dictionary = {}, id: String = "") -> Array:
	var shown: float = -1.0
	var ended: float = -1.0
	var T: float = T0
	var was: bool = false
	while T <= T1 + 1e-9:
		if at.has(snappedf(T, DT)):
			at[snappedf(T, DT)].call(T)
		v.step(T, false, Vector3.ZERO, 1.0, Vector3.ZERO, -100.0)
		var showing: bool = v.cur != "" and (id == "" or v.cur == id)
		if showing and v.level(T) > 0.0 and shown < 0.0:
			shown = T
		if was and not showing and ended < 0.0:
			ended = T
		was = showing
		T += DT
	return [shown, ended]


func _expect(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		fails.append(what)


func _run() -> void:
	await process_frame
	var ids: Array = FlashSet.ids()
	_expect(ids.size() > 0, "no flashes in %s" % FlashSet.PATH)
	# 1 and 2: rest and timing.
	for id in ids:
		var v := _view()
		v.step(-DT, false, Vector3.ZERO, 1.0, Vector3.ZERO, -100.0)   # the warm-up frame: one transparent quad
		v.step(0.0, false, Vector3.ZERO, 1.0, Vector3.ZERO, -100.0)
		_expect(not v.visible, "%s: drawn at rest" % id)
		v.fire(id, 0.0, false)
		var seq: Dictionary = FlashSet.sequence(id)
		var delay: float = float(seq.get("delay_after_crown_down", 0.0))
		var r: Array = _run_view(v, 0.0, FlashSet.total(id) + delay + 0.5)
		var pl: Dictionary = FlashSet.pulse(id)
		_expect(absf(float(pl.get("total", -1.0)) - FlashSet.total(id)) < 1e-6, "%s: the data's total %.3f s does not match its pulses (%.3f s)" % [id, float(pl.get("total", -1.0)), FlashSet.total(id)])
		_expect(r[0] >= 0.0 and r[0] <= delay + DT + 1e-6, "%s: first shown at %.3f s (want by %.3f)" % [id, r[0], delay + DT])
		_expect(v.visible == false, "%s: still drawn after it ended" % id)
		_expect(absf(r[1] - (FlashSet.total(id) + delay)) <= DT + 1e-6, "%s: gone at %.3f s (want %.3f)" % [id, r[1], FlashSet.total(id) + delay])
		v.free()
		# The beat of nothing after the first pulse, and one pulse with reduced motion.
		if int(pl.get("count", 1)) >= 2 and delay == 0.0:
			v = _view()
			v.fire(id, 0.0, false)
			var gap: float = float(pl.on) + 0.5 * float(pl.off)
			var gap_level: Array = [1.0]
			_run_view(v, 0.0, gap + DT, {snappedf(gap, DT): func(T): gap_level[0] = v.level(T)})
			_expect(gap_level[0] == 0.0, "%s: %.2f between its first pulses (want nothing)" % [id, gap_level[0]])
			v.free()
		v = _view()
		v.reduced_motion = true
		v.fire(id, 0.0, false)
		r = _run_view(v, 0.0, FlashSet.total(id) + delay + 0.5)
		_expect(absf(r[1] - (FlashSet.total(id, true) + delay)) <= DT + 1e-6, "%s with reduced motion: gone at %.3f s (want one pulse, %.3f)" % [id, r[1], FlashSet.total(id, true) + delay])
		v.free()
	# 2b: keep-out.
	var ray: Dictionary = FlashSet.danger_ray()
	for id in ids:
		if String(FlashSet.flash(id).get("kind", "")) != "layout":
			continue
		for fk in ["P", "A", "E", "C"]:
			for b in ([NAN, 0.0, 90.0, 180.0, 270.0] if id == "danger" else [NAN]):
				var bad: Array = FlashView.keep_out_breaks(id, fk, b)
				_expect(bad.is_empty(), "keep-out: %s in family %s%s has shapes at %s degrees (zone %s)" % [id, fk, "" if is_nan(b) else " (bearing %.0f)" % b, bad, FlashSet.keep_out()])
	# 3: arbitration.
	if FlashSet.flash("taunt").size() and FlashSet.flash("hurt").size():
		var v := _view()
		v.fire("taunt", 0.0, false)
		var r: Array = _run_view(v, 0.0, 1.5, {0.2: func(T): v.fire("hurt", T, false)}, "taunt")
		_expect(r[1] > 0.0 and r[1] <= 0.2 + RenderLook.FLASH_OUT + 2.0 * DT, "a heavy hit during a taunt: the taunt ended at %.3f s (want by %.3f)" % [r[1], 0.2 + RenderLook.FLASH_OUT + 2.0 * DT])
		var h: Array = _run_view(v, 1.5, 1.5)
		v.free()
		v = _view()
		v.fire("taunt", 0.0, false)
		r = _run_view(v, 0.0, 1.5, {0.2: func(T): v.fire("hurt", T, false)}, "hurt")
		_expect(r[0] > 0.2 and r[0] <= 0.2 + RenderLook.FLASH_OUT + 2.0 * DT, "the hurt after the taunt started at %.3f s" % r[0])
		v.free()
	if FlashSet.flash("found").size():
		var v := _view()
		crown = true
		v.fire("found", 0.0, false)
		var r: Array = _run_view(v, 0.0, 1.0, {0.4: func(_T): crown = false})
		_expect(r[0] < 0.0, "a flash due while the crown was up for 0.4 s still showed (at %.3f s)" % r[0])
		v.free()
	if FlashSet.flash("pride").size():
		var v := _view()
		v.fire("pride", 0.0, false)
		var r: Array = _run_view(v, 0.0, 1.5, {0.3: func(_T): crown = true})
		_expect(r[1] > 0.0 and r[1] <= 0.3 + RenderLook.FLASH_OUT + 2.0 * DT, "a crown coming up: the flash ended at %.3f s" % r[1])
		v.free()
	if FlashSet.flash("surge").size() and FlashSet.flash("triumph").size():
		var v := _view()
		v.fire("triumph", 0.0, false)
		var r: Array = _run_view(v, 0.0, 0.6, {0.2: func(T): crown = true; v.fire("surge", T, false)}, "triumph")
		_expect(r[1] > 0.0 and r[1] <= 0.2 + RenderLook.FLASH_OUT + 2.0 * DT, "the surge: the triumph ended at %.3f s" % r[1])
		_expect(v.cur == "surge", "the surge did not start over the crown (showing '%s')" % v.cur)
		v.free()
	if FlashSet.flash("resolve").size() and not FlashSet.sequence("resolve").is_empty():
		var seq: Dictionary = FlashSet.sequence("resolve")
		var delay: float = float(seq.get("delay_after_crown_down", 0.1))
		var v := _view()
		crown = true
		v.fire("resolve", 0.0, false)
		var r: Array = _run_view(v, 0.0, 2.0, {0.3: func(T): v.fire("taunt", T, false), 0.5: func(_T): crown = false}, "resolve")
		_expect(absf(r[0] - (0.5 + delay + DT)) <= 0.5 * DT, "Resolve after the crown went down at 0.5 s: shown from %.3f s (want %.3f)" % [r[0], 0.5 + delay + DT])
		v.free()
		v = _view()
		crown = true
		v.fire("resolve", 0.0, false)
		r = _run_view(v, 0.0, float(seq.get("wait_max", 2.0)) + 1.0, {float(seq.get("wait_max", 2.0)) + 0.2: func(_T): crown = false})
		_expect(r[0] < 0.0, "Resolve waited past its wait_max (started at %.3f s)" % r[0])
		v.free()
	if FlashSet.flash("hurt").size():
		var pl: Dictionary = FlashSet.pulse("hurt")
		var v := _view()
		v.fire("hurt", 0.0, false)
		# Again during the last pulse's fade: it holds at full for another `on`, then fades (no new swell).
		var again: float = snappedf(FlashSet.total("hurt") - 0.5 * float(pl.fade), DT)
		var r: Array = _run_view(v, 0.0, 2.0, {again: func(T): v.fire("hurt", T, false)})
		var want: float = again + float(pl.on) + float(pl.fade)
		_expect(absf(r[1] - want) <= 1.5 * DT, "the same flash again extends its last pulse: ended at %.3f s (want %.3f)" % [r[1], want])
		v.free()
	if FlashSet.flash("found").size():
		var v := _view()
		v.fire("found", 0.0, false)
		var t: float = FlashSet.total("found") + 0.1
		var r: Array = _run_view(v, 0.0, t + 0.5, {snappedf(t, DT): func(T): v.fire("found", T, false)})
		_expect(v.cur == "" and r[1] > 0.0, "a cooldown did not hold the second found")
		v.free()
	for id in ids:
		var v := _view()
		info_on = false
		v.fire(id, 0.0, false)
		var r: Array = _run_view(v, 0.0, 0.5)
		var info: bool = String(FlashSet.flash(id).get("class", "")) == "info"
		_expect((r[0] < 0.0) == info, "%s with info flashes off: %s" % [id, "showed" if r[0] >= 0.0 else "did not show"])
		v.free()
		v = _view()
		v.fire(id, 0.0, true)
		r = _run_view(v, 0.0, 0.5)
		_expect(r[0] < 0.0, "%s showed on a hidden fighter" % id)
		v.free()
	# 4: the gameplay hash with the flashes on and off, through the full scene.
	var vpn := SubViewport.new()
	vpn.size = Vector2i(1280, 720)
	root.add_child(vpn)
	var main: Node = load("res://render/main.tscn").instantiate()
	main.manual = true
	vpn.add_child(main)
	await process_frame
	var fired: Dictionary = {}
	for seed in [12345, 4]:
		var hashes: Array = []
		for on in [true, false]:
			main.flashes_on = on
			main.start_match(seed, {"p1": true, "p2": true})
			var S: SimState = main.host.S
			while main.host.ticks < max_ticks and not (S.game.ko != null and S.game.koT > 3.0):
				main.frame(DT)
				if on:
					for fv in main.fighter_views:
						if fv.flash_view.cur != "" and fv.flash_view._t0 == S.T:
							fired[fv.flash_view.cur] = int(fired.get(fv.flash_view.cur, 0)) + 1
			hashes.append(str(SimHash.stateHash(S).gameplay))
		_expect(hashes[0] == hashes[1], "seed %d: the gameplay hash differs with the flashes on (%s) and off (%s)" % [seed, hashes[0], hashes[1]])
		print("seed %d: gameplay hash on %s, off %s" % [seed, hashes[0], hashes[1]])
	print("flashes started in play (from events): %s" % [fired])
	print("Flash check  %d checks over %d flashes" % [checks, ids.size()])
	if fails.is_empty():
		print("\nflash check passed")
	else:
		for f in fails.slice(0, 30):
			print("FAIL  " + f)
		print("\nflash check FAILED (%d)" % fails.size())
	quit(0 if fails.is_empty() else 1)
