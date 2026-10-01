class_name DirLocation
## Location variety (docs/director/location-variety-plan.md; balance-targets.md section 14 C): where the AI leads the fight
## between exchanges. It replaces ai.gd's hero lure.
## - The hero leads away from population, as the lure did. It also moves on once the fight has overstayed a biome: the
##   biome's time share exceeds its planet share by excessStart. The sea (at its surface) and the plains are destinations
##   again.
## - The villain, at prowlTier or above, leads toward towns once they have had less than their share of the fight.
## Destinations are costed in world units from data/director/location.json. No random draws. The population histogram is
## WorldCollateral's (S.popHist, one bucket per STEP).

const PATH: String = "res://data/director/location.json"
## The biome index order of S.dirS.biomeT (the schema's enum order).
const BIOMES: Array = ["ocean", "village", "plains", "city", "forest", "desert", "mountains"]
const STEP: float = 200.0 * SimConst.PS   # one histogram bucket: SimConst.W / BUCKETS
const BUCKETS: int = 48                    # WorldCollateral.HIST_BUCKETS
const WINDOW: int = 2                      # +-2 buckets approximate popNear(x, 900 * WS)
const EMPTY: float = 0.1                   # a bucket (or its window) at or below this population is empty ground
const LURE_START: float = 0.2              # the hero leaves while popNear(f.x, 900) is above this (the old lure's trigger)
const MIN_RECORD: float = 20.0             # seconds of recorded fight before the shares count (not in the schema yet)

static var _d = null
static var _text: String = ""
static var _planet := PackedFloat64Array()   # each biome's share of the planet, from WorldBiomes.SEG
static var _bucketBiome := PackedInt32Array()  # the biome index at each bucket's centre


static func _ensure() -> void:
	if _d != null:
		return
	_text = FileAccess.get_file_as_string(PATH)
	_d = JSON.parse_string(_text)
	if _d == null:
		push_error("DirLocation: could not parse " + PATH)
		_d = {}
	_planet.resize(BIOMES.size())
	_planet.fill(0.0)
	for sg in WorldBiomes.SEG:
		_planet[BIOMES.find(sg[2])] += (sg[1] - sg[0]) / SimConst.W
	_bucketBiome.resize(BUCKETS)
	for k in range(BUCKETS):
		_bucketBiome[k] = BIOMES.find(WorldBiomes.biomeAt(k * STEP + STEP / 2.0))


## The data file's text, for DirData.dataHash() (the replay header).
static func dataText() -> String:
	_ensure()
	return _text


## Once per tick from DirExchange.dirUpdate: dt goes to the biome under the fight (the fighters' shortest-arc midpoint),
## counted between exchanges while neither fighter is launched, so launches do not dilute it.
static func record(S: SimState, dt: float) -> void:
	if S.dirS.biomeT.size() != BIOMES.size():
		var t := PackedFloat64Array()
		t.resize(BIOMES.size())
		t.fill(0.0)
		S.dirS.biomeT = t
	if S.dirS.ex != null or dt <= 0.0:
		return
	var a = S.fighters[0]
	var b = S.fighters[1]
	if a.state == "launched" or b.state == "launched":
		return
	var mx: float = SimWrap.wrap(a.x + SimWrap.sdx(a.x, b.x) * 0.5)
	S.dirS.biomeT[BIOMES.find(WorldBiomes.biomeAt(mx))] += dt


## Where f leads the fight: +1 or -1, or 0 for no move. The role comes from the roster data: a menace meter makes the
## villain, an anguish meter the hero; a fighter with neither does not roam.
static func roam(S: SimState, f) -> float:
	_ensure()
	var hero: bool = f.hasAnguish and not f.hasMenace
	if not hero and not f.hasMenace:
		return 0.0
	var bt: PackedFloat64Array = S.dirS.biomeT
	var total: float = 0.0
	for v in bt:
		total += v
	var i0: int = mini(int(SimWrap.wrap(f.x) / STEP), BUCKETS - 1)
	var cur: int = BIOMES.find(WorldBiomes.biomeAt(f.x))
	var hist: PackedFloat32Array = S.popHist
	if hero:
		var crowded: bool = _window(hist, i0) > LURE_START
		if not bool(_d.oceanSurface) and (WorldTerrain.seaAt(S, f.x) or BIOMES[cur] == "ocean"):
			crowded = true   # without sea destinations, the old rule: the hero never stays over the sea
		var over: bool = total >= MIN_RECORD and bt.size() == BIOMES.size() and bt[cur] / total - _planet[cur] > float(_d.excessStart)
		if not crowded and not over:
			return 0.0
		return _search(S, f, hist, i0, cur, bt, total, _d.destinations.hero, true, crowded)
	# The villain's prowl.
	var towns: Array = _d.destinations.villain
	if f.tier < float(_d.prowlTier) or total < MIN_RECORD or bt.size() != BIOMES.size() or towns.has(BIOMES[cur]):
		return 0.0
	var town: float = 0.0
	var townP: float = 0.0
	for name in towns:
		var bi: int = BIOMES.find(name)
		town += bt[bi]
		townP += _planet[bi]
	if town / total >= townP or total - town < float(_d.prowlAfter):
		return 0.0
	return _search(S, f, hist, i0, cur, bt, total, towns, false, false)


## The cheapest destination each way round the planet: distance + popW x care x the population crossed + varietyW x the
## destination biome's excess share (signed, so a biome under its planet share draws) - keepW for the way f already moves. The hero takes empty buckets of its destination
## biomes (clear of towns when it is leaving a crowd, and another biome when it is only moving on); the villain takes the
## nearest bucket with people in each direction.
static func _search(S: SimState, f, hist: PackedFloat32Array, i0: int, cur: int, bt: PackedFloat64Array, total: float, dest: Array, hero: bool, crowded: bool) -> float:
	var popW: float = float(_d.popW) * f.care
	var varW: float = float(_d.varietyW)
	var keepW: float = float(_d.keepW)
	var shares: bool = total >= MIN_RECORD and bt.size() == BIOMES.size()
	var best: float = 0.0
	var bestCost: float = 1e18
	for s in [1, -1]:
		var popCost: float = 0.0
		var idx: int = i0
		for n in range(1, BUCKETS):
			idx += s
			if idx < 0:
				idx += BUCKETS
			elif idx >= BUCKETS:
				idx -= BUCKETS
			var bi: int = _bucketBiome[idx]
			var win: float = _window(hist, idx)
			var ok: bool = dest.has(BIOMES[bi])
			if ok and hero:
				var own: float = minf(hist[idx] / WorldStructures.POP_NEAR_REF, 1.0)
				ok = own <= EMPTY and (win <= EMPTY or not crowded) and (crowded or bi != cur)
				if ok and BIOMES[bi] != "ocean":
					var x: float = idx * STEP + STEP / 2.0
					ok = not S.base[int(x / SimConst.COL)] < WorldWater.RESERVOIR_BASE   # land, not a crater lake
			elif ok:
				ok = minf(hist[idx] / WorldStructures.POP_NEAR_REF, 1.0) > EMPTY
			if ok:
				var ex: float = (bt[bi] / total - _planet[bi]) if shares else 0.0   # signed: an under-visited biome draws
				var cost: float = n * STEP + popW * popCost + varW * ex - (keepW if SimMathx.jsign(f.vx) == float(s) else 0.0)
				if cost < bestCost:
					bestCost = cost
					best = float(s)
				if not hero:
					break   # the villain wants the nearest town each way; the crowd it crosses must not pull it past one
			popCost += win * STEP
	return best


## Population within +-WINDOW buckets of bucket i, as popNear reads it (POP_NEAR_REF or more is 1).
static func _window(hist: PackedFloat32Array, i: int) -> float:
	var sum: float = 0.0
	for k in range(i - WINDOW, i + WINDOW + 1):
		sum += hist[k + BUCKETS if k < 0 else (k - BUCKETS if k >= BUCKETS else k)]
	return minf(sum / WorldStructures.POP_NEAR_REF, 1.0)
