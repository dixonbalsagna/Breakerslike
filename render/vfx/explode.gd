class_name VfxExplode
extends RefCounted
## An energy blast going off (Orb, 2026-10-02: blasts "erupt into flame and smoke, explosive particles"). Used by shots.gd at a shot's

## it goes off:
##
##   ground   a flame burst (the cel flames: a pale core, orange, then the dark of the smoke), sparks, thrown chunks of the ground's own
##            earth, a flat ring running out along the ground, dark smoke rising, and a scorch that smoulders for a few seconds
##            (wisps of smoke and the odd ember at the point; the crater itself is World's `crater` event)
##   fighter  the same without the chunks and the ring, and shorter: a flame burst, sparks and a little smoke at the body; a guard
##            or a deflect gives sparks and smoke only
##   water    steam: pale puffs rising off the surface and a few sparks (the water plunge is the water effects')
##
## Everything goes into the shared debris pool (no draw call), with a fixed number of draws per call from the cosmetic streams
## (vfx.dust, vfx.shard), so nothing here depends on the quality level; quality only decides how many of the drawn bits are kept.
## Colours: the flames are the cel flame's own (an orange body, a lighter mid and a pale core: fire, not a body aura and not a flash on
## a body), the sparks Art's ember ramp, the smoke and the chunks the biome's own shades. Presentation only.

const DEFAULTS: Dictionary = {
	"explode": {"flames": 5.0, "sparks": 9.0, "chunks": 5.0, "smoke": 4.0, "ring_r0": 0.3, "ring_r1": 1.15, "ring_life": 0.42,
		"smoulder": 6.0, "smoulder_from": 0.5, "smoulder_to": 3.6, "steam": 5.0, "fighter_k": 0.55, "flame_cap": 40.0, "ref_bh": 1.5},
}

static var _data: Dictionary = {}
static var _loaded: bool = false


static func warm() -> void:
	if _loaded:
		return
	_loaded = true
	var path := "res://data/vfx/shots.json"
	if FileAccess.file_exists(path):
		var v = JSON.parse_string(FileAccess.get_file_as_string(path))
		if v is Dictionary:
			_data = v


static func p(key: String) -> float:
	warm()
	var g = _data.get("explode")
	if g is Dictionary and g.has(key):
		return float(g[key])
	return float(DEFAULTS["explode"][key])


## The blast radius in world units (agency-pass.md 15.1) for a kind of shot at a damage and the shooter's tier: a bolt or shard 0.5 bh,
## an arc 1 bh, a lob (or burst) 1.5 bh, a charged shot 1.5 bh tapped and 2 bh fully charged (damage 60 or more of its 66); times 1.25
## at tier 3 and 1.5 at tier 4.
static func radius_for(kind: String, dmg: float, tier: int) -> float:
	var bh: float
	match kind:
		"bolt", "shard":
			bh = 0.5
		"arc":
			bh = 1.0
		"lob":
			bh = 1.5
		"charged":
			bh = 2.0 if dmg >= 60.0 else 1.5
		_:
			bh = 0.5
	var tf: float = 1.5 if tier >= 4 else (1.25 if tier == 3 else 1.0)
	return bh * VfxLook.BH * tf


## How long its smoke stays, seconds, for show (2 for the smallest, 5 for the largest).
static func smoke_s(radius: float) -> float:
	return clampf(1.0 + 2.0 * radius / VfxLook.BH, 2.0, 5.0)


## The share of the full effect a blast of this radius makes: 1 at 1.5 bh.
static func scale_for(radius: float) -> float:
	return clampf(radius / (p("ref_bh") * VfxLook.BH), 0.25, 2.4)


static func _q(d: VfxDebris) -> float:
	return VfxLook.QUALITY_SHARDS[clampi(d.quality, 0, 2)] * (0.5 if d.reduced else 1.0)


## radius: the blast radius (radius_for). surface: "ground", "fighter" or "water". mode: "burst" (a flame burst, the default), "spark" (sparks and smoke only: a guard or a deflect).
## Returns how many bits it asked the pool for (the tests and the budget).
static func at(S: SimState, d: VfxDebris, x: float, y: float, z: float, radius: float, surface: String, mode: String = "burst") -> int:
	var rd: SimRng = d._rd
	var q: float = _q(d)
	var s: float = scale_for(radius) * (p("fighter_k") if surface == "fighter" else 1.0)
	var smoke_life: float = smoke_s(radius)
	var biome: String = VfxPalette.biome_key(x)
	var asked: int = 0
	var flame_cap: int = int(round(p("flame_cap") * (0.5 + 0.5 * q)))
	# Flames: a burst going up and out, the larger ones taller.
	var nf: int = 0 if (mode == "spark" or surface == "water") else clampi(int(round(p("flames") * s)), 1, 9)
	for i in range(nf):
		var side: float = -1.0 + 2.0 * (float(i) + 0.5) / float(nf)
		var vx: float = side * rd.range_(80.0, 220.0) * s + rd.range_(-30.0, 30.0)
		var vy: float = rd.range_(90.0, 200.0) * (0.6 + 0.4 * s)       # local and in proportion: a flame tongue rises about its blast radius, never a pillar
		var sz: float = rd.range_(26.0, 52.0) * (0.55 + 0.6 * s)
		var life: float = rd.range_(0.45, 0.85) * (0.7 + 0.3 * s)
		var keep: bool = rd.next() < q and d._flame_alive < flame_cap
		if keep:
			d.flame(x + rd.range_(-30.0, 30.0) * s, y + rd.range_(0.0, 24.0), z + 6.0, vx, vy, sz, life)
			asked += 1
	# Sparks: bright cinders thrown out, stepped through Art's ember ramp by age.
	var nsp: int = clampi(int(round(p("sparks") * s)), 2, 18)
	for i in range(nsp):
		var ang: float = rd.range_(0.15, PI - 0.15)
		var spd: float = rd.range_(220.0, 520.0) * (0.6 + 0.4 * s)
		var life2: float = rd.range_(0.45, 1.05)
		var len: float = rd.range_(22.0, 48.0) * (0.7 + 0.3 * s)
		var keep2: bool = rd.next() < q and d._ember_tick < VfxLook.EMBER_PER_TICK and d._ember_alive < VfxLook.EMBER_CAP
		if keep2:
			var b: VfxDebris.Bit = d._bit(VfxDebris.EMBER, x + rd.range_(-14.0, 14.0), y + 8.0, z + 10.0, cos(ang) * spd, sin(ang) * spd, 0.5, life2)
			b.col = VfxPalette.ember("hot")
			b.sx = len
			b.sy = 8.0
			b.grav = 520.0
			b.spin = 0.0
			b.rot = ang
			d._ember_tick += 1
			d._ember_alive += 1
			d._add(b)
			asked += 1
	# Smoke: dark puffs rising off the burst.
	var nsm: int = clampi(int(round(p("smoke") * s)), 1, 8)
	for i in range(nsm):
		var sz2: float = rd.range_(44.0, 78.0) * (0.55 + 0.6 * s)
		var life3: float = rd.range_(0.6, 1.0) * smoke_life
		var dx: float = rd.range_(-26.0, 26.0)
		var keep3: bool = rd.next() < q
		if keep3 and not (d.reduced and i > 1):
			d.smoke(x + dx, y + 30.0 + rd.range_(0.0, 30.0), z - 2.0, sz2, life3)
			asked += 1
	if surface == "ground":
		# Chunks of the ground's own earth, thrown and falling.
		var tones: Array = VfxEarth.tones_for_surface("soil", x)
		var nc: int = clampi(int(round(p("chunks") * s)), 2, 10)
		for i in range(nc):
			var sx: float = rd.range_(-1.0, 1.0)
			var vx2: float = sx * rd.range_(160.0, 420.0) * (0.6 + 0.5 * s)
			var vy2: float = rd.range_(380.0, 860.0) * (0.6 + 0.5 * s)
			var sz3: float = rd.range_(9.0, 19.0) * (0.7 + 0.4 * s)
			var life4: float = rd.range_(1.0, 1.8)
			var keep4: bool = rd.next() < q
			if keep4:
				d.chunk(x + rd.range_(-24.0, 24.0), y + 8.0, z + 8.0, vx2, vy2, sz3, life4, tones, 2, 9.0)
				asked += 1
		# The flat ring along the ground.
		if not d.reduced:
			var r0: float = p("ring_r0") * radius
			var r1: float = p("ring_r1") * radius
			d._biome = biome
			d._ring(x, y + 14.0, z + 6.0, r0, (r1 - r0) / p("ring_life"), p("ring_life"), true)
			asked += 1
		# The scorch smoulders for a few seconds: a wisp of smoke and the odd ember at the point, one at a time.
		var nsc: int = clampi(int(round(p("smoulder") * s)), 0, 10)
		var t0: float = d.now
		for i in range(nsc):
			var j := VfxDebris.Job.new()
			j.at = t0 + lerpf(p("smoulder_from"), p("smoulder_to"), float(i) / maxf(float(nsc - 1), 1.0))
			j.kind = "smoulder"
			j.a = {"x": x, "y": y, "z": z, "w": 0.4 * radius, "ember": i % 3 == 1, "q": q, "life": smoke_life}
			d.jobs.append(j)
	elif surface == "water":
		# Steam: pale puffs off the surface, and a few sparks above (the plunge itself is the water effects').
		var nst: int = clampi(int(round(p("steam") * s)), 1, 8)
		for i in range(nst):
			var sz4: float = rd.range_(50.0, 90.0) * (0.55 + 0.6 * s)
			var keep5: bool = rd.next() < q
			if keep5:
				d.dust_puff("ocean", x + rd.range_(-40.0, 40.0), y + rd.range_(0.0, 20.0), z + rd.range_(0.0, 20.0), rd.range_(-30.0, 30.0), rd.range_(70.0, 150.0), sz4 * 0.6, sz4 * 1.8, rd.range_(1.2, 2.0), 2)
				asked += 1
	return asked


## A job that came due: one wisp of the smouldering scorch.
static func run_job(d: VfxDebris, kind: String, a: Dictionary) -> void:
	if kind != "smoulder":
		return
	var rd: SimRng = d._rd
	var dx: float = rd.range_(-1.0, 1.0) * a.w
	var sz: float = rd.range_(30.0, 52.0)
	if rd.next() < a.q:
		d.smoke(a.x + dx, a.y + 10.0, a.z - 2.0, sz, rd.range_(0.55, 0.85) * a.life)
	if a.ember:
		var ang: float = rd.range_(1.0, 2.1)
		var spd: float = rd.range_(90.0, 200.0)
		var keep: bool = rd.next() < a.q and d._ember_tick < VfxLook.EMBER_PER_TICK and d._ember_alive < VfxLook.EMBER_CAP
		if keep:
			var b: VfxDebris.Bit = d._bit(VfxDebris.EMBER, a.x + dx, a.y + 8.0, a.z + 10.0, cos(ang) * spd, sin(ang) * spd, 0.5, rd.range_(0.6, 1.1))
			b.col = VfxPalette.ember("warm")
			b.sx = 36.0
			b.sy = 7.0
			b.grav = 200.0
			b.spin = 0.0
			b.rot = ang
			d._ember_tick += 1
			d._ember_alive += 1
			d._add(b)
