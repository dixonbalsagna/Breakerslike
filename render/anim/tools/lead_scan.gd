extends SceneTree
## Feet-first lint (GB-006, docs/animation/pose-pipeline.md 9.23): a fighter moving fast through the air or along the ground must have his head (or his
## leading shoulder) leading, never his feet, unless he was hit and is tumbling. Seeded AI matches, every fighter-frame of the finished solve; the body's axis
## (pelvis to head centre: the spine's line) is turned the way the pivot turns it on screen (the sim's f.rot, the facing mirror) and set against the velocity.
##   a frame is "feet first" when his speed is over --speed (default 500 units/s) and the axis points against the velocity (axis . velocity < -cos 50 deg:
##   the feet on the leading side), and he is not falling steeply (a landing, upright, is natural) and not tumbling: a launched fighter whose |spin| is over --tumble (default 3 rad/s) is in a tumble and is allowed.
##   godot --headless --path . -s res://render/anim/tools/lead_scan.gd -- [--seeds=4,12345,7,99,5,6,8,9] [--ticks=3000] [--speed=500] [--tumble=3]
##       [--json=out.json] [--strict [--max=N]] [--examples=14]
## Exit 1 with --strict when more than N frames (default 0) are feet first. The shipped budget is --max=40: the first two or three frames of a knockback, before the
## stand-up has caught the shove (docs 9.23).

const DT := 1.0 / 60.0
const COS_LIMIT := -0.64   # cos 130 deg: the body axis within 50 degrees of the line opposite the velocity

var seeds: Array = [4, 12345, 7, 99, 5, 6, 8, 9]
var max_ticks: int = 3000
var speed_min: float = 500.0
var tumble_min: float = 3.0
var strict: bool = false
var max_bad: int = 0
var json_out: String = ""
var n_examples: int = 14
var main: Node


func _initialize() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seeds="):
			seeds = Array(a.substr(8).split(",")).map(func(s): return int(s))
		elif a.begins_with("--ticks="):
			max_ticks = int(a.substr(8))
		elif a.begins_with("--speed="):
			speed_min = float(a.substr(8))
		elif a.begins_with("--tumble="):
			tumble_min = float(a.substr(9))
		elif a.begins_with("--json="):
			json_out = a.substr(7)
		elif a.begins_with("--examples="):
			n_examples = int(a.substr(11))
		elif a.begins_with("--max="):
			max_bad = int(a.substr(6))
		elif a == "--strict":
			strict = true
	DirData.templatesProfile = "dynamic"
	var vpn := SubViewport.new()
	vpn.size = Vector2i(640, 360)
	root.add_child(vpn)
	main = load("res://render/main.tscn").instantiate()
	main.manual = true
	vpn.add_child(main)
	_run.call_deferred()


## The body's axis on screen, pelvis to head, as the pivot draws it: model space (x ahead, y up), mirrored by the facing, turned by -f.rot.
static func axis_of(af: AnimFighter, f) -> Vector2:
	var head: Vector3 = af.head_center()
	var feet: Vector3 = af.socket("pelvis")   # the spine's line, pelvis to head: a kicking leg does not turn it
	var d := Vector2((head.x - feet.x) * af.vface, head.y - feet.y)
	var c: float = cos(-f.rot)
	var s: float = sin(-f.rot)
	return Vector2(d.x * c - d.y * s, d.x * s + d.y * c)


func _run() -> void:
	await process_frame
	AnimRig.setup()
	RenderAnim.enabled = true
	var frames := 0
	var fast := 0
	var bad := 0
	var allowed := 0
	var by_key: Dictionary = {}
	var examples: Array = []
	var prev: Dictionary = {}
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
				# the velocity is measured from where he was a tick ago (a rush moves a fighter by position and leaves f.vx as it was; a hit-stop moves nobody)
				var pk: int = S.fighters.find(f) + 2 * seeds.find(seed)
				var v := Vector2.ZERO
				if prev.has(pk) and int(prev[pk][2]) == S.tick - 1:
					v = Vector2(SimWrap.sdx(float(prev[pk][0]), f.x), f.y - float(prev[pk][1])) / DT
				prev[pk] = [f.x, f.y, S.tick]
				var sp: float = v.length()
				if sp < speed_min:
					continue
				fast += 1
				var ax: Vector2 = axis_of(af, f).normalized()
				var lead: float = ax.dot(v / sp)
				if lead > COS_LIMIT:
					continue
				if v.y < 0.0 and absf(v.y) > 1.2 * absf(v.x):
					continue   # a steep fall feet first is a landing, upright: not laid out along the flight line
				if not (f.state == "launched" and f.slide <= 0.0) and absf(ax.y) > 0.64:
					continue   # on his feet or driven back in an exchange and tilted under 50 degrees from upright: leaning, not laid out
				var tumbling: bool = f.state == "launched" and absf(f.spin) > tumble_min
				if tumbling:
					allowed += 1
					continue
				bad += 1
				var key: String = "%s%s / %s / %s" % [f.state, " (slide)" if f.slide > 0.0 else "", af._part if af._part != "" else "-", String(af._seq.get("id", "-"))]
				by_key[key] = int(by_key.get(key, 0)) + 1
				if examples.size() < n_examples:
					examples.append("seed %d tick %d fighter %d: %s speed %.0f v (%.0f, %.0f) sim v (%.0f, %.0f) rot %.0f deg spin %.1f face %.0f (sim %.0f) axis (%.2f, %.2f) axis.vel %.2f lead w %.2f d %.0f phi %.0f hold '%s' ag %s toward-rival %.0f" % [seed, S.tick, S.fighters.find(f), key, sp, v.x, v.y, f.vx, f.vy, rad_to_deg(f.rot), f.spin, af.vface, f.face, ax.x, ax.y, lead, float(af.debug.get("lead_w", 0.0)), rad_to_deg(float(af.debug.get("lead_d", 0.0))), rad_to_deg(float(af.debug.get("lead_phi", 0.0))), af._ag_hold, (af._ag_kind if af._ag_t0 >= 0.0 else "-"), signf(SimWrap.sdx(f.x, S.fighters[1 - S.fighters.find(f)].x))])
		print("seed %d done" % seed)
	print("\n== feet first (speed over %.0f, not a tumble over %.1f rad/s) ==" % [speed_min, tumble_min])
	print("fighter-frames %d, fast %d, feet leading in a tumble (allowed) %d, feet leading and not a tumble %d" % [frames, fast, allowed, bad])
	var keys: Array = by_key.keys()
	keys.sort_custom(func(a, b): return by_key[a] > by_key[b])
	for k in keys:
		print("  %5d  %s" % [by_key[k], k])
	for e in examples:
		print("  e.g. " + e)
	if json_out != "":
		var jf := FileAccess.open(json_out, FileAccess.WRITE)
		jf.store_string(JSON.stringify({"tool": "lead_scan", "frames": frames, "fast": fast, "allowed": allowed, "bad": bad, "by_key": by_key, "examples": examples}, "  "))
		jf.close()
	quit(1 if (strict and bad > max_bad) else 0)
