extends SceneTree
## Joint-limit scan over seeded AI matches (A2, docs/animation/pose-pipeline.md section 9.3). Steps real matches with the
## mannequin on and reads each solved pose (AnimFighter.q), counting the frames a limb leaves human range:
##   elbow hyperextension (forearm bent the wrong way, more than 3 degrees), knee hyperextension, a joint bent sideways
##   (off the hinge plane), and an upper arm pointing straight back along the body (within 21 degrees of the backward axis).
## With the limb pass on every count must be zero; the numbers before it are the A2 evidence.
##   godot --headless --path . --script res://render/anim/tools/limb_scan.gd [-- --seeds=4,12345,7,99 --ticks=3000 --style=snappy]

const DT := 1.0 / 60.0

var seeds: Array = [4, 12345, 7, 99]
var max_ticks: int = 3000
var style: String = ""
var nolimit: bool = false
var json_out: String = ""
var main: Node


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seeds="):
			seeds = Array(a.substr(8).split(",")).map(func(s): return int(s))
		elif a.begins_with("--ticks="):
			max_ticks = int(a.substr(8))
		elif a.begins_with("--json="):
			json_out = a.substr(7)
		elif a == "--nolimit":
			nolimit = true
		elif a.begins_with("--style="):
			style = a.substr(8)
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
	RenderAnim.style_override = style
	AnimPose.limits_on = not nolimit
	var ix: Dictionary = AnimRig.index
	var counts: Dictionary = {}
	var worst: Dictionary = {}
	var examples: Array = []
	var frames := 0
	for seed in seeds:
		main.start_match(seed, {"p1": true, "p2": true})
		var S: SimState = main.host.S
		while main.host.ticks < max_ticks and not (S.game.ko != null and S.game.koT > 3.0):
			main.frame(DT)
			for f in S.fighters:
				var af: AnimFighter = RenderAnim.fighter(S, f)
				if af.version == 0:
					continue
				frames += 1
				for s in ["l", "r"]:
					var v: Vector3 = af.q[ix["forearm_" + s]] * Vector3(0, -1, 0)
					var th: float = rad_to_deg(atan2(v.x, -v.y))
					_count("elbow hyperextension", th < -3.0, th, seed, S, f, af, counts, worst, examples)
					_count("elbow sideways", absf(v.z) > 0.35, v.z, seed, S, f, af, counts, worst, examples)
					v = af.q[ix["shin_" + s]] * Vector3(0, -1, 0)
					th = rad_to_deg(atan2(v.x, -v.y))
					_count("knee hyperextension", th > 3.0, th, seed, S, f, af, counts, worst, examples)
					_count("knee sideways", absf(v.z) > 0.35, v.z, seed, S, f, af, counts, worst, examples)
					v = af.q[ix["upper_arm_" + s]] * Vector3(0, -1, 0)
					_count("arm straight back", v.x < -0.93, v.x, seed, S, f, af, counts, worst, examples)
		print("seed %d done (%d frames so far)" % [seed, frames])
	print("\nframes scanned (fighter-frames): %d, style %s" % [frames, style if style != "" else "default"])
	for k in ["elbow hyperextension", "elbow sideways", "knee hyperextension", "knee sideways", "arm straight back"]:
		print("  %-22s %6d frames, worst %.1f" % [k, int(counts.get(k, 0)), float(worst.get(k, 0.0))])
	for e in examples.slice(0, 16):
		print("  " + e)
	if json_out != "":
		var jf := FileAccess.open(json_out, FileAccess.WRITE)
		jf.store_string(JSON.stringify({"tool": "limb_scan", "frames": frames, "counts": counts, "worst": worst, "examples": examples.slice(0, 16)}))
		jf.close()
	quit(0)


func _count(key: String, bad: bool, val: float, seed: int, S: SimState, f, af: AnimFighter, counts: Dictionary, worst: Dictionary, examples: Array) -> void:
	if not bad:
		return
	counts[key] = int(counts.get(key, 0)) + 1
	if absf(val) > absf(float(worst.get(key, 0.0))):
		worst[key] = val
		if examples.size() < 64:
			examples.append("%s %.1f: seed %d tick %d fighter %d part '%s' state %s" % [key, val, seed, S.tick, S.fighters.find(f), af._part, f.state])
