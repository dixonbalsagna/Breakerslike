"""L3 (true collisions, behind S.depthOn) applied to a tree that has slice T: python l3_patch.py <root>"""
import sys, json
R = sys.argv[1].rstrip('/') + '/'


def rw(p, fn):
    s = open(R + p, encoding='utf-8', newline='').read()
    cr = '\r\n' in s
    s = s.replace('\r\n', '\n')
    s = fn(s)
    open(R + p, 'w', encoding='utf-8', newline='').write(s.replace('\n', '\r\n') if cr else s)


def rep(s, old, new, n=1):
    assert s.count(old) >= 1, old[:90]
    return s.replace(old, new, n)


# ---------------------------------------------------------------- data: the body's half extents
p = R + 'data/biomes/lanes.json'
d = json.load(open(p, encoding='utf-8'))
d['body'] = {"rx_bh": 0.3, "ry_bh": 0.5, "rz_bh": 0.3}
open(p, 'w', encoding='utf-8').write(json.dumps(d, indent=2) + '\n')

# ---------------------------------------------------------------- lanes.gd
open(R + 'sim/world/lanes.gd', 'w', encoding='utf-8', newline='').write('''class_name WorldLanes
## The fight lanes (docs/world/fight-lanes-world.md, data/biomes/lanes.json): which lane a depth is in, the nearest clear street,
## and the half extents of a fighter's body for the swept test. Pure functions of the data and the buildings; nothing is drawn
## from S.rng. Depths in the file are fighter heights (1 bh = 75 units); the functions work in world units.

const PATH: String = "res://data/biomes/lanes.json"
const BH: float = 75.0
static var _d: Dictionary = {}
static var _loaded: bool = false


static func data() -> Dictionary:
	if not _loaded:
		_loaded = true
		var f := FileAccess.open(PATH, FileAccess.READ)
		if f != null:
			var j = JSON.parse_string(f.get_as_text())
			if j is Dictionary:
				_d = j
	return _d


## The body's half extents [rx, ry, rz] in units.
static func body() -> Array:
	var b: Dictionary = data().get("body", {})
	return [float(b.get("rx_bh", 0.3)) * BH, float(b.get("ry_bh", 0.5)) * BH, float(b.get("rz_bh", 0.3)) * BH]


## The index of the lane that holds depth z (units), or -1.
static func laneAt(z: float) -> int:
	var lanes: Array = data().get("lanes", [])
	for i in range(lanes.size()):
		var l: Dictionary = lanes[i]
		if z <= float(l.top) * BH and z >= float(l.bottom) * BH:
			return i
	return -1


## The nearest depth to z, at x, inside a street that no footprint overlaps for a body of half depth rz: z clamped into each street,
## the closest unblocked one wins; z itself when there is no street.
static func clearLane(S: SimState, x: float, z: float) -> float:
	var rz: float = body()[2]
	var rx: float = body()[0]
	var best: float = z
	var bestd: float = 1.0e30
	for l in data().get("lanes", []):
		if l.kind != "street":
			continue
		var lo: float = float(l.bottom) * BH + rz + 0.5
		var hi: float = float(l.top) * BH - rz - 0.5
		if hi < lo:
			continue
		var zc: float = clampf(z, lo, hi)
		var blockedHere: bool = false
		for bi in WorldStructures.near(S, x, rx):
			var b = S.buildings[bi]
			if not b.alive:
				continue
			if absf(SimWrap.sdx(x, b.x)) < b.w * 0.5 + rx and zc > b.z - b.d * 0.5 - rz and zc < b.z + b.d * 0.5 + rz:
				blockedHere = true
				break
		if blockedHere:
			continue
		var dd: float = absf(zc - z)
		if dd < bestd:
			bestd = dd
			best = zc
	return best
''')


# ---------------------------------------------------------------- structures.gd: along, sweep, blocked, blasts by plan distance
def structures(s):
    s = rep(s, "## Depth from the fighter plane to the building's nearest face.\n", '''## L3: the standing buildings whose x extent can meet a flight from xa to xb (padded by pad), as indices in ascending order. Made once
## per flight or per tick; the sweep then tests only these.
static func along(S: SimState, xa: float, xb: float, pad: float) -> Array:
	var d: float = SimWrap.sdx(xa, xb)
	var mid: float = SimWrap.wrap(xa + d * 0.5)
	var half: float = absf(d) * 0.5 + pad
	var out: Array = []
	for bi in near(S, mid, half):
		var b = S.buildings[bi]
		if b.alive and absf(SimWrap.sdx(mid, b.x)) - b.w * 0.5 <= half:
			out.append(bi)
	out.sort()
	return out


## The earliest crossing of the segment (x0, y0, z0) to (x1, y1, z1) by a body of half extents (rx, ry, rz) against the boxes of the
## buildings in list (a footprint in x and z, from the ground it stands on to its standing top): the slab method, one division an
## axis, no trigonometry. Ties go to the lower index. A box the body already overlaps at the start is reported at t = 0 with the
## face of least penetration, or skipped when skipInside is set (the hit test: a body leaving the building it just crossed).
## Returns {"hit": false} or {"hit": true, "b", "t" (0 to 1), "x", "y", "z", "face" ("end", "top", "bottom", "front", "back"), "nx", "nz"}.
static func sweep(S: SimState, list: Array, x0: float, y0: float, z0: float, x1: float, y1: float, z1: float, rx: float, ry: float, rz: float, skipInside: bool = false) -> Dictionary:
	var best: Dictionary = {"hit": false}
	var bt: float = 2.0
	var d0: float = SimWrap.sdx(x0, x1)
	var d1: float = y1 - y0
	var d2: float = z1 - z0
	for bi in list:
		var b = S.buildings[bi]
		if not b.alive:
			continue
		var cx: float = SimWrap.sdx(x0, b.x)
		var gy: float = baseY(S, b)
		var lo0: float = cx - b.w * 0.5 - rx
		var hi0: float = cx + b.w * 0.5 + rx
		var lo1: float = gy - ry
		var hi1: float = gy + curH(b) + ry
		var lo2: float = b.z - b.d * 0.5 - rz
		var hi2: float = b.z + b.d * 0.5 + rz
		var inside: bool = lo0 <= 0.0 and 0.0 <= hi0 and lo1 <= y0 and y0 <= hi1 and lo2 <= z0 and z0 <= hi2
		var t: float = 0.0
		var axis: int = -1
		var sgn: float = 0.0
		if inside:
			if skipInside:
				continue
			var pen0: float = minf(0.0 - lo0, hi0 - 0.0)
			var pen1: float = minf(y0 - lo1, hi1 - y0)
			var pen2: float = minf(z0 - lo2, hi2 - z0)
			if pen0 <= pen1 and pen0 <= pen2:
				axis = 0
				sgn = -1.0 if (0.0 - lo0) < (hi0 - 0.0) else 1.0
			elif pen1 <= pen2:
				axis = 1
				sgn = -1.0 if (y0 - lo1) < (hi1 - y0) else 1.0
			else:
				axis = 2
				sgn = -1.0 if (z0 - lo2) < (hi2 - z0) else 1.0
		else:
			var tmin: float = 0.0
			var tmax: float = 1.0
			var miss: bool = false
			for a in range(3):
				var p: float = 0.0 if a == 0 else (y0 if a == 1 else z0)
				var dd: float = d0 if a == 0 else (d1 if a == 1 else d2)
				var lo: float = lo0 if a == 0 else (lo1 if a == 1 else lo2)
				var hi: float = hi0 if a == 0 else (hi1 if a == 1 else hi2)
				if absf(dd) < 1.0e-9:
					if p < lo or p > hi:
						miss = true
						break
					continue
				var ta: float = (lo - p) / dd
				var tb: float = (hi - p) / dd
				var sg: float = -1.0
				if ta > tb:
					var tt: float = ta
					ta = tb
					tb = tt
					sg = 1.0
				if ta > tmin:
					tmin = ta
					axis = a
					sgn = sg
				if tb < tmax:
					tmax = tb
				if tmin > tmax:
					miss = true
					break
			if miss or axis < 0:
				continue
			t = tmin
		if t < bt:
			bt = t
			var face: String = "end" if axis == 0 else ("top" if axis == 1 and sgn > 0.0 else ("bottom" if axis == 1 else ("front" if sgn > 0.0 else "back")))
			best = {"hit": true, "b": bi, "t": t, "x": SimWrap.wrap(x0 + d0 * t), "y": y0 + d1 * t, "z": z0 + d2 * t, "face": face, "nx": sgn if axis == 0 else 0.0, "nz": sgn if axis == 2 else 0.0}
	return best


## The index of the lowest building whose box the body overlaps right now, or -1.
static func blocked(S: SimState, x: float, y: float, z: float, rx: float, ry: float, rz: float) -> int:
	for bi in along(S, x, x, rx):
		var b = S.buildings[bi]
		var gy: float = baseY(S, b)
		if absf(SimWrap.sdx(x, b.x)) <= b.w * 0.5 + rx and y >= gy - ry and y <= gy + curH(b) + ry and z >= b.z - b.d * 0.5 - rz and z <= b.z + b.d * 0.5 + rz:
			return bi
	return -1


## Depth from the fighter plane to the building's nearest face.
''')
    # blasts by plan distance
    s = rep(s, '''	var r: float = r0 * tf
	var ringLevelled: int = 0
''', '''	var r: float = r0 * tf
	var ringLevelled: int = 0
	var zc: float = float(cause.z) if (S.depthOn and cause != null and "z" in cause) else 0.0
''')
    s = rep(s, '''		var d: float = absf(SimWrap.sdx(x, b.x)) - b.w / 2.0
		if d > r:
			continue
		if not beam and dz(b) > Z_REACH:
			continue
''', '''		var d: float = absf(SimWrap.sdx(x, b.x)) - b.w / 2.0
		if d > r:
			continue
		if S.depthOn and not beam:
			# L3: a blast reaches a building by its distance in plan, from the blast's depth to the footprint's nearest point
			var gz: float = maxf(0.0, absf(zc - b.z) - b.d * 0.5)
			d = SimDetMath.hypot(maxf(d, 0.0), gz)
			if d > r:
				continue
		elif not beam and dz(b) > Z_REACH:
			continue
''')
    return s


rw('sim/world/structures.gd', structures)


# ---------------------------------------------------------------- brunt.gd
def brunt(s):
    # z function shared by stepZ and the predictor
    s = rep(s, "static func stepZ(S: SimState, f, dt: float) -> void:\n	if f.aimB >= 0:\n		var p: float = clampf(absf(SimWrap.sdx(f.aimX0, f.x)) / f.aimD, 0.0, 1.0)\n		f.z = f.aimZ0 + (f.aimZ1 - f.aimZ0) * p * p * (3.0 - 2.0 * p)\n",
            "static func zAt(x0: float, z0: float, z1: float, d: float, x: float) -> float:\n	var p: float = clampf(absf(SimWrap.sdx(x0, x)) / d, 0.0, 1.0)\n	return z0 + (z1 - z0) * p * p * (3.0 - 2.0 * p)\n\n\nstatic func stepZ(S: SimState, f, dt: float) -> void:\n	if f.aimB >= 0:\n		f.z = zAt(f.aimX0, f.aimZ0, f.aimZ1, f.aimD, f.x)\n")
    # arm: the waypoint starts at the fighter's own depth when depth is on
    s = rep(s, "	f.aimZ0 = 0.0\n	f.aimZ1 = 0.0\n", "	f.aimZ0 = f.z if S.depthOn else 0.0\n	f.aimZ1 = 0.0\n")
    # flightTo: z0 and the swept branch
    s = rep(s, "static func flightTo(S: SimState, x0: float, y0: float, vx0: float, vy0: float, trav: float, b) -> Dictionary:\n",
            "static func flightTo(S: SimState, x0: float, y0: float, vx0: float, vy0: float, trav: float, b, z0: float = 0.0) -> Dictionary:\n")
    s = rep(s, "	if y0 < WorldWater.surfaceAt(S, x0):\n		return {\"ok\": false}\n	var x: float = x0\n	var y: float = y0\n	var vx: float = vx0\n	var vy: float = vy0\n	var t: float = 0.0\n	for n in range(FLIGHT_STEPS):",
            "	if y0 < WorldWater.surfaceAt(S, x0):\n		return {\"ok\": false}\n	if S.depthOn:\n		return _flightToSwept(S, x0, y0, vx0, vy0, trav, b, z0, dir, edge, ahead)\n	var x: float = x0\n	var y: float = y0\n	var vx: float = vx0\n	var vy: float = vy0\n	var t: float = 0.0\n	for n in range(FLIGHT_STEPS):")
    s = rep(s, '''				return {"ok": true, "t": t - dt * (1.0 - fr), "x": edge, "y": yc, "vx": vx, "vy": vy, "spN": SimDetMath.hypot(vx / trav, vy), "dir": dir}''',
            '''				return {"ok": true, "t": t - dt * (1.0 - fr), "x": edge, "y": yc, "vx": vx, "vy": vy, "spN": SimDetMath.hypot(vx / trav, vy), "dir": dir, "aimD": ahead}''')
    s = rep(s, "# ===================================================================== the outcome of one hit (pure)\n", '''## L3: the same flight with the body's real extent, in depth: z follows the waypoint to the target's face exactly as stepZ does (from the
## position at the start of each step), and the first building the swept body meets must be the target, or the flight is not a plan.
static func _flightToSwept(S: SimState, x0: float, y0: float, vx0: float, vy0: float, trav: float, b, z0: float, dir: float, edge: float, ahead: float) -> Dictionary:
	var dt: float = SimConst.DT
	var kAir: float = SimDetMath.pow(0.55, dt)
	var body: Array = WorldLanes.body()
	var z1: float = faceZ(b)
	var aimD: float = maxf(ahead, 1.0)
	var list: Array = WorldStructures.along(S, x0, SimWrap.wrap(x0 + dir * (ahead + b.w + 200.0)), body[0] + 64.0)
	var x: float = x0
	var y: float = y0
	var vx: float = vx0
	var vy: float = vy0
	var t: float = 0.0
	for n in range(FLIGHT_STEPS):
		var ox: float = x
		var oy: float = y
		var zn: float = zAt(x0, z0, z1, aimD, ox)
		t += dt
		vy -= 1000.0 * dt
		vx *= kAir
		x = SimWrap.wrap(x + vx * dt)
		y += vy * dt
		if y < WorldWater.surfaceAt(S, x):
			return {"ok": false}
		var hr: Dictionary = WorldStructures.sweep(S, list, ox, oy, zn, x, y, zn, body[0], body[1], body[2], true)
		if hr.hit:
			if hr.b != b.idx:
				return {"ok": false}
			return {"ok": true, "t": t - dt * (1.0 - hr.t), "x": hr.x, "y": hr.y, "vx": vx, "vy": vy, "spN": SimDetMath.hypot(vx / trav, vy), "dir": dir, "aimD": ahead}
		if SimWrap.sdx(ox, x) * dir > 0.0 and SimWrap.sdx(edge, x) * dir > b.w + 2.0 * body[0]:
			return {"ok": false}
		if y <= WorldTerrain.groundY(S, x, zn):
			return {"ok": false}
	return {"ok": false}


# ===================================================================== the outcome of one hit (pure)
''')
    # aim passes the target's depth
    s = rep(s, "		var fr: Dictionary = flightTo(S, D.x, D.y, WorldSlide.launchVX(sign_, uy, force * tierF), uy * force * tierF, trav, b)",
            "		var fr: Dictionary = flightTo(S, D.x, D.y, WorldSlide.launchVX(sign_, uy, force * tierF), uy * force * tierF, trav, b, D.z)")
    # next passes the exit depth
    s = rep(s, "		var fr: Dictionary = flightTo(S, far, y, vx, vy, trav, cand)\n", "		var fr: Dictionary = flightTo(S, far, y, vx, vy, trav, cand, faceZ(b))\n")
    # hit: the chained aimD from the result
    s = rep(s, "			f.aimD = maxf(absf(SimWrap.sdx(f.x, nx.r.x)), 1.0)\n", "			f.aimD = maxf(float(nx.r.get(\"aimD\", absf(SimWrap.sdx(f.x, nx.r.x)))), 1.0)\n")
    # checkHit: swept branch
    s = rep(s, "static func checkHit(S: SimState, f, ox: float, oy: float) -> bool:\n	if f.aimB < 0:\n		return false\n",
            '''static func checkHit(S: SimState, f, ox: float, oy: float) -> bool:
	if S.depthOn:
		return _checkHitSwept(S, f, ox, oy)
	if f.aimB < 0:
		return false
''')
    s = rep(s, "## Resolve one hit on building b at height y on the near edge, and what happens to the fighter.\n", '''## L3: any building the body meets this tick (the swept body, from the position before the move to the position after, at the depth the
## tick was moved at), whether or not the launch was aimed at it. A body that starts inside a box (just out of the building it crossed)
## does not hit it again.
static func _checkHitSwept(S: SimState, f, ox: float, oy: float) -> bool:
	if f.flightHits > 0 and f.aimB < 0:
		return false   # the launch's chain is over (a rebound, the cap, nothing ahead): the rest of the flight is the ground's
	var body: Array = WorldLanes.body()
	var list: Array = WorldStructures.along(S, ox, f.x, body[0] + 64.0)
	if list.is_empty():
		return false
	var hr: Dictionary = WorldStructures.sweep(S, list, ox, oy, f.z, f.x, f.y, f.z, body[0], body[1], body[2], true)
	if not hr.hit:
		return false
	var b = S.buildings[hr.b]
	var dir: float = -1.0 if f.vx < 0.0 else 1.0
	if f.aimB != hr.b:
		f.aimB = hr.b   # an unaimed flight met it: the hit and its chain read the aim fields
	hit(S, f, b, hr.y, hr.x, dir)
	return true


## Resolve one hit on building b at height y on the near edge, and what happens to the fighter.
''')
    return s


rw('sim/world/brunt.gd', brunt)
print('L3 applied')
