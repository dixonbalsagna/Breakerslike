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


func _run() -> void:
	await process_frame
	_scan_writes()
	AnimData.load_all()
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
