extends SceneTree
## The opening on the real renderer (docs/camera/rule-of-cool-shots.md row 7): Rendering's main scene with Camera's
## compositor, two fighters posed on open plains and moved as the sim's intro moves them (data/fight/intro.json: A falls
## at 0 and lands at 36, B falls at 84 and lands at 114, the staredown at 144, the clock at 300), the intro events
## injected into the rig, and frames saved at key ticks. Needs a window (not --headless).
##   godot --path . --script res://render/camera/tests/intro_shots.gd -- --out=DIR [--size=1280x720] [--s=1] [--reduced]

const TOP := 6000.0
const FALL := [0, 84]
const LAND := [36, 114]
const SHOTS := [12, 30, 40, 70, 100, 125, 150, 235, 250, 275, 295, 302]

var main: Node
var out: String = "."
var seed: int = 1
var reduced: bool = false


func _initialize() -> void:
	var size := Vector2i(1280, 720)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
		elif a.begins_with("--size="):
			var wh: PackedStringArray = a.substr(7).split("x")
			size = Vector2i(int(wh[0]), int(wh[1]))
		elif a.begins_with("--s="):
			seed = int(a.substr(4))
		elif a == "--reduced":
			reduced = true
	var vpn := SubViewport.new()
	vpn.size = size
	vpn.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vpn)
	main = load("res://render/main.tscn").instantiate()
	main.manual = true
	vpn.add_child(main)
	_run.call_deferred()


func _ev(type: String, fields: Dictionary) -> SimState.FxEvent:
	var e := SimState.FxEvent.new()
	e.type = type
	for k in fields:
		e.set(k, fields[k])
	return e


func _run() -> void:
	await process_frame
	main.started = true
	main.start_match(seed)
	main.ui_hud.visible = false
	main.hud.visible = false
	var S: SimState = main.host.S
	var vp: Vector2 = main.get_viewport().get_visible_rect().size
	var x0: float = _plains(S)
	var xs: Array = [SimWrap.wrap(x0 - 450.0), SimWrap.wrap(x0 + 450.0)]
	for i in range(2):
		var f = S.fighters[i]
		f.x = xs[i]
		f.z = 0.0
		f.face = 1.0 if i == 0 else -1.0
		f.y = WorldTerrain.groundY(S, f.x) + TOP
	var view := SplitView.new()
	main.add_child(view)
	view.attach(main)
	view.size = vp
	main.split_rig.reduced_motion = reduced
	main.split_rig.reset(S, vp.x, vp.y)
	var landed: Array = [false, false]
	for t in range(0, 306):
		var evs: Array = []
		if t == 0:
			evs.append(_ev("intro_start", {"dur": 5.0, "delay": 0.5}))
		for k in range(2):
			var g: float = WorldTerrain.groundY(S, S.fighters[k].x)
			if t == FALL[k]:
				evs.append(_ev("entrance_fall", {"actor": float(k), "x": S.fighters[k].x, "y": g, "y1": g + TOP, "dur": float(LAND[k] - FALL[k]) / 60.0}))
			if t == LAND[k]:
				landed[k] = true
				evs.append(_ev("entrance_land", {"actor": float(k), "x": S.fighters[k].x, "y": g, "z": 0.0, "y1": g + TOP, "r": 150.0}))
			if landed[k]:
				S.fighters[k].y = g
			elif t >= FALL[k]:
				var q: float = float(t - FALL[k] + 1) / float(LAND[k] - FALL[k])
				S.fighters[k].y = g + TOP * (1.0 - q * q)
		if t == 144:
			evs.append(_ev("staredown_start", {"dur": 156.0 / 60.0}))
		if t == 300:
			evs.append(_ev("clock_start", {"kind": "full"}))
		S.dt = 1.0 / 60.0
		main.host.follow(vp.x, vp.y)
		main.split_rig.step(S, vp.x, vp.y, evs)
		if t in SHOTS:
			for p in main.all_panes():
				p.snap_occlusion()
			for k in range(3):
				main.render_view(1.0)
				await RenderingServer.frame_post_draw
			var fr: SplitFrame = main.split_frame
			main.get_viewport().get_texture().get_image().save_png("%s/intro_%s%03d.png" % [out, "r_" if reduced else "", t])
			print("t=%d mode %s pitch %.1f z %.3f/%.3f cut %s" % [t, fr.mode, fr.pitch, fr.cam_z[0], fr.cam_z[1], fr.cut])
	quit(0)


static func _plains(S: SimState) -> float:
	var peaks: Array = []
	for c in range(0, SimConst.NC, 16):
		if WorldBiomes.biomeAt(float(c) * SimConst.COL) == "mountains":
			peaks.append(float(c) * SimConst.COL)
	var best: float = 0.0
	var far: float = -1.0
	for c in range(0, SimConst.NC, 8):
		var x: float = float(c) * SimConst.COL
		if WorldBiomes.biomeAt(x) != "plains" or WorldWater.surfaceAt(S, x) > WorldTerrain.groundY(S, x) + 0.5:
			continue
		var d: float = INF
		for px in peaks:
			d = minf(d, absf(SimWrap.sdx(x, px)))
		if d > far:
			far = d
			best = x
	return best
