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


## Legal's lines for a pose that carries a `_legal` list (docs/legal/rule-of-cool-screen.md, wave 1): geometry the sketch can show. Rules:
## hands_open_or_claw (no fist, no cupped state), wrists_apart (two hands at least 7 u apart), no_clasp (two fists not together), not_at_hip
## (no open hand chambered at the hip), no_held_raise (no hand above 80 u in a follow-through: no victory pose), no_leap (both feet
## within 6 u of the floor), single_turn (hip and spine twist together under 140 degrees), no_cross_hold (arms not crossed in a wind-up or
## a follow-through; only the blow itself may cross them), not_both_arms_back (no pose with both hands trailing behind), no_fist_punched_ahead
## (no fist at 30 u ahead), lean_max (pelvis and spine lean together at most 32 degrees).
static func legal_issues(id: String, d: Dictionary) -> Array:
	var out: Array = []
	var rules: Array = d.get("_legal", [])
	if rules.is_empty():
		return out
	var part: String = id.get_slice(".", id.get_slice_count(".") - 1)
	var hs: Dictionary = d.get("hands", {})
	var hr = d.get("hand_r")
	var hl = d.get("hand_l")
	var both: bool = hr != null and hl != null
	var dist: float = 999.0
	if both:
		dist = Vector3(float(hr[0]) - float(hl[0]), float(hr[1]) - float(hl[1]), float(hr[2]) - float(hl[2])).length()
	for rule in rules:
		match String(rule):
			"hands_open_or_claw":
				for sd in ["r", "l"]:
					var hv: String = String(hs.get(sd, "relaxed"))
					if hv != "open" and hv != "claw":
						out.append("hands_open_or_claw: the %s hand is %s" % [sd, hv])
			"wrists_apart":
				if both and dist < 7.0:
					out.append("wrists_apart: the wrists are %.1f u apart" % dist)
			"no_clasp":
				if both and dist < 6.0 and String(hs.get("r", "")) == "fist" and String(hs.get("l", "")) == "fist":
					out.append("no_clasp: two fists %.1f u apart" % dist)
			"not_at_hip":
				for hv2 in [["r", hr], ["l", hl]]:
					var tg = hv2[1]
					if tg != null and absf(float(tg[0])) <= 14.0 and float(tg[1]) >= 24.0 and float(tg[1]) <= 44.0:
						out.append("not_at_hip: the %s hand is at the hip [%.0f, %.0f]" % [hv2[0], float(tg[0]), float(tg[1])])
			"no_held_raise":
				if part == "follow":
					for hv3 in [["r", hr], ["l", hl]]:
						var tg3 = hv3[1]
						if tg3 != null and float(tg3[1]) > 80.0:
							out.append("no_held_raise: the %s hand ends at height %.0f" % [hv3[0], float(tg3[1])])
			"no_leap":
				for fk in ["foot_r", "foot_l"]:
					if d.has(fk) and float(d[fk][1]) > 6.0:
						out.append("no_leap: %s at height %.0f" % [fk, float(d[fk][1])])
			"single_turn":
				var tw: float = absf(float(d.get("hip_twist", 0.0))) + absf(float(d.get("spine", {}).get("twist", 0.0)))
				if tw > 140.0:
					out.append("single_turn: %.0f degrees of twist" % tw)
			"not_both_arms_back":
				if both and float(hr[0]) <= -6.0 and float(hl[0]) <= -6.0:
					out.append("not_both_arms_back: both hands trail behind (x %.0f and %.0f)" % [float(hr[0]), float(hl[0])])
			"no_fist_punched_ahead":
				for hv4 in [["r", hr], ["l", hl]]:
					var tg4 = hv4[1]
					if tg4 != null and float(tg4[0]) >= 30.0 and String(hs.get(hv4[0], "")) == "fist":
						out.append("no_fist_punched_ahead: the %s fist is at x %.0f" % [hv4[0], float(tg4[0])])
			"lean_max":
				var lm: float = absf(float(d.get("lean", 0.0))) + absf(float(d.get("spine", {}).get("lean", 0.0)))
				if lm > 32.0:
					out.append("lean_max: a lean of %.0f degrees from the hips" % lm)
			"no_cross_hold":
				if part != "contact" and both and float(hr[2]) < 0.0 and float(hl[2]) > 0.0:
					out.append("no_cross_hold: the arms are crossed in the %s" % part)
	return out


func _run() -> void:
	AnimData.load_all()
	var raw: Dictionary = AnimData.raw
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
		for lm in legal_issues(String(id), d):
			issues.append({"id": id, "kind": "legal", "detail": lm})
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
		var spin: float = absf(float(d.get("hip_twist", 0.0))) + absf(float(d.get("spine", {}).get("twist", 0.0)))
		for nm2 in ["upper_arm_l", "upper_arm_r"]:
			var v2: Vector3 = p.q[ix[nm2]] * Vector3(0, -1, 0)
			if v2.x < -0.93 and spin <= 90.0:   # in a spin the chest faces away, so a forward arm is back in the chest frame
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
