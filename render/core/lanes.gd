class_name RenderLanes
extends RefCounted
## World's lane table for the renderer (ADR 0009; docs/world/fight-lanes-world.md sections 2 and 10): the band of two
## streets and two block rows, the street strips (sidewalk, kerb parking, carriageway) and the districts' x intervals.
## World's L1 will put it in state as S.lanes, a flat packed array. Until then stub() builds the same array from the
## plan's numbers and from where today's buildings stand, so the painted streets and the lane cue can be drawn and
## judged now. table() gives S.lanes once it exists. Reads the sim only; never writes it.
##
## The array (World's layout): a header of 13 floats (version, nLanes, nStrips, nDistricts, nAvenues, nRows, rowZ0,
## rowStep, zFront, zBack, offLanes, offStrips, offDistricts); lanes, 4 floats each (zTop, zBottom, kind: 0 street, 1
## block, 2 scenery, row); strips, 4 each (lane, zTop, zBottom, kind: 0 sidewalk, 1 kerb parking, 2 carriageway);
## districts, 6 each (x0, x1, look, laneMask, traffic, settlement); avenues, 3 each (x0, x1, district).

const HEADER := 13
const BH: float = 75.0
## The plan's band, in bh, front to back: [zTop, zBottom, kind, row].
const STUB_LANES: Array = [
	[12.5, 7.5, 2.0, 0.0], [5.0, -4.0, 0.0, -1.0], [-4.0, -12.0, 1.0, 1.0], [-12.0, -18.0, 0.0, -1.0],
	[-18.0, -27.0, 1.0, 2.0], [-34.0, -42.0, 2.0, 3.0],
]
## The plan's street strips, in bh: [lane, zTop, zBottom, kind]. They tile each street.
const STUB_STRIPS: Array = [
	[1.0, 5.0, 4.0, 0.0], [1.0, 4.0, 2.8, 1.0], [1.0, 2.8, -1.8, 2.0], [1.0, -1.8, -3.0, 1.0], [1.0, -3.0, -4.0, 0.0],
	[3.0, -12.0, -13.0, 0.0], [3.0, -13.0, -17.0, 2.0], [3.0, -17.0, -18.0, 0.0],
]
const STUB_GAP: float = 1500.0     # buildings farther apart than this along x are in different districts
const STUB_MARGIN: float = 220.0   # a district runs this far past its outermost buildings


## The lane table: World's when the state has one, else the stand-in.
static func table(S: SimState) -> PackedFloat32Array:
	if "lanes" in S:
		var t = S.get("lanes")
		if t is PackedFloat32Array and t.size() >= HEADER:
			return t
	return stub(S)


## The stand-in: the plan's lanes and strips, and a district wherever today's buildings stand in a run along x.
static func stub(S: SimState) -> PackedFloat32Array:
	var xs: Array = []
	for b in S.buildings:
		xs.append([b.x - b.w * 0.5, b.x + b.w * 0.5])
	xs.sort_custom(func(a, b): return a[0] < b[0])
	var spans: Array = []
	for r in xs:
		if spans.is_empty() or r[0] - spans[-1][1] > STUB_GAP:
			spans.append([r[0], r[1]])
		else:
			spans[-1][1] = maxf(spans[-1][1], r[1])
	var t := PackedFloat32Array()
	var off_lanes: int = HEADER
	var off_strips: int = off_lanes + 4 * STUB_LANES.size()
	var off_districts: int = off_strips + 4 * STUB_STRIPS.size()
	t.append_array(PackedFloat32Array([1.0, STUB_LANES.size(), STUB_STRIPS.size(), spans.size(), 0.0, 8.0, 300.0, -300.0, 5.0 * BH, -27.0 * BH, off_lanes, off_strips, off_districts]))
	for l in STUB_LANES:
		t.append_array(PackedFloat32Array([l[0] * BH, l[1] * BH, l[2], l[3]]))
	for s in STUB_STRIPS:
		t.append_array(PackedFloat32Array([s[0], s[1] * BH, s[2] * BH, s[3]]))
	for k in range(spans.size()):
		t.append_array(PackedFloat32Array([spans[k][0] - STUB_MARGIN, spans[k][1] + STUB_MARGIN, 0.0, 63.0, 0.0, k]))
	return t


## The street strips for the ground shader: (zTop, zBottom, kind, the street's centre z), at most `cap`.
static func strips(t: PackedFloat32Array, cap: int) -> Array:
	var out: Array = []
	var off_lanes: int = int(t[10])
	var off_strips: int = int(t[11])
	for k in range(mini(int(t[2]), cap)):
		var o: int = off_strips + 4 * k
		var lane: int = off_lanes + 4 * int(t[o])
		out.append(Vector4(t[o + 1], t[o + 2], t[o + 3], (t[lane] + t[lane + 1]) * 0.5))
	return out


## The districts' x intervals for the ground shader: (x0, x1, laneMask, look), at most `cap` (the widest first).
static func districts(t: PackedFloat32Array, cap: int) -> Array:
	var out: Array = []
	var off: int = int(t[12])
	for k in range(int(t[3])):
		var o: int = off + 6 * k
		out.append(Vector4(t[o], t[o + 1], t[o + 3], t[o + 2]))
	if out.size() > cap:
		out.sort_custom(func(a, b): return a.y - a.x > b.y - b.x)
		out.resize(cap)
	return out
