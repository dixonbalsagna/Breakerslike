extends SceneTree
## Joint-limit lint (docs/animation/joint-limits.md): counts every knee, elbow, hip, shoulder, spine, neck and head that is past its limit or folded the
## wrong way (the limits of data/anim/joints.json), in four kinds of source, and fails (exit 1) when any is found with `--strict`:
##   poses      every authored pose, near and far side, of poses.json and of every wave (waves 1 and 2, step 3, ground, intro, last stand)
##   sequences  every sequence and entry of the waves, played frame by frame through the real entry layer on a stub fighter
##   live       a sample of seeded AI matches, every fighter-frame of the finished solve (the ragdoll, the contact solve and every layer included)
##   stages     (live) the stage that first took a joint past its limits: A before the contact solve (pose data, blends, sequences), B after the contact
##              solve, C after the ragdoll, D after every layer; and what the solve's last pass had to fix, by size and by source
## The "output" counts (live frames that reach the screen, sequence frames after the last pass) are what the player sees: 0 with the limits on. The "sources"
## counts are what each source does before the last pass. --nopass switches every pass off and keeps the limited IK; --legacy switches the limited IK off
## too: the "before" of the fix, on the same data. --head is --legacy with the old hinge pass at the end of the solve: what shipped.
##   godot --headless --path . -s res://render/anim/tools/joint_scan.gd -- [--seeds=4,12345,7,99] [--ticks=3000] [--json=out.json] [--strict]
##       [--nopass | --legacy | --head] [--only=poses,sequences,live] [--examples=12] [--list]

const DT := 1.0 / 60.0

var seeds: Array = [4, 12345, 7, 99]
var max_ticks: int = 3000
var json_out: String = ""
var strict: bool = false
var nopass: bool = false
var legacy: bool = false
var only: Array = ["poses", "sequences", "live"]
var list_poses: bool = false
var n_examples: int = 12
var by_source: Dictionary = {}
var main: Node
var report: Dictionary = {}


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seeds="):
			seeds = Array(a.substr(8).split(",")).map(func(s): return int(s))
		elif a.begins_with("--ticks="):
			max_ticks = int(a.substr(8))
		elif a.begins_with("--json="):
			json_out = a.substr(7)
		elif a.begins_with("--only="):
			only = Array(a.substr(7).split(","))
		elif a.begins_with("--examples="):
			n_examples = int(a.substr(11))
		elif a == "--list":
			list_poses = true
		elif a == "--strict":
			strict = true
		elif a == "--nopass":
			nopass = true
		elif a == "--legacy":
			nopass = true
			legacy = true
		elif a == "--head":   # what shipped before the limits: no limit anywhere but the old hinge pass at the end of the solve
			nopass = true
			legacy = true
			AnimPose.head_pass = true
	if nopass:
		AnimJoints.enabled = false   # before any pose is baked: the sources alone
	if legacy:
		AnimJoints.ik_limits = false
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
	AnimRig.setup()
	RenderAnim.enabled = true
	AnimData.load_every_wave()   # every parked wave too, whichever flags this run has
	if only.has("poses"):
		var rp: Dictionary = AnimJointLint.poses(list_poses)
		report["poses"] = rp.groups
		report["poses_bad_ids"] = rp.bad_ids
	if only.has("sequences"):
		var rs: Dictionary = AnimJointLint.sequences()
		report["sequences"] = rs.groups
		report["sequences_bad_ids"] = rs.bad_ids
		report["sequences_pre_pass_frames"] = rs.pre_pass_frames
	if only.has("live"):
		_live()
	report["ragdoll_ranges"] = _ragdoll_ranges()
	_print_report()
	var bad := _total_bad()
	if json_out != "":
		var jf := FileAccess.open(json_out, FileAccess.WRITE)
		jf.store_string(JSON.stringify({"tool": "joint_scan", "mode": "legacy" if legacy else ("nopass" if nopass else "full"), "bad": bad, "report": report}, "  "))
		jf.close()
	quit(1 if (strict and bad > 0) else 0)


func _live() -> void:
	RenderAnim.joint_audit = true
	var out_rec: Dictionary = {}
	var stage_rec: Dictionary = {"A": {}, "B": {}, "C": {}, "D": {}}
	var fix_frames := 0
	var fixed_by: Dictionary = {}
	var fix_hist: Dictionary = {}
	var big_by: Dictionary = {}
	var big60: Array = []
	var total := 0
	for seed in seeds:
		main.start_match(seed, {"p1": true, "p2": true})
		var S: SimState = main.host.S
		while main.host.ticks < max_ticks and not (S.game.ko != null and S.game.koT > 3.0):
			main.frame(DT)
			for f in S.fighters:
				var af: AnimFighter = RenderAnim.fighter(S, f)
				if af.version == 0:
					continue
				total += 1
				var who: String = "seed %d tick %d fighter %d state %s part '%s' seq '%s'" % [seed, S.tick, S.fighters.find(f), f.state, af._part, String(af._seq.get("id", ""))]
				AnimJointLint.tally(out_rec, AnimJoints.violations(af.q, af._rd.shape_key), who, n_examples)
				if not af.audit.has("D"):
					continue
				for st in ["A", "B", "C", "D"]:
					var vv: Array = af.audit[st]
					# a stage is blamed only for what the stages before it did not already show
					var prev: Array = [] if st == "A" else af.audit[String(char(int(st.unicode_at(0)) - 1))]
					var fresh: Array = vv.filter(func(x): return not prev.any(func(y): return y[0] == x[0] and y[1] == x[1]))
					AnimJointLint.tally(stage_rec[st], fresh, who, n_examples)
					if st == "A" and not fresh.is_empty():
						var sk: String = "%s / %s / %s" % [f.state, af._part if af._part != "" else "-", String(af._seq.get("id", "-"))]
						by_source[sk] = int(by_source.get(sk, 0)) + 1
				var fx: float = float(af.debug.get("limit_fix", 0.0))
				var fb: String = "<=2" if fx <= deg_to_rad(2.0) else ("2-10" if fx <= deg_to_rad(10.0) else ("10-30" if fx <= deg_to_rad(30.0) else ("30-60" if fx <= deg_to_rad(60.0) else ">60")))
				fix_hist[fb] = int(fix_hist.get(fb, 0)) + 1
				if fx > deg_to_rad(60.0) and big60.size() < 60:
					big60.append(who + ": %.0f deg" % rad_to_deg(fx))
				if fx > deg_to_rad(30.0):
					var worst_v: Array = []
					for v in af.audit["D"]:
						if worst_v.is_empty() or float(v[2]) > float(worst_v[2]):
							worst_v = v
					var bk: String = "%s %s / %s / %s / %s" % [worst_v[0] if not worst_v.is_empty() else "?", worst_v[1] if not worst_v.is_empty() else "?", f.state, af._part if af._part != "" else "-", String(af._seq.get("id", "-"))]
					big_by[bk] = int(big_by.get(bk, 0)) + 1
				if fx > deg_to_rad(0.5):
					fix_frames += 1
					var key: String = "contact" if af._ci_w > 0.001 else ("ragdoll" if af._rd.out_w > 0.05 else "layers")
					fixed_by[key] = int(fixed_by.get(key, 0)) + 1
		print("seed %d done" % seed)
	report["live_output"] = out_rec
	report["live_stages"] = stage_rec
	report["live_frames"] = total
	report["pass_fixed_frames"] = fix_frames
	report["pass_fixed_by"] = fixed_by
	report["fix_hist_deg"] = fix_hist
	report["big_by"] = big_by
	report["big60"] = big60
	report["pass_on"] = not nopass


## The ragdoll's own range data against the limits: a hinge degree of freedom whose range reaches past the hinge's, listed for the record (the ragdoll keeps
## to the hinge anyway: AnimRagdoll.apply cuts what it adds to what is left of the range).
func _ragdoll_ranges() -> Array:
	var out: Array = []
	AnimRagdoll.setup()
	for i in range(AnimRagdoll.N):
		var bone: int = AnimRagdoll.bone_a[i]
		if AnimJoints.kind[bone] == AnimJoints.KIND_HINGE and AnimRagdoll.is_x[i] == 0:
			var sg: float = AnimJoints.hinge_sign[bone]
			var lo_f: float = minf(AnimRagdoll.lo[i] * sg, AnimRagdoll.hi[i] * sg)
			var hi_f: float = maxf(AnimRagdoll.lo[i] * sg, AnimRagdoll.hi[i] * sg)
			out.append("%s: turns %.0f to %.0f deg in the direction of flexion (hinge %.0f to %.0f)" % [AnimRig.BONES[bone][0], rad_to_deg(lo_f), rad_to_deg(hi_f), rad_to_deg(AnimJoints.hinge_min[bone]), rad_to_deg(AnimJoints.hinge_max[bone])])
	return out


func _total_bad() -> int:
	var n := 0
	if report.has("poses"):
		n += AnimJointLint.sum(report["poses"], "bad_frames")
	if report.has("sequences"):
		n += AnimJointLint.sum(report["sequences"], "bad_frames")
	if report.has("live_output"):
		n += int(report["live_output"].get("bad_frames", 0))
	return n


func _print_report() -> void:
	print("\n== joint limits (%s) ==" % (("BEFORE, as shipped: only the old hinge pass at the end of the solve" if AnimPose.head_pass else "BEFORE: no limit anywhere (the sources as they were)") if legacy else ("the solves' limited IK only, every pass off" if nopass else "AFTER: limited IK and every pass on")))
	if report.has("poses"):
		var np: int = AnimData.poses.size()
		print("authored poses (%d, near and far side, five shape scales): %d frames checked, %d past a limit" % [np, AnimJointLint.sum(report["poses"], "frames"), AnimJointLint.sum(report["poses"], "bad_frames")])
		for g in report["poses"]:
			var r: Dictionary = report["poses"][g]
			print("  %-14s %5d checked, %5d bad" % [g, int(r.get("frames", 0)), int(r.get("bad_frames", 0))])
		print("  poses with any violation: %d of %d" % [report["poses_bad_ids"].size(), np])
		_print_kinds(report["poses"])
	if report.has("sequences"):
		print("sequences (%d): %d frames played, %d past a limit after the solve's last pass" % [AnimData.entries.size(), AnimJointLint.sum(report["sequences"], "frames"), AnimJointLint.sum(report["sequences"], "bad_frames")])
		for g in report["sequences"]:
			var r2: Dictionary = report["sequences"][g]
			print("  %-14s %5d frames, %5d bad" % [g, int(r2.get("frames", 0)), int(r2.get("bad_frames", 0))])
		print("  frames the sources alone leave past a limit, before the solve's last pass: %d" % int(report["sequences_pre_pass_frames"]))
		print("  sequences with a bad frame: %d of %d" % [report["sequences_bad_ids"].size(), AnimData.entries.size()])
		_print_kinds(report["sequences"])
	if report.has("live_output"):
		var lo: Dictionary = report["live_output"]
		print("live: %d fighter-frames of %d matches: %d reach the screen past a limit" % [int(report["live_frames"]), seeds.size(), int(lo.get("bad_frames", 0))])
		if lo.has("kinds"):
			for k in lo["kinds"]:
				print("    %-28s %6d frames, worst %.1f deg" % [k, lo["kinds"][k], lo["worst"][k]])
		for st in ["A", "B", "C", "D"]:
			var sr: Dictionary = report["live_stages"][st]
			print("  stage %s (%s): %d frames first past a limit" % [st, {"A": "pose data, blends, sequences, layers up to the contact solve", "B": "the contact solve", "C": "the ragdoll", "D": "the layers after the ragdoll"}[st], int(sr.get("bad_frames", 0))])
			if sr.has("kinds"):
				for k2 in sr["kinds"]:
					print("      %-28s %6d, worst %.1f deg" % [k2, sr["kinds"][k2], sr["worst"][k2]])
		print("  the final pass had to fix %d frames by more than half a degree, by source %s" % [int(report["pass_fixed_frames"]), str(report["pass_fixed_by"])])
		print("  size of the final pass's corrections, degrees: ", report["fix_hist_deg"])
		var bks: Array = report["big_by"].keys()
		bks.sort_custom(func(a, b): return report["big_by"][a] > report["big_by"][b])
		print("  corrections over 30 degrees, by the worst joint / state / blow / sequence:")
		for bk2 in bks.slice(0, 12):
			print("      %4d  %s" % [report["big_by"][bk2], bk2])
		var ks: Array = by_source.keys()
		ks.sort_custom(func(a, b): return by_source[a] > by_source[b])
		print("  stage A by state / part / sequence:")
		for k3 in ks.slice(0, 10):
			print("      %5d  %s" % [by_source[k3], k3])
		for e in lo.get("examples", []):
			print("    e.g. " + e)
	for line in report.get("ragdoll_ranges", []):
		print("  ragdoll.json " + line)


func _print_kinds(rec: Dictionary) -> void:
	var kinds: Dictionary = {}
	var worst: Dictionary = {}
	for g in rec:
		var r: Dictionary = rec[g]
		for k in r.get("kinds", {}):
			kinds[k] = int(kinds.get(k, 0)) + int(r["kinds"][k])
			worst[k] = maxf(float(worst.get(k, 0.0)), float(r["worst"][k]))
	var keys: Array = kinds.keys()
	keys.sort()
	for k in keys:
		print("    %-28s %6d, worst %.1f deg" % [k, kinds[k], worst[k]])
