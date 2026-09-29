extends SceneTree
## Engine spike (throwaway, research only). The checks of shared/test-ref.mjs, in GDScript, headless:
##   Godot_v4.7.2-stable_win64_console.exe --headless --path research/engine-spike/godot -s res://tests/run_tests.gd
##   ... -s res://tests/run_tests.gd -- --bench        also time the sim (SIMBENCH line)
##   ... -s res://tests/run_tests.gd -- --golden <abs path>   read golden.json from there (exported builds)
##   ... -s res://tests/run_tests.gd -- --dump <scene|flight-input> <tick>
##                                                     print the state vector (index, value, float64 hex) at a tick,
##                                                     to diff element by element against the Node reference
## Prints the same PASS/FAIL lines as test-ref.mjs (the goldens, then the 6 camera tests) and quits with exit
## code 0 when everything passes, 1 otherwise. Never writes golden.json: the Node reference owns it.
##
## Every dependency is preloaded, so this runs even when the project's global class cache is stale.

const _Wrap = preload("res://sim/wrap.gd")
const _Terrain = preload("res://sim/terrain.gd")
const _Fighter = preload("res://sim/fighter.gd")
const _Scenes = preload("res://sim/scenes.gd")
const _Hash = preload("res://sim/state_hash.gd")
const _Camera = preload("res://view/camera.gd")
const _Simbench = preload("res://tests/simbench.gd")

const CHECKPOINT_NAMES: Array[String] = ["worst", "flight", "flight-input"]
const CHECKPOINTS: Dictionary = {
	"worst": [600, 1980, 3600],
	"flight": [600, 1800, 3600],
	"flight-input": [600, 1800, 3600],   # replay test: box a is flown by a scripted input stream
}
const CAMERA_SCENES: Array[String] = ["sweep", "chase", "orbit", "climb", "flight", "worst"]
const CAMERA_TICKS: int = 3600
const JUMP: float = 0.05
const OFFSETS: Array[float] = [0.5, 1234.5, 4800.0, 9600.0 - 0.25, 7777.77]   # HALF and W - 0.25 as in the JS


## Input stream for the replay golden: called before every step with the tick about to run.
static func scripted_input(n: int) -> PackedFloat64Array:
	return PackedFloat64Array([_Wrap.tri(n, 240) * 2.0 - 1.0, _Wrap.tri(n + 50, 150) * 2.0 - 1.0])


static func sha(v: PackedFloat64Array) -> String:
	return _Hash.sha256_hex(v)


# ------------------------------------------------------------------ number formatting like JS JSON.stringify
## JS Number.prototype.toString (shortest round-trip digits; fixed for 1e-6 <= |v| < 1e21, else exponent).
## String.num_scientific() in Godot 4.7 gives round-trip digits, but NOT always the shortest (seen: 17 digits for
## -30.62496082389662, which JS prints with 16) and C-style layout ("1e-06"). So only its digits and exponent are
## used, and _shortest() trims them. str() and JSON.stringify() keep 14 digits: never use them for this.
static func js_num(v: float) -> String:
	if is_nan(v) or is_inf(v):
		return "null"   # what JSON.stringify prints for NaN and Infinity
	if v == 0.0:
		return "0"
	var neg: bool = v < 0.0
	var s: String = String.num_scientific(absf(v))
	var mant: String = s
	var e10: int = 0
	var epos: int = s.find("e")
	if epos >= 0:
		mant = s.substr(0, epos)
		var es: String = s.substr(epos + 1)
		var eneg: bool = es.begins_with("-")
		es = es.trim_prefix("+").trim_prefix("-")
		e10 = es.to_int() * (-1 if eneg else 1)
	var dot: int = mant.find(".")
	var ip: String = mant if dot < 0 else mant.substr(0, dot)
	var fp: String = "" if dot < 0 else mant.substr(dot + 1)
	var digits: String = ip + fp
	var n: int = ip.length() + e10   # value = 0.<digits> * 10^n
	while digits.length() > 1 and digits.begins_with("0"):
		digits = digits.substr(1)
		n -= 1
	while digits.length() > 1 and digits.ends_with("0"):
		digits = digits.substr(0, digits.length() - 1)
	var sh: Array = _shortest(digits, n, absf(v))
	digits = sh[0]
	n = sh[1]
	var k: int = digits.length()
	var out: String
	if k <= n and n <= 21:
		out = digits + "0".repeat(n - k)
	elif 0 < n and n <= 21:
		out = digits.substr(0, n) + "." + digits.substr(n)
	elif -6 < n and n <= 0:
		out = "0." + "0".repeat(-n) + digits
	else:
		var e: int = n - 1
		var ex: String = ("+" if e >= 0 else "-") + str(absi(e))
		out = (digits if k == 1 else digits.substr(0, 1) + "." + digits.substr(1)) + "e" + ex
	return ("-" if neg else "") + out


## Shortest digit string that still parses back to `target` (value = 0.<digits> * 10^n). Tries 1, 2, ... digits,
## each rounded half-up from the round-trip digits, and keeps the first that round-trips. Returns [digits, n].
## The round-trip check cannot use String.to_float(): in 4.7 it is not correctly rounded (it parses
## "7.88258347483861e-15" to the double JS prints as 7.882583474838611e-15). _exact_value() is used instead.
static func _shortest(digits: String, n: int, target: float) -> Array:
	for k in range(1, digits.length()):
		var d: PackedByteArray = digits.substr(0, k).to_ascii_buffer()
		var nn: int = n
		if digits.unicode_at(k) >= 53:   # next digit >= '5': round up, carrying
			var j: int = k - 1
			while j >= 0 and d[j] == 57:   # '9'
				d[j] = 48
				j -= 1
			if j < 0:
				d.insert(0, 49)   # 99.. -> 100..
				d.resize(k)
				nn += 1
			else:
				d[j] += 1
		var cand: String = d.get_string_from_ascii()
		while cand.length() > 1 and cand.ends_with("0"):
			cand = cand.substr(0, cand.length() - 1)
		if _exact_value(cand, nn) == target:
			return [cand, nn]
	return [digits, n]


## 0.<cand> * 10^nn as a correctly rounded double, or NAN when that cannot be guaranteed. An integer below 2^53
## times or divided by an exact power of ten (up to 1e22) is a single IEEE operation, so it rounds correctly.
## Outside that range the caller keeps the num_scientific() digits (round-trip, at most one digit longer than JS).
static func _exact_value(cand: String, nn: int) -> float:
	var e: int = nn - cand.length()
	if cand.length() > 16 or e < -22:
		return NAN
	var dint: int = cand.to_int()
	while e > 22 and dint < 9007199254740992:   # extended fast path: move the extra powers of ten into the integer
		dint *= 10
		e -= 1
	if dint >= 9007199254740992 or e > 22:
		return NAN
	var p: float = 1.0
	for i in absi(e):
		p *= 10.0
	return float(dint) * p if e >= 0 else float(dint) / p


## JS +v.toFixed(d), printed as a number. String.num(v, d) is printf("%.*f") with the trailing zeros stripped;
## the short result parses back exactly.
static func js_fixed(v: float, d: int) -> String:
	return js_num(String.num(v, d).to_float())


# ------------------------------------------------------------------ golden hashes
func goldens() -> Dictionary:
	var out: Dictionary = {}
	out["terrainBase"] = sha(_Hash.base_vector(_Terrain.new(_Terrain.TERRAIN_SEED)))
	for name in CHECKPOINT_NAMES:
		var input: bool = name == "flight-input"
		var s: _Scenes.Scene = _Scenes.make_scene("flight" if input else name)
		var rec: Dictionary = {}
		var t: int = 0
		for tk in CHECKPOINTS[name]:
			while t < tk:
				if input:
					var inp: PackedFloat64Array = scripted_input(t + 1)
					s.set_input(inp[0], inp[1])
				s.step()
				t += 1
			rec[str(tk)] = sha(_Hash.state_vector(s))
		out[name] = rec
	var cams: Dictionary = {}
	for name in CAMERA_SCENES:
		var s: _Scenes.Scene = _Scenes.make_scene(name)
		var cam := _Camera.new()
		cam.reset(s.a, s.b)
		for i in CAMERA_TICKS:
			s.step()
			cam.step(s.a, s.b)
		cams[name] = {"ticks": CAMERA_TICKS, "hash": sha(_Hash.camera_vector(cam)), "flips": cam.flips}
	out["camera"] = cams
	return out


# ------------------------------------------------------------------ camera seam tests
# For every scripted scene: (1) both boxes stay in frame except while the camera pans through an arc flip;
# (2) no box jumps on screen by more than JUMP of the screen width in one tick; (3) shifting the whole scene by any
# offset (so the seam sits somewhere else) changes nothing on screen: the seam is invisible.
func camera_test(name: String, ticks: int = CAMERA_TICKS) -> Dictionary:
	var s: _Scenes.Scene = _Scenes.make_scene(name)
	var cams: Array[_Camera] = [_Camera.new()]
	var sa: Array[_Fighter] = []   # the shifted copies of a and b, one pair per offset (reused, not reallocated)
	var sb: Array[_Fighter] = []
	for off in OFFSETS:
		cams.append(_Camera.new())
		sa.append(_Fighter.new())
		sb.append(_Fighter.new())
	var nof: int = OFFSETS.size()

	# shifted(off) = [{x: wrap(s.a.x + off), y: s.a.y}, {x: wrap(s.b.x + off), y: s.b.y}]
	var shift := func() -> void:
		for k in nof:
			sa[k].x = _Wrap.wrapx(s.a.x + OFFSETS[k])
			sa[k].y = s.a.y
			sb[k].x = _Wrap.wrapx(s.b.x + OFFSETS[k])
			sb[k].y = s.b.y

	shift.call()
	cams[0].reset(s.a, s.b)
	for k in nof:
		cams[k + 1].reset(sa[k], sb[k])
	var have_prev: bool = false
	var prev: PackedFloat64Array = PackedFloat64Array([0.0, 0.0, 0.0, 0.0])
	var max_jump: float = 0.0
	var out_normal: int = 0
	var out_flip: int = 0
	var flip_ticks: int = 0
	var max_inv: float = 0.0
	var seam_cross: int = 0
	var pa: float = s.a.x
	var pb: float = s.b.x
	for i in ticks:
		s.step()
		if absf(s.a.x - pa) > _Wrap.HALF:
			seam_cross += 1
		if absf(s.b.x - pb) > _Wrap.HALF:
			seam_cross += 1
		pa = s.a.x
		pb = s.b.x
		shift.call()
		cams[0].step(s.a, s.b)
		for k in nof:
			cams[k + 1].step(sa[k], sb[k])
		var c: _Camera = cams[0]
		var sc := PackedFloat64Array([c.screen_x(s.a.x), c.screen_y(s.a.y), c.screen_x(s.b.x), c.screen_y(s.b.y)])
		var out: bool = false
		for v in sc:
			if v < 0.0 or v > 1.0:
				out = true
		if c.flipping:
			flip_ticks += 1
		if out:
			if c.flipping:
				out_flip += 1
			else:
				out_normal += 1
		if have_prev and not c.flipping:
			for k in [0, 2]:
				max_jump = maxf(max_jump, absf(sc[k] - prev[k]))
		prev = sc
		have_prev = true
		for k in nof:
			var ck: _Camera = cams[k + 1]
			var sk := PackedFloat64Array([ck.screen_x(sa[k].x), ck.screen_y(sa[k].y), ck.screen_x(sb[k].x), ck.screen_y(sb[k].y)])
			for j in 4:
				max_inv = maxf(max_inv, absf(sk[j] - sc[j]))
			max_inv = maxf(max_inv, absf(ck.view_w - c.view_w) / c.view_w)
			if ck.flips != c.flips:
				max_inv = INF
	var r: Dictionary = {
		"scene": name, "ticks": ticks, "seamCrossings": seam_cross, "flips": cams[0].flips, "flipTicks": flip_ticks,
		"outOfFrameTicks": out_normal, "outOfFrameDuringFlip": out_flip, "maxScreenJump": max_jump,
		"maxSeamOffsetDiff": max_inv,
	}
	r["pass"] = out_normal == 0 and max_jump < JUMP and max_inv < 1e-6
	return r


## The camera result as JS JSON.stringify prints it (same key order, same number format).
static func camera_json(r: Dictionary) -> String:
	return "{\"scene\":%s,\"ticks\":%d,\"seamCrossings\":%d,\"flips\":%d,\"flipTicks\":%d,\"outOfFrameTicks\":%d,\"outOfFrameDuringFlip\":%d,\"maxScreenJump\":%s,\"maxSeamOffsetDiff\":%s,\"pass\":%s}" % [
		JSON.stringify(r["scene"]), r["ticks"], r["seamCrossings"], r["flips"], r["flipTicks"], r["outOfFrameTicks"],
		r["outOfFrameDuringFlip"], js_fixed(r["maxScreenJump"], 5), js_num(r["maxSeamOffsetDiff"]),
		"true" if r["pass"] else "false"]


static func simbench_json(b: Dictionary) -> String:
	return "{\"stack\":%s,\"reps\":%d,\"ticks\":%d,\"terrainGenMs\":%s,\"worstTickUs\":%s}" % [
		JSON.stringify(b["stack"]), b["reps"], b["ticks"], js_num(b["terrainGenMs"]), js_num(b["worstTickUs"])]


# ------------------------------------------------------------------ dump (divergence hunting)
func dump(name: String, tick: int) -> void:
	var input: bool = name == "flight-input"
	var s: _Scenes.Scene = _Scenes.make_scene("flight" if input else name)
	for t in tick:
		if input:
			var inp: PackedFloat64Array = scripted_input(t + 1)
			s.set_input(inp[0], inp[1])
		s.step()
	var v: PackedFloat64Array = _Hash.state_vector(s)
	for i in v.size():
		print("%d %s %s" % [i, js_num(v[i]), PackedFloat64Array([v[i]]).to_byte_array().hex_encode()])
	print("hash ", sha(v))


# ------------------------------------------------------------------ main
func _init() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	var di: int = args.find("--dump")
	if di >= 0 and di + 2 < args.size():
		dump(args[di + 1], args[di + 2].to_int())
		quit(0)
		return
	var fail: int = 0
	var g: Dictionary = goldens()
	var want: Dictionary = _Hash.golden()
	var gi: int = args.find("--golden")
	if gi >= 0 and gi + 1 < args.size():
		# Exported builds cannot see ../shared; pass the file explicitly: -- --golden <abs path to golden.json>
		var gf := FileAccess.open(args[gi + 1], FileAccess.READ)
		var parsed = JSON.parse_string(gf.get_as_text()) if gf != null else null
		if parsed is Dictionary:
			want = parsed
		else:
			print("WARN could not read --golden " + args[gi + 1])
	if want.get("embedded", false):
		print("WARN shared/golden.json not found; only the embedded worst@1980 golden is available")
	var cmp := func(label: String, a, b) -> int:
		var ok: bool = typeof(a) == TYPE_STRING and typeof(b) == TYPE_STRING and a == b
		print("%s %s %s%s" % ["PASS" if ok else "FAIL", label, a, "" if ok else " expected " + str(b)])
		return 0 if ok else 1
	fail += cmp.call("terrainBase", g["terrainBase"], want.get("terrainBase"))
	for n in CHECKPOINT_NAMES:
		for t in CHECKPOINTS[n]:
			fail += cmp.call("%s@%d" % [n, t], g[n][str(t)], want.get(n, {}).get(str(t)))
	for n in CAMERA_SCENES:
		fail += cmp.call("camera.%s@%d" % [n, CAMERA_TICKS], g["camera"][n]["hash"], want.get("camera", {}).get(n, {}).get("hash"))
	for n in CAMERA_SCENES:
		var r: Dictionary = camera_test(n)
		if not r["pass"]:
			fail += 1
		print("%s camera %s" % ["PASS" if r["pass"] else "FAIL", camera_json(r)])
	if args.has("--bench"):
		print("SIMBENCH " + simbench_json(_Simbench.run()))
	if fail > 0:
		print("%d failure(s)" % fail)
		quit(1)
		return
	print("all reference checks passed")
	quit(0)
