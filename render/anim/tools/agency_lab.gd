extends SceneTree
## Agency lab (docs/animation/pose-pipeline.md 9.22): the agency slice's events through the real solver, injected as the sim sends them. Two fighters in a fixed
## side view, the subject on the left (fighter 0), a rival standing on the right. One scene a run, or all of them on one sheet:
##   taunt            the cue taunt_start on tick 10 (45 ticks), flying
##   charge_light     the cue charge_light on tick 10; the exchange starts at tick 70 (the charge ends: the lab sets a state the layer also ends on)
##   charge_heavy     the cue charge_heavy on tick 10; the exchange starts at tick 90
##   charge_feint     charge_light on tick 10, charge_feint on tick 50 (the peel), the flight ended
##   knock_short, knock_long, drift   the knockback event on tick 10 (kind slideShort 0.5 s, slideLong 1.1 s, drift 1.0 s), the subject sent back
##   embed            the embed event on tick 10 (60 ticks driven in), then the get-up
##   swat, mine, spray   the parked energy sequences of wave energy1 played on tick 10 (spray: four bolts, six ticks apart); run with --waves
## Needs a window to draw; run it with --no-window (offscreen), never a window.
##   godot --no-window --path . -s res://render/anim/tools/agency_lab.gd -- --scene=taunt [--out=a.rgb | --sheet=s.png] [--size=300x200] [--step=2] [--off] [--reduced]
## --off switches the agency poses off (the before).

const DT := 1.0 / 60.0
const SCENES := ["taunt", "charge_light", "charge_heavy", "charge_feint", "knock_short", "knock_long", "drift", "embed"]
const ENERGY := ["swat", "mine", "spray", "curve", "chin", "chin_beam"]   # the parked energy poses (wave energy1, docs 9.24): the lab plays the sequence by hand (nothing fires these yet); needs --waves

var scene: String = "taunt"
var scene_given: bool = false
var out: String = "agency.rgb"
var sheet: String = ""
var off: bool = false
var size := Vector2i(300, 200)
var step: int = 2
var main: Node


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--scene="):
			scene = a.substr(8)
			scene_given = true
		elif a.begins_with("--out="):
			out = a.substr(6)
		elif a.begins_with("--sheet="):
			sheet = a.substr(8)
		elif a == "--off":
			off = true
			RenderAnim.agency_poses = false
		elif a == "--reduced":
			RenderAnim.reduced_motion = true
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


func _ev(type: String, tick: int, fields: Dictionary) -> SimState.FxEvent:
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
	var scenes: Array = [scene] if (sheet == "" or scene_given) else (SCENES + ENERGY if OS.get_cmdline_user_args().has("--waves") else SCENES)
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
	cam.size = 150.0
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
	bm.size = Vector3(600.0, 2.0, 2.0)
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
	var total: int = 150
	if sheet == "":
		fa = FileAccess.open(out, FileAccess.WRITE)
		fa.store_32(size.x)
		fa.store_32(size.y)
		fa.store_32(0)
	for sc in scenes:
		RenderAnim._fighters.clear()
		var sheet_ticks: Array = [8, 14, 22, 34, 50, 66, 90, 120]
		var x0: float = 500.0
		for k in range(total):
			S.tick = 1000 + k
			S.T = 200.0 + float(k) * DT
			var evs: Array = []
			var te := SimState.FxEvent.new()
			te.type = "tick"
			te.dt = DT
			te.frozen = false
			te.tick = S.tick
			evs.append(te)
			f0.state = "free"
			f0.y = 0.0
			f0.vy = 0.0
			f0.vx = 0.0
			f1.state = "free"
			f1.y = 0.0
			f1.x = x0 + 130.0
			f0.face = 1.0
			f1.face = -1.0
			f0.x = x0
			var label_phase: String = sc
			match sc:
				"taunt":
					f0.y = 24.0
					if k == 10:
						evs.append(_ev("cue", S.tick, {"actor": 0.0, "kind": "taunt_start"}))
				"charge_light", "charge_heavy", "charge_feint":
					f0.y = 24.0
					f0.vx = 600.0 if k > 10 and k < 70 else 0.0
					f0.x = x0 + (float(k - 10) * 1.6 if k > 10 else 0.0)
					if k == 10:
						evs.append(_ev("cue", S.tick, {"actor": 0.0, "kind": "charge_heavy" if sc == "charge_heavy" else "charge_light"}))
					if sc == "charge_feint" and k == 50:
						evs.append(_ev("cue", S.tick, {"actor": 0.0, "kind": "charge_feint"}))
					var end_k: int = 90 if sc == "charge_heavy" else 70
					if sc != "charge_feint" and k >= end_k:
						f0.state = "launched"   # the exchange begins: the charge ends (the lab stands for it with a state the layer also ends on)
				"knock_short", "knock_long", "drift":
					var kind: String = {"knock_short": "slideShort", "knock_long": "slideLong", "drift": "drift"}[sc]
					var dur: float = {"knock_short": 0.5, "knock_long": 1.1, "drift": 1.0}[sc]
					var u: float = clampf(float(k - 10) / (dur * 60.0), 0.0, 1.0)
					f0.x = x0 - (1.0 - pow(1.0 - u, 2.0)) * (60.0 if sc == "knock_short" else (130.0 if sc == "knock_long" else 90.0))
					f0.vx = -200.0 * (1.0 - u) if k > 10 else 0.0
					if sc == "drift":
						f0.y = 14.0 * sin(u * PI)
					if k == 10:
						evs.append(_ev("knockback", S.tick, {"victim": 0.0, "attacker": 1.0, "kind": kind, "amount": 60.0, "n": S.tick + int(dur * 60.0), "dur": dur}))
				"swat", "mine", "spray":
					var sq: String = {"curve": "pn.curve", "chin": "rv.on_the_chin", "chin_beam": "rv.chin_beam"}.get(sc, "en." + sc)   # (curve: the Protagonist's curving shot, protag3; chin and chin_beam: the rival's On the Chin, rival1)
					var at: Array = [10, 16, 22, 28] if sc == "spray" else [10]
					if at.has(k) and AnimData.entries.has(sq):
						var afe: AnimFighter = RenderAnim.fighter(S, f0)
						afe._seq = {"id": sq, "t0": S.T, "dur": float(AnimData.entries[sq].dur) / 60.0, "wt": 1.0}
				"embed":
					if k >= 10 and k < 70:
						f0.state = "down"
						f0.x = x0
					if k == 10:
						evs.append(_ev("embed", S.tick, {"actor": 0.0, "dur": 60.0, "x": f0.x, "y": 0.0, "depth": 20.0, "r": 40.0}))
			RenderAnim.consume(S, evs)
			var af0: AnimFighter = RenderAnim.solve(S, f0)
			var af1: AnimFighter = RenderAnim.solve(S, f1)
			var want: bool = (k % step == 0) if sheet == "" else sheet_ticks.has(k)
			if not want:
				continue
			label.text = "%s   tick %d%s%s" % [label_phase, k, "   (reduced motion)" if RenderAnim.reduced_motion else "", "   (agency poses off)" if off else ""]
			var cam_x: float = (f0.x + f1.x) * 0.5 if sc.begins_with("knock") or sc == "drift" else x0 + 60.0
			for i in range(2):
				var af: AnimFighter = af0 if i == 0 else af1
				var f = f0 if i == 0 else f1
				pivots[i].scale = Vector3(af.vface, 1.0, 1.0)
				pivots[i].position = Vector3(f.x - cam_x, -43.0 + f.y, 0.0)
				pivots[i].rotation.z = -f.rot if f.get("rot") != null else 0.0
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
		print("AGENCY LAB ", out, " ", frames_written, " frames ", size.x, "x", size.y)
	if sheet != "" and tiles.size() > 0:
		var cols: int = 4
		var rows: int = int(ceil(float(tiles.size()) / float(cols)))
		var big := Image.create(cols * size.x, rows * size.y, false, Image.FORMAT_RGB8)
		for i in range(tiles.size()):
			big.blit_rect(tiles[i], Rect2i(0, 0, size.x, size.y), Vector2i((i % cols) * size.x, (i / cols) * size.y))
		big.save_png(sheet)
		print("SHEET ", sheet)
	quit(0)
