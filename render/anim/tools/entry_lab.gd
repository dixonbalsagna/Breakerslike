extends SceneTree
## Entry lab (the review pipeline, wave 2: docs/combat/pending/wave2-entries.md): plays each entry of a wave through the real solver (an `entry`
## beat in a real exchange, the real strike that follows it) against a dummy defender, in a close fixed side view. The sim owns the path in
## the game; here the lab moves the attacker along the entry's path (straight, arc, ground with a slide, spiral, rising, a short step, a step
## back and in, a hop) so the poses can be judged in motion, then the favoured strike of wave 1 plays out of it. Distances are compressed
## (a real rush covers 650 to 1,700 u in 15 to 39 ticks; the lab shows 170 u in 24) so the bodies stay big.
##   draw (needs a window): raw RGB frames of every entry (--out=), or a sheet of three frames per entry (--sheet=): the start, the middle, the arrival
##   --measure (headless): the flow of each entry into each favoured strike: the largest bone turn between the entry's last pose and the strike's wind-up
##   godot --path . --script res://render/anim/tools/entry_lab.gd -- --wave=wave2 [--ids=dash,rising] [--out=lab.rgb | --sheet=s.png | --measure --json=f.json]
##       [--size=420x260] [--step=2] [--strike-wave=wave1] [--variant=b] [--label=TEXT]

const DT := 1.0 / 60.0
const HOLD := 8                    # ticks of stance before the entry
const RUSH_TICKS := 24
const PUSHES := {}

var wave: String = "wave2"
var strike_wave: String = "wave1"
var ids: Array = []
var out: String = "entries.rgb"
var sheet: String = ""
var json_out: String = ""
var measure: bool = false
var variant: String = ""
var label_text: String = ""
var size := Vector2i(420, 260)
var step: int = 2
var main: Node
var manifest: Array = []
var strikes: Dictionary = {}


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--wave="):
			wave = a.substr(7)
		elif a.begins_with("--strike-wave="):
			strike_wave = a.substr(14)
		elif a.begins_with("--ids="):
			ids = Array(a.substr(6).split(","))
		elif a.begins_with("--out="):
			out = a.substr(6)
		elif a.begins_with("--sheet="):
			sheet = a.substr(8)
		elif a.begins_with("--json="):
			json_out = a.substr(7)
		elif a == "--measure":
			measure = true
		elif a.begins_with("--variant="):
			variant = a.substr(10)
		elif a.begins_with("--label="):
			label_text = a.substr(8)
		elif a.begins_with("--size="):
			var p: PackedStringArray = a.substr(7).split("x")
			size = Vector2i(int(p[0]), int(p[1]))
		elif a.begins_with("--step="):
			step = int(a.substr(7))
	AnimData.load_waves = true
	DirData.templatesProfile = "dynamic"
	var vpn := SubViewport.new()
	vpn.size = Vector2i(640, 360)
	root.add_child(vpn)
	main = load("res://render/main.tscn").instantiate()
	main.manual = true
	vpn.add_child(main)
	_run.call_deferred()


func _ease(p: float) -> float:
	return p * p * (3.0 - 2.0 * p)


## The attacker's separation from the rival (u) and height above the ground (u) at progress p (0 to 1) of the entry.
func _path(shape: String, p: float, d0: float, off: float, advance: float, rival_y: float) -> Vector2:
	var sep: float = lerpf(d0, off, _ease(p))
	var y: float = 0.0
	match shape:
		"arc":
			y = 60.0 * 4.0 * p * (1.0 - p)
		"ground":
			var s: float = 0.75 * (p / 0.7) if p < 0.7 else 0.75 + 0.25 * (1.0 - pow(1.0 - (p - 0.7) / 0.3, 2.0))
			sep = d0 - (d0 - off) * s
		"spiral":
			y = 0.2 * d0 * 0.5 * sin(PI * p)
		"rising":
			y = (rival_y - 44.0) * _ease(p)
		"none":
			sep = off + advance * (1.0 - _ease(p))
		"back", "hop":
			# nine ticks back to 90 u, then six forward again (the counter step): p is over the whole 15
			var q: float = p * 15.0
			sep = off + 90.0 * (_ease(q / 9.0) if q < 9.0 else (1.0 - _ease((q - 9.0) / 6.0)))
			if shape == "hop":
				y = 40.0 * sin(PI * clampf(q / 9.0, 0.0, 1.0)) if q < 9.0 else 0.0
	return Vector2(sep, y)


func _run() -> void:
	await process_frame
	var mj = JSON.parse_string(FileAccess.get_file_as_string("res://data/anim/waves/%s.entrymap.json" % wave))
	manifest = mj.entries
	var sj = JSON.parse_string(FileAccess.get_file_as_string("res://data/anim/waves/%s.manifest.json" % strike_wave))
	for s in sj.strikes:
		strikes[String(s.name)] = s
	main.start_match(4, {"p1": false, "p2": false})
	for i in range(10):
		main.frame(DT)
	var S: SimState = main.host.S
	RenderAnim.ground_feet = false
	var list: Array = []
	for m in manifest:
		if ids.is_empty() or ids.has(m.name):
			list.append(m)
	if measure:
		_measure(list)
		return
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
	cam.size = 190.0
	cam.environment = env
	sv.add_child(cam)
	cam.position = Vector3(0.0, 40.0, 300.0)
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
	if sheet == "":
		fa = FileAccess.open(out, FileAccess.WRITE)
		fa.store_32(size.x)
		fa.store_32(size.y)
		fa.store_32(list.size() * 40)
	var f0 = S.fighters[0]
	var f1 = S.fighters[1]
	var si: int = 0
	for m in list:
		var eid: String = String(m.id) + ("~" + variant if variant != "" else "")
		if not AnimData.entries.has(eid):
			eid = String(m.id)
		var fav: String = _favoured(m)
		var st: Dictionary = strikes[fav]
		var off: float = float(st.offset)
		var heavy: bool = String(st.weight) == "heavy"
		var lab: Dictionary = m.lab
		var shape: String = String(lab.get("shape", "none"))
		var d0: float = float(lab.get("d0", 60.0))
		var advance: float = float(lab.get("advance", 0.0))
		var rival_y: float = 130.0 if shape == "rising" else 0.0
		var dur_ticks: int = _entry_ticks(m)
		var load_s: float = float(st.ticks.load) * DT * (0.75 + 0.35 * (1.0 if heavy else 0.6)) + 3.0 * DT
		var t_e: float = float(HOLD) * DT
		var tc: float = t_e + float(dur_ticks) * DT + load_s
		var n_ticks: int = int((tc + 0.30) / DT)
		RenderAnim._fighters.clear()
		RenderAnim.force_keyset = String(st.id)
		var base_t: float = 200.0 + float(si) * 9.0
		var base_tick: int = 1000 + si * 500
		var ex := DirExchange.newEx(f0, f1, "heavy" if heavy else "light")
		ex.n = 700 + si
		ex.tag = "LAB"
		var dmg: float = 66.0 if heavy else 26.0
		DirExchange.schedule(ex, t_e, "entry", {"who": "A", "dur": float(dur_ticks) * DT, "id": eid})
		DirExchange.schedule(ex, tc, "strike", {"a": "A", "dmg": dmg, "o": {"big": heavy}})
		S.dirS.ex = ex
		f1.x = 600.0
		f1.y = rival_y
		f1.state = "free"
		f1.vx = 0.0
		f1.vy = 0.0
		f0.state = "free"
		var hit_sent: bool = false
		var sheet_ticks: Array = [int(t_e / DT) + 1, int(t_e / DT) + dur_ticks / 2, int(t_e / DT) + dur_ticks]
		var prev := Vector2.ZERO
		for k in range(n_ticks):
			S.tick = base_tick + k
			S.T = base_t + float(k) * DT
			ex.t = float(k) * DT
			var p: float = clampf((ex.t - t_e) / maxf(float(dur_ticks) * DT, DT), 0.0, 1.0)
			var pos: Vector2 = _path(shape, p, d0, off, advance, rival_y) if ex.t >= t_e else _path(shape, 0.0, d0, off, advance, rival_y)
			if ex.t > tc:
				pos = Vector2(off, pos.y if shape != "rising" else rival_y - 44.0)
			f0.x = f1.x - pos.x
			f0.y = pos.y
			f0.vx = (pos.x - prev.x) * -60.0 if k > 0 else 0.0
			f0.vy = (pos.y - prev.y) * 60.0 if k > 0 else 0.0
			prev = pos
			var te := SimState.FxEvent.new()
			te.type = "tick"
			te.dt = DT
			te.frozen = false
			RenderAnim.consume(S, [te])
			if not hit_sent and ex.t >= tc - DT * 0.5:
				hit_sent = true
				var de := SimState.FxEvent.new()
				de.type = "damage"
				de.victim = 1.0
				de.attacker = 0.0
				de.kind = "heavy" if heavy else "light"
				de.amount = dmg
				var tg: String = String(st.target)
				de.region = "head" if (tg == "head" or tg == "jaw") else ("legs" if (tg == "legs" or tg == "shins") else "core")
				RenderAnim.consume(S, [de])
			var af0: AnimFighter = RenderAnim.solve(S, f0)
			var af1: AnimFighter = RenderAnim.solve(S, f1)
			var want: bool = (k % step == 0) if sheet == "" else sheet_ticks.has(k)
			if not want:
				continue
			label.text = label_text if label_text != "" else "%s  into  %s   %s" % [String(m.name), fav, String(m.path)]
			var cx: float = 600.0 - d0 * 0.45
			for i in range(2):
				var af: AnimFighter = af0 if i == 0 else af1
				var fx: float = f0.x if i == 0 else f1.x
				var fy: float = f0.y if i == 0 else f1.y
				pivots[i].scale = Vector3(af.vface, 1.0, 1.0)
				pivots[i].position = Vector3(fx - cx, -43.0 + fy, 0.0)
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
	RenderAnim.force_keyset = ""
	if fa != null:
		fa.seek(8)
		fa.store_32(frames_written)
		fa.close()
		print("ENTRY LAB ", out, " ", frames_written, " frames ", size.x, "x", size.y)
	if sheet != "" and tiles.size() > 0:
		var cols: int = 6
		var rows: int = int(ceil(float(tiles.size()) / float(cols)))
		var big := Image.create(cols * size.x, rows * size.y, false, Image.FORMAT_RGB8)
		for i in range(tiles.size()):
			big.blit_rect(tiles[i], Rect2i(0, 0, size.x, size.y), Vector2i((i % cols) * size.x, (i / cols) * size.y))
		big.save_png(sheet)
		print("SHEET ", sheet, " ", list.size(), " entries")
	quit(0)


## The favoured strike the lab plays after an entry: the first of its favours that wave 1 poses.
func _favoured(m) -> String:
	for f in m.favours:
		if strikes.has(String(f)):
			return String(f)
	return String(strikes.keys()[0])


func _entry_ticks(m) -> int:
	var t = m.ticks.get("travel", m.ticks.get("c", 0)) if typeof(m.ticks) == TYPE_DICTIONARY else m.ticks
	if String(m.direction) == "rush":
		return RUSH_TICKS
	var n: int = int(t) if (typeof(t) == TYPE_FLOAT or typeof(t) == TYPE_INT) else 9
	if String(m.direction) == "retreat":
		return 15 if String(m.lab.get("shape", "")) != "none" else maxi(n, 6)
	return maxi(n, 12 if n == 0 else n)


## The flow of each entry into each favoured strike: the largest bone turn and the hip offset between the entry's last pose and the strike's wind-up.
func _measure(list: Array) -> void:
	var rep: Array = []
	for m in list:
		var last: String = String(m.poses[m.poses.size() - 1])
		var pa: AnimPose = AnimData.pose(last)
		var row: Dictionary = {"id": String(m.id), "name": String(m.name), "last": last, "flows": []}
		for f in m.favours:
			if not strikes.has(String(f)):
				continue
			var pc: AnimPose = AnimData.pose(String(strikes[String(f)].poses[0]))
			var worst: float = 0.0
			var sum: float = 0.0
			for bn in ["upper_arm_r", "upper_arm_l", "forearm_r", "forearm_l", "thigh_r", "thigh_l", "shin_r", "shin_l"]:
				var a: float = pa.q[AnimRig.index[bn]].angle_to(pc.q[AnimRig.index[bn]])
				worst = maxf(worst, a)
				sum += a
			row.flows.append({"strike": String(f), "max": snappedf(worst, 0.01), "mean": snappedf(sum / 8.0, 0.01), "hips": snappedf((pa.hips - pc.hips).length(), 0.1)})
		rep.append(row)
	print("entry flow (the mean limb-bone turn in rad from the entry's last pose to each favoured strike's wind-up):")
	for r in rep:
		var parts: Array = []
		for fl in r.flows:
			parts.append("%s %.2f" % [fl.strike, fl.mean])
		print("  %-18s %s" % [r.name, ", ".join(parts)])
	if json_out != "":
		var jf := FileAccess.open(json_out, FileAccess.WRITE)
		jf.store_string(JSON.stringify({"tool": "entry_lab", "wave": wave, "flows": rep}))
		jf.close()
	quit(0)
