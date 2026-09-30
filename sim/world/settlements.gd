class_name WorldSettle
## Settlements, districts and landmarks from data/biomes/settlements.json (docs/world/districts-plan.md, slice D1).
##
## NOT YET WIRED: nothing in the tick or in genWorld calls this. It loads and checks the data file, and generates a
## settlement's buildings as plain dictionaries (the D1 window turns them into Building records once Simulation's grant for
## the new fields lands), so Art, Camera and the validator can see the city before the sim changes. It draws nothing from
## S.rng; every stream is derived from the layout seed, one per settlement, district and row, so editing one district never
## moves another's buildings. Every number is in the file.

const PATH: String = "res://data/biomes/settlements.json"
const LAYOUT_SEED: int = 4242               # the layout stream's seed (terrain.gd)
const BH: float = 75.0
const CEILING_FRAC: float = 0.85            # no building is taller than this share of the flight ceiling
const PLACES: Array = ["centre", "start", "end"]
const SHARE_EPS: float = 0.001

static var _data: Dictionary = {}
static var _errors: Array = []
static var _loaded: bool = false


## The parsed and checked file (loaded once). Errors are listed by errors(); on an error the data is empty.
static func data() -> Dictionary:
	if not _loaded:
		_load()
	return _data


static func errors() -> Array:
	if not _loaded:
		_load()
	return _errors


static func _err(msg: String) -> void:
	_errors.append(msg)


static func _load() -> void:
	_loaded = true
	_errors = []
	_data = {}
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		_err("settlements.json: cannot open " + PATH)
		return
	var d = JSON.parse_string(f.get_as_text())
	if not (d is Dictionary):
		_err("settlements.json: not a JSON object")
		return
	_validate(d)
	if _errors.is_empty():
		_data = d


## The 1-based landmark index of a key (0 is none), as stored on a building.
static func landmarkIndex(key: String) -> int:
	var lms: Array = data().get("landmarks", [])
	for i in range(lms.size()):
		if lms[i].key == key:
			return i + 1
	return 0


static func _num(v) -> bool:
	return v is float or v is int


static func _range2(v, where: String, lo: float, hi: float) -> void:
	if not (v is Array) or v.size() != 2 or not _num(v[0]) or not _num(v[1]):
		_err(where + ": expected [min, max]")
	elif v[0] > v[1] or v[0] < lo or v[1] > hi:
		_err(where + ": [%s, %s] outside %s to %s or not ascending" % [str(v[0]), str(v[1]), str(lo), str(hi)])


static func _hdist(v, where: String) -> void:
	if not (v is Dictionary):
		_err(where + ": expected {median, spread, min, max}")
		return
	for k in ["median", "spread", "min", "max"]:
		if not v.has(k) or not _num(v[k]):
			_err(where + ": missing " + k)
			return
	if v.min > v.max or v.median < v.min or v.median > v.max or v.spread < 0.0:
		_err(where + ": min <= median <= max and spread >= 0 needed")
	if v.max * BH > SimConst.CEILING * CEILING_FRAC:
		_err(where + ": max %s bh is above %.0f%% of the flight ceiling" % [str(v.max), CEILING_FRAC * 100.0])


static func _validate(d: Dictionary) -> void:
	if not d.has("pop_height_exp") or not _num(d.pop_height_exp) or d.pop_height_exp < 0.0 or d.pop_height_exp > 1.0:
		_err("pop_height_exp: a number from 0 to 1 (people grow with height to this power)")
	if not d.has("pop0") or not _num(d.pop0) or d.pop0 < 1:
		_err("pop0: a positive number of whole people is needed")
	var shapes: Array = d.get("shapes", [])
	if shapes.is_empty():
		_err("shapes: the closed list of render shapes is missing")
	var lm_keys: Array = []
	var lm_seen := {}
	for l in d.get("landmarks", []):
		var w: String = "landmarks/" + str(l.get("key", "?"))
		if not l.has("key") or lm_seen.has(l.key):
			_err(w + ": missing or repeated key")
			continue
		lm_seen[l.key] = true
		lm_keys.append(l.key)
		if not shapes.has(l.get("shape", "")):
			_err(w + ": unknown shape")
		if not l.has("height_bh") or not _num(l.height_bh) or l.height_bh * BH > SimConst.CEILING * CEILING_FRAC:
			_err(w + ": height_bh missing or above the ceiling share")
		if not l.has("width_bh") or not _num(l.width_bh) or l.width_bh < 0.5 or l.width_bh > 40.0:
			_err(w + ": width_bh missing or outside 0.5 to 40")
		for k in ["hp_mult", "pop_mult"]:
			if not l.has(k) or not _num(l[k]) or l[k] <= 0.0:
				_err(w + ": " + k + " must be positive")
	var pop_total: float = 0.0
	var ids := {}
	for s in d.get("settlements", []):
		var sid: String = str(s.get("id", "?"))
		if ids.has(sid) or sid == "?":
			_err("settlements: missing or repeated id " + sid)
		ids[sid] = true
		_range2(s.get("span", null), sid + "/span", 0.0, 9600.0)
		pop_total += float(s.get("pop_share", 0.0))
		var share: float = 0.0
		var names := {}
		for dd in s.get("districts", []):
			var dn: String = sid + "/" + str(dd.get("name", "?"))
			if names.has(dd.get("name", "?")):
				_err(dn + ": repeated district name")
			names[dd.get("name", "?")] = true
			share += float(dd.get("share", 0.0))
			var rows: Array = dd.get("rows", [])
			if rows.is_empty():
				_err(dn + "/rows: none")
			for rw in rows:
				if not (rw is int or rw is float) or int(rw) < 0 or int(rw) > 3:
					_err(dn + "/rows: rows are 0 to 3")
			var wsum: float = 0.0
			for kd in dd.get("kinds", []):
				wsum += float(kd.get("weight", 0.0))
				if not (kd.get("kind", "") in ["tower", "house"]):
					_err(dn + "/kinds: kind is tower or house")
				if not shapes.has(kd.get("shape", "")):
					_err(dn + "/kinds: unknown shape " + str(kd.get("shape", "")))
				if kd.has("height_bh"):
					_hdist(kd.height_bh, dn + "/kinds/height_bh")
				if kd.has("width_bh"):
					_range2(kd.width_bh, dn + "/kinds/width_bh", 0.5, 40.0)
			if wsum <= 0.0:
				_err(dn + "/kinds: weights sum to zero")
			_hdist(dd.get("height_bh", null), dn + "/height_bh")
			_range2(dd.get("width_bh", null), dn + "/width_bh", 0.5, 40.0)
			_range2(dd.get("depth_aspect", null), dn + "/depth_aspect", 0.2, 3.0)
			_range2(dd.get("gap_bh", null), dn + "/gap_bh", 0.0, 40.0)
			_range2(dd.get("block_bh", null), dn + "/block_bh", 4.0, 200.0)
			_range2(dd.get("avenue_bh", null), dn + "/avenue_bh", 1.0, 40.0)
			var rh = dd.get("row_h", null)
			if not (rh is Array) or rh.size() != 4:
				_err(dn + "/row_h: four factors, one per row")
			if not _num(dd.get("pop_density", null)) or dd.pop_density < 0.0:
				_err(dn + "/pop_density: a number >= 0")
			for lm in dd.get("landmarks", []):
				if not lm_keys.has(lm.get("key", "")):
					_err(dn + "/landmarks: unknown key " + str(lm.get("key", "")))
				if not (lm.get("place", "") in PLACES):
					_err(dn + "/landmarks: place is centre, start or end")
				if not (lm.get("row", -1) in rows):
					_err(dn + "/landmarks: the landmark's row is not one of the district's rows")
		if absf(share - 1.0) > SHARE_EPS:
			_err(sid + "/districts: shares sum to %.3f, not 1" % share)
	if absf(pop_total - 1.0) > SHARE_EPS:
		_err("settlements: pop_share sums to %.3f, not 1" % pop_total)


# ===================================================================== the generator (scratch: plain dictionaries)

static func _gauss(r: SimRng) -> float:
	return (r.next() + r.next() + r.next() + r.next() - 2.0) * 1.7320508


static func _pick(kinds: Array, u: float) -> Dictionary:
	var tot: float = 0.0
	for k in kinds:
		tot += float(k.weight)
	var t: float = u * tot
	for k in kinds:
		t -= float(k.weight)
		if t < 0.0:
			return k
	return kinds[kinds.size() - 1]


## The trimmed span [x start, x end] in world units of settlement s on a world whose platforms are already in S.base (the
## trim reads the ground; on the lifted ground it gives the same answer as WorldTerrain._platforms, which runs first).
static func span(S: SimState, s: Dictionary) -> Array:
	var PS: float = SimConst.PS
	var COL: float = SimConst.COL
	var NC: int = SimConst.NC
	var i0: int = int(s.span[0] * PS / COL)
	var i1: int = int(s.span[1] * PS / COL)
	while i0 < i1 and S.base[i0 % NC] < WorldTerrain.TRIM_G:
		i0 += 1
	while i1 > i0 and S.base[i1 % NC] < WorldTerrain.TRIM_G:
		i1 -= 1
	return [float(i0) * COL, float(i1) * COL]


## Generate settlement s (an entry of data().settlements). Returns {"buildings": Array of Dictionary, "span": [a, b],
## "districts": Array of {name, look, a, b, avenues: [[x0, x1], ...]}, "rejected": int}. A building is {x, w, d, h, kind,
## shape, row, z, district, landmark, seed, floors, maxhp, pop}. It changes nothing in S.
static func generate(S: SimState, s: Dictionary) -> Dictionary:
	var WS: float = SimConst.WS
	var sp: Array = span(S, s)
	var span_len: float = sp[1] - sp[0]
	var out: Array = []
	var dinfo: Array = []
	var rejected: int = 0
	var cum: float = 0.0
	var di: int = 0
	var lms: Array = data().landmarks
	for dd in s.districts:
		var da: float = sp[0] + cum * span_len
		cum += float(dd.share)
		var db: float = sp[0] + cum * span_len
		var dc: float = 0.5 * (da + db)
		var half: float = maxf(0.5 * (db - da), 1.0)
		# avenues: decided once per district, shared by every row
		var ra := SimRng.new(SimRng.deriveSeed(LAYOUT_SEED, "settle:%s:%s:avenues" % [s.id, dd.name]))
		var avenues: Array = []
		var ax: float = da
		while true:
			ax += ra.range_(dd.block_bh[0], dd.block_bh[1]) * BH
			if ax >= db - float(dd.avenue_bh[1]) * BH:
				break
			var aw: float = ra.range_(dd.avenue_bh[0], dd.avenue_bh[1]) * BH
			avenues.append([ax, ax + aw])
			ax += aw
		dinfo.append({"name": dd.name, "look": dd.look, "a": da, "b": db, "avenues": avenues})
		var first: int = out.size()
		for row in dd.rows:
			var r := SimRng.new(SimRng.deriveSeed(LAYOUT_SEED, "settle:%s:%s:row%d" % [s.id, dd.name, int(row)]))
			var x: float = da + r.range_(0.0, 6.0) * BH
			while x < db:
				# one fixed set of draws per candidate, used or not
				var uk: float = r.next()
				var kd: Dictionary = _pick(dd.kinds, uk)
				var uw: float = r.next()
				var ua: float = r.next()
				var g: float = _gauss(r)
				var ug: float = r.next()
				var seed_: float = r.next()
				var wr: Array = kd.width_bh if kd.has("width_bh") else dd.width_bh
				var hd: Dictionary = kd.height_bh if kd.has("height_bh") else dd.height_bh
				var w: float = (wr[0] + uw * (wr[1] - wr[0])) * BH
				var aspect: float = dd.depth_aspect[0] + ua * (dd.depth_aspect[1] - dd.depth_aspect[0])
				var gap: float = (dd.gap_bh[0] + ug * (dd.gap_bh[1] - dd.gap_bh[0])) * BH
				var blocked: bool = false
				for av in avenues:
					if x < av[1] and x + w > av[0]:
						x = av[1]
						blocked = true
						break
				if blocked:
					continue
				if x + w > db:
					break
				var cx: float = x + w * 0.5
				var cen: float = maxf(0.0, 1.0 - absf(cx - dc) / half)
				var h_bh: float = hd.median * SimDetMath.exp(hd.spread * g) * (1.0 + float(hd.get("centre_bump", dd.height_bh.centre_bump)) * cen)
				h_bh = clampf(h_bh, hd.min, hd.max) * float(dd.row_h[int(row)])
				h_bh = minf(h_bh, SimConst.CEILING * CEILING_FRAC / BH)
				if int(row) == 0:
					h_bh = minf(h_bh, WorldTerrain.FG_H_MAX_BH)
				x += w + gap
				if not WorldTerrain._footOk(S, cx, w):
					rejected += 1
					continue
				var h: float = h_bh * BH
				out.append({"x": cx, "w": w, "d": w * aspect, "h": h, "kind": kd.kind, "shape": kd.shape, "row": int(row),
					"z": WorldTerrain.ROW_Z_BH[int(row)] * BH + ((seed_ - 0.5) * 2.0 * WorldTerrain.ROW_JITTER_BH * BH if int(row) > 0 else 0.0),
					"district": di, "landmark": 0, "seed": seed_, "hp_mult": 1.0, "pop_mult": 1.0, "dens": float(dd.pop_density)})
		# landmarks: by rule, not by draw
		for lmr in dd.landmarks:
			var li: int = landmarkIndex(lmr.key)
			var lm: Dictionary = lms[li - 1]
			for n in range(int(lmr.get("count", 1))):
				var best: int = -1
				var bestd: float = 1.0e30
				var target: float = dc if lmr.place == "centre" else (da if lmr.place == "start" else db)
				for i in range(first, out.size()):
					var b: Dictionary = out[i]
					if b.landmark != 0 or b.row != int(lmr.row):
						continue
					var dist: float = absf(b.x - target)
					if dist < bestd:
						bestd = dist
						best = i
				if best < 0:
					continue
				var b2: Dictionary = out[best]
				b2.landmark = li
				b2.shape = lm.shape
				b2.h = float(lm.height_bh) * BH
				b2.w = float(lm.width_bh) * BH
				b2.d = b2.w * 0.9
				b2.kind = "tower" if lm.height_bh >= 12.0 else "house"
				b2.hp_mult = float(lm.hp_mult)
				b2.pop_mult = float(lm.pop_mult)
				# a plaza: the foreground row is cleared in front of it
				for i in range(out.size() - 1, first - 1, -1):
					var f: Dictionary = out[i]
					if f.row == 0 and absf(f.x - b2.x) < (f.w + b2.w) * 0.5 + 2.0 * BH:
						out.remove_at(i)
						if i < best:
							best -= 1
		di += 1
	# people: whole, by largest remainder, weighted by footprint x density x height to a data power (pop_height_exp)
	var pop: float = float(int(round(float(s.pop_share) * float(data().pop0))))
	var wts: Array = []
	var wsum: float = 0.0
	for b in out:
		var wt: float = (b.w / BH) * (b.d / BH) * b.dens * SimDetMath.pow(b.h / BH, float(data().pop_height_exp)) * b.pop_mult
		wts.append(wt)
		wsum += wt
	var shares: Array = []
	var given: int = 0
	for i in range(out.size()):
		var exact: float = pop * wts[i] / maxf(wsum, 0.000001)
		out[i].pop = int(floor(exact))
		given += int(out[i].pop)
		shares.append([exact - floor(exact), i])
	shares.sort_custom(func(p, q): return p[0] > q[0] or (p[0] == q[0] and p[1] < q[1]))
	var left: int = int(pop) - given
	for k in range(mini(maxi(left, 0), shares.size())):
		out[shares[k][1]].pop += 1
	for b in out:
		b.floors = WorldBrunt.floorCount(b.h)
		var h0: float = b.h / WS
		b.maxhp = h0 * (6.0 if b.kind == "tower" else 3.0) * b.hp_mult
	out.sort_custom(func(p, q): return p.x < q.x or (p.x == q.x and p.row < q.row))
	return {"buildings": out, "span": sp, "districts": dinfo, "rejected": rejected}
