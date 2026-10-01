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
var fails: Array = []
var checks: int = 0


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seeds="):
			seeds = Array(a.substr(8).split(",")).map(func(s): return int(s))
		elif a.begins_with("--ticks="):
			max_ticks = int(a.substr(8))
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
	]
	# [role, cancel, time, the pose that must come, true if it must come]
	var cases: Array = [
		["D", false, 0.25, "def.parry_ready", true], ["A", false, 0.25, "def.parry_ready", false],
		["D", true, 0.34, "def.parry", true], ["A", true, 0.34, "react.rebuff", true],
		["D", false, 1.1, "def.slip", true], ["A", false, 1.1, "def.slip", false],
		["D", false, 1.6, "def.blink_in", true], ["A", false, 1.6, "def.blink_in", false],
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


func _run() -> void:
	await process_frame
	_scan_writes()
	AnimData.load_all()
	_test_beats()
	_test_form()
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
			var vars: Dictionary = {}
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
			print("  contact solve: %d IK frames, %d contacts within reach (worst gap %.2f units), %d beyond reach (the sim put the fighters farther apart than the arm, lunge and step-in reach), %d facing flips" % [ikf, gl.size(), gworst, far, flips])
			print("  base variants played: %s" % [vars])
			print("  blows: %d, announced under 4 ticks ahead (no wind-up possible): %d" % [blows, late])
			print("seed %d %s: %d ticks, %d part frames, %d contact frames, worst contact error %.5f rad, solve %.1f us each (%d solves), hash %s" % [seed, mode, main.host.ticks, parts, frames, cerr, float(RenderAnim.solve_usec) / maxf(1.0, RenderAnim.solve_count), RenderAnim.solve_count, hashes[mode]])
		_expect(hashes["off"] == hashes["snappy"] and hashes["off"] == hashes["fluid"] and hashes["off"] == hashes["mix"], "seed %d: the gameplay hash differs with the mannequin (off %s, mix %s, snappy %s, fluid %s)" % [seed, hashes["off"], hashes["mix"], hashes["snappy"], hashes["fluid"]])
	RenderAnim.enabled = true
	RenderAnim.style_override = ""
	RenderAnim.debug_checks = false
	print("Anim check  %d checks" % checks)
	if fails.is_empty():
		print("\nanim check passed")
	else:
		for f in fails.slice(0, 20):
			print("FAIL  " + f)
		print("\nanim check FAILED (%d)" % fails.size())
	quit(0 if fails.is_empty() else 1)
