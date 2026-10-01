extends SceneTree
## The panel cut-in on the real renderer (docs/camera/rule-of-cool-shots.md): Rendering's main scene with Camera's
## compositor attached, two fighters posed on open plains, a signature's beam added to the state, the rig stepped, and the
## frame saved with the strip open. Needs a window (not --headless).
##   godot --path . --script res://render/camera/tests/panel_shot.gd -- --out=DIR [--size=1280x720] [--s=1] [--kind=signature] [--slot=0] [--still]

var main: Node
var out: String = "."
var seed: int = 1
var kind: String = "signature"
var slot: int = 0
var still: bool = false


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
		elif a.begins_with("--kind="):
			kind = a.substr(7)
		elif a.begins_with("--slot="):
			slot = int(a.substr(7))
		elif a == "--still":
			still = true
	var vpn := SubViewport.new()
	vpn.size = size
	vpn.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vpn)
	main = load("res://render/main.tscn").instantiate()
	main.manual = true
	vpn.add_child(main)
	_run.call_deferred()


func _run() -> void:
	await process_frame
	main.started = true
	main.start_match(seed)
	main.ui_hud.visible = false
	main.hud.visible = false
	var S: SimState = main.host.S
	var vp: Vector2 = main.get_viewport().get_visible_rect().size
	var x0: float = _plains(S)
	for i in range(2):
		var f = S.fighters[i]
		f.x = SimWrap.wrap(x0 + (-260.0 if i == 0 else 260.0))
		f.y = WorldTerrain.groundY(S, f.x) + 2.0
		f.z = 0.0
		f.face = 1.0 if i == 0 else -1.0
	var view := SplitView.new()
	main.add_child(view)
	view.attach(main)
	view.size = vp
	main.split_rig.reduced_motion = still
	main.split_rig.reset(S, vp.x, vp.y)
	for k in range(120):
		main.host.follow(vp.x, vp.y)
		main.split_rig.step(S, vp.x, vp.y, [])
	# the request, as the rig would take it from the sim
	if kind == "signature":
		var b := SimState.Beam.new()
		b.A = S.fighters[slot]
		S.beams.append(b)
		main.split_rig.step(S, vp.x, vp.y, [])
		S.beams.clear()
	else:
		var ev := SimState.FxEvent.new()
		ev.type = "ko"
		ev.winner = float(slot)
		ev.loser = float(1 - slot)
		main.split_rig.step(S, vp.x, vp.y, [ev])
	for k in range(16):
		main.split_rig.step(S, vp.x, vp.y, [])
	for p in main.all_panes():
		p.snap_occlusion()
	for k in range(4):
		main.render_view(1.0)
		await RenderingServer.frame_post_draw
	var fr: SplitFrame = main.split_frame
	print("panel: %s" % str(fr.panel))
	main.get_viewport().get_texture().get_image().save_png("%s/panel_%s_%d%s.png" % [out, kind, slot, "_still" if still else ""])
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
