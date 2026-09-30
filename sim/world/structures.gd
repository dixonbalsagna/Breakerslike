class_name WorldStructures
## Buildings and civilians: the twin of structures.js (curH, damageBuilding, damageArea, explode, popNear,
## nearestBuilding), with a spatial index, depth rows (docs/world/buildings-in-depth.md), blast-levelled buildings that
## implode into their footprint and leave rubble heaps (its section 4c), and every death routed through
## WorldCollateral.kill (docs/world/collateral-caps.md).

const WS: float = SimConst.WS
## popNear reads 1 at this many living civilians within the radius: the original 70, times WS / PS because the population
## per building is scaled by that (terrain.gd _row) while the radius callers pass grows with WS.
const POP_NEAR_REF: float = 70.0 * SimConst.WS / SimConst.PS
## The nearest-building search skips buildings closer than this (the original 60, times WS: a building is WS times wider).
const NEAR_MIN: float = 60.0 * SimConst.WS
## Depth rows (a building's row field): 0 foreground, 1 the front street, 2 mid, 3 back. Until the director-chosen brunt
## (B2) replaces the incidental collision, only the front street collides with a launched fighter or is a BUILDING SMASH
## target: it is the row the prototype had on the fighter plane.
const PLANE_ROW: float = 1.0
## Blasts that are hits or impacts reach buildings this far in depth (from the plane to the nearest face); beams do not care.
const Z_REACH: float = 260.0 * WS
## Spatial index: buildings by the bucket of their centre. A query reaches every bucket within r plus the widest half width.
const BUCKETS: int = 128
const BUCKET_W: float = SimConst.W / 128.0
const MAX_HALF_W: float = 64.0 * WS / 2.0 + 8.0
# ---- implode and rubble (blast-levelled buildings, buildings-in-depth.md 4c) ----
const IMPLODE_SPEED: float = 1000.0 * WS   # the ripple's speed, units per second (cosmetic delay)
const IMPLODE_MAX_DELAY: float = 1.0
const IMPLODE_EVENT_CAP: int = 24          # building_fall events per blast; the rest fold into one summary
const BH: float = 75.0
const RUBBLE_H_FRAC: float = 0.10          # heap height as a share of the building's standing height
const RUBBLE_MIN: float = 0.5 * BH
const RUBBLE_MAX: float = 6.0 * BH
const RUBBLE_SPILL: float = 0.6            # the heap is 2 * this * w wide (a mound 1.2 w across the footprint)
const RUBBLE_BOWL_CAP: float = 0.3         # inside a fresh bowl the heap is at most this share of the local depth


## Standing height shrinks with damage to 30 percent of full; a destroyed building is gone (the rubble heap is ground).
static func curH(b) -> float:
	if not b.alive:
		return 1.0
	if b.floors >= WorldBrunt.FLOORS_MIN and b.fmask != (1 << b.floors) - 1:
		# a skyscraper with floors gone stands as tall as its top standing floor
		return float(WorldBrunt.topFloor(b) + 1) * WorldBrunt.floorH(b)
	return b.h * (0.3 + 0.7 * b.hp / b.maxhp)


## Build the spatial index (once per world; the buildings never move).
static func buildIndex(S: SimState) -> void:
	S.bIdx = []
	for i in range(BUCKETS):
		S.bIdx.append(PackedInt32Array())
	for i in range(S.buildings.size()):
		var b = S.buildings[i]
		b.idx = i
		var k: int = mini(int(SimWrap.wrap(b.x) / BUCKET_W), BUCKETS - 1)
		S.bIdx[k].append(i)


## The indices of the buildings whose centres are within r + the widest half width of x, in bucket order (then index).
static func near(S: SimState, x: float, r: float) -> Array:
	var out: Array = []
	var reach: float = r + MAX_HALF_W
	if reach * 2.0 >= SimConst.W:
		for i in range(S.buildings.size()):
			out.append(i)
		return out
	var k0: int = int(floor((SimWrap.wrap(x) - reach) / BUCKET_W))
	var k1: int = int(floor((SimWrap.wrap(x) + reach) / BUCKET_W))
	for k in range(k0, k1 + 1):
		for i in S.bIdx[posmod(k, BUCKETS)]:
			out.append(i)
	return out


## Depth from the fighter plane to the building's nearest face.
static func dz(b) -> float:
	return maxf(0.0, absf(b.z) - b.d * 0.5)


## local: the damage is a brunt's local floor damage (its people are handled by the floors), so only the collapse below applies.
static func damageBuilding(S: SimState, b, d: float, cause, mode: String = "burst", cx: float = 0.0, evt: float = 0.0, local: bool = false) -> void:
	if not b.alive or d <= 0.0:
		return
	var before: float = b.hp
	b.hp -= d
	var frac: float = SimMathx.jmin(before, d) / b.maxhp
	var dead: float = SimMathx.jmin(b.popAlive, b.pop * frac * 1.3)
	if dead > 0.0 and not local:
		WorldCollateral.kill(S, b.idx, dead, cause, evt, cx)
	var gy: float = WorldTerrain.groundY(S, b.x)
	if b.hp <= 0.0:
		b.alive = false
		S.world.structuresLost += 1.0
		if b.popAlive > 0.0:
			WorldCollateral.kill(S, b.idx, b.popAlive, cause, evt, cx)
		b.popAlive = 0.0
		SimFx.debris(S, b.x, gy + b.h * 0.5, 14, "#77808f" if b.kind == "tower" else "#8a6a4a", 620.0)
		SimFx.dust(S, b.x, gy, 5, "#a89f92")
		if b.h > 200.0:
			SimFx.shake(S, 10.0, b.x)
		var heap: float = _heap(S, b)
		var delay: float = 0.0
		if mode == "implode":
			delay = clampf(absf(SimWrap.sdx(cx, b.x)) / IMPLODE_SPEED, 0.0, IMPLODE_MAX_DELAY)
			if S.world.fallTick != float(S.tick):
				S.world.fallTick = float(S.tick)
				S.world.fallN = 0.0
				S.world.fallFold = 0.0
		if mode != "implode" or S.world.fallN < float(IMPLODE_EVENT_CAP):
			S.world.fallN += 1.0
			SimFx.buildingFall(S, b.idx, b.x, b.z, b.w, b.h, mode, delay, cx, heap, 1.0)
		else:
			S.world.fallFold += 1.0
	else:
		SimFx.debris(S, b.x, gy + curH(b), 4, "#77808f", 300.0)


## Bring building b down now (its hp is spent): everything left in it is lost or flees, and it falls in the given mode.
static func collapse(S: SimState, b, cause, mode: String, cx: float, evt: float) -> void:
	b.hp = minf(b.hp, 0.0)
	damageBuilding(S, b, 0.001, cause, mode, cx, evt, true)


## The heap a fallen building leaves: a smooth mound over its footprint, added to the ground (S.deform) and recorded in
## S.rubble. Inside a fresh bowl it is capped so it never quietly rebuilds the crater. Returns the crest height.
static func _heap(S: SimState, b) -> float:
	var NC: int = SimConst.NC
	var COL: float = SimConst.COL
	var H: float = clampf(RUBBLE_H_FRAC * b.h, RUBBLE_MIN, RUBBLE_MAX)
	var c0: int = int(floor(SimWrap.wrap(b.x) / COL))
	var here: float = S.deform[c0]
	if here < -0.5 * H:
		H = minf(H, RUBBLE_BOWL_CAP * (-here))
	if H <= 0.0:
		return 0.0
	var half: float = RUBBLE_SPILL * b.w
	var n: int = int(ceil(half / COL))
	for k in range(-n, n + 1):
		var i: int = (c0 + k + NC) % NC
		var u: float = absf(float(k) * COL) / half
		if u >= 1.0:
			continue
		var t: float = 1.0 - u * u
		var add: float = H * t * t
		var v: float = minf(WorldCrater.DEFORM_CEIL, S.deform[i] + add)
		var got: float = v - S.deform[i]
		S.deform[i] = v
		S.rubble[i] += got
	return H


## Standing buildings whose footprint is within r and whose top reaches y - 0.6 r take dmg (30 percent at r); trees
## within 0.7 r burn when y is less than r above their ground. A hit, impact or blast reaches only buildings within
## Z_REACH in depth of the plane; a beam (beam = true) ignores depth. The buildings levelled by it implode. evt is the
## caller's set-piece token for the collateral allowance (0 for none).
static func damageArea(S: SimState, x: float, y: float, r: float, dmg: float, cause, beam: bool = false, evt: float = 0.0) -> void:
	S.world.fallTick = -1.0
	for bi in near(S, x, r):
		var b = S.buildings[bi]
		if not b.alive:
			continue
		var d: float = absf(SimWrap.sdx(x, b.x)) - b.w / 2.0
		if d > r:
			continue
		if not beam and dz(b) > Z_REACH:
			continue
		var top: float = WorldTerrain.groundY(S, b.x) + curH(b)
		if y - r * 0.6 > top:
			continue
		damageBuilding(S, b, dmg * (1.0 - SimMathx.jclamp(d / r, 0.0, 1.0) * 0.7), cause, "implode", x, evt)
	if S.world.fallFold > 0.0:
		SimFx.buildingFall(S, -1, x, 0.0, 0.0, 0.0, "implode", 0.0, x, 0.0, S.world.fallFold)
		S.world.fallFold = 0.0
	for t in S.trees:
		if t.alive and absf(SimWrap.sdx(x, t.x)) < r * 0.7 and y < WorldTerrain.groundY(S, t.x) + r:
			t.alive = false
			SimFx.fire(S, t.x, WorldTerrain.groundY(S, t.x), 2)


static func explode(S: SimState, x: float, y: float, r: float, cause) -> void:
	SimFx.spark(S, x, y, 26, "#fff1b5", 900.0)
	SimFx.ring(S, x, y, r * 2.6, "#ffe2a0", 0.5, 20.0)
	SimFx.ring(S, x, y, r * 1.5, "#ff8a3d", 0.7, 10.0)
	SimFx.fire(S, x, y, 10)
	SimFx.debris(S, x, y, 10, "#6d6a66", 700.0)
	# The crater digs first, then the buildings it reaches are levelled and their heaps added.
	if y < WorldTerrain.groundY(S, x) + r:
		WorldCrater.dig(S, x, WorldCrater.explodeEnergy(cause.tier), cause, "beam", 0.0, 1.0, true)
	damageArea(S, x, y, r * 1.8, 130.0 + cause.tier * 110.0, cause)
	SimFx.shake(S, 16.0, x)
	S.dirS.stop = SimMathx.jmax(S.dirS.stop, 0.08)


## Living civilians in standing buildings centred within r of x, scaled so POP_NEAR_REF or more reads 1.
static func popNear(S: SimState, x: float, r: float) -> float:
	var s: float = 0.0
	for bi in near(S, x, r):
		var b = S.buildings[bi]
		if b.alive and absf(SimWrap.sdx(x, b.x)) < r:
			s += b.popAlive
	return SimMathx.jclamp(s / POP_NEAR_REF, 0.0, 1.0)


## Nearest standing building on the front street on one side (sign), more than NEAR_MIN and less than maxD away, whose
## top is above y - 40. Returns {"b", "d"} or null.
static func nearestBuilding(S: SimState, x: float, sign: float, maxD: float, y: float):
	var best = null
	var bd: float = 1e9
	for bi in near(S, x, maxD):
		var b = S.buildings[bi]
		if not b.alive or b.row != PLANE_ROW:
			continue
		var d: float = SimWrap.sdx(x, b.x) * sign
		if d > NEAR_MIN and d < maxD and d < bd and y < WorldTerrain.groundY(S, b.x) + curH(b) + 40.0:
			bd = d
			best = b
	return {"b": best, "d": bd} if best != null else null
