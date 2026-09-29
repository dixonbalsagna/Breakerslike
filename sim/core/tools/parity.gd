extends SceneTree
## GDScript parity check: reproduces every golden vector the JS core wrote (sim/core/test/golden-gd.json, from
## node sim/core/tools/golden.js) and exits 0 only if all match bit for bit. From the repo root:
##   godot --headless --path . --script res://sim/core/tools/parity.gd
## Each check repeats golden.js's recipe exactly: the same inputs from the same float arithmetic, the same Hasher.

const GOLDEN := "res://sim/core/test/golden-gd.json"
const LIT_RE := "(?<![\\w.])(\\d+\\.\\d+(?:e[+-]?\\d+)?|\\d+e[+-]?\\d+)(?![\\w.])"

var failures: int = 0


func _init() -> void:
	var t0: int = Time.get_ticks_usec()
	var g: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(GOLDEN))
	print("Meridian GDScript parity   Godot %s" % Engine.get_version_info().string)
	check("literals", _literals(g))
	check("constants", _constants(g))
	check("cosmetic stream seeds", _stream_seeds(g))
	check("rng", _rng(g))
	check("wrap", _wrap(g))
	check("sin/cos", _sincos(g))
	check("pow/exp/log/hypot", _powexplog(g))
	check("tick-0 state", _tick0(g))
	var tm: int = Time.get_ticks_usec()
	check("matches", _matches(g))
	check("human-input replays", _replays(g))
	print("      (matches and replays: %.1f s)" % ((Time.get_ticks_usec() - tm) / 1e6))
	_bench()
	print("time  %.1f s" % ((Time.get_ticks_usec() - t0) / 1e6))
	print("\nGDScript parity FAILED" if failures else "\nGDScript parity passed")
	quit(1 if failures else 0)


func check(name: String, err: String) -> void:
	if err == "":
		print("ok    " + name)
	else:
		failures += 1
		print("FAIL  %s: %s" % [name, err])


## Every float literal in the .gd sources must parse to the bits a correctly rounded parser gives (GDScript's parser
## is not correctly rounded for long literals), and golden.js must have seen them all.
func _literals(g: Dictionary) -> String:
	var want := {}
	for e in g.literals:
		want[e.lit] = e.hex
	var found := {}
	var re := RegEx.create_from_string(LIT_RE)
	var strip_str := RegEx.create_from_string("\"[^\"\\n]*\"")
	var strip_com := RegEx.create_from_string("(?m)#.*$")
	for file in _gd_files("res://sim"):
		var src: String = strip_com.sub(strip_str.sub(FileAccess.get_file_as_string(file), "\"\"", true), "", true)
		for m in re.search_all(src):
			found[m.get_string(1)] = true
	var missing: Array = found.keys().filter(func(k): return not want.has(k))
	if missing.size():
		return "golden-gd.json is stale (new literals %s). Run: node sim/core/tools/golden.js" % [missing]
	var lits: Array = want.keys()
	var scr := GDScript.new()
	scr.source_code = "extends RefCounted\nfunc v() -> Array:\n\treturn [%s]\n" % ", ".join(lits)
	if scr.reload() != OK:
		return "could not compile the literal list"
	var vals: Array = scr.new().v()
	var bad: Array = []
	for i in range(lits.size()):
		if SimMathx.bits(vals[i]) != want[lits[i]]:
			bad.append("%s parses to %s, want %s" % [lits[i], SimMathx.bits(vals[i]), want[lits[i]]])
	return "" if bad.is_empty() else "; ".join(bad)


func _gd_files(dir: String) -> Array:
	var out: Array = []
	for f in DirAccess.get_files_at(dir):
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	for d in DirAccess.get_directories_at(dir):
		out.append_array(_gd_files(dir.path_join(d)))
	return out


func _constants(g: Dictionary) -> String:
	var got: Array = [SimDetMath.PIO2_1, SimDetMath.PIO2_1T, SimDetMath.INVPIO2, SimDetMath.LN2_HI, SimDetMath.LN2_LO, SimDetMath.INVLN2, SimDetMath.SQRT2, SimDetMath.SQRT_HALF]
	got.append_array(Array(SimDetMath.SIN_C)); got.append_array(Array(SimDetMath.COS_C)); got.append_array(Array(SimDetMath.EXP_C)); got.append_array(Array(SimDetMath.LOG_C))
	if got.size() != g.constants.size():
		return "%d constants, want %d" % [got.size(), g.constants.size()]
	for i in range(got.size()):
		if SimMathx.bits(got[i]) != g.constants[i]:
			return "constant %d is %s, want %s" % [i, SimMathx.bits(got[i]), g.constants[i]]
	return ""


func _stream_seeds(g: Dictionary) -> String:
	var ids: Array = ["vfx.spark", "vfx.debris", "vfx.dust", "vfx.splash", "vfx.fire", "vfx.charge", "vfx.water", "camera", "audio"]
	for seed_s in g.streamSeeds:
		for i in range(ids.size()):
			var got: int = SimRng.deriveSeed(int(seed_s), ids[i])
			if got != int(g.streamSeeds[seed_s][i]):
				return "seed %s %s: %d, want %d" % [seed_s, ids[i], got, int(g.streamSeeds[seed_s][i])]
	return ""


func _rng(g: Dictionary) -> String:
	for seed_s in g.rng:
		var r := SimRng.new(int(seed_s))
		var h := SimHash.Hasher.new()
		for i in range(5000):
			h.num(r.next())
		h.num(float(r.state_i32()))
		if h.hex() != g.rng[seed_s]:
			return "seed %s: %s, want %s" % [seed_s, h.hex(), g.rng[seed_s]]
	return ""


func _wrap(g: Dictionary) -> String:
	var h := SimHash.Hasher.new()
	for i in range(8001):
		h.num(SimWrap.wrap(-40000.0 + float(i) * 10.0037))
	for i in range(2000):
		var a: float = float(i) * 4.8 + 0.3
		var b: float = 9599.7 - float(i) * 3.3
		h.num(SimWrap.sdx(a, b))
		h.num(SimWrap.sdx(b, a))
	return "" if h.hex() == g.wrap else "%s, want %s" % [h.hex(), g.wrap]


func _sincos(g: Dictionary) -> String:
	var h := SimHash.Hasher.new()
	for i in range(102190):
		var x: float = -700.0 + float(i) * 0.0137
		h.num(SimDetMath.sin(x))
		h.num(SimDetMath.cos(x))
	return "" if h.hex() == g.sincos else "%s, want %s" % [h.hex(), g.sincos]


func _powexplog(g: Dictionary) -> String:
	var h := SimHash.Hasher.new()
	var DT: float = SimConst.DT
	var bases: Array = [0.55, 0.05, 0.1, 0.001, 0.0008, 0.03, 0.02, 0.98, 0.5, 1.5, 7.25]
	var exps: Array = [DT, DT * 0.35, DT * 0.1, DT * 0.35 * 0.1, 1.0, 0.35, 0.1, 0.035, 2.0, 0.5, -1.5, 3.7]
	for b in bases:
		for e in exps:
			h.num(SimDetMath.pow(b, e))
	for i in range(4616):
		h.num(SimDetMath.exp(-30.0 + float(i) * 0.013))
	for i in range(3000):
		h.num(SimDetMath.log(0.0001 + float(i) * 0.37))
	for i in range(2000):
		h.num(SimDetMath.hypot(float(i) * 1.7 - 1500.0, 900.0 - float(i) * 0.9))
	return "" if h.hex() == g.powexplog else "%s, want %s" % [h.hex(), g.powexplog]


func _tick0(g: Dictionary) -> String:
	for seed_s in g.tick0:
		var S := SimCore.createSim()
		SimCore.newMatch(S, int(seed_s))
		var got: String = SimHash.stateHash(S).gameplay
		SimCore.dispose(S)
		var want: String = g.tick0[seed_s]
		if got != want:
			var why := "seed %s: %s (want %s)" % [seed_s, got, want]
			if seed_s == "1":
				why += "; " + _first_diff(SimHash.collect(S, "gameplay"), g.tick0Values)
			return why
	return ""


const CHAR_KEYS: Array = ["name", "title", "role", "col", "aura", "hair", "care", "dmgMul", "spd", "maxhp", "sigName"]


## golden.js ARMS (QA's match setups), in GDScript.
static func _apply_arm(arm: String, fs: Array) -> void:
	var base_arm: String = arm.trim_suffix("-flip")
	if base_arm == "swap":
		var a: Dictionary = _pick(fs[0])
		var b: Dictionary = _pick(fs[1])
		_put(fs[0], b)
		_put(fs[1], a)
	elif base_arm == "mirror-villain" or base_arm == "mirror-hero":
		var v: Dictionary = _pick(fs[1] if base_arm == "mirror-villain" else fs[0])
		var va := v.duplicate()
		va.name = v.name + "-A"
		var vb := v.duplicate()
		vb.name = v.name + "-B"
		_put(fs[0], va)
		_put(fs[1], vb)
	if arm.ends_with("-flip"):
		fs[0].x = 2900.0
		fs[1].x = 2150.0
		fs[0].face = -1.0
		fs[1].face = 1.0


static func _pick(f) -> Dictionary:
	var d := {}
	for k in CHAR_KEYS:
		d[k] = f.get(k)
	return d


static func _put(f, c: Dictionary) -> void:
	for k in c:
		f.set(k, c[k])
	f.hp = f.maxhp


static func _intent(d):
	if d == null:
		return null
	var i := SimIntent.new()
	i.mx = d.mx; i.my = d.my; i.dash = d.dash; i.charge = d.charge
	i.light = d.light; i.heavy = d.heavy; i.sig = d.sig; i.stance = d.stance
	return i


static func _full(S: SimState, V: SimFxView, cam: SimCamera) -> String:
	var h := SimHash.Hasher.new()
	h.num(cam.x); h.num(cam.y); h.num(cam.z)
	return SimHash.stateHash(S).gameplay + ":" + SimHash.viewHash(S, V) + ":" + h.hex()


## golden.js goldenRun(): the same run, the same digests.
func _golden_run(arm: String, seed: int, replay, check_every: int) -> Dictionary:
	var S := SimCore.createSim()
	var cam := SimCamera.new()
	SimCore.newMatch(S, seed, replay.ai if replay != null else {})
	var V := SimFxView.new(seed)
	_apply_arm(arm, S.fighters)
	var h := SimHash.Hasher.new()
	var checkpoints: Array = [_full(S, V, cam)]
	var cur: Array = [null, null]
	var steps: int = 0
	var ii: int = 0
	var ti: int = 0
	while (steps < int(replay.ticks)) if replay != null else (steps < 18000 and not (S.game.ko != null and S.game.koT > 3.0)):
		if replay != null:
			while ti < replay.toggles.size() and int(replay.toggles[ti][0]) == steps:
				SimCore.toggleAI(S, int(replay.toggles[ti][1]))
				ti += 1
			while ii < replay.inputs.size() and int(replay.inputs[ii][0]) == steps:
				cur[int(replay.inputs[ii][1])] = _intent(replay.inputs[ii][2])
				ii += 1
		SimCore.step(S, cur if replay != null else null)
		cam.camStep(S, S.dt, 1200.0, 700.0)
		steps += 1
		h.num(S.T)
		h.num(float(S.rng.state_i32()))
		for f in S.fighters:
			for k in ["x", "y", "vx", "vy", "hp", "ki", "power", "tier", "stance"]:
				h.num(f.get(k))
			h.text(f.state)
		for l in S.out.feed:
			h.num(l.t)
			h.text(l.tag)
			h.text(l.sub)
		S.out.feed.clear()
		SimHash.hashFx(h, S.out.fx)
		V.consume(S, S.out.fx)
		S.out.fx.clear()
		if steps % check_every == 0:
			checkpoints.append(_full(S, V, cam))
	var result := {"ticks": steps, "light": h.hex(), "checkpoints": checkpoints, "final": _full(S, V, cam)}
	SimCore.dispose(S)
	return result


static func _compare_run(got: Dictionary, want: Dictionary, label: String, check_every: int) -> String:
	for i in range(mini(got.checkpoints.size(), want.checkpoints.size())):
		if got.checkpoints[i] != want.checkpoints[i]:
			return "%s: first full-state difference by tick %d (checkpoint %d): %s vs JS %s" % [label, i * check_every, i, got.checkpoints[i], want.checkpoints[i]]
	if got.ticks != int(want.ticks):
		return "%s: %d ticks, JS %d" % [label, got.ticks, int(want.ticks)]
	if got.light != want.light:
		return "%s: per-tick digest %s, JS %s (checkpoints agree: the difference is between checkpoints or in the feed text)" % [label, got.light, want.light]
	if got.final != want.final:
		return "%s: final state %s, JS %s" % [label, got.final, want.final]
	return ""


func _matches(g: Dictionary) -> String:
	var ce: int = int(g.checkEvery)
	var bad: Array = []
	var ticks: int = 0
	for m in g.matches:
		var got: Dictionary = _golden_run(m.arm, int(m.seed), null, ce)
		ticks += got.ticks
		var e := _compare_run(got, m, "%s seed %d" % [m.arm, int(m.seed)], ce)
		if e != "":
			bad.append(e)
	if bad.size():
		return "; ".join(bad)
	print("      %d matches, %d ticks: every per-tick digest and full-state checkpoint identical" % [g.matches.size(), ticks])
	return ""


func _replays(g: Dictionary) -> String:
	var ce: int = int(g.checkEvery)
	for r in g.replays:
		var got: Dictionary = _golden_run("default", int(r.replay.seed), r.replay, ce)
		var e := _compare_run(got, r.run, "replay seed %d" % int(r.replay.seed), ce)
		if e != "":
			return e
	return ""


## Tick cost: AI-vs-AI matches with no hashing. The sim tick (step) and the render side's reference cosmetic consumer
## (view/fx.gd plus the camera follow) are timed apart; the first tick of each match (warm-up) is left out.
func _bench() -> void:
	var sim_t := PackedInt64Array()
	var view_t := PackedInt64Array()
	for seed in range(1, 11):
		var S := SimCore.createSim()
		var cam := SimCamera.new()
		var V := SimFxView.new(seed)
		SimCore.newMatch(S, seed)
		var steps: int = 0
		while steps < 18000 and not (S.game.ko != null and S.game.koT > 3.0):
			var t0: int = Time.get_ticks_usec()
			SimCore.step(S)
			var t1: int = Time.get_ticks_usec()
			V.consume(S, S.out.fx)
			cam.camStep(S, S.dt, 1200.0, 700.0)
			var t2: int = Time.get_ticks_usec()
			S.out.fx.clear()
			S.out.feed.clear()
			if steps > 0:
				sim_t.append(t1 - t0)
				view_t.append(t2 - t1)
			steps += 1
		SimCore.dispose(S)
	print("time  sim tick:  " + _dist(sim_t))
	print("time  cosmetic consumer and camera (render side): " + _dist(view_t))


static func _dist(v: PackedInt64Array) -> String:
	var s := v.duplicate()
	s.sort()
	var n: int = s.size()
	var tot: int = 0
	for x in s:
		tot += x
	return "mean %.1f us, p50 %d, p99 %d, p99.9 %d, max %d us over %d ticks of 10 matches" % [float(tot) / n, s[n / 2], s[int(n * 0.99)], s[int(n * 0.999)], s[n - 1], n]


## The first value that differs from a JS value list (tagged strings from golden.js).
func _first_diff(vals: Array, want: Array) -> String:
	for i in range(maxi(vals.size(), want.size())):
		var got: String = _tag(vals[i]) if i < vals.size() else "(missing)"
		var w: String = want[i] if i < want.size() else "(missing)"
		if got != w:
			return "first difference at value %d: GDScript %s, JS %s" % [i, got, w]
	return "value lists are equal (the hash code differs)"


static func _tag(v) -> String:
	match typeof(v):
		TYPE_FLOAT:
			return "n:" + SimMathx.bits(v)
		TYPE_INT:
			return "n:" + SimMathx.bits(float(v))
		TYPE_STRING:
			return "s:" + v
		TYPE_BOOL:
			return "b:1" if v else "b:0"
	return "z"
