class_name WorldLanes
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
