extends SceneTree
## Intro lab (docs/architecture/intro-phase.md, docs/camera/rule-of-cool-shots.md row 7): the opening's five seconds through the real solver, from the sim's own
## events injected on their ticks (intro_start 0; A's entrance_fall 0 and entrance_land 36; B's 84 and 114; staredown_start 144 for 156 ticks; clock_start 300),
## with the fighters in the sim's `intro` state, S.T frozen at 0 and only S.tick running, and the camera's cuts as Camera planned them: falling with the faller,
## a low frame at each touchdown, the two-shot, two face cuts (ticks 240 to 264 and 264 to 288), the two-shot again. The fighters stand 200 units apart here (the
## sim's 900 would not fit a lab view). Needs a window.
##   godot --path . --script res://render/anim/tools/intro_lab.gd -- [--out=intro.rgb | --sheet=s.png] [--reduced] [--off] [--skip=20] [--size=360x220] [--step=2]
## --off: the opening's poses switched off (the before). --reduced: reduced motion (he drops into frame and stands). --skip=N: a press at tick N (clock_start, kind skip).

const DT := 1.0 / 60.0
const FALL := [0, 84]
const LAND := [36, 114]
const STARE := 144
const CLOCK := 300
const TOP := 6000.0
const GAP := 200.0

var out: String = "intro.rgb"
var sheet: String = ""
var off: bool = false
var skip_at: int = -1
var size := Vector2i(360, 220)
var step: int = 2
var main: Node


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
		elif a.begins_with("--sheet="):
			sheet = a.substr(8)
		elif a == "--reduced":
			RenderAnim.reduced_motion = true
		elif a == "--off":
			off = true
			RenderAnim.intro_poses = false
		elif a.begins_with("--skip="):
			skip_at = int(a.substr(7))
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


func _ev(type: String, fields: Dictionary, tick: int) -> SimState.FxEvent:
	var e := SimState.FxEvent.new()
	e.type = type
	e.tick = tick
	for k in fields:
		e.set(k, fields[k])
	return e


func _run() -> void:
	await process_frame
	AnimData.load_all()
	main.start_match(4, {"p1": false, "p2": false})
	for i in range(10):
		main.frame(DT)
	var S: SimState = main.host.S
	RenderAnim.ground_feet = false
	RenderAnim._fighters.clear()
	var f0 = S.fighters[0]
	var f1 = S.fighters[1]
	var sv := SubViewport.new()
	sv.size = size
	sv.own_world_3d = true
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(sv)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.16, 0.2, 0.3)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.8, 0.8, 0.85)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.environment = env
	sv.add_child(cam)
	cam.position = Vector3(0.0, 0.0, 400.0)
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
	bm.size = Vector3(2400.0, 2.0, 2.0)
	ground.mesh = bm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.4, 0.35, 0.3)
	gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ground.material_override = gm
	sv.add_child(ground)
	ground.position = Vector3(0.0, -43.0, 0.0)
	var craters: Array = []
	for i in range(2):
		var cr := MeshInstance3D.new()
		var cm := BoxMesh.new()
		cm.size = Vector3(300.0, 8.0, 2.0)
		cr.mesh = cm
		var cmat := StandardMaterial3D.new()
		cmat.albedo_color = Color(0.22, 0.18, 0.15)
		cmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		cr.material_override = cmat
		cr.visible = false
		sv.add_child(cr)
		craters.append(cr)
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
		fa.store_32(CLOCK / step + 1)
	var xs: Array = [500.0, 500.0 + GAP]
	var sheet_ticks: Array = [20, 36, 44, 70, 114, 130, 160, 200, 225, 252, 276, 292]
	var skipped: bool = false
	var end_tick: int = CLOCK + 12
	for k in range(end_tick):
		S.tick = 100 + k
		S.T = 0.0
		var evs: Array = []
		var tkn: int = 100 + k
		var phase: int = k
		if k == 0:
			evs.append(_ev("intro_start", {"dur": 5.0, "delay": 0.4}, tkn))
		for j in range(2):
			if k == FALL[j]:
				evs.append(_ev("entrance_fall", {"actor": float(j), "x": xs[j], "y": 0.0, "y1": TOP, "dur": float(LAND[j] - FALL[j]) / 60.0}, tkn))
			if k == LAND[j]:
				evs.append(_ev("entrance_land", {"actor": float(j), "x": xs[j], "y": 0.0, "y1": TOP, "r": 150.0}, tkn))
		if k == STARE:
			evs.append(_ev("staredown_start", {"dur": float(CLOCK - STARE) / 60.0}, tkn))
		if k == CLOCK or (skip_at >= 0 and k == skip_at):
			evs.append(_ev("clock_start", {"kind": "skip" if skip_at >= 0 and k == skip_at else "full"}, tkn))
			if skip_at >= 0 and k == skip_at:
				skipped = true
		var te := SimState.FxEvent.new()
		te.type = "tick"
		te.dt = DT
		te.frozen = true
		te.tick = tkn
		evs.append(te)
		# the sim's state: in the `intro` state until the clock, falling on a closed-form path
		for j in range(2):
			var f = S.fighters[j]
			f.state = "free" if (k >= CLOCK or skipped) else "intro"
			f.x = xs[j]
			f.vx = 0.0
			var y: float = 0.0
			if not skipped:
				if k < FALL[j]:
					y = TOP
				elif k < LAND[j]:
					var u: float = float(k - FALL[j]) / float(LAND[j] - FALL[j])
					y = TOP * (1.0 - u * u)
			f.y = y
			f.vy = 0.0 if y <= 0.0 or y >= TOP else -TOP * 2.0 * float(k - FALL[j]) / pow(float(LAND[j] - FALL[j]), 2.0) * 60.0
			f.face = 1.0 if j == 0 else -1.0
		RenderAnim.consume(S, evs)
		var af0: AnimFighter = RenderAnim.solve(S, f0)
		var af1: AnimFighter = RenderAnim.solve(S, f1)
		var want: bool = (k % step == 0) if sheet == "" else sheet_ticks.has(k)
		if not want:
			continue
		# the cameras of the shot plan
		var look_x: float = 0.0
		var look_y: float = 0.0
		var csize: float = 150.0
		var who: String = "two-shot"
		var shot: String = "two-shot"
		if skipped:
			shot = "skip: the ordinary framing"
		elif k < 36:
			shot = "A falls"
			look_x = xs[0] + 10.0
			look_y = f0.y + 40.0
			csize = 300.0
		elif k < 84:
			shot = "A lands"
			look_x = xs[0] + 20.0
			csize = 120.0
			look_y = 0.26 * csize
		elif k < 114:
			shot = "B falls"
			look_x = xs[1] - 10.0
			look_y = f1.y + 40.0
			csize = 300.0
		elif k < STARE:
			shot = "B lands"
			look_x = xs[1] - 20.0
			csize = 120.0
			look_y = 0.26 * csize
		elif k >= 240 and k < 264:
			shot = "A's face"
			look_x = xs[0] + 6.0
			look_y = 80.0
			csize = 30.0
		elif k >= 264 and k < 288:
			shot = "B's face"
			look_x = xs[1] - 6.0
			look_y = 80.0
			csize = 30.0
		else:
			shot = "two-shot"
			look_x = xs[0] + GAP * 0.5
			look_y = 46.0
			csize = 175.0 - 15.0 * clampf(float(k - STARE) / 150.0, 0.0, 1.0)
		cam.size = csize
		cam.position = Vector3(look_x, look_y - 43.0, 400.0)
		for i in range(2):
			var af: AnimFighter = af0 if i == 0 else af1
			var f = f0 if i == 0 else f1
			pivots[i].scale = Vector3(af.vface, 1.0, 1.0)
			pivots[i].position = Vector3(xs[i], -43.0 + f.y, 0.0)
			bodies[i].apply(af.q, af.hips, af.curl, af.root_off)
			craters[i].visible = k >= LAND[i] and not off
			craters[i].position = Vector3(xs[i], -43.0 - 2.0, -4.0)
		label.text = "tick %d   %s%s%s" % [k, shot, "   (reduced motion)" if RenderAnim.reduced_motion else "", "   (poses off)" if off else ""]
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
		print("INTRO LAB ", out, " ", frames_written, " frames ", size.x, "x", size.y)
	if sheet != "" and tiles.size() > 0:
		var cols: int = 4
		var rows: int = int(ceil(float(tiles.size()) / float(cols)))
		var big := Image.create(cols * size.x, rows * size.y, false, Image.FORMAT_RGB8)
		for i in range(tiles.size()):
			big.blit_rect(tiles[i], Rect2i(0, 0, size.x, size.y), Vector2i((i % cols) * size.x, (i / cols) * size.y))
		big.save_png(sheet)
		print("SHEET ", sheet)
	quit(0)
