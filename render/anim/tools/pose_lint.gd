extends SceneTree
## Per-pose lint (the review pipeline, docs/animation/review-plan.md). Headless. Every pose of data/anim/poses.json is baked and
## checked: a hand or foot target the two-bone IK could not reach (the residual in units: the pose does not show what was
## authored), an elbow or knee out of human range, an upper arm pointing straight back, a foot below the floor in a standing
## family, a pelvis outside its sane height, and any NaN. Overlay and additive poses are checked for NaN only.
##   godot --headless --path . --script res://render/anim/tools/pose_lint.gd [-- --json=out.json --reach=1.0 --ids=prefix,prefix]

var json_out: String = ""
var reach_tol: float = 1.0
var prefixes: Array = []


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--json="):
			json_out = a.substr(7)
		elif a.begins_with("--reach="):
			reach_tol = float(a.substr(8))
		elif a.begins_with("--ids="):
			prefixes = Array(a.substr(6).split(","))
	_run.call_deferred()


func _run() -> void:
	AnimData.load_all()
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/anim/poses.json")).get("poses", {})
	var gq: Array[Quaternion] = []
	gq.resize(AnimRig.N)
	var gp := PackedVector3Array()
	gp.resize(AnimRig.N)
	var issues: Array = []
	var n := 0
	var ix: Dictionary = AnimRig.index
	for id in raw:
		if not prefixes.is_empty():
			var hit := false
			for pre in prefixes:
				if String(id).begins_with(pre):
					hit = true
			if not hit:
				continue
		n += 1
		var d: Dictionary = raw[id]
		var p: AnimPose = AnimData.pose(id)
		var nan := false
		for i in range(AnimRig.N):
			if is_nan(p.q[i].x) or is_nan(p.q[i].w):
				nan = true
		if nan:
			issues.append({"id": id, "kind": "nan", "detail": "a rotation is NaN"})
			continue
		if p.additive:
			continue
		AnimPose.fk(p.q, p.hips, gq, gp)
		# targets the IK could not reach
		for nm in ["hand_r", "hand_l", "foot_r", "foot_l"]:
			if d.has(nm):
				var t: Array = d[nm]
				var tgt := Vector3(float(t[0]), float(t[1]), float(t[2]))
				var res: float = (gp[ix[nm]] - tgt).length()
				if res > reach_tol:
					var got: Vector3 = gp[ix[nm]]
					issues.append({"id": id, "kind": "unreachable", "detail": "%s target [%.0f, %.0f, %.0f] is %.1f units out of reach (the limb is clamped to [%.1f, %.1f, %.1f])" % [nm, tgt.x, tgt.y, tgt.z, res, got.x, got.y, got.z], "value": snappedf(res, 0.1), "limb": nm, "achieved": [snappedf(got.x, 0.5), snappedf(got.y, 0.5), snappedf(got.z, 0.5)]})
		# joints in human range
		for pair in [["forearm_l", 1.0, "left elbow"], ["forearm_r", 1.0, "right elbow"], ["shin_l", -1.0, "left knee"], ["shin_r", -1.0, "right knee"]]:
			var v: Vector3 = p.q[ix[pair[0]]] * Vector3(0, -1, 0)
			var th: float = atan2(v.x, -v.y) * float(pair[1])
			if th < -0.06 or th > 2.65:
				issues.append({"id": id, "kind": "joint range", "detail": "%s at %.0f degrees" % [pair[2], rad_to_deg(th)], "value": snappedf(rad_to_deg(th), 1.0)})
		for nm2 in ["upper_arm_l", "upper_arm_r"]:
			var v2: Vector3 = p.q[ix[nm2]] * Vector3(0, -1, 0)
			if v2.x < -0.93:
				issues.append({"id": id, "kind": "arm straight back", "detail": "%s points straight back along the body" % nm2})
		var fam: String = String(d.get("family", "upright"))
		var stand: bool = fam in ["upright", "upright_lunge", "crouched", "kneel"]
		var lowest: float = minf(gp[ix["foot_l"]].y, gp[ix["foot_r"]].y)
		if stand and lowest < 0.0:
			issues.append({"id": id, "kind": "foot below floor", "detail": "the lowest foot is at y %.1f" % lowest, "value": snappedf(lowest, 0.1)})
		var ph: float = gp[ix["pelvis"]].y
		if ph < -10.0 or ph > 90.0:
			issues.append({"id": id, "kind": "pelvis height", "detail": "the pelvis is at y %.0f" % ph, "value": snappedf(ph, 1.0)})
	print("pose lint: %d poses, %d issues" % [n, issues.size()])
	for it in issues.slice(0, 50):
		print("  %-26s %-16s %s" % [it.id, it.kind, it.detail])
	if json_out != "":
		var f := FileAccess.open(json_out, FileAccess.WRITE)
		f.store_string(JSON.stringify({"tool": "pose_lint", "poses": n, "issues": issues}))
		f.close()
	quit(0)
