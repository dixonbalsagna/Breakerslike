class_name AnimJointLint
extends RefCounted
## The joint-limit lint's data scans (docs/animation/joint-limits.md), shared by tools/joint_scan.gd (the full report) and tools/anim_check.gd (the gate): every
## authored pose and every sequence of every wave measured against data/anim/joints.json. A "record" is {frames, bad_frames, kinds: {"twist thigh_r": n},
## worst: {...}, examples: [...]}. Render only.

const SHAPES: Array = ["", "P", "A", "E", "C"]
const DT := 1.0 / 60.0


## Adds one measured frame (its violations `viol`, named `who`) to `into`; returns the number of violations.
static func tally(into: Dictionary, viol: Array, who: String, max_examples: int = 12) -> int:
	into["frames"] = int(into.get("frames", 0)) + 1
	if viol.is_empty():
		return 0
	into["bad_frames"] = int(into.get("bad_frames", 0)) + 1
	var kinds: Dictionary = into.get("kinds", {})
	var worst: Dictionary = into.get("worst", {})
	var ex: Array = into.get("examples", [])
	for v in viol:
		var k: String = "%s %s" % [v[0], v[1]]
		kinds[k] = int(kinds.get(k, 0)) + 1
		if float(v[2]) > float(worst.get(k, 0.0)):
			worst[k] = snappedf(float(v[2]), 0.1)
	if ex.size() < max_examples:
		ex.append(who + ": " + ", ".join(viol.map(func(v): return "%s %s %.0f" % [v[0], v[1], v[2]])))
	into["kinds"] = kinds
	into["worst"] = worst
	into["examples"] = ex
	return viol.size()


## Every authored pose (the additive deltas are not postures), near side and far side, at each shape's scale. Returns {groups: {wave: record}, bad_ids: [...]}.
static func poses(print_each: bool = false) -> Dictionary:
	var groups: Dictionary = {}
	var bad_ids: Dictionary = {}
	for id in AnimData.poses:
		var p: AnimPose = AnimData.poses[id]
		if p.additive:
			continue
		for mir in [false, true]:
			var pp: AnimPose = AnimData.pose(id, mir)
			for sh in SHAPES:
				var v: Array = AnimJoints.violations(pp.q, sh)
				var grp: String = String(AnimData.wave_of.get(id, "poses.json"))
				var rec: Dictionary = groups.get(grp, {})
				tally(rec, v, id + (" (far side)" if mir else "") + (" shape " + sh if sh != "" else ""))
				groups[grp] = rec
				if not v.is_empty():
					bad_ids[id] = true
					if print_each and not mir and sh == "":
						print("POSE ", id, "  ", ", ".join(v.map(func(x): return "%s %s %.0f" % [x[0], x[1], x[2]])))
	return {"groups": groups, "bad_ids": bad_ids.keys()}


## A sequence's length in ticks: its own `dur`, or (an entry a beat times) its fixed phases plus 20 ticks for each phase that takes the rest.
static func entry_ticks(en: Dictionary) -> int:
	if en.has("dur"):
		return int(en.dur)
	var n := 0
	for ph in en.phases:
		n += int(ph.ticks) if ph.has("ticks") else 20
	return n


## Every sequence and entry played frame by frame through the real entry layer on a stub fighter that stands in the aggressive stance, each frame measured
## after the solve's last pass (what reaches the screen) and, counted separately, before it (what the sources alone leave). Returns
## {groups: {prefix: record}, bad_ids: [...], pre_pass_frames: n}.
static func sequences() -> Dictionary:
	var groups: Dictionary = {}
	var bad_ids: Dictionary = {}
	var pre := 0
	var base: AnimPose = AnimData.pose("stance.aggressive")
	for sid in AnimData.entries:
		var en: Dictionary = AnimData.entries[sid]
		var dticks: int = entry_ticks(en)
		var dur: float = float(dticks) / 60.0
		var af := AnimFighter.new(0)
		var grp: String = String(sid).get_slice(".", 0)
		var rec: Dictionary = groups.get(grp, {})
		for tk in range(dticks + 4):
			af.q = base.q.duplicate()
			af.hips = base.hips
			af.curl = base.curl
			af._entry_layer(0.0, dur, sid, float(tk) * DT, DT)
			if not AnimJoints.violations(af.q, "").is_empty():
				pre += 1
			AnimPose.limit_limbs(af.q, "")   # the pass every solve ends with
			var v: Array = AnimJoints.violations(af.q, "")
			tally(rec, v, "%s tick %d" % [sid, tk])
			if not v.is_empty():
				bad_ids[sid] = true
		groups[grp] = rec
	return {"groups": groups, "bad_ids": bad_ids.keys(), "pre_pass_frames": pre}


static func sum(groups: Dictionary, key: String) -> int:
	var n := 0
	for g in groups:
		n += int(groups[g].get(key, 0))
	return n


## The last pass the solver had before the joint limits (hinges only, and the shoulder's blind spot): `joint_scan --head` runs it alone, so the report can say what
## shipped before this fix. Nothing else calls it.
static func old_pass(lq: Array[Quaternion]) -> void:
	var ix: Dictionary = AnimRig.index
	for pair in [["forearm_l", 1.0], ["forearm_r", 1.0], ["shin_l", -1.0], ["shin_r", -1.0]]:
		var i: int = ix[pair[0]]
		var sg: float = pair[1]
		var v: Vector3 = lq[i] * Vector3(0, -1, 0)
		var th: float = atan2(v.x, -v.y) * sg
		var tc: float = clampf(th, -0.05, 2.62)
		if tc != th or absf(v.z) > 0.02:
			lq[i] = Quaternion(Vector3(0, 0, 1), tc * sg)
	for nm in ["upper_arm_l", "upper_arm_r"]:
		var i2: int = ix[nm]
		var v2: Vector3 = lq[i2] * Vector3(0, -1, 0)
		if v2.x < -0.8:
			var xn: float = -0.8 - (-v2.x - 0.8) * 0.5
			var r0: float = sqrt(maxf(1.0 - v2.x * v2.x, 0.0))
			if r0 > 0.0001:
				var k: float = sqrt(1.0 - xn * xn) / r0
				lq[i2] = Quaternion(v2, Vector3(xn, v2.y * k, v2.z * k).normalized()) * lq[i2]
