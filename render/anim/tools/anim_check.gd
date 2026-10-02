extends SceneTree
## Animation check (slice A1, docs/animation/pose-pipeline.md sections 8.6 and 10). Real AI matches run through the full
## scene, one tick per frame, on the templates' dynamic profile:
## 1. the gameplay hash is the same with the mannequin on and off, for both timing styles (render only);
## 2. no bone rotation is ever NaN;
## 3. timing fidelity: on the frame of every blow's contact the solved pose is the contact key (max angle error);
## 4. strikes and reactions actually play (counts), and every part came from a known key set;
## 5. (A2) the contact solve runs and the striking limb ends within 2 units of the defender on average; the per-part mix is a fourth mode;
## 6. nothing under render/anim/ assigns to the sim state S (a static scan).
##   godot --path . --script res://render/anim/tools/anim_check.gd [-- --seeds=4,12345 --ticks=4200]

const DT := 1.0 / 60.0

var seeds: Array = [4, 12345]
var max_ticks: int = 4200
var main: Node
var report_out: String = ""
var report: Dictionary = {"runs": []}
var fails: Array = []
var checks: int = 0


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seeds="):
			seeds = Array(a.substr(8).split(",")).map(func(s): return int(s))
		elif a.begins_with("--ticks="):
			max_ticks = int(a.substr(8))
		elif a.begins_with("--report="):
			report_out = a.substr(9)
	DirData.templatesProfile = "dynamic"
	var vpn := SubViewport.new()
	vpn.size = Vector2i(1280, 720)
	root.add_child(vpn)
	main = load("res://render/main.tscn").instantiate()
	main.manual = true
	vpn.add_child(main)
	_run.call_deferred()


func _expect(ok: bool, what: String) -> void:
	checks += 1
	if not ok:
		fails.append(what)


func _scan_writes() -> void:
	var re := RegEx.new()
	re.compile("(^|[^\\w.])(S|f|ex)\\.[\\w.\\[\\]]+\\s*([+\\-*/]?=)[^=]")
	var d := DirAccess.open("res://render/anim")
	var n := 0
	for fn in d.get_files():
		if not fn.ends_with(".gd"):
			continue
		var lines: PackedStringArray = FileAccess.get_file_as_string("res://render/anim/" + fn).split("\n")
		for i in range(lines.size()):
			var l: String = lines[i].strip_edges()
			if l.begins_with("#") or l.begins_with("##"):
				continue
			n += 1
			_expect(re.search(l) == null, "%s:%d assigns to the sim state: %s" % [fn, i + 1, l])
	print("static scan: %d code lines in render/anim/ read the sim and never assign to it" % n)


## The defensive and clash beats on a stub exchange (no match needed, so a parry is forced): each layer must pull the
## pose toward its own key and leave the fighters it is not for alone.
func _test_beats() -> void:
	var beats: Array = [
		{"op": "wind", "t": 0.0, "args": {}},
		{"op": "strike", "t": 0.3, "args": {"a": "A"}},
		{"op": "slip", "t": 1.0, "args": {}},
		{"op": "dodge", "t": 1.5, "args": {}},
		{"op": "guardBreak", "t": 2.0, "args": {}},
		{"op": "clashWave", "t": 2.5, "args": {}},
		{"op": "dodge", "t": 3.0, "args": {"side": "cross", "dur": 0.15}},
	]
	# [role, cancel, time, the pose that must come, true if it must come]
	var cases: Array = [
		["D", false, 0.25, "def.parry_ready", true], ["A", false, 0.25, "def.parry_ready", false],
		["D", true, 0.34, "def.parry", true], ["A", true, 0.34, "react.rebuff", true],
		["D", false, 1.1, "def.slip", true], ["A", false, 1.1, "def.slip", false],
		["D", false, 1.6, "def.blink_in", true], ["A", false, 1.6, "def.blink_in", false],
		["D", false, 3.04, "def.hop", true], ["D", false, 3.12, "def.drop", true], ["A", false, 3.04, "def.hop", false],
		["D", false, 2.1, "def.guard_break", true], ["A", false, 2.1, "def.guard_break", false],
		["D", false, 2.6, "clash.push", true], ["A", false, 2.6, "clash.push", true],
		["D", false, 3.6, "def.parry_ready", false],
	]
	for c in cases:
		var af := AnimFighter.new(0)
		af._beat_layers({"beats": beats, "cancel": c[1]}, c[0], 0.0, c[2])
		var key: AnimPose = AnimData.pose(c[3])
		var before := 0.0
		var after := 0.0
		for i in range(AnimRig.N):
			before += Quaternion.IDENTITY.angle_to(key.q[i])
			after += af.q[i].angle_to(key.q[i])
		if c[4]:
			_expect(after < before * 0.6, "beat test: %s at %.2f s (cancel %s, role %s) did not pull toward %s (%.2f of %.2f)" % [c[0], c[2], c[1], c[0], c[3], after, before])
		else:
			_expect(after > before * 0.99, "beat test: role %s at %.2f s moved toward %s though the beat is not its own" % [c[0], c[2], c[3]])
	print("beat test: %d cases on a stub exchange (parry forced)" % cases.size())


## The transformation's three beats, in each version, without a match: the gather compresses, the break is exactly the break
## pose on its first tick, the settle holds the settle pose, and the last tick is back on the base pose.
func _test_form() -> void:
	var n := 0
	for v in ["full", "short", "live"]:
		var spec: Dictionary = AnimData.forms[v]
		var g: int = int(spec.gather)
		var b: int = int(spec["break"])
		var tot: int = g + b + int(spec.settle)
		var poses: Dictionary = {}
		for k in AnimData.form_poses:
			poses[k] = AnimData.pose(String(AnimData.form_poses[k]))
		var base: AnimPose = AnimData.pose("stance.aggressive")
		var steps: Array = [["gather", float(g - 1)], ["break", float(g) + 0.5], ["settle", float(g + b) + minf(float(spec.hold) * 0.5, 4.0) + 1.0]]
		for st in steps:
			var af := AnimFighter.new(0)
			af._base = base.q.duplicate()
			af._base_hips = base.hips
			af._base_curl = base.curl
			for i in range(AnimRig.N):
				af.q[i] = base.q[i]
			af.hips = base.hips
			af._form_pose(spec, st[1], v == "live")
			var key: AnimPose = poses[st[0]]
			var d_base := 0.0
			var d_after := 0.0
			for i in range(AnimRig.N):
				d_base += base.q[i].angle_to(key.q[i])
				d_after += af.q[i].angle_to(key.q[i])
			var tol: float = 0.05 if st[0] == "break" else (0.7 if (st[0] == "gather" and v == "live") else 0.45)
			_expect(d_after <= d_base * tol + 0.001, "form test: %s %s beat at tick %.1f is %.2f from its pose (the base is %.2f)" % [v, st[0], st[1], d_after, d_base])
			n += 1
		var af2 := AnimFighter.new(0)
		af2._base = base.q.duplicate()
		af2._base_hips = base.hips
		af2._base_curl = base.curl
		af2._form_pose(spec, float(tot) - 0.5, v == "live")
		var back := 0.0
		for i in range(AnimRig.N):
			back += af2.q[i].angle_to(base.q[i])
		_expect(back < 0.3, "form test: %s ends %.2f rad from the base pose" % [v, back])
		n += 1
	print("form test: %d checks (full, short, live: gather, break, settle, end)" % n)


## Battle damage on a real match, the wear set by hand on a fresh one (a test: this match's hash is not compared): fighter 0 has
## both arms and both legs broken, fighter 1 is worn and then fresh. The broken arm must hang when no blow is being thrown, no
## blow may use the broken limb, the stance must sag toward the brink and the worn fighter must breathe harder than the fresh one.
func _test_wounds() -> void:
	# Every part is a controlled case that cannot depend on how a live match plays (the sim changes under it: launches, embeds, skids): a match is started only for
	# the fighters' records, and the animation is driven directly.
	var live_was: bool = RenderAnim.wave1_live
	RenderAnim.wave1_live = false
	RenderAnim.enabled = true
	RenderAnim.style_override = ""
	main.start_match(4, {"p1": true, "p2": true})
	var S: SimState = main.host.S
	for i in range(30):
		main.frame(DT)
	var a = S.fighters[0]
	var b = S.fighters[1]
	var at: int = int(a.wd.stageAt[2])
	a.wear = [0, 0, at, at]
	a.stage = [0, 0, 3, 3]
	b.wear = [0, int(at * 0.85), 0, 0]
	b.stage = [0, 2, 0, 0]
	var s2: int = AnimRig.index["spine_2"]
	# 1. a broken arm hangs: a fighter standing calm (no blow, no sequence, no ragdoll) with his right or left arm broken, over a second of sim time
	var hang_n := 0
	var hang_ok := 0
	for slot_i in [0, 1]:
		var afa := AnimFighter.new(slot_i)
		afa._wound_read(a)
		var limp: AnimPose = AnimData.pose("wound.arm_limp", not afa._hang_right)
		var fo: int = AnimRig.index["forearm_" + ("r" if afa._hang_right else "l")]
		var stub: Dictionary = {"state": "free", "vx": 0.0}
		for tk in range(60):
			afa.q = AnimData.pose("stance.aggressive").q.duplicate()
			afa.hips = AnimData.pose("stance.aggressive").hips
			afa._part = ""
			afa._wound_limbs(stub, float(tk) * DT)
			hang_n += 1
			if afa.q[fo].angle_to(limp.q[fo]) < 0.3:
				hang_ok += 1
	_expect(hang_n > 0 and hang_ok == hang_n, "wound test: the broken arm hung on %d of %d calm frames" % [hang_ok, hang_n])
	# 3. a fighter at the brink is drawn toward the sagging stance more than a fresh one: the same fighter, the same state, only the sim's brink progress differs
	var sag0: AnimPose = AnimData.pose("wound.sag")
	var dists: Array = []
	for brink in [1.0, 0.0]:
		var afb := AnimFighter.new(1)
		b.state = "free"
		afb._wound_read(b)
		afb._brinkp = brink
		afb._tq = AnimPose.identity_q()
		afb._bkey = -1   # rebuild the target now
		afb._bkey2 = -1
		afb._target_base(S, b, S.T)
		var dw := 0.0
		for nm0 in ["spine_1", "spine_2", "head", "pelvis"]:
			var i0: int = AnimRig.index[nm0]
			dw += afb._tq[i0].angle_to(sag0.q[i0])
		dists.append(dw)
	var d_worn: float = dists[0]
	var d_fresh: float = dists[1]
	_expect(d_worn < d_fresh * 0.9, "wound test: the stance did not sag toward the brink (%.3f against %.3f)" % [d_worn, d_fresh])
	# 2. no blow uses a broken limb: one match, and only if it threw blows with the arm broken (counted when it did; the number must be 0)
	var afm: AnimFighter = RenderAnim.fighter(S, a)
	for i in range(600):
		main.frame(DT)
	_expect(int(afm.debug["wound_bad"]) == 0, "wound test: %d blows used a broken limb (of %d)" % [afm.debug["wound_bad"], afm.debug["wound_strikes"]])
	# the breath of a worn fighter against a fresh one, in a controlled setup (the same fighter, the same four seconds, only the wear differs):
	# a live match plays differently whenever the sim changes, so the chest of whoever happened to be standing in it is not a measure
	b.state = "free"
	var ranges: Array = []
	for wear_b in [[0, int(at * 0.85), 0, 0], [0, 0, 0, 0]]:
		b.wear = wear_b
		b.stage = [0, 2, 0, 0] if int(wear_b[1]) > 0 else [0, 0, 0, 0]
		var afc := AnimFighter.new(1)
		afc._wound_read(b)
		var lo_c := 9.0
		var hi_c := -9.0
		for tk in range(240):
			afc.q = AnimPose.identity_q()
			afc._wear_motion(b, float(tk) * DT)
			var angc: float = afc.q[s2].angle_to(Quaternion.IDENTITY)
			lo_c = minf(lo_c, angc)
			hi_c = maxf(hi_c, angc)
		ranges.append(hi_c - lo_c)
	_expect(float(ranges[0]) > float(ranges[1]) * 1.2, "wound test: the worn fighter's chest moves %.3f, the fresh one's %.3f" % [ranges[0], ranges[1]])
	print("wound test: broken arm hung on %d of %d calm frames, %d blows by the broken limb, stance sag %.3f against %.3f fresh, chest range worn %.3f fresh %.3f (controlled)" % [hang_ok, hang_n, afm.debug["wound_bad"], d_worn, d_fresh, ranges[0], ranges[1]])
	RenderAnim.wave1_live = live_was


## A broken arm hangs heavy while the body is thrown about: with the same kicks, a broken arm swings a third as far as the good one beside it.
func _test_heavy_arm() -> void:
	var swing: Array = []
	for broken in [false, true]:
		var af := AnimFighter.new(0)
		af._arm_broken = broken
		af._hang_right = true
		af._rd.reset()
		for i in range(AnimRagdoll.N):
			af._rd.th[i] = 0.5
		var q1: Array[Quaternion] = AnimPose.identity_q()
		af._rd.apply(q1, 1.0, af._rd_scale())
		var ix: Dictionary = AnimRig.index
		swing.append([q1[ix["upper_arm_r"]].angle_to(Quaternion.IDENTITY), q1[ix["upper_arm_l"]].angle_to(Quaternion.IDENTITY)])
	_expect(float(swing[1][0]) < float(swing[0][0]) * 0.5 and absf(float(swing[1][1]) - float(swing[0][1])) < 0.001, "heavy arm test: the broken arm swings %.2f against %.2f (the good arm %.2f and %.2f)" % [swing[1][0], swing[0][0], swing[1][1], swing[0][1]])
	print("heavy arm test: a broken arm swings %.2f rad where the same arm unbroken swings %.2f; the good arm is untouched" % [swing[1][0], swing[0][0]])


## The joint limits (docs/animation/joint-limits.md): no knee or elbow can be bent past its end or the wrong way, from any source.
## 1. every authored pose (near and far side, each shape's scale) of every wave is inside the limits; 2. every sequence frame, after the solve's last pass;
## 3. the rule itself: a thigh twisted 170 degrees (the flipped knee of a kick) is out of range, and the pass folds the knee the right way;
## 4. the limited IK reaches a kick, a high kick and a hand behind the shoulder with the bend plane inside the twist range and the end where it was asked;
## 5. a ragdoll thrown to its extremes keeps every elbow and knee inside its hinge before the last pass; 6. a live match: no frame that reaches the screen is past a limit.
func _test_joints() -> void:
	AnimData.load_every_wave()
	var rp: Dictionary = AnimJointLint.poses()
	var bad_p: int = AnimJointLint.sum(rp.groups, "bad_frames")
	_expect(bad_p == 0, "joint limits: %d pose frames are past a limit (%s)" % [bad_p, ", ".join(rp.bad_ids.slice(0, 6))])
	var rs: Dictionary = AnimJointLint.sequences()
	var bad_s: int = AnimJointLint.sum(rs.groups, "bad_frames")
	_expect(bad_s == 0, "joint limits: %d sequence frames are past a limit (%s)" % [bad_s, ", ".join(rs.bad_ids.slice(0, 6))])
	var ix: Dictionary = AnimRig.index
	# 3. a flipped knee
	var flip: Array[Quaternion] = AnimPose.identity_q()
	flip[ix["thigh_r"]] = Quaternion(Vector3(0, 1, 0), deg_to_rad(170.0)) * Quaternion(Vector3(0, 0, 1), deg_to_rad(80.0))
	flip[ix["shin_r"]] = Quaternion(Vector3(0, 0, 1), deg_to_rad(-60.0))
	var before: Array = AnimJoints.violations(flip, "")
	AnimJoints.enforce(flip, "")
	var after: Array = AnimJoints.violations(flip, "")
	var tw_after: float = AnimJoints.twist_of(flip[ix["thigh_r"]])
	_expect(not before.is_empty() and after.is_empty() and absf(tw_after) <= deg_to_rad(86.0), "joint limits: a thigh twisted 170 degrees was not brought inside the range (twist now %.0f)" % rad_to_deg(tw_after))
	# 4. limited IK on a kick, a high kick and a hand behind the shoulder
	var base: AnimPose = AnimData.pose("stance.aggressive")
	var worst_end: float = 0.0
	var worst_tw: float = 0.0
	var n_ik := 0
	for lean in [0.0, 25.0, -20.0]:
		for tgt in [Vector3(52, 44, 6), Vector3(48, 54, 8), Vector3(40, 20, 6), Vector3(60, 30, 6), Vector3(22, 14, 6)]:
			var lq: Array[Quaternion] = base.q.duplicate()
			lq[ix["pelvis"]] = Quaternion(Vector3(0, 0, 1), -deg_to_rad(lean))
			var gq: Array[Quaternion] = []
			gq.resize(AnimRig.N)
			var gp := PackedVector3Array()
			gp.resize(AnimRig.N)
			AnimPose.fk(lq, base.hips, gq, gp)
			var th: int = ix["thigh_r"]
			AnimPose.ik_limb(lq, gq, gp, th, th + 1, th + 2, tgt, gp[th] + Vector3(10, 1, 0), -1.0)
			AnimPose.fk(lq, base.hips, gq, gp)
			var ex: Vector2 = AnimJoints.ball_excess(lq, th, "")
			worst_tw = maxf(worst_tw, ex.x + ex.y)
			worst_end = maxf(worst_end, (gp[th + 2] - tgt).length() if (tgt - gp[th]).length() < 33.0 else 0.0)
			n_ik += 1
	_expect(worst_tw <= 0.0005 and worst_end < 0.5, "joint limits: the limited IK left a thigh %.3f rad past its range or the foot %.2f units from a reachable target" % [worst_tw, worst_end])
	# 5. a ragdoll thrown to its extremes
	var rd_bad := 0
	for sgn in [1.0, -1.0]:
		for mag in [0.6, 1.5, 3.0]:
			var af := AnimFighter.new(0)
			af._rd.reset()
			for i in range(AnimRagdoll.N):
				af._rd.th[i] = mag * sgn * (1.0 if i % 2 == 0 else -1.0)
			var rq: Array[Quaternion] = base.q.duplicate()
			af._rd.apply(rq, 1.0)
			for nm in ["forearm_l", "forearm_r", "shin_l", "shin_r"]:
				var bi: int = ix[nm]
				var th2: float = AnimJoints.hinge_state(rq[bi], bi).x
				if th2 < AnimJoints.hinge_min[bi] - 0.02 or th2 > AnimJoints.hinge_max[bi] + 0.02:
					rd_bad += 1
	_expect(rd_bad == 0, "joint limits: the ragdoll folded %d elbows or knees past their hinge" % rd_bad)
	# 6. a live match
	RenderAnim.enabled = true
	main.start_match(4, {"p1": true, "p2": true})
	var S: SimState = main.host.S
	var live_bad := 0
	var live_n := 0
	RenderAnim.joint_audit = true
	var src_bad := 0
	while main.host.ticks < 2400 and not (S.game.ko != null and S.game.koT > 3.0):
		main.frame(DT)
		for f in S.fighters:
			var a: AnimFighter = RenderAnim.fighter(S, f)
			if a.version == 0:
				continue
			live_n += 1
			if not AnimJoints.violations(a.q, a._rd.shape_key).is_empty():
				live_bad += 1
			if a.audit.has("D") and not (a.audit["D"] as Array).is_empty():
				src_bad += 1
	RenderAnim.joint_audit = false
	_expect(live_bad == 0 and live_n > 1000, "joint limits: %d of %d live fighter-frames reach the screen past a limit" % [live_bad, live_n])
	print("joint limits: %d poses and %d sequence frames inside the limits; a flipped thigh is brought in; the limited IK keeps %d targets legal (worst %.4f rad); ragdoll hinges kept; live %d frames, %d reach the screen past a limit (the sources alone leave %d for the last pass)" % [AnimJointLint.sum(rp.groups, "frames") / 10, AnimJointLint.sum(rs.groups, "frames"), n_ik, worst_tw, live_n, live_bad, src_bad])


## The agency slice's events (docs/animation/pose-pipeline.md 9.22): a knockback holds its pose for the event's own length and lets go; the embed plays its sequence
## over the held-down ticks; the far taunt plays its shrug and is cut by taunt_end_cut; a charge holds its flight pose until a fall (or the exchange) ends it, and a
## feint swaps it for the peel; reduced motion plays them at 60%; switched off, none of it plays.
func _test_agency() -> void:
	var A: Dictionary = AnimData.agency
	_expect(not A.is_empty() and AnimData.pose_exists("ag.hold.charge_heavy") and AnimData.entries.has("ag.taunt") and AnimData.entries.has("ag.embed"), "agency test: the agency data or its poses did not load")
	main.start_match(4, {"p1": true, "p2": true})
	var S: SimState = main.host.S
	var f = S.fighters[0]
	var base: AnimPose = AnimData.pose("stance.aggressive")
	var ix: Dictionary = AnimRig.index
	var th: int = ix["thigh_l"]
	# a knockback: mixed in while it lasts, gone after it
	var af := AnimFighter.new(0)
	af.on_agency("knockback", 1.0, {"kind": "slideLong", "dur": 0.6})
	var seen := 0.0
	var gone := false
	for tk in range(0, 120, 3):
		af.q = base.q.duplicate()
		af.hips = base.hips
		af._agency_layer(S, f, 1.0 + float(tk) / 60.0)
		if tk == 18:
			seen = af.q[th].angle_to(base.q[th])
		if tk == 117:
			gone = af.q[th].angle_to(base.q[th]) < 0.0001 and af._ag_t0 < 0.0
	_expect(seen > 0.1 and gone, "agency test: the knockback pose %s (%.3f rad mid-slide) and %s after it" % ["did not play" if seen <= 0.1 else "played", seen, "was gone" if gone else "stayed"])
	# the embed and the taunt: sequences, the taunt cut
	af.on_agency("embed", 2.0, {"dur": 1.0})
	_expect(String(af._seq.get("id", "")) == "ag.embed" and absf(float(af._seq.dur) - 1.0) < 0.001, "agency test: the embed sequence did not start for the held-down time")
	af.on_agency("taunt_start", 3.0, {})
	_expect(String(af._seq.get("id", "")) == "ag.taunt", "agency test: the taunt did not start")
	af.on_agency("taunt_end_cut", 3.2, {})
	_expect(af._seq.is_empty(), "agency test: the taunt was not cut")
	# a charge: held until a fall; a feint takes the peel
	var ac := AnimFighter.new(0)
	ac.on_agency("charge_heavy", 5.0, {})
	f.state = "free"
	ac.q = base.q.duplicate()
	ac._agency_layer(S, f, 5.5)
	var held: bool = ac._ag_t1 < 0.0 and ac._ag_hold == "ag.hold.charge_heavy"
	f.state = "launched"
	ac._agency_layer(S, f, 5.6)
	var ended: bool = ac._ag_t1 >= 0.0
	f.state = "free"
	ac.on_agency("charge_feint", 6.0, {})
	_expect(held and ended and ac._ag_hold == "ag.hold.charge_peel" and ac._ag_t1 > 6.0, "agency test: the charge held %s, ended on a fall %s, the feint took the peel %s" % [held, ended, ac._ag_hold == "ag.hold.charge_peel"])
	# reduced motion plays at 60%
	var red_was: bool = RenderAnim.reduced_motion
	RenderAnim.reduced_motion = true
	var ar := AnimFighter.new(0)
	ar.on_agency("knockback", 1.0, {"kind": "slideShort", "dur": 0.5})
	var w_red: float = ar._ag_w
	RenderAnim.reduced_motion = red_was
	var ar2 := AnimFighter.new(0)
	ar2.on_agency("knockback", 1.0, {"kind": "slideShort", "dur": 0.5})
	_expect(w_red < ar2._ag_w * 0.7, "agency test: reduced motion plays the knockback at %.2f of %.2f" % [w_red, ar2._ag_w])
	# switched off: nothing
	RenderAnim.agency_poses = false
	var ao := AnimFighter.new(0)
	ao.on_agency("knockback", 1.0, {"kind": "slideShort", "dur": 0.5})
	ao.on_agency("embed", 1.0, {"dur": 1.0})
	RenderAnim.agency_poses = true
	_expect(ao._ag_t0 < 0.0 and ao._seq.is_empty(), "agency test: the events played with the agency poses off")
	print("agency test: knockback mid-slide %.3f rad, embed, taunt cut, charge held and ended on a fall, feint peel, reduced motion %.2f of %.2f, off plays nothing" % [seen, w_red, ar2._ag_w])


## The active ragdoll (overhaul unit A): the same match at one tick a frame and at two ticks a frame ends with the same ragdoll state
## (it is stepped per sim tick, never per frame); reduced motion shrinks the motion; the overhaul can be switched off; the ground
## events of World's plan (a stub shaped like docs/world/ground-contact.md) move the body. The gameplay hash is compared in the main loop.
func _rd_run(per_frame: int, until: int, reduced: bool, enabled: bool = true) -> Dictionary:
	RenderAnim.enabled = true
	RenderAnim.ragdoll_enabled = enabled
	RenderAnim.reduced_motion = reduced
	main.start_match(4, {"p1": true, "p2": true})
	var S: SimState = main.host.S
	var maxe := 0.0
	var maxlook := 0.0
	var active := 0
	while main.host.ticks < until:
		main.frame(DT * per_frame)
		for f in S.fighters:
			var rd: AnimRagdoll = RenderAnim.fighter(S, f)._rd
			maxe = maxf(maxe, rd.energy())
			maxlook = maxf(maxlook, absf(RenderAnim.fighter(S, f)._look))
			if rd.out_w > 0.5:
				active += 1
	var th: Array = []
	for f in S.fighters:
		var rd2: AnimRagdoll = RenderAnim.fighter(S, f)._rd
		for i in range(AnimRagdoll.N):
			th.append(snappedf(rd2.th[i], 0.0001))
		th.append(snappedf(rd2.out_w, 0.0001))
		var afx: AnimFighter = RenderAnim.fighter(S, f)
		for i in range(5):
			th.append(snappedf(afx._sx[i], 0.0001))
		th.append(snappedf(afx._look, 0.0001))
	RenderAnim.reduced_motion = false
	return {"th": th, "maxe": maxe, "active": active, "ticks": main.host.ticks, "look": maxlook}


func _test_ragdoll() -> void:
	var a: Dictionary = _rd_run(1, 1200, false)
	var b: Dictionary = _rd_run(2, 1200, false)
	_expect(a.ticks == b.ticks, "ragdoll test: the runs ended on different ticks (%d, %d)" % [a.ticks, b.ticks])
	var di: int = -1
	for i in range(mini(a.th.size(), b.th.size())):
		if a.th[i] != b.th[i]:
			di = i
			break
	_expect(di < 0, "ragdoll test: the ragdoll state differs between one tick a frame and two at entry %d of %d (%s against %s; per fighter: 12 joints, out_w, 5 cloth, look)" % [di, a.th.size(), str(a.th[di] if di >= 0 else 0), str(b.th[di] if di >= 0 else 0)])
	_expect(a.active > 20, "ragdoll test: the ragdoll was never active (%d frames)" % a.active)
	var r: Dictionary = _rd_run(1, 1200, true)
	# reduced motion narrows every joint to half its range as well as shrinking the drive, so even a whole match with hard tumbles is calmer by a good margin
	_expect(r.maxe < a.maxe * 0.6, "ragdoll test: reduced motion moves %.2f against %.2f" % [r.maxe, a.maxe])
	var kick_e: Array = []
	for amp_k in [1.0, 0.35]:
		var rdk := AnimRagdoll.new()
		rdk.crumple(1.0, amp_k)
		var mk := 0.0
		for tk in range(40):
			rdk.step(DT, Vector2.ZERO, Vector2.ZERO, 1.0, amp_k, float(tk) * DT)
			mk = maxf(mk, rdk.energy())
		kick_e.append(mk)
	_expect(float(kick_e[1]) < float(kick_e[0]) * 0.5, "ragdoll test: the same crumple moves %.2f at reduced motion against %.2f" % [kick_e[1], kick_e[0]])
	var off: Dictionary = _rd_run(1, 600, false, false)
	_expect(off.maxe == 0.0, "ragdoll test: the switch left the ragdoll moving (%.3f)" % off.maxe)
	RenderAnim.ragdoll_enabled = true
	# World's ground events, a stub in the planned shape
	var S: SimState = main.host.S
	var af := AnimFighter.new(0)
	af.on_ground_event("bounce", {"actor": 0, "k": 1, "vn": -2400.0, "vt": 900.0, "keep": 0.5, "surface": "soil"}, 1.0)
	var e1: float = af._rd.energy() + af._rd.om[0] * 0.0
	var w1 := 0.0
	for i in range(AnimRagdoll.N):
		w1 += absf(af._rd.om[i])
	af.on_ground_event("land", {"actor": 0, "kind": "slam", "sin_a": 0.96, "surface": "soil"}, 1.1)
	var w2 := 0.0
	for i in range(AnimRagdoll.N):
		w2 += absf(af._rd.om[i])
	_expect(w1 > 1.0 and w2 > w1, "ragdoll test: the ground events did not move the body (%.2f, %.2f)" % [w1, w2])
	_expect(a.look > 0.03, "ragdoll test: the head never looked at the opponent (%.3f)" % a.look)
	var sk := AnimFighter.new(0)
	sk.on_skim(2.0, 3000.0)
	_expect(sk._skim_t0 == 2.0 and absf(sk._rd.om[1]) > 1.0, "ragdoll test: a water skim did not start the arch")
	print("ragdoll test: same state at one and two ticks a frame, %d active frames, reduced %.2f of %.2f, ground-event stub %.1f then %.1f rad/s" % [a.active, r.maxe, a.maxe, w1, w2])


## Hit reactions computed from the blow (overhaul unit B): the direction decides which way the head snaps, the force and the
## victim's wear scale it, two hits in a row differ, the same hit at the same tick is the same (a replay), reduced motion shrinks it.
func _hit(af: AnimFighter, d: Vector2, force: float, tick: int, region: String = "head") -> Array:
	af._rd.reset()
	af.on_hit(1.0, region, d.x < 0.0, 0.5, "", d, force, tick)
	return [af._rd.om[0], af._rd.om[1], af._rd.om[2], af._rd.om[5]]


func _test_hits() -> void:
	RenderAnim.ragdoll_enabled = true
	RenderAnim.reduced_motion = false
	var af := AnimFighter.new(0)
	var front: Array = _hit(af, Vector2(-1, 0), 0.8, 100)
	var back: Array = _hit(af, Vector2(1, 0), 0.8, 100)
	_expect(front[0] > 1.0 and back[0] < -1.0, "hit test: the head snaps %.2f from the front and %.2f from behind" % [front[0], back[0]])
	var gut: Array = _hit(af, Vector2(-1, 0), 0.8, 100, "core")
	_expect(gut[1] < -1.0, "hit test: a blow to the gut from the front should fold the spine forward (%.2f)" % gut[1])
	var small: Array = _hit(af, Vector2(-1, 0), 0.3, 100)
	var big: Array = _hit(af, Vector2(-1, 0), 1.2, 100)
	_expect(absf(big[0]) > absf(small[0]) * 2.5, "hit test: force 1.2 gives %.2f, force 0.3 gives %.2f" % [big[0], small[0]])
	af._worn = 0.9
	var worn: Array = _hit(af, Vector2(-1, 0), 0.8, 100)
	af._worn = 0.0
	var fresh: Array = _hit(af, Vector2(-1, 0), 0.8, 100)
	_expect(absf(worn[0]) > absf(fresh[0]) * 1.3, "hit test: a worn fighter's head snaps %.2f against %.2f fresh" % [worn[0], fresh[0]])
	var first: Array = _hit(af, Vector2(-1, 0), 0.8, 200)
	var second: Array = _hit(af, Vector2(-1, 0), 0.8, 200)
	_expect(first != second, "hit test: two identical hits in a row came out identical")
	var a1 := AnimFighter.new(1)
	var a2 := AnimFighter.new(1)
	var r1: Array = _hit(a1, Vector2(-1, 0), 0.8, 300)
	var r2: Array = _hit(a2, Vector2(-1, 0), 0.8, 300)
	_expect(r1 == r2, "hit test: the same hit at the same tick differs between two bodies (a replay would differ)")
	RenderAnim.reduced_motion = true
	var red: Array = _hit(AnimFighter.new(1), Vector2(-1, 0), 0.8, 300)
	RenderAnim.reduced_motion = false
	_expect(absf(red[0]) < absf(r1[0]) * 0.5, "hit test: reduced motion head snap %.2f against %.2f" % [red[0], r1[0]])
	# the contact catch's smear: the body lags the anchor and catches up in 3 ticks; the contact solve reaches that far
	var cs := AnimFighter.new(0)
	cs._smear = -20.0
	cs._smear_t0 = 1.0
	_expect(cs._smear_now(1.0) == -20.0 and cs._smear_now(1.025) < -2.0 and cs._smear_now(1.025) > -18.0 and cs._smear_now(1.06) == 0.0, "hit test: the catch smear does not ease out")
	print("hit test: head snap front %.1f behind %.1f, force 0.3 gives %.1f and 1.2 gives %.1f, worn %.1f fresh %.1f, two in a row %.1f then %.1f" % [front[0], back[0], small[0], big[0], worn[0], fresh[0], first[0], second[0]])


## Feet on a slope (overhaul unit D): a crater is dug beside a stand on open ground; with the feet placed the ankles must sit on the
## ground under each foot (the pose's own ankle height, 2.5 u), without they float or sink. The fighter is a stub (position and
## state only) on a real terrain, so the check does not depend on where an AI match happens to fight.
func _slope_run(on: bool, S: SimState, X: float) -> Dictionary:
	var f := {"x": X, "y": WorldTerrain.groundY(S, X), "state": "free", "slide": 0.0, "vx": 0.0, "vy": 0.0}
	var af := AnimFighter.new(0)
	af.vface = 1.0
	var base: AnimPose = AnimData.pose("stance.aggressive")
	for i in range(AnimRig.N):
		af.q[i] = base.q[i]
	af.hips = base.hips
	var gq: Array[Quaternion] = []
	gq.resize(AnimRig.N)
	var gp := PackedVector3Array()
	gp.resize(AnimRig.N)
	var err := 0.0
	var n := 0
	var worst := 0.0
	var g0: float = WorldTerrain.groundY(S, X)
	for k in range(-20, 40):
		# stand at a series of places across the crater wall
		var x: float = X + float(k) * 10.0
		f.x = x
		f.y = WorldTerrain.groundY(S, x)
		for i in range(AnimRig.N):
			af.q[i] = base.q[i]
		af.hips = base.hips
		if on:
			for rep in range(40):
				for i in range(AnimRig.N):
					af.q[i] = base.q[i]
				af.hips = base.hips
				af._gf_gtick = -100
				af._gf_x_valid = false
				af._ground_feet(S, f, 0.05)
		AnimPose.fk(af.q, af.hips, gq, gp)
		for nm in ["foot_l", "foot_r"]:
			var gpf: Vector3 = gp[AnimRig.index[nm]]
			var fx: float = x + gpf.x
			var gd: float = WorldTerrain.groundY(S, fx) - WorldTerrain.groundY(S, x)
			if absf(gd) > 3.0:
				var e: float = absf(gpf.y - gd - 2.5)
				err += e
				worst = maxf(worst, e)
				n += 1
	return {"n": n, "mean": err / maxf(1.0, n), "worst": worst}


func _test_slope() -> void:
	RenderAnim.enabled = true
	RenderAnim.ragdoll_enabled = true
	RenderAnim.ground_feet = true
	main.start_match(4, {"p1": true, "p2": true})
	var S: SimState = main.host.S
	for i in range(5):
		main.frame(DT)
	var X: float = -1.0
	var xs: float = 0.0
	while xs < 100000.0:
		var g: float = WorldTerrain.groundY(S, xs)
		if g > 40.0 and absf(WorldTerrain.groundY(S, xs + 120.0) - g) < 1.0 and absf(WorldTerrain.groundY(S, xs - 120.0) - g) < 1.0:
			X = xs
			break
		xs += 100.0
	_expect(X >= 0.0, "slope test: found no flat land for the test crater")
	if X < 0.0:
		return
	WorldCrater.dig(S, SimWrap.wrap(X + 150.0), 1.0, S.fighters[1], "impact", 0.0, 1.0, false)
	var off: Dictionary = _slope_run(false, S, X)
	var on: Dictionary = _slope_run(true, S, X)
	_expect(on.n > 5, "slope test: the stand was never on a slope (%d foot samples)" % on.n)
	_expect(on.mean < 1.5 and on.mean < off.mean * 0.5, "slope test: the ankle is %.2f u off the ground with the feet placed and %.2f without" % [on.mean, off.mean])
	print("slope test: %d foot samples on a crater wall, ankle height error %.2f u with the feet placed (worst %.1f), %.2f without" % [on.n, on.mean, on.worst, off.mean])


## Anticipation and follow-through by the blow's weight, and the beam's aim (overhaul unit D).
func _test_weight_aim() -> void:
	var w20: float = AnimFighter._blow_weight({"dmg": 20.0})
	var w50: float = AnimFighter._blow_weight({"dmg": 50.0})
	var w90: float = AnimFighter._blow_weight({"dmg": 90.0})
	_expect(w20 < w50 and w50 < w90 and w90 <= 1.4, "weight test: the blow weights are %.2f, %.2f, %.2f" % [w20, w50, w90])
	_expect(AnimFighter._blow_weight({"o": {"big": true}}) == 1.0 and AnimFighter._blow_weight({}) < 1.0, "weight test: a chain link or a blow without damage reads wrong")
	var af := AnimFighter.new(0)
	var before: Quaternion = af.q[AnimRig.index["upper_arm_r"]]
	af._aim_arms(0.5, 1.0)
	var turned: float = af.q[AnimRig.index["upper_arm_r"]].angle_to(before)
	_expect(absf(turned - 0.5) < 0.02, "aim test: the arm turned %.3f rad for an aim of 0.5" % turned)
	print("weight test: blow weights %.2f %.2f %.2f for 20 50 90 damage; aim turns the arms %.2f rad for 0.5" % [w20, w50, w90, turned])


## Unit E: the defender's side and the fighters' own flinch shapes.
func _test_defender() -> void:
	var stub: Dictionary = {"cancel": false, "t": 0.0, "kind": "heavy", "beats": [{"op": "strike", "t": 0.1, "done": false, "args": {"a": "A", "dmg": 60.0}}, {"op": "strike", "t": 0.4, "done": false, "args": {"a": "A", "dmg": 0.0}}]}
	var nb: Array = AnimFighter._next_blow(stub)
	_expect(nb.size() == 4 and absf(float(nb[0]) - 0.1) < 0.001 and nb[1] == true and float(nb[2]) == 60.0, "defender test: the next blow is %s" % str(nb))
	stub.cancel = true
	_expect(AnimFighter._next_blow(stub).is_empty(), "defender test: a parried exchange still has a next blow")
	stub.cancel = false
	stub.t = 0.42
	var miss: Array = AnimFighter._next_blow(stub)
	_expect(miss.size() == 4 and float(miss[2]) == 0.0 and float(miss[0]) < 0.0, "defender test: a blow just missed should be found (%s)" % str(miss))
	stub.beats.append({"op": "dodge", "t": 0.2, "done": true, "args": {}})
	_expect(AnimFighter._has_evade(stub), "defender test: a dodge beat is not seen")
	# the flinch keys differ per fighter: the same heavy blow, a few ticks of the ragdoll, two shapes
	RenderAnim.ragdoll_enabled = true
	RenderAnim.reduced_motion = false
	var res: Array = []
	for rid in ["KAI", "VORR"]:
		var af := AnimFighter.new(0)
		af._rd.set_shape(rid)
		af.on_hit(1.0, "core", true, 0.9, "", Vector2(-1, 0), 1.2, 500)
		for i in range(25):
			af._rd.w_crumple = af._hit_crum * af._hit_w * 0.5
			af._rd.w_brace = (1.0 - af._hit_crum) * af._hit_w * 0.45
			af._hit_w = maxf(0.0, af._hit_w - (1.0 / 60.0) / 0.3)
			af._rd.step(1.0 / 60.0, Vector2.ZERO, Vector2.ZERO, 0.4, 1.0, 1.0 + i / 60.0)
		res.append(af._rd.th.duplicate())
	var dist := 0.0
	for i in range(AnimRagdoll.N):
		dist += absf(res[0][i] - res[1][i])
	_expect(dist > 0.3, "defender test: two fighters flinch the same (%.3f rad apart in total)" % dist)
	var ev: Array = AnimFighter._next_evade({"beats": [{"op": "dodge", "t": 0.5, "args": {}}, {"op": "slip", "t": 0.3, "args": {}}], "t": 0.2})
	_expect(ev.size() == 2 and absf(float(ev[0]) - 0.1) < 0.001 and int(ev[1]) == 1, "defender test: the next evade is %s" % str(ev))
	var ms: Array = AnimFighter._next_miss({"beats": [{"op": "strike", "t": 0.3, "args": {"a": "A", "dmg": 0.0}}, {"op": "strike", "t": 0.1, "args": {"a": "A", "dmg": 40.0}}], "t": 0.25})
	_expect(ms.size() == 2 and absf(float(ms[0]) - 0.05) < 0.001 and int(ms[1]) == 0, "defender test: the next whiff is %s" % str(ms))
	var lean := AnimFighter.new(0)
	lean._lean_away(1.0, 1.0)
	var over := AnimFighter.new(0)
	over._over_commit(1.0, 1.0)
	var blk := AnimFighter.new(0)
	blk.on_blocked(1.0)
	_expect(lean._rd.om[0] > 3.0 and over._rd.om[1] < -3.0 and blk._rd.om[2] < -3.0, "defender test: lean-away, over-commit and blocked recoil do not point the right ways (%.1f, %.1f, %.1f)" % [lean._rd.om[0], over._rd.om[1], blk._rd.om[2]])
	_expect(lean._evade_offsets(1.15) < -0.5 and over._evade_offsets(1.15) > 0.5 and blk._evade_offsets(1.03) < -1.0, "defender test: the evade root offsets do not move the body the right way")
	print("defender test: next blow %s, a miss is found, the two shapes flinch %.2f rad apart in total" % [str(nb), dist])


## Unit F: idles with personality, the guard's overlap, the turn-around step.
func _test_personality() -> void:
	RenderAnim.ragdoll_enabled = true
	RenderAnim.reduced_motion = false
	var ranges: Dictionary = {}
	for stance in [1, 2]:
		var lo := 99.0
		var hi := -99.0
		for k in range(240):
			var af := AnimFighter.new(0)
			af.hips = Vector3.ZERO
			af._personality_layer(float(k) / 60.0, stance, 0, 1.0)
			lo = minf(lo, af.hips.y)
			hi = maxf(hi, af.hips.y)
		ranges[stance] = hi - lo
	_expect(ranges[2] > ranges[1] * 2.0, "personality test: the evasive bounce is %.2f and the defensive %.2f" % [ranges[2], ranges[1]])
	var chest: Array = []
	for tier in [0, 3]:
		var m := 0.0
		for k in range(240):
			var af2 := AnimFighter.new(0)
			af2._personality_layer(float(k) / 60.0, 0, tier, 1.0)
			m = maxf(m, af2.q[AnimRig.index["spine_2"]].angle_to(Quaternion.IDENTITY))
		chest.append(m)
	_expect(chest[1] > chest[0] * 1.15, "personality test: the breath of tier 4 (%.4f) is not deeper than tier 1 (%.4f)" % [chest[1], chest[0]])
	var g := AnimFighter.new(0)
	g._stance_kick(0, 1)
	var up: float = g._rd.om[2]
	var g2 := AnimFighter.new(0)
	g2._stance_kick(1, 0)
	var down: float = g2._rd.om[2]
	_expect(up > 1.0 and down < -1.0, "personality test: the guard kicks are %.2f up and %.2f down" % [up, down])
	var t := AnimFighter.new(0)
	t._turn_t0 = 5.0
	t._turn_dir = 1.0
	t._turn_layer(5.11)
	_expect(t.hips.y < -0.8 and t.q[AnimRig.index["thigh_r"]].angle_to(Quaternion.IDENTITY) > 0.2, "personality test: the turn step does not dip and swing (%.2f)" % t.hips.y)
	var t2 := AnimFighter.new(0)
	t2._turn_t0 = 5.0
	t2._turn_layer(5.3)
	_expect(t2.hips == Vector3.ZERO, "personality test: the turn step runs past its time")
	print("personality test: bounce %.2f evasive against %.2f defensive, breath %.4f tier 4 against %.4f tier 1, guard kicks %.1f up %.1f down, turn dip %.2f" % [ranges[2], ranges[1], chest[1], chest[0], up, down, t.hips.y])


## Unit G: the gait events, the shudder of a nearby impact, the bank.
func _test_flight() -> void:
	_expect(AnimFighter._gait_event(20000.0, 100.0, 300.0) == "burst", "flight test: a hard push from nearly still is not a burst")
	_expect(AnimFighter._gait_event(20000.0, 900.0, 1100.0) == "", "flight test: a run getting faster is a burst")
	_expect(AnimFighter._gait_event(-12000.0, 900.0, 600.0) == "brake", "flight test: a hard slowdown from a run is not a brake")
	_expect(AnimFighter._gait_event(-12000.0, 100.0, 80.0) == "", "flight test: a slow body is braking")
	RenderAnim.ragdoll_enabled = true
	RenderAnim.reduced_motion = false
	var af := AnimFighter.new(0)
	af.on_shock(1.0, 0.8)
	var h := 0.0
	for k in range(30):
		af.hips = Vector3.ZERO
		af._shock_layer(1.0 + float(k) / 60.0)
		h = maxf(h, absf(af.hips.y))
	var late := AnimFighter.new(0)
	late.on_shock(1.0, 0.8)
	late.hips = Vector3.ZERO
	late._shock_layer(2.5)
	_expect(h > 0.5 and late.hips.y == 0.0, "flight test: the shudder is %.2f at its height and %.2f after 1.5 s" % [h, late.hips.y])
	var far := AnimFighter.new(0)
	far.on_shock(1.0, 0.0)
	_expect(far._shock_amp == 0.0, "flight test: an impact of no strength shook him")
	print("flight test: gait events found, the shudder of a nearby impact peaks at %.2f u" % h)


## Unit H: the quality levels switch the layers they list off, and only those, and never touch the simulation.
func _test_quality() -> void:
	RenderAnim.ragdoll_enabled = true
	RenderAnim.set_quality("high")
	for nm in ["ragdoll", "feet", "look", "aim", "personality", "transitions", "defender", "flight", "cloth", "lean"]:
		_expect(RenderAnim.layer(nm), "quality test: layer %s is off at high" % nm)
	RenderAnim.set_quality("medium")
	_expect(not RenderAnim.layer("look") and not RenderAnim.layer("feet") and not RenderAnim.layer("personality") and RenderAnim.layer("ragdoll") and RenderAnim.layer("defender"), "quality test: medium switches the wrong layers")
	RenderAnim.set_quality("low")
	_expect(RenderAnim.layer("ragdoll") and not RenderAnim.layer("cloth") and not RenderAnim.layer("flight"), "quality test: low keeps the ragdoll and drops the cloth and flight layers")
	RenderAnim.set_quality("minimal")
	_expect(not RenderAnim.layer("ragdoll"), "quality test: minimal keeps the ragdoll")
	var hashes: Dictionary = {}
	for lv in ["high", "low", "minimal"]:
		RenderAnim.set_quality(lv)
		main.start_match(4, {"p1": true, "p2": true})
		var S: SimState = main.host.S
		while main.host.ticks < 600:
			main.frame(DT)
		hashes[lv] = str(SimHash.stateHash(S).gameplay)
	RenderAnim.set_quality("high")
	_expect(hashes.high == hashes.low and hashes.high == hashes.minimal, "quality test: the gameplay hash differs between quality levels (%s)" % str(hashes))
	print("quality test: levels switch their layers, the gameplay hash is the same at high, low and minimal (%s)" % hashes.high)


## Unit K: the winner's beats after a KO (stand, survey, then hold or a raised fist by shape) and the KO's fall, on stub fighters
## (position and state only) in a real world.
func _tq_nearest(af: AnimFighter, ids: Array) -> String:
	var best: String = ""
	var bd := 1.0e9
	for id in ids:
		var p: AnimPose = AnimData.pose(id)
		var d := 0.0
		for i in range(AnimRig.N):
			d += af._tq[i].angle_to(p.q[i])
		if d < bd:
			bd = d
			best = id
	return best


func _stub(S: SimState, state: String, st: float, id: String) -> Dictionary:
	return {"state": state, "stateT": st, "slide": 0.0, "stance": 0, "vx": 0.0, "vy": 0.0, "ki": 50.0, "x": S.fighters[0].x, "y": WorldTerrain.groundY(S, S.fighters[0].x), "id": id, "tier": 1.0, "beamCharge": null}


func _test_win_ko() -> void:
	RenderAnim.enabled = true
	RenderAnim.ragdoll_enabled = true
	main.start_match(4, {"p1": true, "p2": true})
	var S: SimState = main.host.S
	for i in range(5):
		main.frame(DT)
	S.game.ko = S.fighters[1]
	var cands: Array = ["win.stand", "win.survey", "emote.victory", "stance.aggressive"]
	var got: Array = []
	for pair in [[1.2, "KAI"], [2.5, "KAI"], [6.0, "KAI"], [6.0, "VORR"]]:
		S.game.koT = pair[0]
		var af := AnimFighter.new(0)
		af._target_base(S, _stub(S, "free", 0.0, pair[1]), 5.0)
		got.append(_tq_nearest(af, cands))
	_expect(got == ["win.stand", "win.survey", "win.survey", "emote.victory"], "win test: the winner's beats are %s" % str(got))
	var f2: Dictionary = _stub(S, "down", 0.0, "KAI")
	S.game.ko = f2
	var early := AnimFighter.new(0)
	early._target_base(S, f2, 5.0)
	f2.stateT = 0.6
	var late := AnimFighter.new(0)
	late._target_base(S, f2, 5.0)
	var fall: Array = [_tq_nearest(early, ["react.stagger", "down.ko"]), _tq_nearest(late, ["react.stagger", "down.ko"])]
	_expect(fall == ["react.stagger", "down.ko"], "win test: the KO falls %s" % str(fall))
	S.game.ko = null
	print("win test: the winner's beats %s, a KO falls %s" % [str(got), str(fall)])


## The clavicle hunch effector and the socket table: the shoulder goes where it is told on both sides, a baked pose with a hand
## target past the arm's reach carries its shoulder toward it, an authored hunch moves the shoulder of its pose, and the table
## names every limb and region a key set may use.
func _test_hunch() -> void:
	var ix: Dictionary = AnimRig.index
	var gq: Array[Quaternion] = []
	gq.resize(AnimRig.N)
	var gp := PackedVector3Array()
	gp.resize(AnimRig.N)
	var q0: Array[Quaternion] = AnimPose.identity_q()
	AnimPose.fk(q0, Vector3.ZERO, gq, gp)
	var rest: Dictionary = {"r": gp[ix["upper_arm_r"]], "l": gp[ix["upper_arm_l"]]}
	var moved: Array = []
	for sd in ["r", "l"]:
		var lq: Array[Quaternion] = AnimPose.identity_q()
		AnimPose.hunch(lq, sd, 3.0, 2.0)
		AnimPose.fk(lq, Vector3.ZERO, gq, gp)
		var dlt: Vector3 = gp[ix["upper_arm_" + sd]] - rest[sd]
		moved.append(snappedf(dlt.x, 0.1))
		moved.append(snappedf(dlt.y, 0.1))
		_expect(absf(dlt.x - 3.0) < 0.15 and absf(dlt.y - 2.0) < 0.3, "hunch test: the %s shoulder moved by %s, not (3, 2)" % [sd, str(dlt)])
	# a hand target past the arm's reach: the baked shoulder comes toward it, and nothing moves with the hunch off
	var d: Dictionary = {"family": "upright", "hand_r": [45, 60, 5], "hand_l": [0, 30, -10]}
	var on: AnimPose = AnimPose.bake("t_on", d)
	var was: bool = AnimPose.hunch_auto
	AnimPose.hunch_auto = false
	var off: AnimPose = AnimPose.bake("t_off", d)
	AnimPose.hunch_auto = was
	var shx: Array = []
	for pz in [on, off]:
		AnimPose.fk(pz.q, pz.hips, gq, gp)
		shx.append(gp[ix["upper_arm_r"]].x)
	_expect(float(shx[0]) > float(shx[1]) + 1.0, "hunch test: the shoulder reached %.1f with the hunch, %.1f without" % [shx[0], shx[1]])
	# the table names every limb and region the key sets use
	var limbs: Dictionary = AnimData.sockets.get("limbs", {})
	var regs: Dictionary = AnimData.sockets.get("regions", {})
	for k in AnimData.keysets:
		var ks = AnimData.keysets[k]
		if typeof(ks) != TYPE_DICTIONARY or not ks.has("limb"):
			continue
		var lb: String = String(ks.get("limb", "hand_r"))
		_expect(limbs.has(lb.get_slice("_", 0)), "hunch test: key set %s names the limb %s, not in sockets.json" % [k, lb])
		_expect(regs.has(String(ks.get("target", "chest"))), "hunch test: key set %s names the region %s, not in sockets.json" % [k, ks.get("target", "chest")])
	print("hunch test: shoulder moved by %s, the reach hunch brought it %.1f units forward, %d limbs and %d regions in the socket table" % [str(moved), float(shx[0]) - float(shx[1]), limbs.size(), regs.size()])


## Per-fighter tuning against the four shape languages (data/anim/shapes.json): the same blow flinches each shape by its own
## amount (the heavy build least, the sweeping build most in the arms and spine), and every shape has an idle entry.
func _test_shapes() -> void:
	var out: Dictionary = {}
	for key in ["P", "A", "E", "C"]:
		AnimRagdoll.shape_of["T_" + key] = key
		var rd := AnimRagdoll.new()
		rd.set_shape("T_" + key)
		rd.hit(1.0, 0.0, 1.0, 1, 0.0, 0.0)
		var sums: Dictionary = {"head": 0.0, "spine": 0.0, "arms": 0.0, "legs": 0.0}
		for i in range(AnimRagdoll.N):
			var bn: String = String(AnimRig.BONES[AnimRagdoll.bone_a[i]][0])
			var grp: String = "legs"
			if bn.begins_with("head") or bn.begins_with("neck"):
				grp = "head"
			elif bn.begins_with("spine") or bn.begins_with("pelvis"):
				grp = "spine"
			elif bn.begins_with("upper_arm") or bn.begins_with("forearm") or bn.begins_with("clavicle"):
				grp = "arms"
			sums[grp] = float(sums[grp]) + absf(rd.om[i])
		out[key] = sums
		_expect(AnimData.shapes.get(key, {}).has("idle") and AnimData.shapes.get(key, {}).has("hit"), "shape test: no idle and hit entry for shape %s" % key)
		AnimRagdoll.shape_of.erase("T_" + key)
	_expect(float(out["C"].head) < float(out["P"].head) and float(out["C"].head) < float(out["A"].head), "shape test: the heavy build's head does not flinch least (%s)" % str(out))
	_expect(float(out["E"].arms) > float(out["A"].arms) and float(out["E"].arms) > float(out["C"].arms), "shape test: the sweeping build's arms do not flinch most (%s)" % str(out))
	print("shape test: head flinch P %.1f A %.1f E %.1f C %.1f, arms P %.1f A %.1f E %.1f C %.1f" % [out.P.head, out.A.head, out.E.head, out.C.head, out.P.arms, out.A.arms, out.E.arms, out.C.arms])


## The entry layer (parked sequences of poses played by an `entry` beat): a phase with ticks holds that long, the last phase is shown at the end,
## and the first at the start.
func _test_entry() -> void:
	AnimData.entries["t.entry"] = {"phases": [{"pose": "stance.aggressive", "ticks": 3}, {"pose": "move.dash"}, {"pose": "move.brake", "ticks": 3}]}
	var ix: Dictionary = AnimRig.index
	var errs: Array = []
	for pair in [[0.0, "stance.aggressive"], [0.5, "move.dash"], [0.9999, "move.brake"]]:
		var af := AnimFighter.new(0)
		var dur: float = 0.4
		af._entry_layer(0.0, dur, "t.entry", float(pair[0]) * dur, 1.0 / 60.0)
		var pz: AnimPose = AnimData.pose(String(pair[1]))
		var worst: float = 0.0
		for bn in ["upper_arm_r", "thigh_l", "spine_2"]:
			worst = maxf(worst, af.q[ix[bn]].angle_to(pz.q[ix[bn]]))
		errs.append(snappedf(worst, 0.001))
		_expect(worst < 0.05, "entry test: at %.2f of the entry the pose is %.3f rad from %s" % [float(pair[0]), worst, String(pair[1])])
	AnimData.entries.erase("t.entry")
	print("entry test: the entry's start, middle and end are %s rad from their poses" % str(errs))


## World's ground-contact events as the sim sends them (spd, n, k, vn, vt, sina, slope, vx, vy, cause, kind, surface, dur): a bounce starts the bounce
## sequence at a weight by its speed and its surface, a launch off a lip or a crest the launch sequence, a tumble's landing holds the brace until the
## tumble ends, a recovery is the tech flip, and the end of the journey lets the brace go.
func _test_ground() -> void:
	var af := AnimFighter.new(0)
	var G: Dictionary = AnimData.ground
	_expect(not G.is_empty() and AnimData.entries.has("gc.bounce") and AnimData.pose_exists("gc.hold.brace_tumble"), "ground test: the ground data or poses are not loaded")
	af.on_ground_event("bounce", {"actor": 0, "n": 1, "k": 1, "vn": -1800.0, "vt": 900.0, "surface": "rock", "sina": 0.7, "slope": 0.1, "spd": 1500.0}, 1.0)
	_expect(String(af._seq.get("id", "")) == "gc.bounce" and float(af._seq.wt) > 0.99, "ground test: a hard bounce on rock did not start gc.bounce at full weight (%s)" % str(af._seq))
	var af2 := AnimFighter.new(0)
	af2.on_ground_event("bounce", {"actor": 0, "n": 1, "k": 1, "vn": -900.0, "vt": 100.0, "surface": "sand", "sina": 0.5, "slope": 0.0, "spd": 900.0}, 1.0)
	_expect(float(af2._seq.wt) < float(af._seq.wt) - 0.2, "ground test: a soft bounce on sand is not lighter than a hard one on rock (%.2f against %.2f)" % [float(af2._seq.wt), float(af._seq.wt)])
	var af3 := AnimFighter.new(0)
	af3.on_ground_event("left_ground", {"actor": 0, "n": 1, "cause": "bounce", "vx": 100.0, "vy": 800.0, "spd": 800.0}, 1.0)
	_expect(af3._seq.is_empty(), "ground test: leaving the ground by a bounce started a launch sequence")
	af3.on_ground_event("left_ground", {"actor": 0, "n": 1, "cause": "lip", "vx": 900.0, "vy": 500.0, "spd": 1800.0, "slope": -0.7}, 2.0)
	_expect(String(af3._seq.get("id", "")) == "gc.lip_launch", "ground test: a launch off a lip did not start gc.lip_launch")
	af3.on_ground_event("land", {"actor": 0, "n": 1, "kind": "tumble", "surface": "soil", "contacts": 2}, 3.0)
	_expect(af3._gc_hold_t0 >= 0.0 and af3._gc_hold_t1 < 0.0, "ground test: a tumble's landing did not hold the brace")
	af3.on_ground_event("tumble_end", {"actor": 0, "n": 1, "kind": "recover", "contacts": 2}, 4.0)
	_expect(af3._gc_hold_t1 >= 0.0 and String(af3._seq.get("id", "")) == "gc.tech_flip", "ground test: a recovery did not release the brace and flip")
	var af5 := AnimFighter.new(0)
	af5.on_ground_event("land", {"actor": 0, "kind": "tumble", "surface": "soil", "spd": 250.0}, 1.0)
	var firm_w: float = af5._gc_hold_w
	var af6 := AnimFighter.new(0)
	af6.on_ground_event("land", {"actor": 0, "kind": "tumble", "surface": "soil", "spd": 1800.0}, 1.0)
	var loose_w: float = af6._gc_hold_w
	var af7 := AnimFighter.new(0)
	af7._worn = 1.0
	af7.on_ground_event("land", {"actor": 0, "kind": "tumble", "surface": "soil", "spd": 250.0}, 1.0)
	_expect(firm_w > loose_w + 0.2 and af7._gc_hold_w < firm_w - 0.15 and loose_w < 0.5 and firm_w <= 0.85, "ground test: the brace is not firmer when slow and looser when fast or worn (%.2f slow, %.2f fast, %.2f slow and worn)" % [firm_w, loose_w, af7._gc_hold_w])
	var af4 := AnimFighter.new(0)
	af4.on_ground_event("land", {"actor": 0, "kind": "tumble", "surface": "soil"}, 1.0)
	af4.on_ground_event("journey_end", {"actor": 0, "kind": "stop"}, 2.0)
	_expect(af4._gc_hold_t1 >= 0.0, "ground test: the end of the journey left the brace held")
	print("ground test: bounce weights %.2f (rock, hard) and %.2f (sand, soft), the lip launch, the tumble brace (%.2f slow, %.2f fast, %.2f slow and worn) and its release, the tech flip" % [float(af._seq.wt), float(af2._seq.wt), firm_w, loose_w, af7._gc_hold_w])


## The opening (docs/architecture/intro-phase.md): the sim's events on the sim's tick (the match clock is frozen) drive the pose: the fall until the landing, the
## landing sequence, the staredown set and its tension near the clock, reduced motion standing from the start, and clock_start handing the body back.
func _test_intro() -> void:
	AnimData.load_all()
	if AnimData.intro.is_empty() or not AnimData.entries.has("in.land"):
		_expect(false, "intro test: the opening's data is not loaded")
		return
	main.start_match(4, {"p1": false, "p2": false})
	var S: SimState = main.host.S
	var f = S.fighters[0]
	f.state = "intro"
	var ix: Dictionary = AnimRig.index
	var af := AnimFighter.new(0)
	var evs: Array = []
	for spec in [["intro_start", 0, 0.0], ["entrance_fall", 0, 0.6], ["entrance_land", 36, 0.0], ["staredown_start", 144, 2.6]]:
		var e := SimState.FxEvent.new()
		e.type = String(spec[0])
		e.tick = int(spec[1])
		e.dur = float(spec[2])
		evs.append(e)
		af.on_intro(e.type, float(e.tick) / 60.0, e.dur, "")
	_expect(not af._intro.is_empty() and float(af._intro.land_t) > 0.0, "intro test: the events did not set the opening")
	var errs: Array = []
	for pair in [[20, "in.hold.fall"], [200, "in.hold.set"]]:
		af.q = AnimPose.identity_q()
		S.tick = int(pair[0])
		af._intro_layer(S, f)
		var pz: AnimPose = AnimData.pose(String(pair[1]))
		var worst: float = 0.0
		for bn in ["spine_2", "upper_arm_r", "thigh_l"]:
			worst = maxf(worst, af.q[ix[bn]].angle_to(pz.q[ix[bn]]))
		errs.append(snappedf(worst, 0.001))
		_expect(worst < 0.4, "intro test: at tick %d the pose is %.2f rad from %s" % [int(pair[0]), worst, String(pair[1])])
	# the tension near the clock is the tense pose, and reduced motion stands from the start
	af.q = AnimPose.identity_q()
	S.tick = 285
	af._intro_layer(S, f)
	var tp: AnimPose = AnimData.pose("in.hold.tense")
	_expect(af.q[ix["spine_2"]].angle_to(tp.q[ix["spine_2"]]) < 0.15, "intro test: the pose near the clock is not the tension")
	RenderAnim.reduced_motion = true
	af.q = AnimPose.identity_q()
	S.tick = 20
	af._intro_layer(S, f)
	var sp: AnimPose = AnimData.pose("in.hold.set")
	_expect(af.q[ix["spine_2"]].angle_to(sp.q[ix["spine_2"]]) < 0.05, "intro test: reduced motion did not stand while falling")
	RenderAnim.reduced_motion = false
	af.on_intro("clock_start", 5.0, 0.0, "full")
	_expect(af._intro.is_empty(), "intro test: clock_start did not hand the body back")
	f.state = "free"
	print("intro test: the fall, the set and the tension are %s rad from their poses; reduced motion stands; the clock ends it" % str(errs))


## The opening through the sim's own state and events (a match started with the setup's "intro": true): the mannequin follows the fall, the landing and the
## staredown, the tension is in before the clock, and the clock hands the body back; the gameplay hash is compared in the main loop.
func _test_intro_real() -> void:
	RenderAnim.enabled = true
	main.start_match(4, {"p1": false, "p2": false}, {"intro": true})
	var S: SimState = main.host.S
	var ix: Dictionary = AnimRig.index
	# the very first frame, before the first tick's events: both fighters are in the fall pose, not standing
	for j0 in range(2):
		var af0: AnimFighter = RenderAnim.solve(S, S.fighters[j0])
		var pz0: AnimPose = AnimData.pose("in.hold.fall")
		var w0: float = 0.0
		for bn0 in ["spine_2", "upper_arm_r", "thigh_l"]:
			w0 = maxf(w0, af0.q[ix[bn0]].angle_to(pz0.q[ix[bn0]]))
		_expect(S.fighters[j0].state == "intro" and w0 < 0.5, "intro real test: on the first frame fighter %d is %s and %.2f rad from the fall pose" % [j0, S.fighters[j0].state, w0])
	var checks: Array = [[20, 0, "in.hold.fall"], [110, 0, "in.hold.set"], [60, 1, "in.hold.fall"], [270, 0, "in.hold.tense"], [270, 1, "in.hold.tense"]]
	var results: Array = []
	var ci: int = 0
	while main.host.ticks < 300 and ci < checks.size():
		main.frame(DT)
		var ck: Array = checks[ci]
		if S.tick >= int(ck[0]):
			var f = S.fighters[int(ck[1])]
			var af: AnimFighter = RenderAnim.solve(S, f)
			af.socket("foot_l")
			var pz: AnimPose = AnimData.pose(String(ck[2]))
			var worst: float = 0.0
			for bn in ["spine_2", "upper_arm_r", "thigh_l"]:
				worst = maxf(worst, af.q[ix[bn]].angle_to(pz.q[ix[bn]]))
			results.append(snappedf(worst, 0.01))
			_expect(f.state == "intro" and worst < 0.5, "intro real test: at tick %d fighter %d is %s and %.2f rad from %s" % [int(ck[0]), int(ck[1]), f.state, worst, String(ck[2])])
			ci += 1
	_expect(ci == checks.size(), "intro real test: the opening did not reach all its checks (%d of %d)" % [ci, checks.size()])
	for i in range(40):
		main.frame(DT)
	_expect(S.fighters[0].state == "free" and S.fighters[1].state == "free", "intro real test: the fighters are not free after the clock")
	_expect(RenderAnim.fighter(S, S.fighters[0])._intro.is_empty(), "intro real test: the clock did not end the opening in the animator")
	print("intro real test: the animator follows the sim's own opening: %s rad from the fall, set, fall, tension, tension poses" % str(results))


## The last stand's body cue (docs/architecture/last-stand.md): ready starts the steadying beat of his shape and the held resolve, `expired` slumps him, `used`
## only lets the resolve go; reduced motion plays it at 60%.
func _test_last_stand() -> void:
	AnimData.load_all()
	_expect(not AnimData.last_stand.is_empty() and AnimData.entries.has("ls.ready_a") and AnimData.pose_exists("ls.hold.resolve"), "last stand test: the data or poses are not loaded")
	var got: Array = []
	for pair in [["KAI", "ls.ready_p"], ["VORR", "ls.ready_a"]]:
		var af := AnimFighter.new(0)
		af._rd.set_shape(String(pair[0]))
		af.on_last_stand("last_stand_ready", 5.0, 20.0, "")
		got.append(String(af._seq.get("id", "")))
		_expect(String(af._seq.get("id", "")) == String(pair[1]) and af._ls_t0 == 5.0, "last stand test: %s plays %s, not %s" % [String(pair[0]), String(af._seq.get("id", "")), String(pair[1])])
		af.on_last_stand("last_stand_end", 9.0, 0.0, "used")
		_expect(af._ls_t1 == 9.0 and String(af._seq.get("id", "")) == String(pair[1]), "last stand test: a used window slumped him or kept the resolve held")
	var ex := AnimFighter.new(0)
	ex.on_last_stand("last_stand_ready", 5.0, 20.0, "")
	ex.on_last_stand("last_stand_end", 25.0, 0.0, "expired")
	_expect(String(ex._seq.get("id", "")) == "ls.slump", "last stand test: an expired window did not slump")
	RenderAnim.reduced_motion = true
	var rd := AnimFighter.new(0)
	rd.on_last_stand("last_stand_ready", 5.0, 20.0, "")
	_expect(float(rd._seq.wt) < 0.7, "last stand test: reduced motion does not soften the beat")
	RenderAnim.reduced_motion = false
	print("last stand test: %s for the two shapes in play, the slump on expiry, reduced motion softer" % str(got))


func _run() -> void:
	await process_frame
	_scan_writes()
	AnimData.load_all()
	_test_beats()
	_test_form()
	_test_hunch()
	_test_shapes()
	_test_entry()
	_test_ground()
	_test_intro()
	_test_intro_real()
	_test_last_stand()
	RenderAnim.debug_checks = true
	for seed in seeds:
		var hashes: Dictionary = {}
		for mode in ["off", "mix", "snappy", "fluid"]:
			RenderAnim.enabled = mode != "off"
			RenderAnim.style_override = mode if (mode == "snappy" or mode == "fluid") else ""
			RenderAnim.solve_usec = 0
			RenderAnim.solve_count = 0
			main.start_match(seed, {"p1": true, "p2": true})
			var S: SimState = main.host.S
			while main.host.ticks < max_ticks and not (S.game.ko != null and S.game.koT > 3.0):
				main.frame(DT)
			hashes[mode] = str(SimHash.stateHash(S).gameplay)
			if mode == "off":
				continue
			var frames := 0
			var cerr := 0.0
			var parts := 0
			var nan := 0
			var ikf := 0
			var gmax := 0.0
			var gsum := 0.0
			var gn := 0
			var flips := 0
			var gl: Array = []
			var far := 0
			var blows := 0
			var rdt := 0
			var rdu := 0
			var catches := 0
			var vars: Dictionary = {}
			var ksets: Dictionary = {}
			var s3n: int = 0
			var lsn: int = 0
			var late := 0
			for id in RenderAnim._fighters:
				var d: Dictionary = RenderAnim._fighters[id].debug
				frames += int(d.contact_frames)
				cerr = maxf(cerr, float(d.contact_err_max))
				parts += int(d.parts)
				nan += int(d.nan)
				ikf += int(d.ik_frames)
				gmax = maxf(gmax, float(d.gap_max))
				gsum += float(d.gap_sum)
				gn += int(d.gap_n)
				flips += int(d.face_flips)
				blows += int(d.blows)
				rdt += int(d.rd_ticks)
				rdu += int(d.rd_usec)
				catches += int(d.catches)
				s3n += int(d.get("step3", 0))
				lsn += int(d.get("last_stand", 0))
				for kk in d.get("keysets", {}):
					ksets[kk] = int(ksets.get(kk, 0)) + int(d.keysets[kk])
				for vk in d.variants:
					vars[vk] = int(vars.get(vk, 0)) + int(d.variants[vk])
				late += int(d.late)
				if mode == "mix":
					for ln in d.late_notes:
						print("    late: seed %d %s" % [seed, ln])
				for gi in range(0, d.gaps.size(), 2):
					if float(d.gaps[gi + 1]) <= 0.0:
						gl.append(float(d.gaps[gi]))
					else:
						far += 1
				if mode == "mix":
					for nt in d.notes:
						print("    short: seed %d %s" % [seed, nt])
			_expect(nan == 0, "seed %d %s: %d NaN rotations" % [seed, mode, nan])
			_expect(frames > 0, "seed %d %s: no blow reached its contact frame (%d part frames)" % [seed, mode, parts])
			_expect(cerr < 0.02, "seed %d %s: the pose on a contact frame is %.4f rad from the contact key" % [seed, mode, cerr])
			gl.sort()
			var gworst: float = gl.back() if gl.size() > 0 else 0.0
			_expect(ikf > 0 and gl.size() > 0, "seed %d %s: the contact solve never ran (%d IK frames, %d reachable contacts)" % [seed, mode, ikf, gl.size()])
			_expect(gworst < 1.0, "seed %d %s: a blow within reach ends %.2f units short of the defender" % [seed, mode, gworst])
			report.runs.append({"seed": seed, "mode": mode, "contact_err_max": cerr, "contact_gap_worst": gworst, "contacts_within_reach": gl.size(), "contacts_beyond_reach": far, "solve_us": float(RenderAnim.solve_usec) / maxf(1.0, RenderAnim.solve_count), "late_blows": late, "blows": blows, "catches": catches})
			print("  contact solve: %d IK frames, %d contacts within reach (worst gap %.2f units), %d beyond reach (the sim put the fighters farther apart than the arm, lunge and step-in reach), %d facing flips" % [ikf, gl.size(), gworst, far, flips])
			print("  base variants played: %s" % [vars])
			if mode == "mix":
				print("  key sets played: %s" % [ksets])
				if RenderAnim.step3_cues:
					print("  step 3 cue sequences played: %d, last stand cues: %d" % [s3n, lsn])
			print("  ragdoll step: %.1f us a tick a fighter (%d ticks), %d contact catches smeared" % [float(rdu) / maxf(1.0, rdt), rdt, catches])
			print("  blows: %d, announced under 4 ticks ahead (no wind-up possible): %d" % [blows, late])
			print("seed %d %s: %d ticks, %d part frames, %d contact frames, worst contact error %.5f rad, solve %.1f us each (%d solves), hash %s" % [seed, mode, main.host.ticks, parts, frames, cerr, float(RenderAnim.solve_usec) / maxf(1.0, RenderAnim.solve_count), RenderAnim.solve_count, hashes[mode]])
		_expect(hashes["off"] == hashes["snappy"] and hashes["off"] == hashes["fluid"] and hashes["off"] == hashes["mix"], "seed %d: the gameplay hash differs with the mannequin (off %s, mix %s, snappy %s, fluid %s)" % [seed, hashes["off"], hashes["mix"], hashes["snappy"], hashes["fluid"]])
	await _test_wounds()
	_test_heavy_arm()
	await _test_ragdoll()
	_test_slope()
	_test_hits()
	_test_weight_aim()
	_test_defender()
	_test_personality()
	_test_flight()
	_test_quality()
	_test_win_ko()
	_test_agency()
	_test_joints()
	RenderAnim.enabled = true
	RenderAnim.style_override = ""
	RenderAnim.debug_checks = false
	print("Anim check  %d checks" % checks)
	if report_out != "":
		report["checks"] = checks
		report["failures"] = fails
		var rf := FileAccess.open(report_out, FileAccess.WRITE)
		rf.store_string(JSON.stringify(report))
		rf.close()
	if fails.is_empty():
		print("\nanim check passed")
	else:
		for f in fails.slice(0, 20):
			print("FAIL  " + f)
		print("\nanim check FAILED (%d)" % fails.size())
	quit(0 if fails.is_empty() else 1)
