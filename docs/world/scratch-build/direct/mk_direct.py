"""Shots meeting buildings in flight, the chip pool, deflected-shot landings in the air, mines.  python mk_direct.py <root>"""
import sys, json
R = sys.argv[1].rstrip('/') + '/'


def rw(p, fn):
    s = open(R + p, encoding='utf-8', newline='').read()
    cr = '\r\n' in s
    s = fn(s.replace('\r\n', '\n'))
    open(R + p, 'w', encoding='utf-8', newline='').write(s.replace('\n', '\r\n') if cr else s)


def rep(s, a, b):
    assert s.count(a) == 1, a[:80]
    return s.replace(a, b)


# state: the chip pool (hashed)
rw('sim/core/state.gd', lambda s: rep(s, '	var popAlive: float = 0.0\n\n\nclass TreeState', '	var popAlive: float = 0.0\n	var wear: float = 0.0      # hit points of unshown wear from light shots (WorldBlast.shotBuilding): it shows (and is paid in one blow) at chip.threshold of maxhp\n\n\nclass TreeState'))
rw('sim/core/hash.gd', lambda s: rep(s, '"floors", "fmask"]', '"floors", "fmask", "wear"]'))


# fx: a floor_hit that is a shot's
def fx(s):
    return rep(s, '## B2: a brunt hit floors of a skyscraper', '''## A shot hit floors of a skyscraper (WorldBlast.shotBuilding): the same event as a brunt's, victim -1, the shot's direction in ux, uy.
static func floorHitShot(S: SimState, b, floor_: int, n: int, outcome: String, ratio: float, y: float, slot: int, ux: float, uy: float) -> void:
	var e := _ev(S, "floor_hit")
	e.b = float(b.idx); e.floor = floor_; e.n = n; e.outcome = outcome; e.ratio = ratio
	e.x = b.x; e.y = y; e.z = WorldBrunt.faceZ(b)
	e.ux = ux; e.uy = uy
	e.kind = b.kind; e.owner = float(slot); e.victim = -1.0


## B2: a brunt hit floors of a skyscraper''')


rw('sim/core/fx.gd', fx)


# brunt: the outcome by damage
def brunt(s):
    s = rep(s, '''static func outcomeOf(S: SimState, b, y: float, spN: float, tier: float) -> Dictionary:
	var dmg: float = spN * (0.55 + 0.25 * tier) * BRUNT_MUL
''', '''static func outcomeOf(S: SimState, b, y: float, spN: float, tier: float) -> Dictionary:
	return outcomeDmg(S, b, y, spN * (0.55 + 0.25 * tier) * BRUNT_MUL)


## The same by the damage itself (a brunt's from its speed and tier, a shot's from its kind: WorldBlast.shotBuilding).
static func outcomeDmg(S: SimState, b, y: float, dmg: float) -> Dictionary:
''')
    return s


rw('sim/world/brunt.gd', brunt)


# shots: the per-tick test and the end cause
def shots(s):
    s = rep(s, '''		if sh.dead or hitOne:
			continue
''', '''		if sh.dead or hitOne:
			continue
		if sh.mode == LINE and WorldBlast.shotMeetsBuilding(S, sh, mx[i], my[i], rad[i]):   # World: a shot that flies into a building ends there
			end(S, sh, "building")
			continue
''')
    return s


rw('sim/core/shots.gd', shots)

BLAST_TAIL = '''


const STEP: float = 24.0   # the sample spacing along a shot's path this tick (the narrowest building is wider)


## Does the shot (already moved this tick by dx, dy; radius r) fly into a standing building of the front street? If it does, the building takes
## the shot's direct hit here (it reaches a building whose nearest face is within Z_REACH of its plane, as every blast does) and the call returns true (the caller ends the shot). A shot that meets a fighter first never gets here.
static func shotMeetsBuilding(S: SimState, sh, dx: float, dy: float, r: float) -> bool:
	var D: Dictionary = data()
	if D.is_empty() or not D.get("direct", {}).has(sh.kind):
		return false
	var len: float = SimDetMath.hypot(dx, dy)
	var x0: float = sh.x - dx
	var y0: float = sh.y - dy
	var mxm: float = SimWrap.wrap(x0 + dx * 0.5)
	var ylo: float = minf(y0, sh.y) - r
	var yhi: float = maxf(y0, sh.y) + r
	var hit = null
	var hitS: float = 2.0
	for i in WorldStructures.near(S, mxm, len * 0.5 + r):
		var b = S.buildings[i]
		if not b.alive or absf(SimWrap.sdx(mxm, b.x)) > b.w * 0.5 + len * 0.5 + r:
			continue
		if maxf(0.0, absf(sh.z - b.z) - b.d * 0.5) > WorldStructures.Z_REACH:
			continue
		if ylo > WorldTerrain.groundY(S, b.x) + b.h + 200.0 + r:   # well above it (the cheap reject: the ground here, the building's full height, a heap's worth)
			continue
		var gy: float = WorldStructures.baseY(S, b)
		var top: float = gy + WorldStructures.curH(b) + r
		if ylo > top or yhi < gy - 5.0:
			continue
		# the first sample along the path that is inside this building (the nearest to the start wins among buildings)
		var n: int = maxi(1, int(ceil(len / STEP)))
		for s in range(0, n + 1):
			var px: float = SimWrap.wrap(x0 + dx * float(s) / float(n))
			var py: float = y0 + dy * float(s) / float(n)
			if absf(SimWrap.sdx(px, b.x)) <= b.w * 0.5 + r and py >= gy - 5.0 and py <= top:
				var fs: float = float(s) / float(n)
				if fs < hitS:
					hitS = fs
					hit = b
				break
	if hit != null:
		var px2: float = SimWrap.wrap(x0 + dx * hitS)
		var py2: float = y0 + dy * hitS
		shotBuilding(S, sh.owner, sh.kind, sh.power, hit, px2, py2, sh.z, sh.vx, sh.vy)
		sh.x = px2
		sh.y = py2
		return true
	return false


## A shot hits building b at (x, y): the damage by the shot's kind and the shooter's tier, through the building's floors (a skyscraper loses
## floors: dent, crack or punch, and a punched span pancakes what stands above it) or its hit points (a house). A light shot (chip in the data)
## first piles into the building's wear pool (nothing shows); at chip.threshold of maxhp the pool is paid in one blow. Returns {"outcome",
## "dmg", "levelled"}: outcome chip (nothing shown), or what the floors did, or hit/collapse for a plain building.
static func shotBuilding(S: SimState, slot: int, kind: String, power: float, b, x: float, y: float, z: float, vx: float, vy: float) -> Dictionary:
	var D: Dictionary = data()
	var h: Dictionary = D.direct[kind]
	var f = S.fighters[slot]
	var ti: int = clampi(int(f.tier), 1, 4) - 1
	var dmg: float = float(h.damage) * float(D.tierDamage[ti])
	var res := {"outcome": "hit", "dmg": dmg, "levelled": false}
	var k: Dictionary = D.kinds[kind]
	var sp: float = maxf(SimDetMath.hypot(vx, vy), 0.000001)
	SimFx.ring(S, x, y, float(k.ringR) * 0.5, "#ffffff", 0.3, 8.0, z)
	SimFx.shake(S, float(k.shake) * 0.5, x, z)
	if bool(h.get("chip", false)):
		b.wear += dmg
		if b.wear < float(D.chip.threshold) * b.maxhp:
			res.outcome = "chip"
			SimFx.debris(S, x, y, 2, "#77808f", 300.0, z)
			return res
		dmg = b.wear   # it shows: the pool is paid in one blow
		b.wear = 0.0
		res.dmg = dmg
		res.outcome = "wound"
	var by = f
	if b.floors >= WorldBrunt.FLOORS_MIN:
		var oc: Dictionary = WorldBrunt.outcomeDmg(S, b, y, dmg)
		var c: Dictionary = _floors(S, b, oc, by, x, y, slot, vx / sp, vy / sp)
		res.outcome = "collapse" if c.collapse else ("pancake" if c.pancake else oc.outcome)
		res.levelled = not b.alive
	else:
		WorldStructures.damageBuilding(S, b, dmg, by, "burst", x, 0.0)
		res.levelled = not b.alive
		if res.levelled:
			res.outcome = "collapse"
	SimFx.debris(S, x, y, int(k.debris), "#77808f", 500.0, z)
	SimFx.dust(S, x, y, int(k.dust), "", z)
	return res


## WorldBrunt.applyFloors for a shot: the same rules (punch clears the floors it covers, crack and dent keep damage on them, the core wears by
## CORE_SHARE, a punched span pancakes the floors above), with no fighter in the event.
static func _floors(S: SimState, b, oc: Dictionary, by, cx: float, y: float, slot: int, ux: float, uy: float) -> Dictionary:
	var res := {"pancake": false, "collapse": false}
	var F: int = b.floors
	if b.fdmg.size() != F:
		b.fdmg = PackedFloat32Array()
		b.fdmg.resize(F)
		b.fdmg.fill(0.0)
	var popF: float = WorldBrunt.floorPop(b)
	var lowest: int = oc.k
	if oc.outcome == "punch":
		var cleared: int = 0
		for j in oc.hit:
			b.fmask = b.fmask & ~(1 << j)
			b.fdmg[j] = 0.0
			cleared += 1
			lowest = mini(lowest, j)
		if cleared > 0:
			WorldCollateral.kill(S, b.idx, popF * float(cleared), by, 0.0, cx, lowest)
		SimFx.floorHitShot(S, b, lowest, cleared, "punch", oc.ratio, y, slot, ux, uy)
	elif oc.outcome == "crack":
		for j in oc.hit:
			b.fdmg[j] += oc.dmg
		var d: float = popF * float(oc.hit.size()) * minf(1.0, oc.ratio * WorldBrunt.FLOOR_DEATH)
		if d > 0.0:
			WorldCollateral.kill(S, b.idx, d, by, 0.0, cx, oc.hit[0])
		SimFx.floorHitShot(S, b, oc.hit[0], 0, "crack", oc.ratio, y, slot, ux, uy)
	else:
		for j in oc.hit:
			b.fdmg[j] += oc.dmg
		SimFx.floorHitShot(S, b, oc.hit[0] if oc.hit.size() > 0 else oc.k, 0, "dent", oc.ratio, y, slot, ux, uy)
	b.hp -= WorldBrunt.CORE_SHARE * oc.dmg
	if b.hp <= 0.0:
		res.collapse = true
		WorldStructures.collapse(S, b, by, "burst", cx, 0.0)
		return res
	if oc.outcome == "punch":
		var pk: Dictionary = WorldBrunt.pancake(S, b, by, 0.0, cx, null)
		res.pancake = pk.pancake
		res.collapse = pk.collapse
	return res


## A mine's blast (a ground mine rests on the ground, an air mine hangs at y): the shot's own blast by the mine's kind row, a vertical one.
static func mineBlast(S: SimState, slot: int, x: float, y: float, z: float) -> Dictionary:
	return shotHit(S, slot, "mine", x, y, z, 0.0, -1.0, "ground")
'''


def blast(s):
    # air bursts: the crater scales with the height above the ground
    s = rep(s, '''	var E: float = float(k.craterE) * float(D.tierEnergy[ti])
''', '''	var E: float = float(k.craterE) * float(D.tierEnergy[ti])
	var air: float = maxf(0.0, y - g)   # a burst above the ground (a mine in the air, a shot that ran out of life): the bowl fades with the height
	if air > 0.0:
		E *= maxf(0.0, 1.0 - air / (float(k.get("airReach", 6.0)) * 75.0))
''')
    s = rep(s, '''	res.crater = WorldCrater.dig(S, x, E, f, "impact", vx / sp, absf(vy) / sp, false, z)
''', '''	if E > 0.02:
		res.crater = WorldCrater.dig(S, x, E, f, "impact", vx / sp, absf(vy) / sp, false, z)
''')
    return s.rstrip('\n') + BLAST_TAIL


rw('sim/world/blast.gd', blast)

p = R + 'data/biomes/blast.json'
d = json.load(open(p, encoding='utf-8'))
d['direct'] = {
    "bolt": {"damage": 24, "chip": True},
    "shard": {"damage": 14, "chip": True},
    "arc": {"damage": 150},
    "charged": {"damage": 300},
    "lob": {"damage": 220},
}
d['chip'] = {"threshold": 0.12}
d['kinds']['mine'] = {"craterE": 0.6, "radius": 130, "damage": 130, "debris": 8, "dust": 3, "ringR": 340, "shake": 5.0, "splash": 8, "airReach": 6.0}
for kk in ("bolt", "shard", "arc", "charged", "lob"):
    d['kinds'][kk]["airReach"] = 4.0
open(p, 'w', encoding='utf-8').write(json.dumps(d, indent=2) + '\n')
print('ok')
