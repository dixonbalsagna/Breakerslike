class_name SimGolden
## The golden-vector recipes, shared by the generator (tools/golden.gd) and the check (tools/parity.gd), so the two can
## never disagree about what a vector means. Since ADR 0006 the GDScript sim is the source of truth: these recipes
## define the goldens. (They are the recipes of the frozen JS generator, sim/core/tools/golden.js, carried over
## unchanged, so the JS-generated record in sim/core/test/frozen/ is checked the same way.)

const CHECK_EVERY: int = 120
const RNG_SEEDS: Array = [0, 1, 7, 4242, 2147483647, 2147483648, 4294967295, 12345]
const TICK0_SEEDS: Array = [1, 2, 3, 42, 1000, 4294967295]
const STREAM_SEEDS: Array = [0, 1, 42, 4294967295]
const STREAM_IDS: Array = ["vfx.spark", "vfx.debris", "vfx.dust", "vfx.splash", "vfx.fire", "vfx.charge", "vfx.water", "camera", "audio"]
## [arm, seed]: one match per QA arm, 8 matches (S2 cut: with 6-minute matches each runs to the 18000-tick cap, so the
## 17-match set made the golden check slow; the batch tools cover the seeds this dropped).
const MATCHES: Array = [["default", 1], ["swap", 1], ["mirror-villain", 1], ["mirror-hero", 1],
	["default-flip", 2], ["swap-flip", 2], ["mirror-villain-flip", 2], ["mirror-hero-flip", 2]]
const CHAR_KEYS: Array = ["id", "name", "title", "role", "col", "aura", "hair", "care", "dmgMul", "spd", "maxhp", "sigName"]
const INTENT: Array = ["mx", "my", "dash", "charge", "light", "heavy", "sig", "stance"]


## Every golden vector, as the JSON the generator writes.
static func build() -> Dictionary:
	var g := {"format": "orb-golden", "v": 2, "generatedBy": "sim/core/tools/golden.gd (GDScript sim, the source of truth since ADR 0006)", "godot": Engine.get_version_info().string}
	g.constants = constants()
	g.streamSeeds = {}
	for s in STREAM_SEEDS:
		g.streamSeeds[str(s)] = streamSeeds(s)
	g.rng = {}
	for s in RNG_SEEDS:
		g.rng[str(s)] = rngHash(s)
	g.wrap = wrapHash()
	g.sincos = sincosHash()
	g.powexplog = powHash()
	g.tick0 = {}
	for s in TICK0_SEEDS:
		g.tick0[str(s)] = tick0Hash(s)
	g.tick0Values = tick0Values(1)
	g.rally = rallyHash()
	g.wounds = woundsHash()
	g.checkEvery = CHECK_EVERY
	g.matches = []
	for m in MATCHES:
		g.matches.append(goldenRun(m[0], m[1], null))
	g.replays = []
	for rp in [scriptedReplay(11, 3000, false, [1500, 2100]), scriptedReplay(12, 2400, true, [])]:
		g.replays.append({"replay": rp, "run": goldenRun("default", rp.seed, rp)})
	return g


static func constants() -> Array:
	var got: Array = [SimDetMath.PIO2_1, SimDetMath.PIO2_1T, SimDetMath.INVPIO2, SimDetMath.LN2_HI, SimDetMath.LN2_LO, SimDetMath.INVLN2, SimDetMath.SQRT2, SimDetMath.SQRT_HALF]
	got.append_array(Array(SimDetMath.SIN_C))
	got.append_array(Array(SimDetMath.COS_C))
	got.append_array(Array(SimDetMath.EXP_C))
	got.append_array(Array(SimDetMath.LOG_C))
	return got.map(func(x): return SimMathx.bits(x))


static func streamSeeds(seed: int) -> Array:
	return STREAM_IDS.map(func(id): return SimRng.deriveSeed(seed, id))


static func rngHash(seed: int) -> String:
	var r := SimRng.new(seed)
	var h := SimHash.Hasher.new()
	for i in range(5000):
		h.num(r.next())
	h.num(float(r.state_i32()))
	return h.hex()


static func wrapHash() -> String:
	var h := SimHash.Hasher.new()
	for i in range(8001):
		h.num(SimWrap.wrap(-40000.0 + float(i) * 10.0037))
	for i in range(2000):
		var a: float = float(i) * 4.8 + 0.3
		var b: float = 9599.7 - float(i) * 3.3
		h.num(SimWrap.sdx(a, b))
		h.num(SimWrap.sdx(b, a))
	return h.hex()


static func sincosHash() -> String:
	var h := SimHash.Hasher.new()
	for i in range(102190):
		var x: float = -700.0 + float(i) * 0.0137
		h.num(SimDetMath.sin(x))
		h.num(SimDetMath.cos(x))
	return h.hex()


static func powHash() -> String:
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
	return h.hex()


## Wounds (wounds.gd) driven directly: a fixed sequence of wearing hits of every family, with recovery phases in and
## out of hiding, so every stage, the brink and the recovery rules are pinned even while matches still end on HP (S1).
static func woundsHash() -> String:
	var S := SimCore.createSim()
	SimCore.newMatch(S, 7)
	var f = S.fighters[1]
	var h := SimHash.Hasher.new()
	var fams: Array = ["light", "heavy", "guard", "spread"]
	for i in range(260):
		SimWounds.applyHit(S, f, 12.0 + float(i % 9) * 7.0, fams[i % 4])
		if i % 11 == 10:
			f.hidden = i % 22 == 21
			for t in range(90):
				SimWounds.step(S, f)
		for r in range(4):
			h.num(float(f.wear[r]))
			h.num(float(f.stage[r]))
		h.u(1 if f.brink else 0)
	h.num(float(S.rng.state_i32()))
	SimHash.hashFx(h, S.out.fx)
	SimCore.dispose(S)
	return h.hex()


## S4 Rally, forced (like woundsHash): Second Wind mends the core; the cooldown holds; the next Rally mends the head; a
## brink too deep for one mend gets none; Spite ignores a signature win and mends the arms first on a win by hand; second
## breath's recovered wear accumulates.
static func rallyHash() -> String:
	var S := SimCore.createSim()
	SimCore.newMatch(S, 7)
	var f = S.fighters[0]
	var g = S.fighters[1]
	g.rally = "spite"
	var h := SimHash.Hasher.new()
	var snap := func(x) -> void:
		for r in range(4):
			h.num(float(x.wear[r])); h.num(float(x.stage[r]))
		h.u(1 if x.brink else 0)
		h.num(float(x.rallied)); h.num(float(x.rallies)); h.num(float(x.rallyCool)); h.num(float(x.breathWear))
	var put := func(x, w: Array) -> void:
		for r in range(4):
			x.wear[r] = w[r]
		SimWounds.updateStages(S, x)
	var wait := func(x, n: int) -> void:
		for t in range(n):
			SimWounds.step(S, x)
	put.call(f, [300000, 560000, 200000, 100000])       # core broken: on the brink
	SimWounds.onContestSurvived(S, f); snap.call(f)     # Second Wind mends the core
	put.call(f, [560000, 534000, 560000, 100000])       # head and arms broken
	SimWounds.onContestSurvived(S, f); snap.call(f)     # the cooldown holds
	wait.call(f, SimWounds.RALLY_COOL_TICKS); snap.call(f)
	SimWounds.onContestSurvived(S, f); snap.call(f)     # the head (core already rallied)
	put.call(f, [534000, 560000, 560000, 560000])       # core and two limbs: too deep for one mend
	wait.call(f, SimWounds.RALLY_COOL_TICKS)
	SimWounds.onContestSurvived(S, f); snap.call(f)
	put.call(g, [200000, 300000, 560000, 560000])       # arms and legs broken
	SimWounds.onDecisive(S, g, "beam"); snap.call(g)    # a signature win is not by hand
	SimWounds.onDecisive(S, g, "clash"); snap.call(g)   # Spite: arms first
	put.call(g, [200000, 300000, 400000, 100000])       # a battered region, 10 s after the last exchange
	S.T = 10.0
	wait.call(g, 60); snap.call(g)                      # second breath: 60 ticks x 100 units
	SimHash.hashFx(h, S.out.fx)
	SimCore.dispose(S)
	return h.hex()


static func tick0Hash(seed: int) -> String:
	var S := SimCore.createSim()
	SimCore.newMatch(S, seed)
	var got: String = SimHash.stateHash(S).gameplay
	SimCore.dispose(S)
	return got


## The tick-0 gameplay values as tagged strings, for first-difference diagnostics.
static func tick0Values(seed: int) -> Array:
	var S := SimCore.createSim()
	SimCore.newMatch(S, seed)
	var vals: Array = SimHash.collect(S, "gameplay").map(func(v): return tag(v))
	SimCore.dispose(S)
	return vals


static func tag(v) -> String:
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


## QA's match setups ("arms"): default, swap, mirror-villain, mirror-hero, and each with -flip (spawn sides exchanged).
static func applyArm(arm: String, fs: Array) -> void:
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
		fs[0].x = SimConst.START_X + SimConst.START_GAP   # S4: was 2900 and 2150, the pre-scale spawns
		fs[1].x = SimConst.START_X
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


## One golden run. Every tick folds a light digest (time, rng, fighters' core numbers and state, feed lines, fx events);
## every CHECK_EVERY ticks and at the end the full state is recorded (sim, reference cosmetic view, camera). With a
## replay the run applies its AI toggles and intents for exactly replay.ticks; without, it runs to KO + 3 s or 18000.
static func goldenRun(arm: String, seed: int, replay) -> Dictionary:
	var S := SimCore.createSim()
	var cam := SimCamera.new()
	SimCore.newMatch(S, seed, replay.ai if replay != null else {})
	var V := SimFxView.new(seed)
	applyArm(arm, S.fighters)
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
		if steps % CHECK_EVERY == 0:
			checkpoints.append(_full(S, V, cam))
	var result := {"arm": arm, "seed": seed, "ticks": steps, "light": h.hex(), "checkpoints": checkpoints, "final": _full(S, V, cam)}
	SimCore.dispose(S)
	return result


## A scripted human (P1, and P2 when both) as a replay: moves, dashes, charges, switches stance and presses attacks.
static func scriptedReplay(seed: int, ticks: int, both: bool, toggleAt: Array) -> Dictionary:
	var r := SimRng.new(seed ^ 0x51ed)
	var held: Array = [{"mx": 0.0, "my": 0.0, "dash": false, "charge": false}, {"mx": 0.0, "my": 0.0, "dash": false, "charge": false}]
	var rp := {"seed": seed, "ai": {"p1": false, "p2": not both}, "ticks": ticks, "inputs": [], "toggles": toggleAt.map(func(t): return [t, 1])}
	var last: Array = [null, null]
	var steer: Array = [-1.0, 0.0, 1.0]
	for t in range(ticks):
		for k in range(2 if both else 1):
			var hk: Dictionary = held[k]
			if r.next() < 0.05:
				hk.mx = steer[int(floor(r.next() * 3.0))]
			if r.next() < 0.05:
				hk.my = steer[int(floor(r.next() * 3.0))]
			if r.next() < 0.02:
				hk.dash = not hk.dash
			if r.next() < 0.01:
				hk.charge = not hk.charge
			var i := {"mx": hk.mx, "my": hk.my, "dash": hk.dash, "charge": hk.charge}
			i.light = r.next() < 0.03
			i.heavy = r.next() < 0.015
			i.sig = r.next() < 0.008
			i.stance = floor(r.next() * 4.0) if r.next() < 0.004 else -1.0
			var changed: bool = last[k] == null
			if not changed:
				for q in INTENT:
					if last[k][q] != i[q]:
						changed = true
						break
			if changed:
				rp.inputs.append([t, k, i])
				last[k] = i
	return rp


## "" if a run matches its golden, or the first difference.
static func compareRun(got: Dictionary, want: Dictionary, label: String) -> String:
	for i in range(mini(got.checkpoints.size(), want.checkpoints.size())):
		if got.checkpoints[i] != want.checkpoints[i]:
			return "%s: first full-state difference by tick %d (checkpoint %d): %s vs golden %s" % [label, i * CHECK_EVERY, i, got.checkpoints[i], want.checkpoints[i]]
	if got.ticks != int(want.ticks):
		return "%s: %d ticks, golden %d" % [label, got.ticks, int(want.ticks)]
	if got.light != want.light:
		return "%s: per-tick digest %s, golden %s (checkpoints agree: the difference is between checkpoints, in the feed text or in the fx events)" % [label, got.light, want.light]
	if got.final != want.final:
		return "%s: final state %s, golden %s" % [label, got.final, want.final]
	return ""
