class_name WorldStructures
## Buildings and civilians: the twin of structures.js (curH, casualty, damageBuilding, damageArea, explode, popNear,
## nearestBuilding).


## Standing height shrinks with damage to 30 percent of full; a destroyed building leaves 9 units of rubble.
## popNear reads 1 at this many living civilians within the radius: the original 70, times WS / PS because the population
## per building is scaled by that (terrain.gd _row) while the radius callers pass grows with WS.
const POP_NEAR_REF: float = 70.0 * SimConst.WS / SimConst.PS
## The nearest-building search skips buildings closer than this (the original 60, times WS: a building is WS times wider).
const NEAR_MIN: float = 60.0 * SimConst.WS


static func curH(b) -> float:
	return b.h * (0.3 + 0.7 * b.hp / b.maxhp) if b.alive else 9.0


## Casualties feed the villain who caused them and the hero's anguish (QA-003: only the first hero in the list).
static func casualty(S: SimState, n: float, cause) -> void:
	if n <= 0.0:
		return
	S.world.casualties += n
	if cause != null and cause.role == "villain":
		cause.menace = SimMathx.jmin(100.0, cause.menace + n * 0.9)
		cause.power = SimMathx.jmin(100.0, cause.power + n * 0.09)
	var hero = null
	for f in S.fighters:
		if f.role == "hero":
			hero = f
			break
	if hero != null:
		hero.anguish = SimMathx.jmin(100.0, hero.anguish + n * (0.9 if cause == hero else 0.5))


static func damageBuilding(S: SimState, b, d: float, cause) -> void:
	if not b.alive or d <= 0.0:
		return
	var before: float = b.hp
	b.hp -= d
	var frac: float = SimMathx.jmin(before, d) / b.maxhp
	var dead: float = SimMathx.jmin(b.popAlive, b.pop * frac * 1.3)
	b.popAlive -= dead
	casualty(S, dead, cause)
	var gy: float = WorldTerrain.groundY(S, b.x)
	if b.hp <= 0.0:
		b.alive = false
		S.world.structuresLost += 1.0
		casualty(S, b.popAlive, cause)
		b.popAlive = 0.0
		SimFx.debris(S, b.x, gy + b.h * 0.5, 14, "#77808f" if b.kind == "tower" else "#8a6a4a", 620.0)
		SimFx.dust(S, b.x, gy, 5, "#a89f92")
		if b.h > 200.0:
			SimFx.shake(S, 10.0)
	else:
		SimFx.debris(S, b.x, gy + curH(b), 4, "#77808f", 300.0)


## Standing buildings whose footprint is within r and whose top reaches y - 0.6 r take dmg (30 percent at r); trees
## within 0.7 r burn when y is less than r above their ground.
static func damageArea(S: SimState, x: float, y: float, r: float, dmg: float, cause) -> void:
	for b in S.buildings:
		if not b.alive:
			continue
		var d: float = absf(SimWrap.sdx(x, b.x)) - b.w / 2.0
		if d > r:
			continue
		var top: float = WorldTerrain.groundY(S, b.x) + curH(b)
		if y - r * 0.6 > top:
			continue
		damageBuilding(S, b, dmg * (1.0 - SimMathx.jclamp(d / r, 0.0, 1.0) * 0.7), cause)
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
	damageArea(S, x, y, r * 1.8, 130.0 + cause.tier * 110.0, cause)
	if y < WorldTerrain.groundY(S, x) + r:
		WorldCrater.dig(S, x, WorldCrater.explodeEnergy(cause.tier), cause, "beam")
	SimFx.shake(S, 16.0)
	S.dirS.stop = SimMathx.jmax(S.dirS.stop, 0.08)


## Living civilians in standing buildings centred within r of x, scaled so 70 or more reads 1.
static func popNear(S: SimState, x: float, r: float) -> float:
	var s: float = 0.0
	for b in S.buildings:
		if b.alive and absf(SimWrap.sdx(x, b.x)) < r:
			s += b.popAlive
	return SimMathx.jclamp(s / POP_NEAR_REF, 0.0, 1.0)


## Nearest standing building on one side (sign), more than 60 and less than maxD away, whose top is above y - 40.
## Returns {"b", "d"} or null.
static func nearestBuilding(S: SimState, x: float, sign: float, maxD: float, y: float):
	var best = null
	var bd: float = 1e9
	for b in S.buildings:
		if not b.alive:
			continue
		var d: float = SimWrap.sdx(x, b.x) * sign
		if d > NEAR_MIN and d < maxD and d < bd and y < WorldTerrain.groundY(S, b.x) + curH(b) + 40.0:
			bd = d
			best = b
	return {"b": best, "d": bd} if best != null else null
