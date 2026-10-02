extends SceneTree
## Match close-up reel: a real seeded AI match on the live sim, both fighters drawn through the real solver in a fixed side view that follows the pair (framed to
## hold both, the ground profile drawn under them), with a caption that names what the agency layer is playing (a knockback, an embed, a taunt, a charge).
## For judging the slice-3 poses (docs/animation/pose-pipeline.md 9.22) against the sim's own events. Raw RGB frames for tools/gif.mjs. Needs a window to draw:
## run it with --no-window (offscreen), never a window.
##   godot --no-window --path . -s res://render/anim/tools/match_close.gd -- --out=a.rgb [--seed=4] [--from=2500] [--count=70] [--step=2] [--size=360x220]
##       [--subject=0|1] [--no-agency-poses]
## --subject= keeps the frame on one fighter (the default follows whoever the agency layer is playing).

const DT := 1.0 / 60.0

var out: String = "match_close.rgb"
var seed_: int = 4
var from_tick: int = 0
var count: int = 80
var step: int = 2
var size := Vector2i(360, 220)
var forced: int = -1
var main: Node


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
		elif a.begins_with("--seed="):
			seed_ = int(a.substr(7))
		elif a.begins_with("--from="):
			from_tick = int(a.substr(7))
		elif a.begins_with("--count="):
			count = int(a.substr(8))
		elif a.begins_with("--step="):
			step = int(a.substr(7))
		elif a.begins_with("--subject="):
			forced = int(a.substr(10))
		elif a.begins_with("--size="):
			var p: PackedStringArray = a.substr(7).split("x")
			size = Vector2i(int(p[0]), int(p[1]))
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
		bd.position = Vector3(0.0, -34.0, 0.0)
		pivots.append(pv)
		bodies.append(bd)
	var ground := MeshInstance3D.new()
	var im := ImmediateMesh.new()
	ground.mesh = im
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.45, 0.55, 0.4)
	gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ground.material_override = gm
	sv.add_child(ground)
	var cl := CanvasLayer.new()
	sv.add_child(cl)
	var label := Label.new()
	label.position = Vector2(4, 2)
	label.add_theme_font_size_override("font_size", 11)
	cl.add_child(label)
	main.start_match(seed_, {"p1": true, "p2": true})
	var S: SimState = main.host.S
	while main.host.ticks < from_tick:
		main.frame(DT)
	var fa := FileAccess.open(out, FileAccess.WRITE)
	fa.store_32(size.x)
	fa.store_32(size.y)
	fa.store_32(count)
	var cx: float = 0.0
	var cy: float = 0.0
	var csize: float = 160.0
	var first := true
	var subj: int = 0
	for n in range(count * step):
		main.frame(DT)
		var f0 = S.fighters[0]
		var f1 = S.fighters[1]
		# the frame follows whoever the agency layer is playing (the pair when they are close): far apart, a frame that held both would show neither
		var tagged: int = -1
		for i2 in range(2):
			var a2: AnimFighter = RenderAnim.fighter(S, S.fighters[i2])
			if a2._ag_t0 >= 0.0 or not a2._ag_sq.is_empty() or String(a2._seq.get("id", "")).begins_with("ag."):
				tagged = i2
		if forced >= 0:
			subj = forced
		elif tagged >= 0:
			subj = tagged
		var fs = S.fighters[subj]
		var fo = S.fighters[1 - subj]
		var dso: float = SimWrap.sdx(fs.x, fo.x)   # (sdx(a, b) is b minus a: from the subject to the rival)
		var near: bool = absf(dso) < 330.0
		var mx: float = fs.x + (dso * 0.3 if near else signf(dso) * 30.0)   # always on the subject, leaning toward the rival
		var my: float = fs.y
		var want: float = clampf(absf(dso) * 1.0 + 140.0, 170.0, 300.0) if near else 170.0
		if first:
			cx = mx
			cy = my
			csize = want
			first = false
		else:
			cx = mx   # (the world wraps: no smoothing across the seam)
			cy = lerpf(cy, my, 0.7)
			csize = lerpf(csize, want, 0.15)
		if n % step != 0:
			continue
		cam.size = csize * float(size.y) / float(size.x)
		cam.position = Vector3(0.0, cy - cam.size * 0.04, 400.0)
		var caption: Array = []
		for i in range(2):
			var f = S.fighters[i]
			var af: AnimFighter = RenderAnim.solve(S, f)
			var vx: float = SimWrap.sdx(cx, f.x)   # from the camera to the fighter
			pivots[i].position = Vector3(vx, f.y, 0.0)
			pivots[i].scale = Vector3(af.vface, 1.0, 1.0)
			pivots[i].rotation.z = -f.rot * af.vface if false else -f.rot
			bodies[i].apply(af.q, af.hips, af.curl, af.root_off)
			var tag: String = ""
			if af._ag_t0 >= 0.0:
				tag = af._ag_kind
			elif String(af._seq.get("id", "")).begins_with("ag."):
				tag = String(af._seq.id)
			elif not af._ag_sq.is_empty():
				tag = String(af._ag_sq.id)
			if tag != "":
				caption.append("%s: %s" % ["A" if i == 0 else "B", tag])
		# the ground under the pair
		im.clear_surfaces()
		im.surface_begin(Mesh.PRIMITIVE_LINE_STRIP, gm)
		var gx: float = -csize * 0.6
		while gx <= csize * 0.6:
			im.surface_add_vertex(Vector3(gx, WorldTerrain.groundY(S, SimWrap.wrap(cx + gx)) - 1.0, -2.0))
			gx += 6.0
		im.surface_end()
		label.text = "tick %d   seed %d   %s%s" % [main.host.ticks, seed_, "   ".join(caption), "   (agency poses off)" if not RenderAnim.agency_poses else ""]
		for _w in range(3):
			await process_frame
		var img: Image = sv.get_texture().get_image()
		img.convert(Image.FORMAT_RGB8)
		fa.store_buffer(img.get_data())
	fa.close()
	print("MATCH CLOSE ", out, " ", count, " frames ", size.x, "x", size.y)
	quit(0)
