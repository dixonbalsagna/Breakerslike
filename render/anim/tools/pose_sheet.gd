extends SceneTree
## Pose sheet: the poses of data/anim/poses.json on a contact sheet, each in the staged cheat-out view and in pure
## profile, with the mannequin's own outline, for review at any size (docs/animation/pose-pipeline.md section 6.2). It
## builds the mannequin directly (no sim, no game scene) and needs a window (not --headless).
##   godot --path . --script res://render/anim/tools/pose_sheet.gd -- --out=sheet.png [--prefix=strike.] [--ids=a,b]
##       [--cols=6] [--cell=220] [--small=1] [--mirror=1]
## --compare=old.json (written by pose_dump.gd --q in the tree to compare against): each pose is drawn twice, old on the left and new on the right, each in both views.
## --small=1 adds each pose at 38 px tall beside it (Play zoom). --mirror=1 shows the far-side (mirrored) version.

var out: String = "pose_sheet.png"
var prefix: String = ""
var ids: Array = []
var cols: int = 6
var cell: int = 220
var small: bool = false
var mirror: bool = false
var compare: String = ""


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--out="):
			out = a.substr(6)
		elif a.begins_with("--prefix="):
			prefix = a.substr(9)
		elif a.begins_with("--ids="):
			ids = Array(a.substr(6).split(","))
		elif a.begins_with("--cols="):
			cols = int(a.substr(7))
		elif a.begins_with("--cell="):
			cell = int(a.substr(7))
		elif a.begins_with("--small="):
			small = a.substr(8) == "1"
		elif a.begins_with("--mirror="):
			mirror = a.substr(9) == "1"
		elif a.begins_with("--compare="):
			compare = a.substr(10)
	_run.call_deferred()


func _run() -> void:
	AnimData.load_all()
	var list: Array = []
	if ids.size() > 0:   # the sheet follows the order of --ids (to set two fighters' poses side by side), every id that exists
		for want in ids:
			if AnimData.poses.has(want):
				list.append(want)
	for id in AnimData.poses:
		if ids.size() > 0:
			pass
		elif id.begins_with(prefix) and not AnimData.poses[id].additive:
			list.append(id)
	var old_q: Dictionary = {}
	if compare != "":
		old_q = JSON.parse_string(FileAccess.get_file_as_string(compare))
	var span: int = 2 if compare != "" else 1   # a pose takes two cells when it is drawn old and new
	var rows: int = int(ceil(list.size() / float(cols)))
	var cwf: float = 1.25 if compare != "" else 1.0   # a compare cell is wider than it is tall: a lying body is wide
	var cw: int = int(cell * cwf)
	var cwu: float = 100.0 * cwf
	var w: int = cols * cw * span
	var h: int = rows * cell
	var sv := SubViewport.new()
	sv.size = Vector2i(w, h)
	sv.own_world_3d = true
	sv.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(sv)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.13, 0.15, 0.22)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = float(h) / float(cell) * 100.0 / 1.0
	cam.environment = env
	sv.add_child(cam)
	cam.position = Vector3(float(w) / float(cw) * cwu * 0.5, -float(h) / float(cell) * 50.0, 300.0)
	cam.current = true
	var pal: Dictionary = {"body": Color("#3d8fdc"), "legs": Color("#1b1f2a"), "arms": Color("#e6b995"), "skin": Color("#efc7a2"), "gear": Color("#cdd6e4"), "accent": Color("#4fb9a8"), "hair": Color("#22c7a9")}
	for n in range(list.size()):
		var id: String = list[n]
		var p: AnimPose = AnimData.pose(id, mirror)
		var cx: float = (n % cols) * cwu * span + cwu * 0.5
		var fy: float = -(n / cols) * 100.0 - 94.0
		var views: Array = [[-30.0, -22.0], [0.0, 4.0]]
		for side in range(span):
			var sq: Array[Quaternion] = p.q
			var shp: Vector3 = p.hips
			var scl: Vector2 = p.curl
			if side == 0 and compare != "" and old_q.has(id):
				var oq: Dictionary = old_q[id]
				sq = []
				for e in oq.q:
					sq.append(Quaternion(float(e[0]), float(e[1]), float(e[2]), float(e[3])))
				shp = Vector3(float(oq.hips[0]), float(oq.hips[1]), float(oq.hips[2]))
				scl = Vector2(float(oq.curl[0]), float(oq.curl[1]))
			for v in views:
				var b := AnimBody.new()
				b.build(pal, false)
				sv.add_child(b)
				b.position = Vector3(cx + cwu * side + v[1], fy, 0.0)
				b.rotation.y = deg_to_rad(v[0])
				b.apply(sq, shp, scl)
			if compare != "":
				var tl := Label.new()
				tl.text = "old" if side == 0 else "new"
				tl.position = Vector2(((n % cols) * span + side) * cw + cw - 36, (n / cols) * cell + 2)
				tl.add_theme_font_size_override("font_size", 12)
				tl.add_theme_color_override("font_color", Color(0.95, 0.75, 0.45) if side == 0 else Color(0.55, 0.95, 0.7))
				sv.add_child(tl)
		if small:
			var bs := AnimBody.new()
			bs.build(pal, false)
			sv.add_child(bs)
			bs.position = Vector3(cx + 32.0, fy, 0.0)
			bs.rotation.y = deg_to_rad(-30.0)
			bs.apply(p.q, p.hips, p.curl)
			bs.scale = Vector3.ONE * (38.0 / 85.0)
		var lb := Label.new()
		lb.text = id + (" (m)" if mirror else "")
		lb.position = Vector2((n % cols) * cw * span + 4, (n / cols) * cell + 2)
		lb.add_theme_font_size_override("font_size", 13)
		lb.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
		sv.add_child(lb)
	for _f in range(4):
		await process_frame
	var img: Image = sv.get_texture().get_image()
	img.save_png(out)
	print("SHEET ", out, " ", list.size(), " poses")
	quit()
