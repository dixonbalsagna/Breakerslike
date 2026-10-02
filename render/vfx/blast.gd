class_name VfxBlast
extends RefCounted
## Blast amplification (docs/vfx/power-language.md idea 2): a crater (the sim's `crater` event) is bigger to look at the higher the tier
## of the fighter who caused it, without any fighter being faster. On top of earth.gd's ejecta it adds, by the causer's tier: a flat
## shock ring running out along the ground, chunks thrown from the rim (some lobbed high so they come down a second later), a dust
## dome with a wide skirt, a fall of small pebbles half a second later, and the bowl's dust sliding down its slopes while it settles.
## Tier 1 adds nothing; tier 2 a little; tier 3 clearly more; tier 4 the most (and a second ring). Scaled too by the bowl's own size.
## Everything is a spawn into the shared debris pool (no new draw call), from the cosmetic stream vfx.dust, with a fixed number of
## draws a crater, so the stream does not depend on quality. Presentation only: it reads the event and the fighter's tier.
##
## Legal's stacking rule (docs/legal/rule-of-cool-screen.md): this is a one-off event of mark 4 (rubble, ground, wind), never a held
## state. Craters from ground-level power-ups (cause "powerup") come at the end of a charge, next to the crouch and the scream, so
## they stay as they were (a separate flag, default off, until Legal clears them); a fighter who is charging gets none.

const DEFAULTS: Dictionary = {
	"blast": {"mult_t1": 0.0, "mult_t2": 0.45, "mult_t3": 1.0, "mult_t4": 1.7, "r_ref": 160.0, "rs_min": 0.6, "rs_max": 2.2, "gap_s": 0.25,
		"ring_life": 0.5, "ring_r0": 0.75, "ring_r1": 1.7, "ring_r1_t": 0.5, "ring2_delay": 0.12, "chunks": 4.0, "lob": 0.3, "pebbles": 6.0, "pebble_delay": 0.5,
		"dome": 5.0, "settle": 4.0, "settle_from": 0.4, "settle_to": 1.6, "chunk_min": 10.0, "chunk_max": 22.0},
}

static var _data: Dictionary = {}
static var _loaded: bool = false

var made: int = 0                 # craters amplified (the tests)
var skipped: int = 0              # skipped: tier 1, no owner, a power-up, charging, too soon
var rings: int = 0
var chunks: int = 0
var _last_at := [-1000.0, -1000.0]   # per owner slot: the effects-clock time of the last one


static func warm() -> void:
	if _loaded:
		return
	_loaded = true
	var path := "res://data/vfx/power.json"
	if FileAccess.file_exists(path):
		var v = JSON.parse_string(FileAccess.get_file_as_string(path))
		if v is Dictionary:
			_data = v


static func p(group: String, key: String) -> float:
	warm()
	var g = _data.get(group)
	if g is Dictionary and g.has(key):
		return float(g[key])
	return float(DEFAULTS[group][key])


func reset() -> void:
	made = 0
	skipped = 0
	rings = 0
	chunks = 0
	_last_at = [-1000.0, -1000.0]
	warm()


## The tier's share of the full effect: 0 for tier 1.
static func mult_for(tier: int) -> float:
	return p("blast", "mult_t%d" % clampi(tier, 1, 4))


## A `crater` event (x, y, r, depth, rim, energy, cause, owner, special). debris: the shared pool; now: the effects clock. powerup_ok:
## the flag that lets ground-level power-up craters through (default off).
func on_crater(S: SimState, e, debris: VfxDebris, now: float, powerup_ok: bool) -> void:
	var owner: int = int(e.owner)
	if owner < 0 or owner >= S.fighters.size():
		skipped += 1
		return
	var f = S.fighters[owner]
	var cause: String = String(e.get("cause") if e.get("cause") != null else "impact")
	if cause == "powerup" and not powerup_ok:
		skipped += 1
		return
	if f.state == "charging" or f.beamCharge != null:
		skipped += 1
		return
	var m: float = mult_for(VfxReact.tier_of(f))
	if m <= 0.0:
		skipped += 1
		return
	if now - float(_last_at[owner]) < p("blast", "gap_s"):
		skipped += 1
		return
	_last_at[owner] = now
	made += 1
	var x: float = float(e.x)
	var y: float = float(e.y)
	var r: float = maxf(float(e.r), 40.0)
	var z: float = float(e.get("z") if e.get("z") != null else 0.0)
	var rs: float = clampf(r / p("blast", "r_ref"), p("blast", "rs_min"), p("blast", "rs_max"))
	var k: float = m * rs
	var q: float = VfxLook.QUALITY_SHARDS[clampi(debris.quality, 0, 2)] * (0.5 if debris.reduced else 1.0)
	var biome: String = VfxPalette.biome_key(x)
	var tones: Array = VfxEarth.tones_for_surface("soil", x)
	var rd: SimRng = debris._rd
	var sws: float = sqrt(SimConst.WS)
	# 1. The shock ring along the ground, and for tier 4 a second one behind it. Not with reduced motion (it is a motion).
	if not debris.reduced:
		debris._biome = biome
		var life: float = p("blast", "ring_life") * (0.8 + 0.2 * m)
		var r1: float = r * (p("blast", "ring_r1") + p("blast", "ring_r1_t") * m)
		var r0: float = r * p("blast", "ring_r0")
		debris._ring(x, y + 18.0, z + 8.0, r0, (r1 - r0) / life, life, true)
		rings += 1
		if m >= 1.5:
			var j := VfxDebris.Job.new()
			j.at = now + p("blast", "ring2_delay")
			j.kind = "blast_ring"
			j.a = {"x": x, "y": y + 18.0, "z": z + 8.0, "r0": r0 * 0.9, "growth": (r1 * 0.85 - r0 * 0.9) / (life * 0.9), "life": life * 0.9}
			debris.jobs.append(j)
			rings += 1
	# 2. Chunks thrown from the rim, bigger and more by tier; some lobbed so high that they come down about a second later.
	var nch: int = clampi(int(round(p("blast", "chunks") * k)), 0, 18)
	var csz: float = 0.8 + 0.2 * m
	for i in range(nch):
		var side: float = 1.0 if rd.next() < 0.5 else -1.0
		var off: float = side * r * rd.range_(0.7, 1.1)
		var lob: bool = rd.next() < p("blast", "lob")
		var vx: float = side * rd.range_(120.0, 420.0) * (0.7 + 0.3 * sqrt(m)) * sws
		var vy: float = (rd.range_(1100.0, 1700.0) if lob else rd.range_(450.0, 1000.0)) * (0.8 + 0.2 * sqrt(m)) * sws
		var sz: float = rd.range_(p("blast", "chunk_min"), p("blast", "chunk_max")) * csz
		var life2: float = (rd.range_(2.0, 3.0) if lob else rd.range_(1.2, 2.0))
		if rd.next() < q:
			debris.chunk(x + off, y + 8.0, z + 8.0, vx, vy, sz, life2, tones, 2, 8.0)
			chunks += 1
	# 3. The dust dome and the skirt along the ground.
	var ndome: int = clampi(int(round(p("blast", "dome") * k)), 0, 20)
	for i in range(ndome):
		var side: float = 1.0 if i % 2 == 0 else -1.0
		var sz: float = rd.range_(34.0, 62.0) * (0.8 + 0.25 * m)
		var up: bool = i % 3 == 0       # one in three rises as a column off the bowl, the rest skirt the ground
		var vx: float = (rd.range_(-50.0, 50.0) if up else side * rd.range_(160.0, 480.0) * (0.6 + 0.4 * m)) * sws
		var vy: float = (rd.range_(140.0, 320.0) if up else rd.range_(10.0, 60.0)) * (0.7 + 0.3 * m) * sws
		var lf: float = rd.range_(1.0, 1.8)
		if rd.next() < q:
			debris.dust_puff(biome, x + (rd.range_(-0.3, 0.3) * r if up else side * r * rd.range_(0.2, 0.9)), y + rd.range_(0.0, 30.0), z + rd.range_(2.0, 26.0), vx, vy, sz * 0.6, sz * 2.0, lf, i % 3)
	# 4. The second fall: pebbles dropping out of the air half a second on.
	var npb: int = clampi(int(round(p("blast", "pebbles") * k)), 0, 20)
	if npb > 0:
		var j2 := VfxDebris.Job.new()
		j2.at = now + p("blast", "pebble_delay")
		j2.kind = "blast_pebbles"
		j2.a = {"x": x, "y": y, "z": z, "r": r, "n": npb, "tones": tones, "q": q}
		debris.jobs.append(j2)
	# 5. The bowl settling: dust sliding down the slopes, one puff at a time over a second or so.
	var nset: int = clampi(int(round(p("blast", "settle") * k)), 0, 12)
	for i in range(nset):
		var j3 := VfxDebris.Job.new()
		j3.at = now + lerpf(p("blast", "settle_from"), p("blast", "settle_to"), float(i) / maxf(float(nset - 1), 1.0))
		j3.kind = "blast_settle"
		j3.a = {"x": x, "y": y, "z": z, "r": r, "side": 1.0 if i % 2 == 0 else -1.0, "biome": biome, "q": q}
		debris.jobs.append(j3)


## A job that came due (VfxDebris._run_job): static so the pool holds no reference back to this object.
static func run_job(d: VfxDebris, S: SimState, kind: String, a: Dictionary) -> void:
	var rd: SimRng = d._rd
	match kind:
		"blast_ring":
			d._biome = VfxPalette.biome_key(a.x)
			d._ring(a.x, a.y, a.z, a.r0, a.growth, a.life, true)
		"blast_pebbles":
			for i in range(int(a.n)):
				var ox: float = rd.range_(-1.2, 1.2) * a.r
				var h: float = rd.range_(260.0, 620.0)
				var sz: float = rd.range_(5.0, 9.0)
				var vx: float = rd.range_(-60.0, 60.0)
				if rd.next() < a.q:
					d.chunk(a.x + ox, a.y + h, a.z + rd.range_(2.0, 20.0), vx, rd.range_(-80.0, 40.0), sz, rd.range_(1.0, 1.6), a.tones, 2, 6.0)
		"blast_settle":
			var s: float = a.side
			var gx: float = SimWrap.wrap(a.x + s * a.r * rd.range_(0.6, 0.95))
			var gy: float = WorldTerrain.groundY(S, gx)
			var sz: float = rd.range_(22.0, 40.0)
			if rd.next() < a.q:
				d.dust_puff(a.biome, gx, gy + rd.range_(2.0, 14.0), a.z + rd.range_(2.0, 20.0), -s * rd.range_(25.0, 70.0), rd.range_(0.0, 22.0), sz * 0.6, sz * 1.9, rd.range_(1.1, 1.8), 1)
