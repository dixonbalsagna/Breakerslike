extends SceneTree
## Re-aims hand targets that the joint limits turned into stiff or elbow-high arms (docs/animation/joint-limits.md). For each pose id it bakes the pose with the
## hand target moved over a small grid (forward, down, in) and keeps the target that gives the arm nearest the old look: the bend within 40 degrees of the old
## pose's, the elbow not above the shoulder and the hand, and the hand as near the authored place as that allows. The result is a table for
## data/anim/targets.json (pose id -> the hand targets to use); nothing is written by this tool but its output file. Headless.
##   godot --headless --path . -s res://render/anim/tools/retarget_suggest.gd -- --old=old_q.json --ids=a,b,c --out=targets_suggest.json [--waves]
## old_q.json is a dump of the old rig's baked rotations (pose_qdump.gd in the old tree).

var old_path: String = ""
var ids: Array = []
var out: String = "targets_suggest.json"


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--old="):
			old_path = a.substr(6)
		elif a.begins_with("--ids="):
			ids = Array(a.substr(6).split(","))
		elif a.begins_with("--out="):
			out = a.substr(6)
	AnimData.load_waves = true
	AnimRig.setup()
	AnimData.load_all()
	AnimJoints.retarget_max = 0.0   # judge each target as it stands: the bake must not slide it on its own
	var old_q: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(old_path)) if old_path != "" else {}
	var ix: Dictionary = AnimRig.index
	var result: Dictionary = {}
	# the limb that lands a blow keeps its authored target in every pose of its key set (the contact slice reads that reach)
	var locked: Dictionary = {}
	for ksid in AnimData.keysets:
		var ks: Dictionary = AnimData.keysets[ksid]
		for lk in [ks.get("limb", ""), ks.get("limb2", "")]:
			if String(lk).begins_with("hand_"):
				for kk in ks.get("keys", []):
					var l2: Array = locked.get(String(kk.pose), [])
					l2.append(String(lk))
					locked[String(kk.pose)] = l2
	var gq: Array[Quaternion] = []
	gq.resize(AnimRig.N)
	var gp := PackedVector3Array()
	gp.resize(AnimRig.N)
	for id in ids:
		if not AnimData.raw.has(id):
			continue
		var sk: Dictionary = AnimData.raw[id]
		var row: Dictionary = {}
		for sd in ["r", "l"]:
			var key: String = "hand_" + sd
			if not sk.has(key):
				continue
			if locked.get(id, []).has(key):
				continue
			var a: int = ix["upper_arm_" + sd]
			var auth: Vector3 = Vector3(float(sk[key][0]), float(sk[key][1]), float(sk[key][2]))
			var old_flex: float = NAN
			if old_q.has(id):
				var oq: Array = old_q[id].q[a + 1]
				old_flex = rad_to_deg(AnimJoints.hinge_state(Quaternion(oq[0], oq[1], oq[2], oq[3]), a + 1).x)
			var best_cost: float = 1.0e9
			var best: Vector3 = auth
			var cur_cost: float = 0.0
			for dx in [0.0, 2.0, 4.0, 6.0, 8.0, 10.0, 12.0, 14.0]:
				for dy in [-12.0, -9.0, -6.0, -3.0, 0.0, 3.0]:
					for dz in [0.0, -3.0, 3.0]:
						var t: Vector3 = auth + Vector3(dx, dy, dz * (1.0 if sd == "r" else -1.0))
						var sk2: Dictionary = sk.duplicate(true)
						sk2[key] = [t.x, t.y, t.z]
						var p: AnimPose = AnimPose.bake(id + "#try", sk2)
						AnimPose.fk(p.q, p.hips, gq, gp)
						var S: Vector3 = gp[a]
						var E: Vector3 = gp[a + 1]
						var H: Vector3 = gp[a + 2]
						var flex: float = rad_to_deg(AnimJoints.hinge_state(p.q[a + 1], a + 1).x)
						var tw: float = absf(rad_to_deg(AnimJoints.twist_of(p.q[a])))
						var cost: float = 0.0
						cost += maxf(0.0, E.y - maxf(S.y, H.y)) * 1.0           # an elbow above the shoulder and the hand
						if not is_nan(old_flex):
							cost += maxf(0.0, absf(flex - old_flex) - 40.0) / 20.0  # a bend far from the old pose's
						cost += (t - auth).length() * 0.5                        # the hand far from where it was authored
						cost += maxf(0.0, tw - 60.0) / 30.0
						if dx == 0.0 and dy == 0.0 and dz == 0.0:
							cur_cost = cost
						if cost < best_cost:
							best_cost = cost
							best = t
			if (best - auth).length() > 0.5 and best_cost < cur_cost - 0.5:
				row[key] = [snappedf(best.x, 0.1), snappedf(best.y, 0.1), snappedf(best.z, 0.1)]
		if not row.is_empty():
			result[id] = row
			print(id, " ", row)
	var f := FileAccess.open(out, FileAccess.WRITE)
	f.store_string(JSON.stringify(result, "  "))
	f.close()
	quit(0)
