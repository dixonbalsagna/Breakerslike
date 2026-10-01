extends SceneTree
## Silhouette-distinctness lint (docs/animation/review-plan.md, the review pipeline). Headless, no window: each pose is rebuilt by
## forward kinematics, its limbs rasterised as thick segments in the side view onto a 160 x 140 unit grid (feet on the floor, centred
## on the pelvis), and every pair of poses compared by overlap (intersection over union). Two poses that read the same are flagged:
## across families at --cross (default 0.85), inside a family at --same (default 0.95, where a chamber that is the contact pose is
## a key that does nothing). Per pose: area, width, height, and whether a limb is hidden inside the body's mass (the readability
## of a silhouette at 40 px). Pairs listed in data/anim/lint_allow.json are not flagged, and its overlay prefixes are not compared.
##   godot --headless --path . --script res://render/anim/tools/silhouette_lint.gd [-- --ids=prefix,prefix --cross=0.90 --same=0.97 --json=out.json --mirror --contact-only | --suffix=.travel]

const W := 160
const H := 140
const OX := -70.0
const OY := -10.0

# bone pairs and their radius in model units
const SEGMENTS := [
	["pelvis", "spine_1", 7.5], ["spine_1", "spine_2", 8.0], ["spine_2", "neck", 7.0], ["neck", "head", 3.5],
	["clavicle_r", "upper_arm_r", 3.8], ["upper_arm_r", "forearm_r", 3.4], ["forearm_r", "hand_r", 3.0], ["hand_r", "fingers_r", 3.0],
	["clavicle_l", "upper_arm_l", 3.8], ["upper_arm_l", "forearm_l", 3.4], ["forearm_l", "hand_l", 3.0], ["hand_l", "fingers_l", 3.0],
	["pelvis", "thigh_r", 5.0], ["thigh_r", "shin_r", 4.6], ["shin_r", "foot_r", 3.8],
	["pelvis", "thigh_l", 5.0], ["thigh_l", "shin_l", 4.6], ["shin_l", "foot_l", 3.8],
]

var prefixes: Array = []
var cross_thr: float = 0.85
var same_thr: float = 0.95
var json_out: String = ""
var mirror: bool = false
var suffix: String = ""   # across families, compare only the poses that end in this suffix (a wave: wind-ups and follow-throughs share templates by design)
var overlay: Array = []


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--ids="):
			prefixes = Array(a.substr(6).split(","))
		elif a.begins_with("--cross="):
			cross_thr = float(a.substr(8))
		elif a.begins_with("--same="):
			same_thr = float(a.substr(7))
		elif a.begins_with("--json="):
			json_out = a.substr(7)
		elif a == "--mirror":
			mirror = true
		elif a == "--contact-only":
			suffix = ".contact"
		elif a.begins_with("--suffix="):
			suffix = a.substr(9)
	_run.call_deferred()


static func _stamp(grid: PackedByteArray, cx: float, cy: float, r: float) -> void:
	var x0: int = maxi(0, int(floor(cx - r - OX)))
	var x1: int = mini(W - 1, int(ceil(cx + r - OX)))
	var y0: int = maxi(0, int(floor(cy - r - OY)))
	var y1: int = mini(H - 1, int(ceil(cy + r - OY)))
	var r2: float = r * r
	for y in range(y0, y1 + 1):
		var dy: float = (float(y) + OY + 0.5) - cy
		for x in range(x0, x1 + 1):
			var dx: float = (float(x) + OX + 0.5) - cx
			if dx * dx + dy * dy <= r2:
				grid[y * W + x] = 1


static func _line(grid: PackedByteArray, a: Vector2, b: Vector2, r: float) -> void:
	var n: int = maxi(1, int(ceil(a.distance_to(b) / (r * 0.6))))
	for i in range(n + 1):
		var p: Vector2 = a.lerp(b, float(i) / float(n))
		_stamp(grid, p.x, p.y, r)


## The side-view mask of a baked pose.
static func mask(p: AnimPose) -> PackedByteArray:
	var gq: Array[Quaternion] = []
	gq.resize(AnimRig.N)
	var gp := PackedVector3Array()
	gp.resize(AnimRig.N)
	AnimPose.fk(p.q, p.hips, gq, gp)
	var grid := PackedByteArray()
	grid.resize(W * H)
	var cx: float = gp[AnimRig.index["pelvis"]].x
	for sg in SEGMENTS:
		var a: Vector3 = gp[AnimRig.index[sg[0]]]
		var b: Vector3 = gp[AnimRig.index[sg[1]]]
		_line(grid, Vector2(a.x - cx, a.y), Vector2(b.x - cx, b.y), float(sg[2]))
	# the head's mass, the fists and the feet
	var hd: int = AnimRig.index["head"]
	var hc: Vector3 = gp[hd] + gq[hd] * Vector3(0, 6, 0)
	_stamp(grid, hc.x - cx, hc.y, 6.5)
	for nm in ["hand_r", "hand_l"]:
		var h: int = AnimRig.index[nm]
		var f: Vector3 = gp[h] + gq[h] * Vector3(0, -4, 0)
		_stamp(grid, f.x - cx, f.y, 3.6)
	for nm2 in ["foot_r", "foot_l"]:
		var ft: int = AnimRig.index[nm2]
		var t0: Vector3 = gp[ft]
		var t1: Vector3 = gp[ft] + gq[ft] * Vector3(8, -1.5, 0)
		_line(grid, Vector2(t0.x - cx, t0.y), Vector2(t1.x - cx, t1.y), 2.6)
	return grid


static func iou(a: PackedByteArray, b: PackedByteArray) -> float:
	var inter: int = 0
	var uni: int = 0
	for i in range(W * H):
		var x: int = a[i]
		var y: int = b[i]
		inter += x & y
		uni += x | y
	return float(inter) / maxf(1.0, float(uni))


func _run() -> void:
	AnimData.load_all()
	var ids: Array = []
	for id in AnimData.poses:
		var p: AnimPose = AnimData.poses[id]
		if p.additive:
			continue
		if prefixes.is_empty():
			ids.append(id)
		else:
			for pre in prefixes:
				if String(id).begins_with(pre):
					ids.append(id)
					break
	var allow: Dictionary = {}
	var txt: String = FileAccess.get_file_as_string("res://data/anim/lint_allow.json")
	if txt != "":
		var aj = JSON.parse_string(txt)
		if typeof(aj) == TYPE_DICTIONARY:
			overlay = aj.get("overlay", [])
			for pr in aj.get("pairs", []):
				allow[String(pr[0]) + "|" + String(pr[1])] = true
				allow[String(pr[1]) + "|" + String(pr[0])] = true
	var kept: Array = []
	for id in ids:
		var skip := false
		for ov in overlay:
			if String(id).begins_with(String(ov)):
				skip = true
		if not skip:
			kept.append(id)
	ids = kept
	ids.sort()
	var masks: Dictionary = {}
	var metrics: Dictionary = {}
	for id in ids:
		var m: PackedByteArray = mask(AnimData.pose(id, mirror))
		masks[id] = m
		var area: int = 0
		var x0: int = W
		var x1: int = -1
		var y0: int = H
		var y1: int = -1
		for i in range(W * H):
			if m[i] == 1:
				area += 1
				var x: int = i % W
				var y: int = i / W
				x0 = mini(x0, x)
				x1 = maxi(x1, x)
				y0 = mini(y0, y)
				y1 = maxi(y1, y)
		metrics[id] = {"area": area, "w": x1 - x0 + 1, "h": y1 - y0 + 1}
	var pairs: Array = []
	for i in range(ids.size()):
		for j in range(i + 1, ids.size()):
			var a: String = ids[i]
			var b: String = ids[j]
			if allow.has(a + "|" + b):
				continue
			if a.replace("~b", "") == b.replace("~b", ""):
				continue   # a strike and its B version are meant to look alike
			var v: float = iou(masks[a], masks[b])
			var fa: String = a.substr(0, a.rfind(".")) if a.contains(".") else a
			var fb: String = b.substr(0, b.rfind(".")) if b.contains(".") else b
			var same: bool = fa == fb
			if suffix != "" and not same and not (a.ends_with(suffix) and b.ends_with(suffix)):
				continue
			if (same and v >= same_thr) or (not same and v >= cross_thr):
				pairs.append({"a": a, "b": b, "iou": snappedf(v, 0.001), "kind": "same family" if same else "across families"})
	pairs.sort_custom(func(x, y): return x.iou > y.iou)
	print("silhouette lint: %d poses, %d pairs over the thresholds (across families %.2f, inside a family %.2f)" % [ids.size(), pairs.size(), cross_thr, same_thr])
	for pr in pairs.slice(0, 40):
		print("  %-28s %-28s %.3f  %s" % [pr.a, pr.b, pr.iou, pr.kind])
	if json_out != "":
		var f := FileAccess.open(json_out, FileAccess.WRITE)
		f.store_string(JSON.stringify({"tool": "silhouette_lint", "poses": ids.size(), "cross": cross_thr, "same": same_thr, "pairs": pairs, "metrics": metrics}))
		f.close()
	quit(0)
