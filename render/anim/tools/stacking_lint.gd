extends SceneTree
## Legal's stacking rule as a lint (docs/design/rule-of-cool.md section 1 rule 9, docs/legal/rule-of-cool-screen.md). A known
## franchise's power-up scene is a stack of seven marks: (1) a crouch with fists clenched at the sides, (2) a scream or a drawn-out
## chant, (3) a flame-shaped body aura streaming upward, (4) rubble rising in a ring, the ground cracking and wind under a
## changing sky, (5) crackling lightning on the body, (6) hair rising or changing colour, (7) a gold, white or red flash with a
## form name shouted. No single moment in our game may show more than two. This lint takes the moments of data/anim/moments.json
## (each lists the poses it plays and the marks the other systems declare for it: VFX, Audio, World, Camera, Art), adds the one
## mark a pose can show by itself (mark 1, found from the pose's sketch: crouched, both hands fists, hands low and at the sides),
## plus any `_marks` a pose declares, and flags every moment over two (a moment at two is a warning: it has no room left).
## It also lists every pose that shows mark 1 alone, so a charge pose that is a crouch with fists at the sides is never made by
## accident.
##   godot --headless --path . --script res://render/anim/tools/stacking_lint.gd [-- --json=out.json --moments=res://data/anim/moments.json]

var json_out: String = ""
var moments_path: String = "res://data/anim/moments.json"


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--json="):
			json_out = a.substr(7)
		elif a.begins_with("--moments="):
			moments_path = a.substr(10)
	_run.call_deferred()


## Mark 1 from a pose's sketch: a crouch, both hands fists, both hand targets low and close to the body's sides.
static func mark_one(d: Dictionary) -> bool:
	var crouched: bool = String(d.get("family", "")) in ["crouched", "kneel"]
	if d.has("hips"):
		crouched = crouched or float(d["hips"][1]) <= -6.0
	var hs: Dictionary = d.get("hands", {})
	if String(hs.get("l", "")) != "fist" or String(hs.get("r", "")) != "fist":
		return false
	for k in ["hand_l", "hand_r"]:
		if not d.has(k):
			return false
		var h: Array = d[k]
		if absf(float(h[0])) > 12.0 or float(h[1]) > 52.0:
			return false
	return crouched


func _run() -> void:
	AnimData.load_all()
	var raw: Dictionary = AnimData.raw
	var one_pose: Array = []
	var declared: Dictionary = {}
	for id in raw:
		var d: Dictionary = raw[id]
		var marks: Array = []
		if mark_one(d):
			marks.append(1)
			one_pose.append(id)
		for m in d.get("_marks", []):
			if not marks.has(int(m)):
				marks.append(int(m))
		declared[id] = marks
	var moments: Array = []
	var mt: String = FileAccess.get_file_as_string(moments_path)
	if mt != "":
		var mj = JSON.parse_string(mt)
		if typeof(mj) == TYPE_DICTIONARY:
			moments = mj.get("moments", [])
	var rows: Array = []
	var fails := 0
	var warns := 0
	for mo in moments:
		var marks: Dictionary = {}
		var why: Array = []
		for pid in mo.get("poses", []):
			if not declared.has(String(pid)):
				why.append("unknown pose %s" % pid)
				continue
			for m in declared[String(pid)]:
				marks[int(m)] = "pose " + String(pid)
		var ex: Dictionary = mo.get("marks", {})
		for k in ex:
			marks[int(k)] = String(ex[k])
		var n: int = marks.size()
		var status: String = "ok"
		if n > 2:
			status = "FAIL"
			fails += 1
		elif n == 2:
			status = "warn"
			warns += 1
		rows.append({"id": mo.get("id", "?"), "label": mo.get("label", ""), "marks": marks.keys(), "count": n, "status": status, "sources": marks, "problems": why, "owners": mo.get("owners", [])})
	print("stacking lint: %d moments, %d over two marks, %d at two; %d poses show mark 1 (crouch with fists at the sides): %s" % [moments.size(), fails, warns, one_pose.size(), str(one_pose)])
	for r in rows:
		print("  %-26s marks %-10s %s%s" % [r.id, str(r.marks), r.status, ("  " + str(r.problems)) if not r.problems.is_empty() else ""])
	if json_out != "":
		var f := FileAccess.open(json_out, FileAccess.WRITE)
		f.store_string(JSON.stringify({"tool": "stacking_lint", "moments": rows, "fails": fails, "warns": warns, "mark_one_poses": one_pose}))
		f.close()
	quit(0)
