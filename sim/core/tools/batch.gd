extends SceneTree
## AI-vs-AI batch runner on the GDScript sim: the successor of prototype/tools/sim-stats.js. From the repo root:
##   godot --headless --path . --script res://sim/core/tools/batch.gd -- [matches=60] [baseSeed=1] [--arm=NAME] [--json] [--jobs=N]
## --jobs=N splits the seed range over N child Godot processes (contiguous blocks) and aggregates their records in seed
## order, so the output and digest are the same as a single-process run. (--records=PATH is the children's mode.)
## Match i uses seed baseSeed+i, so the output is identical on every run (no clock in it); the digest hashes every
## match's final state, so comparing two runs is a one-line diff. Arms (who sits where): default, swap, mirror-villain,
## mirror-hero, and each with -flip. Statistics come from the feed lines, as in QA's match runner.
## Exit code 1 on a NaN or a fighter outside [0, W).

const MAX_STEPS: int = 43200   # 12 sim-minutes (wounds-plan S2: spec-wounds §5 test 3, p99)
const KO_TAIL: float = 3.0
const STANCES: Array = ["AGGRESSIVE", "DEFENSIVE", "EVASIVE", "ESCAPE"]

var re_atk := RegEx.create_from_string("^([A-Z][A-Z0-9-]*) (LIGHT|HEAVY|SIG) vs (\\w+)$")
var re_beam := RegEx.create_from_string("^(.+) over (\\w+) \\((.+)\\) → (\\w+)")
var re_launch := RegEx.create_from_string("^LAUNCH: (.+)$")
var re_parry := RegEx.create_from_string("^([A-Z][A-Z0-9-]*) PARRIES$")
var re_chain := RegEx.create_from_string("^CHAIN x(\\d+) ended$")
var re_hide := RegEx.create_from_string("^([A-Z][A-Z0-9-]*) goes to ground$")
var re_found := RegEx.create_from_string("^[A-Z][A-Z0-9-]* found$")


func _init() -> void:
	var pos: Array = []
	var arm: String = "default"
	var as_json: bool = false
	var jobs: int = 1
	var records_out: String = ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--arm="):
			arm = a.substr(6)
		elif a == "--json":
			as_json = true
		elif a.begins_with("--jobs="):
			jobs = maxi(1, int(a.substr(7)))
		elif a.begins_with("--records="):
			records_out = a.substr(10)
		else:
			pos.append(a)
	var n: int = int(pos[0]) if pos.size() > 0 else 60
	var base: int = int(pos[1]) if pos.size() > 1 else 1
	if n < 1 or not (arm.trim_suffix("-flip") in ["default", "swap", "mirror-villain", "mirror-hero"]):
		print("usage: godot --headless --path . --script res://sim/core/tools/batch.gd -- [matches=60] [baseSeed=1] [--arm=default|swap|mirror-villain|mirror-hero[-flip]] [--json]")
		quit(2)
		return
	var t0: int = Time.get_ticks_usec()
	var recs: Array = []
	if jobs > 1 and n > 1:
		recs = run_jobs(n, base, arm, mini(jobs, n))
	else:
		for i in range(n):
			recs.append(run_match(base + i, arm))
	for r in recs:
		if r.bad != "":
			print("FAIL  seed %d: %s" % [int(r.seed), r.bad])
			quit(1)
			return
	if records_out != "":
		var f := FileAccess.open(records_out, FileAccess.WRITE)
		f.store_string(JSON.stringify(recs))
		f.close()
		quit(0)
		return
	var digest := SimHash.Hasher.new()
	for r in recs:
		digest.text(r.hash)
	var secs: float = (Time.get_ticks_usec() - t0) / 1e6
	var agg: Dictionary = aggregate(recs)
	agg.digest = digest.hex()
	agg.seconds = secs
	agg.matchesPerMinute = n / secs * 60.0
	if as_json:
		print(JSON.stringify({"args": {"matches": n, "baseSeed": base, "arm": arm}, "stats": agg}, " "))
	else:
		report(agg, n, base, arm)
	quit(0)


## Runs contiguous seed blocks in child processes and returns their records in seed order.
func run_jobs(n: int, base: int, arm: String, jobs: int) -> Array:
	var exe: String = OS.get_executable_path()
	var root: String = ProjectSettings.globalize_path("res://")
	var pids: Array = []
	var files: Array = []
	var start: int = base
	for j in range(jobs):
		var count: int = n / jobs + (1 if j < n % jobs else 0)
		var out: String = OS.get_user_data_dir().path_join("batch_%d_%d.json" % [OS.get_process_id(), j])
		files.append(out)
		pids.append(OS.create_process(exe, ["--headless", "--path", root, "--script", "res://sim/core/tools/batch.gd", "--", str(count), str(start), "--arm=" + arm, "--records=" + out]))
		start += count
	while pids.any(func(pid): return OS.is_process_running(pid)):
		OS.delay_msec(100)
	var recs: Array = []
	for out in files:
		var got = JSON.parse_string(FileAccess.get_file_as_string(out))
		if not (got is Array):
			recs.append({"seed": -1, "bad": "a child process wrote no records (" + out + ")"})
			continue
		recs.append_array(got)
		DirAccess.remove_absolute(out)
	return recs


func run_match(seed: int, arm: String) -> Dictionary:
	var S := SimCore.createSim()
	SimCore.newMatch(S, seed)
	SimGolden.applyArm(arm, S.fighters)
	var fs: Array = S.fighters
	var slot := {}
	for i in range(2):
		slot[fs[i].name] = i
	var rec := {"seed": seed, "names": [fs[0].name, fs[1].name], "attacks": {"light": 0, "heavy": 0, "sig": 0}, "ambush": 0, "launches": {}, "melee": {},
		"beams": [], "parries": [0, 0], "chains": [], "hides": [0, 0], "found": 0, "seam": 0, "maxMove": 0.0, "bad": "", "koAt": -1.0, "winner": -1,
		"breaks": 0, "firstBrink": -1.0, "firstBroken": "", "wearIn": [0.0, 0.0, 0.0, 0.0]}
	var prevWear: Array = [fs[0].wear.duplicate(), fs[1].wear.duplicate()]
	var prev: Array = [fs[0].x, fs[1].x]
	var steps: int = 0
	while steps < MAX_STEPS and not (S.game.ko != null and S.game.koT > KO_TAIL):
		SimCore.step(S)
		steps += 1
		for e in S.out.fx:
			if e.type == "region_broken":
				rec.breaks += 1
				if rec.firstBroken == "":
					rec.firstBroken = e.region
			elif e.type == "brink_enter" and rec.firstBrink < 0.0:
				rec.firstBrink = S.T
		S.out.fx.clear()
		for i in range(2):
			for ri in range(4):
				var dw: int = fs[i].wear[ri] - prevWear[i][ri]
				if dw > 0:
					rec.wearIn[ri] += float(dw) / SimWounds.WEAR_SCALE
				prevWear[i][ri] = fs[i].wear[ri]
		if S.game.ko != null and rec.koAt < 0.0:
			rec.koAt = S.T
			rec.winner = 1 - fs.find(S.game.ko)
		for i in range(2):
			var f = fs[i]
			if not (is_finite(f.x) and is_finite(f.y) and is_finite(f.hp) and is_finite(f.ki)):
				rec.bad = "NaN in %s at %.2f s" % [f.name, S.T]
			if f.x < 0.0 or f.x >= SimConst.W:
				rec.bad = "%s x %f outside [0, W)" % [f.name, f.x]
			if absf(f.x - prev[i]) > SimConst.HALF:
				rec.seam += 1
			rec.maxMove = maxf(rec.maxMove, absf(SimWrap.sdx(prev[i], f.x)))
			prev[i] = f.x
		for l in S.out.feed:
			parse(rec, l.tag, l.sub, slot, fs)
		S.out.feed.clear()
		if rec.bad != "":
			break
	rec.ticks = steps
	rec.timeout = S.game.ko == null
	if rec.koAt < 0.0:
		rec.koAt = S.T
	rec.civPct = S.world.casualties / S.world.pop0 * 100.0
	rec.structs = S.world.structuresLost
	rec.nStructs = S.buildings.size()
	rec.craters = S.world.craters
	rec.hash = SimHash.stateHash(S).gameplay
	SimCore.dispose(S)
	return rec


func parse(rec: Dictionary, tag: String, sub: String, slot: Dictionary, fs: Array) -> void:
	var m := re_atk.search(tag)
	if m:
		var kind: String = m.get_string(2).to_lower()
		rec.attacks[kind] += 1
		if sub.ends_with("(ambush)"):
			rec.ambush += 1
		if kind == "sig":
			var b := re_beam.search(sub)
			if b:
				rec.beams.append({"bio": b.get_string(2), "variant": b.get_string(3), "out": b.get_string(4)})
		else:
			var base: String = sub.trim_suffix("  (ambush)").trim_suffix(" → COUNTER")
			rec.melee[base] = rec.melee.get(base, 0) + 1
		return
	m = re_launch.search(tag)
	if m:
		rec.launches[m.get_string(1)] = rec.launches.get(m.get_string(1), 0) + 1
		return
	m = re_parry.search(tag)
	if m:
		rec.parries[slot.get(m.get_string(1), 0)] += 1
		return
	m = re_chain.search(tag)
	if m:
		rec.chains.append(int(m.get_string(1)))
		return
	m = re_hide.search(tag)
	if m:
		rec.hides[slot.get(m.get_string(1), 0)] += 1
		return
	if re_found.search(tag):
		rec.found += 1


static func _dist(vals: Array) -> Dictionary:
	var s := vals.duplicate()
	s.sort()
	var n: int = s.size()
	var tot: float = 0.0
	for v in s:
		tot += v
	var q := func(p: float) -> float:
		var x: float = (n - 1) * p
		var i: int = int(floor(x))
		return s[i] if i + 1 >= n else s[i] * (1.0 - (x - i)) + s[i + 1] * (x - i)
	return {"mean": tot / n, "min": s[0], "p10": q.call(0.1), "p50": q.call(0.5), "p90": q.call(0.9), "max": s[n - 1]}


## Wilson 95% interval for k of n.
static func _wilson(k: int, n: int) -> Array:
	if n == 0:
		return [NAN, NAN]
	var z: float = 1.96
	var p: float = float(k) / n
	var d: float = 1.0 + z * z / n
	var c: float = p + z * z / (2.0 * n)
	var r: float = z * sqrt(p * (1.0 - p) / n + z * z / (4.0 * n * n))
	return [(c - r) / d, (c + r) / d]


func aggregate(recs: Array) -> Dictionary:
	var n: int = recs.size()
	var a := {"n": n, "names": recs[0].names, "slotWins": [0, 0], "timeouts": 0, "launches": {}, "melee": {}, "beamsByBiome": {}, "beamOutcomes": {},
		"attacks": {"light": 0, "heavy": 0, "sig": 0}}
	var lens: Array = []
	var civ: Array = []
	var structs: Array = []
	var craters: Array = []
	var beams: int = 0
	var parries: int = 0
	var chains: int = 0
	var hides: int = 0
	var with_hide: int = 0
	var ambush: int = 0
	var found: int = 0
	var seam_matches: int = 0
	var max_move: float = 0.0
	var ticks: int = 0
	var breaks: Array = []
	var brinks: Array = []
	var firstBroken := {}
	var wearIn: Array = [0.0, 0.0, 0.0, 0.0]
	for r in recs:
		breaks.append(float(r.breaks))
		if r.firstBrink >= 0.0:
			brinks.append(r.firstBrink)
		if r.firstBroken != "":
			firstBroken[r.firstBroken] = firstBroken.get(r.firstBroken, 0) + 1
		for ri in range(4):
			wearIn[ri] += r.wearIn[ri]
		if r.timeout:
			a.timeouts += 1
		else:
			a.slotWins[int(r.winner)] += 1
		lens.append(r.koAt)
		civ.append(r.civPct)
		structs.append(r.structs)
		craters.append(r.craters)
		for k in r.launches:
			a.launches[k] = a.launches.get(k, 0) + r.launches[k]
		for k in r.melee:
			a.melee[k] = a.melee.get(k, 0) + r.melee[k]
		for k in r.attacks:
			a.attacks[k] += r.attacks[k]
		for b in r.beams:
			a.beamsByBiome[b.bio] = a.beamsByBiome.get(b.bio, 0) + 1
			a.beamOutcomes[b.out] = a.beamOutcomes.get(b.out, 0) + 1
		beams += r.beams.size()
		parries += r.parries[0] + r.parries[1]
		chains += r.chains.size()
		hides += r.hides[0] + r.hides[1]
		if r.hides[0] + r.hides[1] > 0:
			with_hide += 1
		ambush += r.ambush
		found += r.found
		if r.seam > 0:
			seam_matches += 1
		max_move = maxf(max_move, r.maxMove)
		ticks += r.ticks
	var decided: int = n - a.timeouts
	a.p1Rate = float(a.slotWins[0]) / decided if decided else NAN
	a.p1Ci = _wilson(a.slotWins[0], decided)
	a.length = _dist(lens)
	a.civPct = _dist(civ)
	a.structs = _dist(structs)
	a.nStructs = recs[0].nStructs
	a.craters = _dist(craters)
	a.beams = beams
	a.perMatch = {"beams": float(beams) / n, "parries": float(parries) / n, "chains": float(chains) / n, "hides": float(hides) / n, "ambushAttacks": float(ambush) / n, "found": float(found) / n}
	a.matchesWithHide = float(with_hide) / n
	a.seam = {"matchesWithCrossing": seam_matches, "maxMovePerTick": max_move}
	a.ticks = ticks
	var wt: float = wearIn[0] + wearIn[1] + wearIn[2] + wearIn[3]
	a.wounds = {"breaksPerMatch": _dist(breaks), "matchesWithBrink": brinks.size(), "firstBrink": _dist(brinks) if brinks.size() else {}, "firstBroken": firstBroken,
		"wearShare": {"head": wearIn[0] / wt if wt > 0.0 else 0.0, "core": wearIn[1] / wt if wt > 0.0 else 0.0, "arms": wearIn[2] / wt if wt > 0.0 else 0.0, "legs": wearIn[3] / wt if wt > 0.0 else 0.0}}
	return a


static func _shares(d: Dictionary) -> String:
	var tot: int = 0
	for k in d:
		tot += d[k]
	var keys: Array = d.keys()
	keys.sort_custom(func(x, y): return d[x] > d[y] or (d[x] == d[y] and x < y))
	return "  ".join(keys.map(func(k): return "%s %.0f%%" % [k, 100.0 * d[k] / tot])) if tot else "-"


func report(a: Dictionary, n: int, base: int, arm: String) -> void:
	print("matches %d   arm %s   seeds %d..%d   digest %s" % [n, arm, base, base + n - 1, a.digest])
	var wins := {a.names[0]: a.slotWins[0], a.names[1]: a.slotWins[1]}
	if a.timeouts:
		wins.timeout = a.timeouts
	print("wins %s   P1 %.1f%% [%.1f%%, %.1f%%]  (%s in P1)" % [JSON.stringify(wins), a.p1Rate * 100.0, a.p1Ci[0] * 100.0, a.p1Ci[1] * 100.0, a.names[0]])
	var L: Dictionary = a.length
	print("length to KO avg %.1fs  p10 %.1f  p50 %.1f  p90 %.1f  min %.1f  max %.1f" % [L.mean, L.p10, L.p50, L.p90, L.min, L.max])
	print("collateral avg %.0f%% of civilians   %.1f of %d structures   craters %.0f" % [a.civPct.mean, a.structs.mean, a.nStructs, a.craters.mean])
	var nl: int = 0
	for k in a.launches:
		nl += a.launches[k]
	print("launches %d:  %s" % [nl, _shares(a.launches)])
	print("beams %d (%.1f/match) by biome:  %s   outcomes:  %s" % [a.beams, a.perMatch.beams, _shares(a.beamsByBiome), _shares(a.beamOutcomes)])
	print("parry %.2f/match   chains %.2f/match   hides %.2f/match (%.0f%% of matches)   ambush attacks %.2f/match" % [a.perMatch.parries, a.perMatch.chains, a.perMatch.hides, a.matchesWithHide * 100.0, a.perMatch.ambushAttacks])
	print("seam: %d of %d matches crossed the seam   max per-tick move %.1f units" % [a.seam.matchesWithCrossing, n, a.seam.maxMovePerTick])
	print("melee exchanges:  %s" % _shares(a.melee))
	var w: Dictionary = a.wounds
	var ws: Dictionary = w.wearShare
	print("wounds: breaks %.2f/match (max %d)   matches reaching the brink %d of %d%s   first broken %s   wear share head %.0f%% core %.0f%% arms %.0f%% legs %.0f%%" % [w.breaksPerMatch.mean, int(w.breaksPerMatch.max), w.matchesWithBrink, n,
		("   first brink median %.0fs" % w.firstBrink.p50) if w.matchesWithBrink > 0 else "", _shares(w.firstBroken), ws.head * 100.0, ws.core * 100.0, ws.arms * 100.0, ws.legs * 100.0])
	print("speed: %d matches in %.1f s = %.0f matches per minute (%.0f ticks/s)" % [n, a.seconds, a.matchesPerMinute, a.ticks / a.seconds])
