extends SceneTree
## Director tempo and fight-location statistics on the GDScript sim (Encounter Systems). Read-only: it steps matches
## exactly as tools/batch.gd does and only observes state and feed lines, so it never changes behaviour. From the repo root:
##   godot --headless --path . --script res://sim/director/tools/tempo.gd -- [matches=100] [baseSeed=1] [--arm=NAME] [--json]
## Measures, from the start of a match to the KO (the targets are docs/design/balance-targets.md section 10):
##   exchanges started per minute of fight time; exchange length (request to release) and breathing room (release to the
##   next request), medians; interval between one fighter's attack requests (AI cadence), median;
##   planner launches per minute; long-haul share (at least 1,500 units of horizontal travel between the launch and the
##   landing, when the fighter is next down or free: a chain that catches and relaunches it mid-air continues the flight);
##   new-biome share (the biome where it lands differs from the one it was launched from);
##   share of fight time underwater (y < 0 over sea, both fighters) and over the ocean biome; beams by biome.

const MAX_STEPS: int = 18000
const LONG_HAUL: float = 1500.0 * SimConst.TRAV_LAUNCH   # units of horizontal travel; a launch reaches TRAV_LAUNCH times as far since the world scale (SC)

var re_atk := RegEx.create_from_string("^([A-Z][A-Z0-9-]*) (LIGHT|HEAVY|SIG) vs (\\w+)$")
var re_beam := RegEx.create_from_string("^(.+) over (\\w+) \\((.+)\\) → (\\w+)")
var re_launch := RegEx.create_from_string("^LAUNCH: (.+)$")


func _init() -> void:
	var pos: Array = []
	var arm: String = "default"
	var as_json: bool = false
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--arm="):
			arm = a.substr(6)
		elif a == "--json":
			as_json = true
		else:
			pos.append(a)
	var n: int = int(pos[0]) if pos.size() > 0 else 100
	var base: int = int(pos[1]) if pos.size() > 1 else 1
	var agg := {"n": n, "fightSec": 0.0, "exchanges": 0, "exLen": [], "gaps": [], "atkGaps": [], "launches": 0, "launchTypes": {},
		"flights": 0, "long": 0, "newBiome": 0, "plannerFlights": 0, "plannerLong": 0, "plannerNewBiome": 0, "travel": [],
		"underwaterSec": 0.0, "oceanSec": 0.0, "biomeSec": {}, "groundLandings": 0, "slideLandings": 0, "menace": [], "anguish": [], "beams": {}, "lens": [], "p1Wins": 0, "timeouts": 0, "civ": []}
	for i in range(n):
		run_match(base + i, arm, agg)
	var out: Dictionary = summarize(agg)
	if as_json:
		print(JSON.stringify({"args": {"matches": n, "baseSeed": base, "arm": arm}, "tempo": out}, " "))
	else:
		for k in out:
			print("%-28s %s" % [k, str(out[k])])
	quit(0)


func run_match(seed: int, arm: String, agg: Dictionary) -> void:
	var S := SimCore.createSim()
	SimCore.newMatch(S, seed)
	SimGolden.applyArm(arm, S.fighters)
	var fs: Array = S.fighters
	var slot := {fs[0].name: 0, fs[1].name: 1}
	var prevEx = null
	var exStart: float = -1.0
	var lastEnd: float = -1.0
	var lastAtk: Array = [-1.0, -1.0]
	var prevState: Array = [fs[0].state, fs[1].state]
	var prevX: Array = [fs[0].x, fs[1].x]
	var fl: Array = [[], []]            # open flights per fighter: {biome at launch, travel, planner}; a chain can stack two
	var steps: int = 0
	while steps < MAX_STEPS and S.game.ko == null:
		var T0: float = S.T
		SimCore.step(S)
		steps += 1
		S.out.fx.clear()
		var dt: float = S.T - T0
		agg.fightSec += dt
		var plannerLaunch: bool = false
		for l in S.out.feed:
			var m := re_atk.search(l.tag)
			if m:
				var s: int = slot.get(m.get_string(1), 0)
				if lastAtk[s] >= 0.0:
					agg.atkGaps.append(l.t - lastAtk[s])
				lastAtk[s] = l.t
				if m.get_string(2) == "SIG":
					var b := re_beam.search(l.sub)
					if b:
						agg.beams[b.get_string(2)] = agg.beams.get(b.get_string(2), 0) + 1
				continue
			m = re_launch.search(l.tag)
			if m:
				plannerLaunch = true
				agg.launches += 1
				agg.launchTypes[m.get_string(1)] = agg.launchTypes.get(m.get_string(1), 0) + 1
		S.out.feed.clear()
		if S.dirS.ex != prevEx:
			if prevEx != null and exStart >= 0.0:
				agg.exLen.append(S.T - exStart)
				lastEnd = S.T
			if S.dirS.ex != null:
				agg.exchanges += 1
				if lastEnd >= 0.0:
					agg.gaps.append(S.T - lastEnd)
				exStart = S.T
			prevEx = S.dirS.ex
		for k in range(2):
			var f = fs[k]
			if f.y < 0.0 and WorldTerrain.seaAt(S, f.x):
				agg.underwaterSec += dt
			var fb: String = WorldBiomes.biomeAt(f.x)
			agg.biomeSec[fb] = agg.biomeSec.get(fb, 0.0) + dt
			if fb == "ocean":
				agg.oceanSec += dt
			for r in fl[k]:
				r.travel += SimWrap.sdx(prevX[k], f.x)
				if f.slide > 0.0:
					r.slid = true
			if f.state == "launched" and prevState[k] != "launched":
				fl[k].append({"bio": WorldBiomes.biomeAt(f.x), "travel": 0.0, "planner": plannerLaunch, "slid": false})
			# A flight ends when the fighter lands (down or free); a chain catch (locked) and relaunch continue it.
			if (f.state == "down" or f.state == "free") and not fl[k].is_empty():
				if f.state == "down":
					agg.groundLandings += 1
					if fl[k][0].slid:
						agg.slideLandings += 1
				for r in fl[k]:
					_close(agg, r, WorldBiomes.biomeAt(f.x))
				fl[k] = []
			prevState[k] = f.state
			prevX[k] = f.x
	agg.lens.append(S.T)
	if S.game.ko == null:
		agg.timeouts += 1
	elif S.game.ko == fs[1]:
		agg.p1Wins += 1
	for f in fs:
		if f.role == "villain":
			agg.menace.append(f.menace)
		else:
			agg.anguish.append(f.anguish)
	agg.civ.append(S.world.casualties / S.world.pop0 * 100.0)
	SimCore.dispose(S)


static func _close(agg: Dictionary, r: Dictionary, landBio: String) -> void:
	var tr: float = absf(r.travel)
	var nb: bool = landBio != r.bio
	agg.flights += 1
	agg.travel.append(tr)
	if tr >= LONG_HAUL:
		agg.long += 1
	if nb:
		agg.newBiome += 1
	if r.planner:
		agg.plannerFlights += 1
		if tr >= LONG_HAUL:
			agg.plannerLong += 1
		if nb:
			agg.plannerNewBiome += 1


static func _median(a: Array) -> float:
	if a.is_empty():
		return NAN
	var s := a.duplicate()
	s.sort()
	var m: int = s.size() / 2
	return s[m] if s.size() % 2 == 1 else (s[m - 1] + s[m]) / 2.0


static func _mean(a: Array) -> float:
	if a.is_empty():
		return NAN
	var t: float = 0.0
	for v in a:
		t += v
	return t / a.size()


static func _r(x: float, d: int = 2) -> float:
	var p: float = pow(10.0, d)
	return round(x * p) / p


func summarize(a: Dictionary) -> Dictionary:
	var mins: float = a.fightSec / 60.0
	var beamTot: int = 0
	for k in a.beams:
		beamTot += a.beams[k]
	var beamShare := {}
	for k in a.beams:
		beamShare[k] = _r(100.0 * a.beams[k] / beamTot, 1)
	var timeShare := {}
	for k in a.biomeSec:
		timeShare[k] = _r(100.0 * a.biomeSec[k] / (2.0 * a.fightSec), 1)
	var typeShare := {}
	for k in a.launchTypes:
		typeShare[k] = _r(100.0 * a.launchTypes[k] / a.launches, 1)
	return {
		"matchLengthMean_s": _r(_mean(a.lens), 1),
		"p1WinRate": _r(float(a.p1Wins) / (a.n - a.timeouts), 3),
		"timeouts": a.timeouts,
		"civiliansLostMean_pct": _r(_mean(a.civ), 1),
		"exchangesPerMin": _r(a.exchanges / mins),
		"exchangeLenMedian_s": _r(_median(a.exLen)),
		"breathingRoomMedian_s": _r(_median(a.gaps)),
		"breathingRoomOver10s": a.gaps.filter(func(g): return g > 10.0).size(),
		"attackIntervalMedian_s": _r(_median(a.atkGaps)),
		"launchesPerMin": _r(a.launches / mins),
		"launchTypes_pct": typeShare,
		"plannerLongHaul_pct": _r(100.0 * a.plannerLong / maxf(1.0, a.plannerFlights), 1),
		"plannerNewBiome_pct": _r(100.0 * a.plannerNewBiome / maxf(1.0, a.plannerFlights), 1),
		"allFlightsLongHaul_pct": _r(100.0 * a.long / maxf(1.0, a.flights), 1),
		"allFlightsNewBiome_pct": _r(100.0 * a.newBiome / maxf(1.0, a.flights), 1),
		"flightTravelMedian_units": _r(_median(a.travel), 0),
		"slideShareOfGroundLandings_pct": _r(100.0 * a.slideLandings / maxf(1.0, a.groundLandings), 1),
		"underwaterTime_pct": _r(100.0 * a.underwaterSec / (2.0 * a.fightSec), 1),
		"overOceanTime_pct": _r(100.0 * a.oceanSec / (2.0 * a.fightSec), 1),
		"beamsByBiome_pct": beamShare,
		"fightTimeByBiome_pct": timeShare,
		"villainMenaceAtEnd_mean": _r(_mean(a.menace), 1),
		"heroAnguishAtEnd_mean": _r(_mean(a.anguish), 1),
	}
