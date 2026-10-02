class_name WorldLanes
## The fight lanes (docs/world/fight-lanes-world.md, data/biomes/lanes.json): the lane table the ground shader and the props read
## (build, S.lanes: derived, not hashed), which lane a depth is in, the nearest clear street, and the half extents of a fighter's body
## for the swept test. Pure functions of the data and the buildings; nothing is drawn from S.rng. Depths in the file are fighter
## heights (1 bh = 75 units); the functions work in world units.

const PATH: String = "res://data/biomes/lanes.json"
const BH: float = 75.0
const KIND: Dictionary = {"street": 0.0, "block": 1.0, "scenery": 2.0, "ridge": 3.0}
const STRIP_KIND: Dictionary = {"sidewalk": 0.0, "kerb": 1.0, "carriageway": 2.0}
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


## S.lanes (docs/world/fight-lanes-world.md section 10): a flat PackedFloat32Array, world units, z positive toward the camera.
## 0 to 12 header (version, nLanes, nStrips, nDistricts, nAvenues, nRows, rowZ0, rowStep, zFront, zBack, offLanes, offStrips,
## offDistricts); lanes 4 floats each (zTop, zBottom, kind 0 street / 1 block / 2 scenery / 3 ridge, row or -1); strips 4 each (lane,
## zTop, zBottom, kind 0 sidewalk / 1 kerb / 2 carriageway); districts 6 each (x0, x1, look index, lane mask, traffic, settlement);
## then avenues 3 each (x0, x1, district). dlist is the generator's district records over all settlements, west to east.
static func build(S: SimState, dlist: Array) -> PackedFloat32Array:
	var d: Dictionary = data()
	var lanes: Array = d.get("lanes", [])
	var strips: Array = d.get("strips", [])
	var looks: Array = WorldSettle.data().get("looks", [])
	var nav: int = 0
	for dd in dlist:
		nav += dd.avenues.size()
	var out := PackedFloat32Array()
	var offL: int = 13
	var offS: int = offL + 4 * lanes.size()
	var offD: int = offS + 4 * strips.size()
	out.resize(offD + 6 * dlist.size() + 3 * nav)
	out.fill(0.0)
	out[0] = 1.0
	out[1] = float(lanes.size())
	out[2] = float(strips.size())
	out[3] = float(dlist.size())
	out[4] = float(nav)
	out[5] = float(WorldTerrain.ROWS)
	out[6] = WorldTerrain.ROW_Z0
	out[7] = WorldTerrain.ROW_STEP
	out[8] = float(d.get("z_front", 5.0)) * BH
	out[9] = float(d.get("z_back", -27.0)) * BH
	out[10] = float(offL)
	out[11] = float(offS)
	out[12] = float(offD)
	var names := {}
	for i in range(lanes.size()):
		var l: Dictionary = lanes[i]
		names[l.name] = i
		var o: int = offL + 4 * i
		out[o] = float(l.top) * BH
		out[o + 1] = float(l.bottom) * BH
		out[o + 2] = float(KIND.get(l.kind, 2.0))
		out[o + 3] = float(l.row)
	for i in range(strips.size()):
		var st: Dictionary = strips[i]
		var o2: int = offS + 4 * i
		out[o2] = float(names.get(st.lane, -1))
		out[o2 + 1] = float(st.top) * BH
		out[o2 + 2] = float(st.bottom) * BH
		out[o2 + 3] = float(STRIP_KIND.get(st.kind, 0.0))
	var oa: int = offD + 6 * dlist.size()
	for i in range(dlist.size()):
		var dd: Dictionary = dlist[i]
		var mask: int = 0
		var blocks: bool = false
		for li in range(lanes.size()):
			var ln: Dictionary = lanes[li]
			if ln.kind != "street" and int(ln.row) in dd.rows:
				mask |= 1 << li
				blocks = blocks or ln.kind == "block"
		for li in range(lanes.size()):
			if lanes[li].kind == "street" and blocks:
				mask |= 1 << li
		var o3: int = offD + 6 * i
		out[o3] = float(dd.a)
		out[o3 + 1] = float(dd.b)
		out[o3 + 2] = float(looks.find(dd.look))
		out[o3 + 3] = float(mask)
		out[o3 + 4] = float(dd.get("traffic", 0.0))
		out[o3 + 5] = float(dd.get("settlement", 0))
		for av in dd.avenues:
			out[oa] = float(av[0])
			out[oa + 1] = float(av[1])
			out[oa + 2] = float(i)
			oa += 3
	return out
