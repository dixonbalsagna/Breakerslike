extends SceneTree
## Cue lab (the review pipeline, Encounter's step 3 cues: data/anim/waves/step3.*): each cue event (perfect_block, reversal, dodge_cancel, burst,
## burst_absorbed) is sent through the real solver as the sim's own `cue` event, with the right fighter in front of it: the actor on the right, the
## other fighter (the one who staggers, absorbs or is shoved) on the left. A burst shoves him by a jump in his speed, as the sim does. A fixed side view,
## captioned. Needs a window.
##   godot --path . --script res://render/anim/tools/cue_lab.gd -- [--cues=perfect_block,burst] [--out=cues.rgb | --sheet=s.png] [--variant=b] [--label=TEXT]
##       [--size=380x240] [--step=2]

const DT := 1.0 / 60.0
const HOLD := 10

var cues: Array = []
var out: String = "cues.rgb"
var sheet: String = ""
var variant: String = ""
var label_text: String = ""
var size := Vector2i(380, 240)
var step: int = 2
var main: Node


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--cues="):
			cues = Array(a.substr(7).split(","))
		elif a.begins_with("--out="):
			out = a.substr(6)
		elif a.begins_with("--sheet="):
			sheet = a.substr(8)
		elif a.begins_with("--variant="):
			variant = a.substr(10)
		elif a.begins_with("--label="):
			label_text = a.substr(8)
		elif a.begins_with("--size="):
			var p: PackedStringArray = a.substr(7).split("x")
			size = Vector2i(int(p[0]), int(p[1]))
		elif a.begins_with("--step="):
			step = int(a.substr(7))
	RenderAnim.step3_cues = true
	AnimData.load_waves = true
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
	if variant != "":
		for k in AnimData.cue_map:
			for role in AnimData.cue_map[k]:
				var sid: String = String(AnimData.cue_map[k][role]) + "~" + variant
				if AnimData.entries.has(sid):
					AnimData.cue_map[k][role] = sid
	var list: Array = []
	for k in AnimData.cue_map:
		if cues.is_empty() or cues.has(k):
			list.append(k)
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
		fa.store_32(list.size() * 40)
	var f0 = S.fighters[0]
	var f1 = S.fighters[1]
	var si: int = 0
	for kind in list:
		var m: Dictionary = AnimData.cue_map[kind]
		var asid: String = String(m.get("actor", ""))
		var dur_ticks: int = int(AnimData.entries[asid].dur) if AnimData.entries.has(asid) else 20
		var osid: String = String(m.get("other", m.get("other_if_stunned", m.get("other_if_shoved", ""))))
		if AnimData.entries.has(osid):
			dur_ticks = maxi(dur_ticks, int(AnimData.entries[osid].dur))
		RenderAnim._fighters.clear()
		S.dirS.ex = null
		var base_t: float = 200.0 + float(si) * 9.0
		var base_tick: int = 1000 + si * 500
		f0.x = 500.0
		f1.x = 560.0
		f0.y = 0.0
		f1.y = 0.0
		f0.state = "free"
		f1.state = "free"
		f0.vx = 0.0
		f0.vy = 0.0
		f1.vx = 0.0
		f1.vy = 0.0
		var n_ticks: int = HOLD + dur_ticks + 14
		var sent: bool = false
		var sheet_ticks: Array = [HOLD + 2, HOLD + dur_ticks / 2, HOLD + dur_ticks - 1]
		for k in range(n_ticks):
			S.tick = base_tick + k
			S.T = base_t + float(k) * DT
			if kind == "burst" and k > HOLD:
				f0.vx = -700.0 * pow(0.78, float(k - HOLD - 1)) if k <= HOLD + 8 else 0.0
				f0.x -= 0.0
			var te := SimState.FxEvent.new()
			te.type = "tick"
			te.dt = DT
			te.frozen = false
			te.tick = S.tick
			var evs: Array = [te]
			if k == HOLD and (kind == "perfect_block" or kind == "reversal"):
				f0.stunTicks = 24 if kind == "perfect_block" else 16   # the sim staggers the attacker on this tick
			if not sent and k == HOLD:
				sent = true
				var ce := SimState.FxEvent.new()
				ce.type = "cue"
				ce.actor = 1.0
				ce.kind = kind
				ce.tick = S.tick
				evs.append(ce)
			RenderAnim.consume(S, evs)
			var af0: AnimFighter = RenderAnim.solve(S, f0)
			var af1: AnimFighter = RenderAnim.solve(S, f1)
			var want: bool = (k % step == 0) if sheet == "" else sheet_ticks.has(k)
			if not want:
				continue
			label.text = label_text if label_text != "" else "%s   actor: %s   other: %s" % [String(kind), asid.get_slice(".", 1), osid.get_slice(".", 1)]
			for i in range(2):
				var af: AnimFighter = af0 if i == 0 else af1
				var fx: float = (f0.x - 10.0 * float(k > HOLD and kind == "burst") * 0.0) if i == 0 else f1.x
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
		si += 1
	if fa != null:
		fa.seek(8)
		fa.store_32(frames_written)
		fa.close()
		print("CUE LAB ", out, " ", frames_written, " frames ", size.x, "x", size.y)
	if sheet != "" and tiles.size() > 0:
		var cols: int = 6
		var rows: int = int(ceil(float(tiles.size()) / float(cols)))
		var big := Image.create(cols * size.x, rows * size.y, false, Image.FORMAT_RGB8)
		for i in range(tiles.size()):
			big.blit_rect(tiles[i], Rect2i(0, 0, size.x, size.y), Vector2i((i % cols) * size.x, (i / cols) * size.y))
		big.save_png(sheet)
		print("SHEET ", sheet, " ", list.size(), " cues")
	quit(0)
