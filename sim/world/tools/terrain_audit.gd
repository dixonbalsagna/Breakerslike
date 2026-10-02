extends SceneTree
## Terrain audit over real matches (Orb's playtest 8: "weird unexpected behaviour from terrain deformation"). From the repo root:
##   godot --headless --path . --script res://sim/world/tools/terrain_audit.gd -- [firstSeed=1] [count=3] [everyTicks=1200]
## Plays AI-vs-AI matches and, at every snapshot, scans the ground (base + deform), the water and the buildings for things
## that look wrong: steep new steps, isolated spikes and pits, clamped (flat-topped) deformation, water that does not meet
## itself, buildings on tilted or hollowed ground, fighters inside the ground. Prints the counts per snapshot and the worst
## cases with their x and tick. It changes nothing and draws nothing from S.rng.

const BH: float = 75.0
const STEP_STEEP: float = 1.0 * BH       # a step between neighbouring columns of more than this (a cliff)
const STEP_NEW: float = 0.6 * BH         # ... or this when the base had no such step
const SPIKE: float = 0.4 * BH            # a column this far above (spike) or below (pit) both neighbours
const TILT: float = 0.5 * BH             # ground varying by more than this across a building's footprint
const WATER_CLIFF: float = 0.5 * BH      # neighbouring wet columns whose surfaces differ by more than this
const PERCH: float = 1.5 * BH            # a wet column this far above sea level


func _init() -> void:
	var args: Array = OS.get_cmdline_user_args()
	var first: int = int(args[0]) if args.size() > 0 else 1
	var cnt: int = int(args[1]) if args.size() > 1 else 3
	var every: int = int(args[2]) if args.size() > 2 else 1200
	for m in range(cnt):
		_match(first + m, every)
	quit(0)


func _match(seed: int, every: int) -> void:
	var S := SimCore.createSim()
	SimCore.newMatch(S, seed, {}, {"intro": false})
	var base0 := S.base.duplicate()
	var steps: int = 0
	var worst := {}
	while S.game.ko == null and steps < 54000:
		SimCore.step(S, null)
		S.out.fx.clear()
		S.out.feed.clear()
		steps += 1
		if steps % every == 0:
			_scan(S, base0, steps, seed, worst, false)
	_scan(S, base0, steps, seed, worst, true)
	SimCore.dispose(S)


func _scan(S: SimState, base0: PackedFloat32Array, tick: int, seed: int, worst: Dictionary, final: bool) -> void:
	var NC: int = SimConst.NC
	var COL: float = SimConst.COL
	var G := PackedFloat32Array()
	G.resize(NC)
	for i in range(NC):
		G[i] = S.base[i] + S.deform[i]
	var steep: int = 0
	var newstep: int = 0
	var spikes: int = 0
	var pits: int = 0
	var clampU: int = 0
	var clampL: int = 0
	var maxstep: float = 0.0
	var maxstep_x: float = 0.0
	var spike_ex: Array = []
	var pit_ex: Array = []
	var pit_idx: int = -1
	var spike_idx: int = -1
	var step_idx: int = -1
	var newstep_ex: Array = []
	for i in range(NC):
		var j: int = (i + 1) % NC
		var l: int = (i - 1 + NC) % NC
		var d: float = absf(G[j] - G[i])
		var d0: float = absf(base0[j] - base0[i])
		if d > STEP_STEEP:
			steep += 1
		if d > STEP_NEW and d - d0 > STEP_NEW:
			newstep += 1
			if step_idx < 0:
				step_idx = i
			if newstep_ex.size() < 3:
				newstep_ex.append("x %.0f step %.0f (base %.0f)" % [float(i) * COL, d, d0])
		if d > maxstep:
			maxstep = d
			maxstep_x = float(i) * COL
		if S.deform[i] != 0.0:
			var up: float = G[i] - maxf(G[j], G[l])
			var dn: float = minf(G[j], G[l]) - G[i]
			if up > SPIKE:
				spikes += 1
				if spike_idx < 0:
					spike_idx = i
				if spike_ex.size() < 3:
					spike_ex.append("x %.0f +%.0f" % [float(i) * COL, up])
			if dn > SPIKE:
				pits += 1
				if pit_idx < 0:
					pit_idx = i
				if pit_ex.size() < 3:
					pit_ex.append("x %.0f -%.0f" % [float(i) * COL, dn])
		if S.deform[i] >= WorldCrater.DEFORM_CEIL - 0.01:
			clampU += 1
		if S.deform[i] <= WorldCrater.DEFORM_FLOOR + 0.01:
			clampL += 1
	# water
	var wet: int = 0
	var cliffs: int = 0
	var holes: int = 0
	var perched: int = 0
	var maxdepth: float = 0.0
	var cliff_ex: Array = []
	var hole_ex: Array = []
	var perch_ex: Array = []
	for i in range(NC):
		var w: float = S.water[i]
		var j: int = (i + 1) % NC
		var l: int = (i - 1 + NC) % NC
		if w >= WorldWater.MIN_DEPTH:
			wet += 1
			maxdepth = maxf(maxdepth, w)
			var si: float = G[i] + w
			if S.water[j] >= WorldWater.MIN_DEPTH and absf(G[j] + S.water[j] - si) > WATER_CLIFF:
				cliffs += 1
				if cliff_ex.size() < 3:
					cliff_ex.append("x %.0f surfaces %.0f / %.0f" % [float(i) * COL, si, G[j] + S.water[j]])
			if si > PERCH and S.base[i] > WorldWater.RESERVOIR_BASE and S.deform[i] == 0.0:
				perched += 1
				if perch_ex.size() < 3:
					perch_ex.append("x %.0f surface %.0f ground %.0f" % [float(i) * COL, si, G[i]])
		else:
			if S.water[l] >= WorldWater.MIN_DEPTH and S.water[j] >= WorldWater.MIN_DEPTH and G[i] < minf(G[l] + S.water[l], G[j] + S.water[j]) - 0.5 * BH:
				holes += 1
				if hole_ex.size() < 3:
					hole_ex.append("x %.0f ground %.0f beside surfaces %.0f / %.0f" % [float(i) * COL, G[i], G[l] + S.water[l], G[j] + S.water[j]])
	# buildings on the ground
	var tilted: int = 0
	var tilted_deep: int = 0
	var tilt_ex: Array = []
	var alive: int = 0
	for b in S.buildings:
		if not b.alive:
			continue
		alive += 1
		var c0: int = int(floor((b.x - b.w * 0.5) / COL))
		var c1: int = int(floor((b.x + b.w * 0.5) / COL))
		var lo: float = 1.0e9
		var hi: float = -1.0e9
		for c in range(c0, c1 + 1):
			var g: float = G[posmod(c, NC)]
			lo = minf(lo, g)
			hi = maxf(hi, g)
		if hi - lo > TILT:
			if b.row > 1.0:
				tilted_deep += 1   # a deep row's ground is the renderer's own per-row ground, not this heightfield
			else:
				tilted += 1
				if tilt_ex.size() < 3:
					tilt_ex.append("b%d row %d x %.0f varies %.0f over w %.0f" % [b.idx, int(b.row), b.x, hi - lo, b.w])
	# fighters in the ground
	var buried: int = 0
	for f in S.fighters:
		if f.state != "launched" and f.y < WorldTerrain.groundY(S, f.x) - 20.0 and f.y > WorldTerrain.groundY(S, f.x) - 1.0e6 and not (S.water[int(f.x / COL) % NC] > 0.0):
			buried += 1
	print("AUD seed %d tick %5d%s craters %d | steps>1bh %d new-steps %d (max %.0f at x %.0f) spikes %d pits %d clamp up %d low %d | wet %d (max depth %.0f, windows %d) water cliffs %d holes %d perched %d | bldgs alive %d tilted (rows 0-1) %d, deep rows %d | fighters in ground %d" % [seed, tick, " FINAL" if final else "", S.craters.size(), steep, newstep, maxstep, maxstep_x, spikes, pits, clampU, clampL, wet, maxdepth, S.waterWin.size(), cliffs, holes, perched, alive, tilted, tilted_deep, buried])
	if final:
		for pi in [pit_idx, spike_idx, step_idx]:
			if pi >= 0:
				var line: String = "    profile at column %d (x %.0f): " % [pi, float(pi) * COL]
				for k in range(-5, 6):
					var c: int = posmod(pi + k, NC)
					line += "[%d: base %.0f def %.0f rub %.0f] " % [k, S.base[c], S.deform[c], S.rubble[c]]
				print(line)
		for pair in [["new steps", newstep_ex], ["spikes", spike_ex], ["pits", pit_ex], ["water cliffs", cliff_ex], ["water holes", hole_ex], ["perched water", perch_ex], ["tilted buildings", tilt_ex]]:
			if not pair[1].is_empty():
				print("    %s: %s" % [pair[0], "; ".join(pair[1])])
