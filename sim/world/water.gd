class_name WorldWater
## A one-dimensional water model over the terrain columns. GDScript only.
##
## S.water holds the water depth of every column, so the surface is ground + depth, and the surface of standing water
## is sea level. The sea is a reservoir: a column whose original ground is below RESERVOIR_BASE (the prototype's sea
## rule, seaAt) is always full to sea level, and its depth follows the ground when a crater digs the sea floor. Every
## other column is dynamic. Water gets into a dynamic column only by flowing from a wet neighbour, and only if the
## column's ground is below WET_GROUND (the same -30 the sea rule uses, so a shore looks as it always did). So a hole
## fills only when an unbroken run of ground below WET_GROUND connects it to the sea: an inland crater stays dry
## however deep, and a bay dug at the coast fills. That is the whole "no flooding inland" argument;
## docs/world/craters-scorch-water.md has the proof and the test.
##
## Flow is a saturated two-column exchange, computed from the old state and applied afterwards (order-free). It runs
## only in windows around terrain that was just changed below sea level, every WATER_STEP_TICKS unfrozen ticks, and a
## window closes once it has settled. Nothing here draws a random number.

const SEA_LEVEL: float = 0.0
const RESERVOIR_BASE: float = -30.0   # base ground below this is open sea (WorldTerrain.seaAt)
const WET_GROUND: float = -30.0       # a dynamic column takes water only while its ground is below this
const MIN_DEPTH: float = 0.5          # less than this counts as dry
const FLOW_K: float = 0.4             # a link moves this share of the surface difference per step ...
const FLOW_MAX: float = 14.0          # ... at most this much depth per step ...
const FLOW_MIN: float = 0.25          # ... at least this much (or half the difference, if smaller), so the tail is not endless ...
const DONOR_SHARE: float = 0.5        # ... and at most this share of the donor column's water
const FLOW_EPS: float = 0.05          # surface differences below this do not flow
const STEP_TICKS: int = 2             # a flow step every this many unfrozen ticks
const PAD_COLS: int = 6               # a window extends this far past the changed columns
const SETTLE_EPS: float = 0.05        # a step that moves less than this in total counts as quiet
const SETTLE_STEPS: int = 3           # a window closes after this many quiet steps in a row
const MAX_AGE_STEPS: int = 600        # ... or after this many steps whatever happens (a bound on the cost)
const MAX_WINDOWS: int = 8            # more than this and the oldest window is dropped
const MAX_HALF: int = 120             # widest a window may grow (columns each side of its centre)
## Submerged hiding (cover.gd): 60 units under the surface, in water at least 100 deep. The prototype's rule for the sea.
const HIDE_BELOW_SURFACE: float = 60.0
const HIDE_MIN_DEPTH: float = 100.0
const DRY: float = -1e9               # surfaceAt() of a dry column
## Launched fighters skim: a descent shallower than SKIM_MAX_TAN (rise over run), faster than SKIM_MIN_SPEED, skips off
## the surface with vy reversed and scaled by SKIM_LIFT and vx scaled by SKIM_KEEP, up to SKIM_MAX times in a flight.
const SKIM_MIN_SPEED: float = 650.0
const SKIM_MAX_TAN: float = 0.5
const SKIM_LIFT: float = 0.55
const SKIM_KEEP: float = 0.8
const SKIM_MAX: float = 3.0


static func isReservoir(S: SimState, i: int) -> bool:
	return S.base[i] < RESERVOIR_BASE


## Depth of the water at x (the column it falls in), 0 when dry.
static func depthAt(S: SimState, x: float) -> float:
	var d: float = S.water[int(floor(SimWrap.wrap(x) / SimConst.COL))]
	return d if d >= MIN_DEPTH else 0.0


## Height of the water surface at x, or DRY.
static func surfaceAt(S: SimState, x: float) -> float:
	var i: int = int(floor(SimWrap.wrap(x) / SimConst.COL))
	var d: float = S.water[i]
	return S.base[i] + S.deform[i] + d if d >= MIN_DEPTH else DRY


## Start of a match: reservoir columns full to sea level. At the start every other column's ground is above WET_GROUND
## (that is what makes the reservoir the reservoir), so nothing else is wet; only craters make new water.
static func init(S: SimState) -> void:
	var NC: int = SimConst.NC
	S.water = PackedFloat32Array()
	S.water.resize(NC)
	S.water.fill(0.0)
	S.waterWin.clear()
	S.waterTick = 0.0
	for i in range(NC):
		if isReservoir(S, i):
			S.water[i] = maxf(0.0, SEA_LEVEL - (S.base[i] + S.deform[i]))


## Terrain changed around column c0 (half width cols) and the lowest ground there is minG: keep the reservoir
## columns full, and open a flow window if any of it is below sea level.
static func touched(S: SimState, c0: int, cols: int, minG: float) -> void:
	var NC: int = SimConst.NC
	var base: PackedFloat32Array = S.base
	var dfm: PackedFloat32Array = S.deform
	for k in range(-cols, cols + 1):
		var i: int = (c0 + k + NC) % NC
		if base[i] < RESERVOIR_BASE:
			S.water[i] = maxf(0.0, SEA_LEVEL - (base[i] + dfm[i]))
	if minG >= WET_GROUND:
		return
	var hw: int = mini(MAX_HALF, cols + PAD_COLS)
	# Water can only spread from water, and only into a dynamic column that is low enough: worth a window only if the
	# reach holds both some water and some such column.
	var near: bool = false
	var hole: bool = false
	for k in range(-hw, hw + 1):
		var i2: int = (c0 + k + NC) % NC
		if S.water[i2] >= MIN_DEPTH:
			near = true
		if base[i2] >= RESERVOIR_BASE and base[i2] + dfm[i2] < WET_GROUND:
			hole = true
	if not (near and hole):
		return
	for w in S.waterWin:
		var dc: int = absi(colDelta(c0, w[0]))
		if dc <= w[1] + hw:
			w[1] = mini(MAX_HALF, maxi(w[1], dc + hw))
			w[2] = 0
			return
	S.waterWin.append([c0, hw, 0, 0])
	if S.waterWin.size() > MAX_WINDOWS:
		S.waterWin.remove_at(0)


## Shortest signed column distance on the wrapped ring.
static func colDelta(a: int, b: int) -> int:
	var NC: int = SimConst.NC
	var d: int = posmod(b - a, NC)
	return d - NC if d * 2 > NC else d


## One tick of the water model. Call it once per unfrozen tick.
static func step(S: SimState) -> void:
	S.waterTick += 1.0
	if S.waterWin.is_empty() or int(S.waterTick) % STEP_TICKS != 0:
		return
	var NC: int = SimConst.NC
	var base: PackedFloat32Array = S.base
	var dfm: PackedFloat32Array = S.deform
	var wat: PackedFloat32Array = S.water
	var wi: int = 0
	while wi < S.waterWin.size():
		var w: Array = S.waterWin[wi]
		var lo: int = w[0] - w[1]
		var hi: int = w[0] + w[1]
		var flux := PackedFloat32Array()
		flux.resize(hi - lo + 1)   # flux[j - lo]: depth moving from column j to column j + 1 (negative: the other way)
		var b: int = posmod(lo, NC)
		var gb: float = base[b] + dfm[b]
		var rb: bool = base[b] < RESERVOIR_BASE
		var sb: float = SEA_LEVEL if rb and gb < SEA_LEVEL else gb + wat[b]
		for j in range(lo, hi):
			var a: int = b
			var ga: float = gb
			var ra: bool = rb
			var sa: float = sb
			b = posmod(j + 1, NC)
			gb = base[b] + dfm[b]
			rb = base[b] < RESERVOIR_BASE
			sb = SEA_LEVEL if rb and gb < SEA_LEVEL else gb + wat[b]
			if ra and rb:
				continue
			var diff: float = sa - sb
			if absf(diff) < FLOW_EPS:
				continue
			var ad: float = absf(diff)
			var f: float = clampf(FLOW_K * ad, minf(FLOW_MIN, 0.5 * ad), FLOW_MAX)
			if diff > 0.0:   # a to b
				if not ra:
					f = minf(f, DONOR_SHARE * wat[a])
				if not rb and gb >= WET_GROUND:
					f = 0.0
				flux[j - lo] = f
			else:            # b to a
				if not rb:
					f = minf(f, DONOR_SHARE * wat[b])
				if not ra and ga >= WET_GROUND:
					f = 0.0
				flux[j - lo] = -f
		var moved: float = 0.0
		for j in range(lo, hi + 1):
			var i: int = posmod(j, NC)
			if base[i] < RESERVOIR_BASE:
				continue
			var inflow: float = 0.0
			if j > lo:
				inflow += flux[j - 1 - lo]
			if j < hi:
				inflow -= flux[j - lo]
			if inflow != 0.0:
				wat[i] = maxf(0.0, wat[i] + inflow)
				moved += absf(inflow)
		S.water = wat
		w[3] += 1
		w[2] = w[2] + 1 if moved < SETTLE_EPS else 0
		if w[1] < MAX_HALF and (wat[posmod(lo, NC)] >= MIN_DEPTH or wat[posmod(hi, NC)] >= MIN_DEPTH):
			w[1] = mini(MAX_HALF, w[1] + PAD_COLS)   # the front reached the edge: follow it
		if w[2] >= SETTLE_STEPS or w[3] >= MAX_AGE_STEPS:
			S.waterWin.remove_at(wi)
		else:
			wi += 1
