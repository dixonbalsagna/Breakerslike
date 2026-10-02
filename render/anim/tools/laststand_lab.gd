extends SceneTree
## Last-stand lab (docs/architecture/last-stand.md): the body cue through the real solver. Two fighters of different shapes (--shapes=P,A, or E,C) both reach the
## brink on tick 10 (last_stand_ready, injected as the sim sends it); the left one's window expires at tick 130 (the slump), the right one's is used (the
## resolve lets go). Both stand in a wounded stance (the wear set on the fighters, as the sim's wounds would). A fixed side view, captioned. Needs a window.
##   godot --path . --script res://render/anim/tools/laststand_lab.gd -- [--shapes=P,A] [--out=ls.rgb | --sheet=s.png] [--size=380x240] [--step=2] [--off]
## --off switches the cue off (the before).

const DT := 1.0 / 60.0
const READY := 10
const END := 130

var shapes: Array = ["P", "A"]
var out: String = "ls.rgb"
var sheet: String = ""
var off: bool = false
var size := Vector2i(380, 240)
var step: int = 2
var main: Node


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--shapes="):
			shapes = Array(a.substr(9).split(","))
		elif a.begins_with("--out="):
			out = a.substr(6)
		elif a.begins_with("--sheet="):
			sheet = a.substr(8)
		elif a == "--off":
			off = true
			RenderAnim.last_stand_poses = false
		elif a.begins_with("--size="):
			var p: PackedStringArray = a.substr(7).split("x")
			size = Vector2i(int(p[0]), int(p[1]))
		elif a.begins_with("--step="):
			step = int(a.substr(7))
	DirData.templatesProfile = "dynamic"
	var vpn := SubViewport.new()
	vpn.size = Vector2i(640, 360)
	root.add_child(vpn)
	main = load("res://render/main.tscn").instantiate()
	main.manual = true
	vpn.add_child(main)
	_run.call_deferred()


func _run() -> void:
	await process_frame
	AnimData.load_all()
	main.start_match(4, {"p1": false, "p2": false})
	for i in range(10):
		main.frame(DT)
	var S: SimState = main.host.S
	RenderAnim.ground_feet = false
	AnimRagdoll.shape_of = {"default": String(shapes[0]), "KAI": String(shapes[0]), "VORR": String(shapes[1])}
	RenderAnim._fighters.clear()
	var f0 = S.fighters[0]
	var f1 = S.fighters[1]
	for f in [f0, f1]:
		var at: int = int(f.wd.stageAt[2])
		f.wear = [int(at * 0.5), int(at * 0.8), int(at * 0.5), int(at * 0.4)]
		f.stage = [1, 2, 1, 1]
		f.state = "free"
		f.y = 0.0
		f.vx = 0.0
		f.vy = 0.0
	f0.x = 500.0
	f1.x = 560.0
	var sv := SubViewport.new()
	sv.size = size
	sv.own_world_3d = true
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(sv)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.13, 0.15, 0.22)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.8, 0.8, 0.85)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 130.0
	cam.environment = env
	sv.add_child(cam)
	cam.position = Vector3(0.0, 8.0, 300.0)
	cam.current = true
	var pals: Array = [{"body": Color("#3d8fdc"), "legs": Color("#1b1f2a"), "arms": Color("#e6b995"), "skin": Color("#efc7a2"), "gear": Color("#cdd6e4"), "accent": Color("#4fb9a8"), "hair": Color("#22c7a9")},
		{"body": Color("#b0453a"), "legs": Color("#2a1b1b"), "arms": Color("#c79a7e"), "skin": Color("#d8b095"), "gear": Color("#d6cdcd"), "accent": Color("#d8705f"), "hair": Color("#2a2022")}]
	var pivots: Array = []
	var bodies: Array = []
	for i in range(2):
		var pv := Node3D.new()
		sv.add_child(pv)
		var bd := AnimBody.new()
		bd.build(pals[i], false)
		pv.add_child(bd)
		pivots.append(pv)
		bodies.append(bd)
	var ground := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(400.0, 2.0, 2.0)
	ground.mesh = bm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.35, 0.4, 0.5)
	gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ground.material_override = gm
	sv.add_child(ground)
	ground.position = Vector3(0.0, -43.0, 0.0)
	var cl := CanvasLayer.new()
	sv.add_child(cl)
	var label := Label.new()
	label.position = Vector2(4, 2)
	label.add_theme_font_size_override("font_size", 11)
	cl.add_child(label)
	var fa: FileAccess = null
	var tiles: Array = []
	var frames_written: int = 0
	if sheet == "":
		fa = FileAccess.open(out, FileAccess.WRITE)
		fa.store_32(size.x)
		fa.store_32(size.y)
		fa.store_32(0)
	var sheet_ticks: Array = [6, 24, 40, 70, 125, 140, 160, 190]
	var base_t: float = 200.0
	var base_tick: int = 1000
	for k in range(200):
		S.tick = base_tick + k
		S.T = base_t + float(k) * DT
		var evs: Array = []
		var te := SimState.FxEvent.new()
		te.type = "tick"
		te.dt = DT
		te.frozen = false
		te.tick = S.tick
		evs.append(te)
		if k == READY:
			for j in range(2):
				var e := SimState.FxEvent.new()
				e.type = "last_stand_ready"
				e.actor = float(j)
				e.dur = 20.0
				e.tick = S.tick
				evs.append(e)
		if k == END:
			for j in range(2):
				var e2 := SimState.FxEvent.new()
				e2.type = "last_stand_end"
				e2.actor = float(j)
				e2.kind = "expired" if j == 0 else "used"
				e2.tick = S.tick
				evs.append(e2)
		RenderAnim.consume(S, evs)
		var af0: AnimFighter = RenderAnim.solve(S, f0)
		var af1: AnimFighter = RenderAnim.solve(S, f1)
		var want: bool = (k % step == 0) if sheet == "" else sheet_ticks.has(k)
		if not want:
			continue
		var phase: String = "before the brink"
		if k >= READY:
			phase = "the brink: the window is open"
		if k >= END:
			phase = "the window closes (left: expired, right: used)"
		label.text = "%s   left %s   right %s%s" % [phase, String(shapes[0]), String(shapes[1]), "   (cue off)" if off else ""]
		for i in range(2):
			var af: AnimFighter = af0 if i == 0 else af1
			var fx: float = f0.x if i == 0 else f1.x
			pivots[i].scale = Vector3(af.vface, 1.0, 1.0)
			pivots[i].position = Vector3(fx - 530.0, -43.0, 0.0)
			bodies[i].apply(af.q, af.hips, af.curl, af.root_off)
		for _w in range(4):
			await process_frame
		var img: Image = sv.get_texture().get_image()
		img.convert(Image.FORMAT_RGB8)
		if sheet != "":
			tiles.append(img)
		else:
			fa.store_buffer(img.get_data())
			frames_written += 1
	if fa != null:
		fa.seek(8)
		fa.store_32(frames_written)
		fa.close()
		print("LAST STAND LAB ", out, " ", frames_written, " frames ", size.x, "x", size.y)
	if sheet != "" and tiles.size() > 0:
		var cols: int = 4
		var rows: int = int(ceil(float(tiles.size()) / float(cols)))
		var big := Image.create(cols * size.x, rows * size.y, false, Image.FORMAT_RGB8)
		for i in range(tiles.size()):
			big.blit_rect(tiles[i], Rect2i(0, 0, size.x, size.y), Vector2i((i % cols) * size.x, (i / cols) * size.y))
		big.save_png(sheet)
		print("SHEET ", sheet)
	quit(0)
