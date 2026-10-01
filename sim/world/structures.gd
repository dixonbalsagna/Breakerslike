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
const RUBBLE_H_FRAC: float = 0.06          # heap height as a share of the building's standing height
const RUBBLE_MIN: float = 0.5 * BH
const RUBBLE_MAX: float = 4.0 * BH
const RUBBLE_SPILL: float = 1.0            # the heap is 2 * this * w wide (a mound 2.0 w across the footprint; above about 1.1 a low chain flight lands on the heap and plan and outcome differ)
const RUBBLE_SLOPE: float = 0.6            # the heap's steepest slope (crest height is capped to it): a ramp a skid can climb (ground-contact.md)
const RUBBLE_CREST_K: float = 1.54         # the steepest slope of the (1 - u^2)^2 profile is this times crest over half width
const RUBBLE_ROW_MAX: float = 1.0          # only buildings in rows up to this leave a heap on the ground (the fighter plane's); deeper rows' heaps are the event's cosmetic ones
const RING_KEEP: float = 0.25               # a building past a blast's ring cap is left at this share of its hit points
const RUBBLE_BOWL_CAP: float = 0.3         # inside a fresh bowl the heap is at most this share of the local depth


## Standing height shrinks with damage to 30 percent of full; a destroyed building is gone (the rubble heap is ground).
static func curH(b) -> float:
	if not b.alive:
		return 1.0
	if b.floors >= WorldBrunt.FLOORS_MIN and b.fmask != (1 << b.floors) - 1:
		# a skyscraper with floors gone stands as tall as its top standing floor
		return float(WorldBrunt.topFloor(b) + 1) * WorldBrunt.floorH(b)
	return b.h * (0.3 + 0.7 * b.hp / b.maxhp)


## The ground a building stands on: the highest ground over its footprint (T4; Rendering draws footings the same way), so a
## heap or a rim beside it never leaves it floating at one edge or half buried.
static func baseY(S: SimState, b) -> float:
	var NC: int = SimConst.NC
	var COL: float = SimConst.COL
	var c0: int = int(floor((b.x - b.w * 0.5) / COL))
	var c1: int = int(floor((b.x + b.w * 0.5) / COL)) + 1
	var m: float = -1.0e9
	for c in range(c0, c1 + 1):
		var i: int = posmod(c, NC)
		m = maxf(m, S.base[i] + S.deform[i])
	return m


## Which of the columns c0 - half .. c0 + half lie under a standing building's footing (its footprint and the one column each side
## that baseY reads)? 1 for those, 0 for the rest. The terrain relaxation leaves them alone and a heap never lands on them.
static func pinned(S: SimState, c0: int, half: int) -> PackedByteArray:
	var NC: int = SimConst.NC
	var COL: float = SimConst.COL
	var cnt: int = mini(2 * half + 1, NC)
	var out := PackedByteArray()
	out.resize(cnt)
	out.fill(0)
	var xc: float = float(c0) * COL
	for bi in near(S, xc, float(half) * COL + COL):
		var b = S.buildings[bi]
		if not b.alive:
			continue
		var k0: int = int(floor((b.x - b.w * 0.5) / COL)) - 1
		var k1: int = int(floor((b.x + b.w * 0.5) / COL)) + 2
		for c in range(k0, k1 + 1):
			var k: int = posmod(c - (c0 - half), NC)
			if k < cnt:
				out[k] = 1
	return out


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
static func damageBuilding(S: SimState, b, d: float, cause, mode: String = "burst", cx: float = 0.0, evt: float = 0.0, local: bool = false, keep: float = 0.0) -> void:
	# keep (the beam tier gate, balance-targets.md §15): the blow leaves the building standing at keep x maxhp at least.
	if keep > 0.0:
		d = SimMathx.jmin(d, b.hp - keep * b.maxhp)
	if not b.alive or d <= 0.0:
		return
	var before: float = b.hp
	b.hp -= d
	var frac: float = SimMathx.jmin(before, d) / b.maxhp
	var dead: float = SimMathx.jmin(b.popAlive, b.pop * frac * 1.3)
	if dead > 0.0 and not local:
		WorldCollateral.kill(S, b.idx, dead, cause, evt, cx)
	var gy: float = baseY(S, b)
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
## S.rubble. Only buildings in the fighter plane's rows (RUBBLE_ROW_MAX) add to the ground: the planet has one heightfield,
## and a heap from a building 38 fighter heights behind the plane used to stack with the front rows' on the plane itself
## (docs/world/terrain-audit.md). The mound is gentle (crest capped to RUBBLE_SLOPE), skips columns under standing buildings,
## and is relaxed to the angle of repose. Inside a fresh bowl it is capped so it never quietly rebuilds the crater. Returns the
## crest height (the cosmetic heap for a deeper row).
static func _heap(S: SimState, b) -> float:
	var NC: int = SimConst.NC
	var COL: float = SimConst.COL
	var half: float = RUBBLE_SPILL * b.w
	var H: float = minf(clampf(RUBBLE_H_FRAC * b.h, RUBBLE_MIN, RUBBLE_MAX), RUBBLE_SLOPE * half / RUBBLE_CREST_K)
	var c0: int = int(floor(SimWrap.wrap(b.x) / COL))
	var here: float = S.deform[c0]
	if here < -0.5 * H:
		H = minf(H, RUBBLE_BOWL_CAP * (-here))
	if H <= 0.0 or b.row > RUBBLE_ROW_MAX:
		return maxf(H, 0.0)
	var n: int = int(ceil(half / COL))
	var pin: PackedByteArray = pinned(S, c0, n)
	var lim: float = WorldCrater.REPOSE_SLOPE * COL
	for k in range(-n, n + 1):
		var i: int = (c0 + k + NC) % NC
		var u: float = absf(float(k) * COL) / half
		if u >= 1.0 or pin[k + n] == 1:
			continue
		# the mound tapers toward a standing building's footing, so it never leaves a wall against it
		var gap: int = 1000
		for q in range(-n, n + 1):
			if pin[q + n] == 1:
				gap = mini(gap, absi(q - k))
		var t: float = 1.0 - u * u
		var add: float = minf(H * t * t, float(gap) * RUBBLE_SLOPE * COL)
		var v: float = minf(WorldCrater.DEFORM_CEIL, S.deform[i] + add)
		var got: float = v - S.deform[i]
		S.deform[i] = v
		S.rubble[i] += got
	WorldCrater.relax(S, c0, n + WorldCrater.REPOSE_PAD)
	return H


## Standing buildings whose footprint is within r and whose top reaches y - 0.6 r take dmg (30 percent at r); trees
## within 0.7 r burn when y is less than r above their ground. A hit, impact or blast reaches only buildings within
## Z_REACH in depth of the plane; a beam (beam = true) ignores depth. The buildings levelled by it implode. evt is the
## caller's set-piece token for the collateral allowance (0 for none).
## capLeft and keep (the beam tier gate): once this call has levelled capLeft buildings, each further one is left standing
## at keep x maxhp. capLeft -1 is no cap. Returns the number of buildings the call levelled.
## reachMul: the area's growth by the causing fighter's tier (docs/world/structure-reach.md): -1 takes cause.ld.reach, a number
## uses that (the beam's path samples pass 1.0: the beam has its own tier gate). The whole blast scales, its falloff too.
## ringCap (cause.ld.reachRingCap, -1 off): at most this many buildings levelled beyond the old reach per call.
static func damageArea(S: SimState, x: float, y: float, r0: float, dmg: float, cause, beam: bool = false, evt: float = 0.0, capLeft: int = -1, keep: float = 0.0, reachMul: float = -1.0) -> int:
	var levelled: int = 0
	S.world.fallTick = -1.0
	var tf: float = 1.0
	var ringCap: int = -1
	if reachMul >= 0.0:
		tf = reachMul
	elif cause != null and "ld" in cause and cause.ld != null:
		tf = float(cause.ld.reachStructure[clampi(int(cause.tier), 1, 4) - 1])
		ringCap = int(cause.ld.reachRingCap)
	var r: float = r0 * tf
	var ringLevelled: int = 0
	for bi in near(S, x, r):
		var b = S.buildings[bi]
		if not b.alive:
			continue
		var d: float = absf(SimWrap.sdx(x, b.x)) - b.w / 2.0
		if d > r:
			continue
		if not beam and dz(b) > Z_REACH:
			continue
		var top: float = baseY(S, b) + curH(b)
		if y - r * 0.6 > top:
			continue
		var lost0: float = S.world.structuresLost
		var inRing: bool = d > r0
		var kp: float = keep if (capLeft >= 0 and levelled >= capLeft) else 0.0
		if inRing and ringCap >= 0 and ringLevelled >= ringCap:
			kp = RING_KEEP
		damageBuilding(S, b, dmg * (1.0 - SimMathx.jclamp(d / r, 0.0, 1.0) * 0.7), cause, "implode", x, evt, false, kp)
		if S.world.structuresLost > lost0:
			levelled += 1
			if inRing:
				ringLevelled += 1
	if S.world.fallFold > 0.0:
		SimFx.buildingFall(S, -1, x, 0.0, 0.0, 0.0, "implode", 0.0, x, 0.0, S.world.fallFold)
		S.world.fallFold = 0.0
	for t in S.trees:
		if t.alive and absf(SimWrap.sdx(x, t.x)) < r * 0.7 and y < WorldTerrain.groundY(S, t.x) + r:
			t.alive = false
			SimFx.fire(S, t.x, WorldTerrain.groundY(S, t.x), 2)
	return levelled


## sf, capLeft and keep (the beam tier gate): the structure-damage factor and the cap of the beam this blast belongs to,
## passed to damageArea. Returns the number of buildings levelled.
static func explode(S: SimState, x: float, y: float, r: float, cause, sf: float = 1.0, capLeft: int = -1, keep: float = 0.0) -> int:
	SimFx.spark(S, x, y, 26, "#fff1b5", 900.0)
	SimFx.ring(S, x, y, r * 2.6, "#ffe2a0", 0.5, 20.0)
	SimFx.ring(S, x, y, r * 1.5, "#ff8a3d", 0.7, 10.0)
	SimFx.fire(S, x, y, 10)
	SimFx.debris(S, x, y, 10, "#6d6a66", 700.0)
	# The crater digs first, then the buildings it reaches are levelled and their heaps added.
	if y < WorldTerrain.groundY(S, x) + r:
		WorldCrater.dig(S, x, WorldCrater.explodeEnergy(cause.tier), cause, "beam", 0.0, 1.0, true)
	var levelled: int = damageArea(S, x, y, r * 1.8, (130.0 + cause.tier * 110.0) * sf, cause, false, 0.0, capLeft, keep)
	SimFx.shake(S, 16.0, x)
	S.dirS.stop = SimMathx.jmax(S.dirS.stop, 0.08)
	return levelled


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
		if d > NEAR_MIN and d < maxD and d < bd and y < baseY(S, b) + curH(b) + 40.0:
			bd = d
			best = b
	return {"b": best, "d": bd} if best != null else null
