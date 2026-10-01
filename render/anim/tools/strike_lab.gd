extends SceneTree
## Strike lab (the review pipeline, docs/animation/review-plan.md): plays each key set of a wave against a dummy defender standing at that
## strike's own contact distance, through the real solver (the real AnimFighter, the real exchange beats, the contact solve and the
## defender's hit reaction), in a close fixed side view. No match runs: the lab sets the two fighters by hand and feeds the solver a
## strike beat and a damage event. Two modes:
##   draw (needs a window): raw RGB frames for tools/gif.mjs, a captioned reel of every strike, and a contact-frame sheet (--sheet=png)
##   --measure (headless): the reach gap, the second limb's gap, the step-in and the deepest clip of a limb that is not the striking one
##   into the defender, per strike, as JSON (--json=)
##   godot --path . --script res://render/anim/tools/strike_lab.gd -- --wave=wave1 [--ids=jab,cross | --all] [--out=lab.rgb] [--sheet=sheet.png]
##       [--measure --json=reach.json] [--variant=b] [--dist=58] [--size=300x190] [--step=2] [--noragdoll] [--nohunch]
## Strike ids are the wave's short names (the data/anim/waves/<wave>.manifest.json). --variant=b plays the B version of a strike that has one
## (an A/B pair). --dist overrides every strike's distance (to test a spacing).

const DT := 1.0 / 60.0
const TC := 0.7                   # the contact beat's time in the exchange (s)
const PRE := 0.32                 # frames start this long before contact
const POST := 0.40                # and end this long after
const CAPSULES := [["pelvis", "spine_1", 6.5], ["spine_1", "spine_2", 7.0], ["spine_2", "neck", 6.5], ["neck", "head", 3.5],
	["upper_arm_r", "forearm_r", 3.2], ["forearm_r", "hand_r", 2.8], ["upper_arm_l", "forearm_l", 3.2], ["forearm_l", "hand_l", 2.8],
	["pelvis", "thigh_r", 4.5], ["thigh_r", "shin_r", 4.0], ["shin_r", "foot_r", 3.4], ["pelvis", "thigh_l", 4.5], ["thigh_l", "shin_l", 4.0], ["shin_l", "foot_l", 3.4]]

var wave: String = "wave1"
var ids: Array = []
var out: String = "lab.rgb"
var sheet: String = ""
var json_out: String = ""
var measure: bool = false
var variant: String = ""
var sweep: bool = false        # --sweep (with --measure): the farthest distance each strike still reaches and the nearest it stays clear at
var ab_label: bool = false     # --ab: caption the A and B versions of a pair
var dist_over: float = -1.0
var size := Vector2i(300, 190)
var step: int = 2
var main: Node
var manifest: Array = []


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--wave="):
			wave = a.substr(7)
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
		elif a == "--sweep":
			sweep = true
		elif a == "--ab":
			ab_label = true
		elif a.begins_with("--variant="):
			variant = a.substr(10)
		elif a.begins_with("--dist="):
			dist_over = float(a.substr(7))
		elif a.begins_with("--size="):
			var p: PackedStringArray = a.substr(7).split("x")
			size = Vector2i(int(p[0]), int(p[1]))
		elif a.begins_with("--step="):
			step = int(a.substr(7))
		elif a == "--noragdoll":
			RenderAnim.ragdoll_enabled = false
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
	var mj = JSON.parse_string(FileAccess.get_file_as_string("res://data/anim/waves/%s.manifest.json" % wave))
	manifest = mj.strikes
	main.start_match(4, {"p1": false, "p2": false})
	for i in range(10):
		main.frame(DT)
	var S: SimState = main.host.S
	RenderAnim.ground_feet = false
	var list: Array = []
	for m in manifest:
		if ids.is_empty() or ids.has(m.name):
			list.append(m)
	var sv: SubViewport = null
	var bodies: Array = []
	var pivots: Array = []
	var label: Label = null
	var fa: FileAccess = null
	var tiles: Array = []
	if not measure:
		sv = SubViewport.new()
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
		cam.size = 118.0
		cam.environment = env
		sv.add_child(cam)
		cam.position = Vector3(0.0, 0.0, 300.0)
		cam.current = true
		var pals: Array = [{"body": Color("#3d8fdc"), "legs": Color("#1b1f2a"), "arms": Color("#e6b995"), "skin": Color("#efc7a2"), "gear": Color("#cdd6e4"), "accent": Color("#4fb9a8"), "hair": Color("#22c7a9")},
			{"body": Color("#b0453a"), "legs": Color("#2a1b1b"), "arms": Color("#c79a7e"), "skin": Color("#d8b095"), "gear": Color("#d6cdcd"), "accent": Color("#d8705f"), "hair": Color("#2a2022")}]
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
		label = Label.new()
		label.position = Vector2(4, 2)
		label.add_theme_font_size_override("font_size", 11)
		cl.add_child(label)
		if sheet == "":
			fa = FileAccess.open(out, FileAccess.WRITE)
			var nfr: int = list.size() * int(ceil((PRE + POST) / DT / float(step)))
			fa.store_32(size.x)
			fa.store_32(size.y)
			fa.store_32(nfr)
	var report: Array = []
	var f0 = S.fighters[0]
	var f1 = S.fighters[1]
	var si: int = 0
	var frames_written: int = 0
	if sweep:
		var srep: Array = []
		var swi: int = 0
		for m in list:
			var kid0: String = String(m.id)
			var best_reach: float = -1.0
			var best_hip: float = -1.0
			var clear_from: float = -1.0
			for dd in range(20, 100, 2):
				var r: Dictionary = _measure_one(S, f0, f1, m, kid0, float(dd), swi)
				swi += 1
				if float(r.gap) <= 1.0 and float(r.gap2) <= 1.0:
					best_reach = float(dd)
					if float(r.step) <= 0.5:
						best_hip = float(dd)
					if clear_from < 0.0 and float(r.clip) <= 6.0:
						clear_from = float(dd)
			srep.append({"id": String(m.id), "name": String(m.name), "combat_offset": float(m.offset), "combat_reach": float(m.reach), "reach_max": best_reach, "reach_hip": best_hip, "clear_from": clear_from})
		RenderAnim.force_keyset = ""
		print("strike sweep (%s): the farthest distance each strike reaches with the hips alone and with the full step-in (gap 1 u or less), and the nearest it stays clear (clip 6 u or less)" % wave)
		for r in srep:
			print("  %-16s combat offset %3d reach %3d   measured: hips alone %3d, with step-in %3d, clear from %3d" % [r.name, int(r.combat_offset), int(r.combat_reach), int(r.reach_hip), int(r.reach_max), int(r.clear_from)])
		if json_out != "":
			var jf2 := FileAccess.open(json_out, FileAccess.WRITE)
			jf2.store_string(JSON.stringify({"tool": "strike_lab", "wave": wave, "sweep": srep}))
			jf2.close()
		quit(0)
		return
	for m in list:
		var kid: String = String(m.id) + ("~" + variant if variant != "" else "")
		if not AnimData.keysets.has(kid):
			kid = String(m.id)
		var dist: float = dist_over if dist_over > 0.0 else float(m.offset)
		var heavy: bool = String(m.weight) == "heavy"
		RenderAnim._fighters.clear()
		RenderAnim.force_keyset = kid
		var base_t: float = 200.0 + float(si) * 7.0
		var base_tick: int = 1000 + si * 400
		f0.x = 500.0
		f1.x = 500.0 + dist
		f0.y = 0.0
		f1.y = 0.0
		f0.vx = 0.0
		f0.vy = 0.0
		f1.vx = 0.0
		f1.vy = 0.0
		f0.state = "free"
		f1.state = "free"
		var ex := DirExchange.newEx(f0, f1, "heavy" if heavy else "light")
		ex.n = 900 + si
		ex.tag = "LAB"
		var dmg: float = 66.0 if heavy else 26.0
		DirExchange.schedule(ex, TC, "strike", {"a": "A", "dmg": dmg, "o": {"big": heavy}})
		S.dirS.ex = ex
		var n_ticks: int = int((TC + POST) / DT) + 2
		var start_tick: int = int((TC - PRE) / DT)
		var af0: AnimFighter = null
		var af1: AnimFighter = null
		var hit_sent: bool = false
		var gap_info: Dictionary = {}
		var clip: Dictionary = {"depth": 0.0, "pair": ""}
		var max_step: float = 0.0
		for k in range(n_ticks):
			S.tick = base_tick + k
			S.T = base_t + float(k) * DT
			ex.t = float(k) * DT
			var te := SimState.FxEvent.new()
			te.type = "tick"
			te.dt = DT
			te.frozen = false
			RenderAnim.consume(S, [te])
			if not hit_sent and ex.t >= TC - DT * 0.5:
				hit_sent = true
				var de := SimState.FxEvent.new()
				de.type = "damage"
				de.victim = 1.0
				de.attacker = 0.0
				de.kind = "heavy" if heavy else "light"
				de.amount = dmg
				var tg: String = String(m.target)
				de.region = "head" if (tg == "head" or tg == "jaw") else ("legs" if (tg == "legs" or tg == "shins") else ("arms" if tg.begins_with("arm") else "core"))
				RenderAnim.consume(S, [de])
			af0 = RenderAnim.solve(S, f0)
			af1 = RenderAnim.solve(S, f1)
			max_step = maxf(max_step, af0._step_x)
			var at_contact: bool = absf(ex.t - TC) < DT * 0.5
			if at_contact:
				var c: Dictionary = _clip(af0, af1, dist, kid)
				if float(c.depth) > float(clip.depth):
					clip = c
			elif ex.t > TC - DT * 1.5 and ex.t < TC + DT * 2.5:
				var c2: Dictionary = _clip(af0, af1, dist, kid)
				if float(c2.depth) > float(clip.depth):
					clip = c2
			if not measure and k >= start_tick and (k - start_tick) % step == 0:
				label.text = "%s   %d u   %s" % [String(m.name), int(dist), "heavy" if heavy else "light"]
				if ab_label:
					label.text = ("B: %s" % String(m.alt)) if variant == "b" else "A: as drawn"
				for i in range(2):
					var af: AnimFighter = af0 if i == 0 else af1
					pivots[i].scale = Vector3(af.vface, 1.0, 1.0)
					var wx: float = -dist * 0.5 if i == 0 else dist * 0.5
					pivots[i].position = Vector3(wx, -43.0, 0.0)
					bodies[i].apply(af.q, af.hips, af.curl, af.root_off)
				for _w in range(4):
					await process_frame
				if sheet != "" and at_contact:
					var im: Image = sv.get_texture().get_image()
					im.convert(Image.FORMAT_RGB8)
					tiles.append(im)
				elif sheet == "":
					var img: Image = sv.get_texture().get_image()
					img.convert(Image.FORMAT_RGB8)
					fa.store_buffer(img.get_data())
					frames_written += 1
			elif not measure and sheet != "" and at_contact:
				pass
		var d0: Dictionary = af0.debug
		report.append({"id": String(m.id), "name": String(m.name), "keyset": kid, "dist": dist, "weight": String(m.weight),
			"gap": snappedf(float(d0.get("gap_max", 0.0)), 0.1), "gap2": snappedf(float(d0.get("gap2_max", 0.0)), 0.1),
			"excess": float(d0.gaps[1]) if d0.gaps.size() > 1 else 0.0,
			"step_in": snappedf(max_step, 0.1), "ik_frames": int(d0.get("ik_frames", 0)), "contact_err": snappedf(float(d0.get("contact_err_max", 0.0)), 0.0001), "contact_frames": int(d0.get("contact_frames", 0)), "part": String(af0._part), "contacts": int(d0.get("gap_n", 0)), "clip": snappedf(float(clip.depth), 0.1), "clip_pair": String(clip.pair)})
		si += 1
	RenderAnim.force_keyset = ""
	if fa != null:
		# pad the header's frame count to what was written (a variable number of frames per strike)
		fa.seek(8)
		fa.store_32(frames_written)
		fa.close()
		print("LAB ", out, " ", frames_written, " frames ", size.x, "x", size.y)
	if sheet != "" and tiles.size() > 0:
		var cols: int = 6
		var rows: int = int(ceil(float(tiles.size()) / float(cols)))
		var big := Image.create(cols * size.x, rows * size.y, false, Image.FORMAT_RGB8)
		for i in range(tiles.size()):
			big.blit_rect(tiles[i], Rect2i(0, 0, size.x, size.y), Vector2i((i % cols) * size.x, (i / cols) * size.y))
		big.save_png(sheet)
		print("SHEET ", sheet, " ", tiles.size(), " strikes")
	print("strike lab (%s): %d strikes" % [wave, report.size()])
	for r in report:
		print("  %-16s %3d u  gap %4.1f  gap2 %4.1f  step %4.1f  ik %2d/%d  clip %4.1f %s" % [r.name, int(r.dist), r.gap, r.gap2, r.step_in, r.ik_frames, r.contacts, r.clip, r.clip_pair])
	if json_out != "":
		var jf := FileAccess.open(json_out, FileAccess.WRITE)
		jf.store_string(JSON.stringify({"tool": "strike_lab", "wave": wave, "strikes": report}))
		jf.close()
	quit(0)


## The deepest clip of a limb that is not the striking one into the defender: sample points along the attacker's bones against the
## defender's capsules, in world x, y and the shared depth z (both fighters' near sides are +z). The striking limb's own tip is let
## through (it is meant to touch). Returns {depth, pair}.
func _clip(af0: AnimFighter, af1: AnimFighter, dist: float, kid: String) -> Dictionary:
	var ks: Dictionary = AnimData.keysets.get(kid, {})
	var strike_limbs: Array = [String(ks.get("limb", "")), String(ks.get("limb2", ""))]
	af0.socket("foot_l")
	af1.socket("foot_l")
	var best: float = 0.0
	var pair: String = ""
	var ix: Dictionary = AnimRig.index
	# the attacker's points: each bone segment sampled at five places, in world coordinates (attacker at x 0, defender at x dist)
	var pts: Array = []
	for cp in CAPSULES:
		var a: Vector3 = _world(af0, ix[cp[0]], 0.0)
		var b: Vector3 = _world(af0, ix[cp[1]], 0.0)
		for s in range(6):
			pts.append([a.lerp(b, float(s) / 5.0), String(cp[1]), float(cp[2])])
	for p in pts:
		var nm: String = String(p[1])
		# the striking part itself (its end and the joint before it) is allowed to reach the target
		var skip: bool = false
		for sl in strike_limbs:
			if sl == "":
				continue
			var kind: String = sl.get_slice("_", 0)
			var sfx: String = sl.substr(sl.length() - 1) if sl.contains("_") else ""
			if (kind == "hand" and (nm == "hand_" + sfx or nm == "forearm_" + sfx)) or (kind == "foot" and (nm == "foot_" + sfx or nm == "shin_" + sfx)) or (kind == "elbow" and (nm == "forearm_" + sfx or nm == "upper_arm_" + sfx or nm == "hand_" + sfx)) or (kind == "knee" and (nm == "shin_" + sfx or nm == "thigh_" + sfx or nm == "foot_" + sfx)) or (kind == "head" and (nm == "head" or nm == "neck")) or (kind == "shoulder" and (nm == "upper_arm_" + sfx or nm == "spine_2" or nm == "neck")):
				skip = true
		if skip:
			continue
		var pw: Vector3 = p[0]
		pw.x += 0.0
		for dc in CAPSULES:
			var a2: Vector3 = _world(af1, ix[dc[0]], dist)
			var b2: Vector3 = _world(af1, ix[dc[1]], dist)
			var d: float = _seg_dist(pw, a2, b2)
			var pen: float = float(p[2]) + float(dc[2]) - d
			if pen > best:
				best = pen
				pair = "%s into %s" % [nm, String(dc[1])]
	return {"depth": best, "pair": pair}


func _world(af: AnimFighter, bone: int, x0: float) -> Vector3:
	var g: Vector3 = af.gp[bone] + af.root_off
	return Vector3(x0 + af.vface * g.x, g.y, g.z)


func _seg_dist(p: Vector3, a: Vector3, b: Vector3) -> float:
	var ab: Vector3 = b - a
	var t: float = 0.0
	var l2: float = ab.length_squared()
	if l2 > 0.0001:
		t = clampf((p - a).dot(ab) / l2, 0.0, 1.0)
	return p.distance_to(a + ab * t)

## One strike at one distance, solved without drawing: {gap, gap2, step, clip, clip_pair}. The same setup as the draw loop.
func _measure_one(S: SimState, f0, f1, m, kid: String, dist: float, si: int) -> Dictionary:
	var heavy: bool = String(m.weight) == "heavy"
	RenderAnim._fighters.clear()
	RenderAnim.force_keyset = kid
	var base_t: float = 200.0 + float(si) * 7.0
	var base_tick: int = 1000 + si * 400
	f0.x = 500.0
	f1.x = 500.0 + dist
	f0.y = 0.0
	f1.y = 0.0
	f0.vx = 0.0
	f0.vy = 0.0
	f1.vx = 0.0
	f1.vy = 0.0
	f0.state = "free"
	f1.state = "free"
	var ex := DirExchange.newEx(f0, f1, "heavy" if heavy else "light")
	ex.n = 900 + si
	ex.tag = "LAB"
	var dmg: float = 66.0 if heavy else 26.0
	DirExchange.schedule(ex, TC, "strike", {"a": "A", "dmg": dmg, "o": {"big": heavy}})
	S.dirS.ex = ex
	var af0: AnimFighter = null
	var clip: Dictionary = {"depth": 0.0, "pair": ""}
	var max_step: float = 0.0
	for k in range(int((TC + DT * 4.0) / DT)):
		S.tick = base_tick + k
		S.T = base_t + float(k) * DT
		ex.t = float(k) * DT
		var te := SimState.FxEvent.new()
		te.type = "tick"
		te.dt = DT
		te.frozen = false
		RenderAnim.consume(S, [te])
		af0 = RenderAnim.solve(S, f0)
		var af1: AnimFighter = RenderAnim.solve(S, f1)
		max_step = maxf(max_step, af0._step_x)
		if ex.t > TC - DT * 1.5:
			var c: Dictionary = _clip(af0, af1, dist, kid)
			if float(c.depth) > float(clip.depth):
				clip = c
	var d0: Dictionary = af0.debug
	return {"gap": float(d0.get("gap_max", 0.0)), "gap2": float(d0.get("gap2_max", 0.0)), "step": max_step, "clip": float(clip.depth), "clip_pair": String(clip.pair)}
