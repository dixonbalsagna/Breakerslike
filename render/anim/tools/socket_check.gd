extends SceneTree
## Socket check (data/anim/sockets.json, docs/animation/pose-pipeline.md section 9.12). For every striking limb of the table
## (hand, foot, elbow, knee, head) against every region (head, chest, gut, legs), the farthest centre-to-centre distance at which
## the contact solve still lands the blow (the tip within --tol of the skin, default 1.0 unit), found by stepping the defender
## away on level ground from a neutral stance. This is the reach envelope Combat designs the blows' spacing against; the strike
## slice's 58 unit step-in is the contract for the hand and the foot. Exit 1 if the hand or foot misses the chest at 58.
## Needs no window. A tool's own match is used and its fighters are moved by hand, so nothing here is a replay.
##   godot --headless --path . --script res://render/anim/tools/socket_check.gd [-- --tol=1.0 --json=out.json --nohunch]

const DT := 1.0 / 60.0
const LIMBS := ["hand_r", "foot_r", "elbow_r", "knee_r", "shoulder_r", "head"]
const REGIONS := ["head", "jaw", "chest", "gut", "legs", "shins", "arm_l"]

var tol: float = 1.0
var json_out: String = ""
var main: Node


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--tol="):
			tol = float(a.substr(6))
		elif a.begins_with("--json="):
			json_out = a.substr(7)
	DirData.templatesProfile = "dynamic"
	var vpn := SubViewport.new()
	vpn.size = Vector2i(1280, 720)
	root.add_child(vpn)
	main = load("res://render/main.tscn").instantiate()
	main.manual = true
	vpn.add_child(main)
	_run.call_deferred()


func _run() -> void:
	await process_frame
	RenderAnim.enabled = true
	main.start_match(4, {"p1": false, "p2": false})
	for i in range(30):
		main.frame(DT)
	var S: SimState = main.host.S
	var f0 = S.fighters[0]
	var f1 = S.fighters[1]
	var af: AnimFighter = RenderAnim.fighter(S, f0)
	var oaf: AnimFighter = RenderAnim.fighter(S, f1)
	var q0: Array[Quaternion] = af.q.duplicate()
	var h0: Vector3 = af.hips
	var table: Dictionary = {}
	var fails: Array = []
	for limb in LIMBS:
		for region in REGIONS:
			var best: float = -1.0
			var first_gap: float = -1.0
			for dist in range(14, 100, 2):
				f0.x = 100.0
				f0.y = f1.y
				f1.x = 100.0 + float(dist)
				af.vface = 1.0
				oaf.vface = -1.0
				af.q = q0.duplicate()
				af.hips = h0
				af._full_fk = false
				oaf._full_fk = false
				AnimPose.fk(oaf.q, oaf.hips, oaf.gq, oaf.gp)
				oaf._full_fk = true
				af._ci_limb = limb
				af._ci_target = region
				af._ci_side = false
				af._ci_w = 1.0
				af._ci_dmg = 10.0
				af._ci_opp = f1
				af._ci_tc = S.T
				af._gap_tc = -1.0
				af._smear = 0.0
				af.debug["gap_max"] = 0.0
				af.debug["gap_n"] = 0
				af._contact_ik(S, f0)
				if int(af.debug["gap_n"]) == 0:
					continue
				var gap: float = float(af.debug["gap_max"])
				if gap <= tol:
					best = float(dist)
				elif best >= 0.0 and first_gap < 0.0:
					first_gap = gap
			table[limb + " > " + region] = best
	print("socket check (tolerance %.1f u, hunch %s): farthest centre distance each blow lands at" % [tol, "on" if AnimPose.hunch_auto else "off"])
	for limb in LIMBS:
		var row := "  %-9s" % limb
		for region in REGIONS:
			row += "  %s %4.0f" % [region, float(table[limb + " > " + region])]
		print(row)
	for limb in ["hand_r", "foot_r"]:
		if float(table[limb + " > chest"]) < 58.0:
			fails.append("%s does not reach the chest at 58 u (%.0f)" % [limb, float(table[limb + " > chest"])])
	for fl in fails:
		print("FAIL ", fl)
	if json_out != "":
		var jf := FileAccess.open(json_out, FileAccess.WRITE)
		jf.store_string(JSON.stringify({"tool": "socket_check", "tolerance": tol, "hunch": AnimPose.hunch_auto, "reach": table, "failures": fails}))
		jf.close()
	quit(1 if fails.size() > 0 else 0)
