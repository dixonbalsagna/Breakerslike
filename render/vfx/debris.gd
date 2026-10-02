class_name VfxDebris
extends RefCounted
## Shrapnel and collapse dust (docs/vfx/plan.md section 3): ballistic bits simulated on the render side, one pool for the
## whole match, drawn by every pane (shard_view.gd). Glass slivers and triangles, steel bars and concrete chunks fly and
## bounce; dust is cel puffs that rise, drift and grow. Spawners cover the burst-through of a building, the tunnel a chain
## leaves between two hits, and a building's fall (implode: a ripple of dust skirts and falling chips; burst: heavier).
## Randomness comes from the vfx.shard and vfx.dust streams; nothing here reads or writes the sim (it reads terrain
## height for the bounce). A fixed number of draws per spawned bit, so the streams do not depend on the quality level:
## quality only decides how many of the drawn bits are kept.

enum { GLASS, TRI, STEEL, CHUNK, PUFF, RING, EMBER, SPRAY, FLAME }

class Bit:
	var kind: int = 0
	var x: float = 0.0
	var y: float = 0.0
	var z: float = 0.0
	var vx: float = 0.0
	var vy: float = 0.0
	var rot: float = 0.0
	var spin: float = 0.0
	var sx: float = 10.0         # size: length (or diameter)
	var sy: float = 4.0          # and width
	var grow: float = 0.0        # puffs and rings: size growth per second
	var life: float = 1.0
	var age: float = 0.0
	var grav: float = VfxLook.DEBRIS_GRAV
	var drag: float = 0.0
	var col: Color = Color.WHITE
	var col2: Color = Color.WHITE
	var seed: float = 0.0
	var bounces: int = 0
	var glass: bool = false        # an ember that is a glass fleck (a glass trench): keeps its own colour
	var ky: float = -1e9           # a water streak ends when it falls back below this height (the surface)
	var mode: int = 0              # a chunk: 0 concrete (the shared rim colour), 2 earth (lit and shaded sides of its own colour)

## A spawn waiting for its time (an implode's ripple delay): sim time to fire, and what to do.
class Job:
	var at: float = 0.0
	var kind: String = ""
	var a: Dictionary = {}

var bits: Array = []          # Bit
var _spawned_tick: int = 0     # spawns since the last step: the per-tick budget keeps one busy tick from being a frame spike
var _biome: String = "plains"   # the dust colours of the place being spawned at (Art's by_biome)
var _yspread: float = 60.0      # how far above and below the spawn height a shard may start (a floor band, for floors)
var _ember_tick: int = 0        # embers spawned this tick (budget VfxLook.EMBER_PER_TICK)
var _ember_alive: int = 0       # embers in the pool (cap VfxLook.EMBER_CAP)
var _spray_alive: int = 0       # water streaks in the pool (cap data/vfx/water.json caps.spray_alive)
var _rubble_alive: int = 0      # slow rising rubble bits in the pool (cap data/vfx/react.json rubble.alive_cap)
var _flame_alive: int = 0       # flames in the pool (cap data/vfx/earth.json flame.alive_cap)
var _water_ref: WeakRef = null     # weak: VfxWater holds this pool, so a strong link back would be a reference cycle (the exit warning)
var water: VfxWater:             # the water effects (set by the hub); a plunge's second jet comes back through it
	set(v):
		_water_ref = weakref(v) if v != null else null
	get:
		return _water_ref.get_ref() if _water_ref != null else null
var _tone: int = 0              # 0 mid, 1 shadow (a back layer), 2 light (a front layer)
var _tint: Color = Color(0.0, 0.0, 0.0, 0.0)   # a puff's own colour instead of the biome's, while set (dust_puff)
var jobs: Array = []          # Job, waiting
var now: float = 0.0           # the effects clock (hub.fx_now): sim time plus the intro's pre-clock ticks, so a landing's jobs run during the intro, when the sim clock stands still
var spawned: int = 0          # counters for the tests
var dropped: int = 0
var max_live: int = 0
var _rs: SimRng               # vfx.shard
var _rd: SimRng               # vfx.dust
var quality: int = VfxLook.Q_HIGH
var reduced: bool = false


func reset(seed: int) -> void:
	bits.clear()
	jobs.clear()
	_spray_alive = 0
	_rubble_alive = 0
	_flame_alive = 0
	spawned = 0
	dropped = 0
	max_live = 0
	_rs = SimRng.new(SimRng.deriveSeed(seed, "vfx.shard"))
	_rd = SimRng.new(SimRng.deriveSeed(seed, "vfx.dust"))


# ---------------------------------------------------------------------------------------------------------- stepping

## dt: seconds of sim time this tick (a tenth in hit-stop). S: for the ground under a bouncing bit and the clock T.
func step(S: SimState, dt: float) -> void:
	_spawned_tick = 0
	_ember_tick = 0
	_ember_alive = 0
	var spray_n: int = 0   # recounted below, after the jobs, so a job's throws see the real count
	var rubble_n: int = 0
	var flame_n: int = 0
	# Jobs are on unfrozen sim time (S.T): a hit-stopped ripple waits with the world.
	if not jobs.is_empty():
		var i: int = 0
		while i < jobs.size():
			var j: Job = jobs[i]
			if now >= j.at:
				jobs.remove_at(i)
				_run_job(S, j)
			else:
				i += 1
	for i in range(bits.size() - 1, -1, -1):
		var b: Bit = bits[i]
		b.age += dt
		if b.kind == SPRAY:
			spray_n += 1
			b.rot = atan2(b.vy, b.vx)
		if b.grav < 0.0 and b.kind == CHUNK:
			rubble_n += 1
		if b.kind == FLAME:
			flame_n += 1
		if b.kind == EMBER:
			_ember_alive += 1
		if b.age >= b.life:
			bits[i] = bits[bits.size() - 1]
			bits.pop_back()
			continue
		b.vy -= b.grav * dt
		if b.drag > 0.0:
			var k: float = pow(1.0 - b.drag, dt * 60.0)
			b.vx *= k
			b.vy *= k
		b.x = SimWrap.wrap(b.x + b.vx * dt)
		b.y += b.vy * dt
		b.rot += b.spin * dt
		if b.grow != 0.0:
			b.sx += b.grow * dt
			b.sy += b.grow * dt
		if b.kind == SPRAY and b.vy < 0.0 and b.y < b.ky:
			b.age = b.life
		elif b.kind != PUFF and b.kind != RING and b.kind != FLAME and b.z > -200.0:
			var g: float = WorldTerrain.groundY(S, b.x)
			if b.y < g:
				b.y = g
				if b.bounces < 2 and absf(b.vy) > 120.0:
					b.vy = -b.vy * 0.32
					b.vx *= 0.6
					b.spin *= 0.5
					b.bounces += 1
				else:
					b.vy = 0.0
					b.vx *= 0.85
					b.spin = 0.0
					if b.kind == CHUNK and b.mode == 2:
						b.age = maxf(b.age, b.life - 0.3)   # an earth chunk that has come to rest is buried in dust within 0.3 s: it must not lie on the sand as a dark dash
	_spray_alive = spray_n
	_rubble_alive = rubble_n
	_flame_alive = flame_n
	max_live = maxi(max_live, bits.size())


func _run_job(S: SimState, j: Job) -> void:
	match j.kind:
		"skirt":
			_skirt(S, j.a)
		"chips":
			_chips(S, j.a)
		"plunge2":
			if water != null:
				water.rebound(j.a)
		"blow":
			_blow(S, j.a)
		"pflr":
			_pflr(S, j.a)
		"pring":
			_pring(S, j.a)
		"vent":
			_vent(S, j.a)
		"blast_ring", "blast_pebbles", "blast_settle":
			VfxBlast.run_job(self, S, j.kind, j.a)
		"colpuff":
			var a: Dictionary = j.a
			_biome = VfxPalette.biome_key(a.x)
			_tone = a.tone
			_puff_at(a.x, a.y, a.z + (-30.0 if _tone == 1 else (14.0 if _tone == 2 else 0.0)), a.vx, a.vy, a.s0, a.s1, a.life, true)
			_tone = 0


# ---------------------------------------------------------------------------------------------------------- spawners

## The burst-through: in one side, out the other. b: the building {x, w, h, front_z}; the fighter enters at (xi, yi) and
## leaves at (xo, yo) travelling along (dx, dy) at speed sp. size: a scale for the bits from the building's size.
func burst_through(S: SimState, bx: float, w: float, h: float, front_z: float, xi: float, yi: float, xo: float, yo: float, dx: float, dy: float, sp: float, outcome: String, link: int) -> void:
	_biome = VfxPalette.biome_key(bx)
	_tone = 0
	var q: float = VfxLook.QUALITY_SHARDS[clampi(quality, 0, 2)] * (0.5 if reduced else 1.0)
	var kscale: float = clampf(sqrt(maxf(h, 100.0)) / 40.0, 0.7, 2.4)
	var heavy: float = 1.0 if outcome == "collapse" else (0.8 if outcome == "heavy" or outcome == "punch" else (0.55 if outcome == "wreck" else 0.3))
	var ux := Vector2(dx, dy).normalized()
	# In: glass thrown back toward the camera side of the wall, a cone opposite the flight, and a dust puff.
	var n_in: int = int(round(lerpf(VfxLook.GLASS_IN_MIN, VfxLook.GLASS_IN_MAX, clampf(sp / 12000.0, 0.0, 1.0)) * heavy))
	for k in range(n_in):
		_shard(GLASS if k % 3 != 0 else TRI, xi, yi, front_z, -ux, sp * 0.22, 0.55, kscale, q, 0.3)
	for k in range(int(round(VfxLook.STEEL_IN * heavy))):
		_shard(STEEL, xi, yi, front_z, -ux, sp * 0.16, 0.6, kscale, q, 0.4)
	_puffs(xi, yi, front_z, 5 + int(6 * heavy), 90.0 * kscale, 200.0 * kscale, q, 1.0)
	# Out: the cone the fighter carries along, and a bigger burst of dust.
	if outcome != "crack":
		var n_out: int = int(round(lerpf(VfxLook.GLASS_OUT_MIN, VfxLook.GLASS_OUT_MAX, clampf(sp / 12000.0, 0.0, 1.0)) * heavy))
		for k in range(n_out):
			_shard(GLASS if k % 3 != 0 else TRI, xo, yo, front_z, ux, sp * 0.62, 0.42, kscale, q, 0.2)
		for k in range(int(round(lerpf(VfxLook.STEEL_OUT_MIN, VfxLook.STEEL_OUT_MAX, clampf(sp / 12000.0, 0.0, 1.0)) * heavy))):
			_shard(STEEL, xo, yo, front_z, ux, sp * 0.45, 0.5, kscale, q, 0.3)
		for k in range(int(round(VfxLook.CHUNKS_OUT * heavy))):
			_shard(CHUNK, xo, yo, front_z, ux, sp * 0.3, 0.6, kscale, q, 0.3)
		_puffs(xo, yo, front_z, 8 + int(10 * heavy), 110.0 * kscale, 320.0 * kscale, q, 1.2)
	# A ring where the wall gave way.
	_ring(xi, yi, front_z + 6.0, 30.0 * kscale, 520.0 * kscale, 0.24)
	if outcome != "crack":
		_ring(xo, yo, front_z + 6.0, 30.0 * kscale, 700.0 * kscale, 0.28)


## The tunnel between two hits of a chain: dust and small chips streamed along the segment the fighter flies.
func chain_tunnel(x0: float, y0: float, x1: float, y1: float, z: float, link: int, size: float) -> void:
	_biome = VfxPalette.biome_key(x0)
	_tone = 0
	var q: float = VfxLook.QUALITY_SHARDS[clampi(quality, 0, 2)] * (0.5 if reduced else 1.0)
	var d: float = maxf(absf(SimWrap.sdx(x0, x1)), 1.0)
	var n: int = clampi(int(d / 260.0), 3, 24)
	var dir := Vector2(SimWrap.sdx(x0, x1), y1 - y0).normalized()
	for k in range(n):
		var t: float = float(k) / float(n)
		var px: float = x0 + SimWrap.sdx(x0, x1) * t
		var py: float = y0 + (y1 - y0) * t
		_puffs(px, py, z, 1, 80.0 * size, 240.0 * size * (1.0 + 0.15 * float(link)), q, 1.0)
		if k % 2 == 0:
			_shard(CHUNK if k % 4 == 0 else GLASS, px, py, z, dir, 900.0, 0.9, size, q, 0.4)


## A building's fall. mode: "implode" (a skirt of dust and chips falling straight, staggered by delay, from the sim's
## ripple) or "burst" (heavier, no ripple). bx, w, h: its footprint and height; front_z the depth of its facade.
func building_fall(S: SimState, bx: float, w: float, h: float, front_z: float, mode: String, delay: float, cx: float) -> void:
	var a: Dictionary = {"x": bx, "w": w, "h": h, "z": front_z, "mode": mode, "cx": cx}
	var j := Job.new()
	j.at = now + delay
	j.kind = "skirt"
	j.a = a
	jobs.append(j)
	var j2 := Job.new()
	j2.at = now + delay + 0.05
	j2.kind = "chips"
	j2.a = a
	jobs.append(j2)


## A district of implodes folded into one event past the cap: one big cloud, not n.
func district(S: SimState, x: float, n: float) -> void:
	_biome = VfxPalette.biome_key(x)
	_tone = 0
	var q: float = VfxLook.QUALITY_SHARDS[clampi(quality, 0, 2)]
	var span: float = clampf(n * 90.0, 600.0, 6000.0)
	for k in range(int(round(minf(n, 30.0) * q))):
		var px: float = x + _rd.range_(-0.5, 0.5) * span
		var g: float = WorldTerrain.groundY(S, px)
		_puff_at(px, g + _rd.range_(0.0, 200.0), -160.0, 0.0, _rd.range_(200.0, 700.0), _rd.range_(250.0, 700.0), _rd.range_(300.0, 900.0), 3.5, true)


func _skirt(S: SimState, a: Dictionary) -> void:
	var q: float = VfxLook.QUALITY_SHARDS[clampi(quality, 0, 2)] * (0.5 if reduced else 1.0)
	var bx: float = a.x
	var w: float = a.w
	var h: float = a.h
	_biome = VfxPalette.biome_key(bx)
	var g: float = WorldTerrain.groundY(S, bx)
	var kscale: float = clampf(sqrt(maxf(h, 100.0)) / 40.0, 0.7, 2.4)
	var heavy: float = 1.3 if a.mode == "burst" else 1.0
	var base: float = clampf(0.5 * (w + 0.15 * h), 200.0, 1100.0)   # dust scales with the tower, not only its footprint
	# The skirt: a ring of dust thrown out along the ground around the base, in three layers (a dark back bank, the body,
	# and a light front edge), so it has depth and reads as one heavy cloud.
	var n: int = int(round(clampf(w / 40.0 + h / 300.0, 10.0, 40.0) * heavy))
	for k in range(n):
		var t: float = (float(k) + _rd.next()) / float(n) - 0.5
		var out: float = signf(t) * _rd.range_(150.0, 700.0) * kscale
		var up: float = _rd.range_(100.0, 500.0) * kscale
		var kp: float = _rd.next()
		var pz: float = _rd.range_(6.0, 44.0)
		var ps: float = base * _rd.range_(0.7, 1.3)
		var pl: float = _rd.range_(2.4, 4.0)
		var py: float = _rd.range_(0.0, 150.0)
		_tone = k % 3
		if kp < q:
			_puff_at(bx + t * w * 1.4, g + py, a.z + pz + (-30.0 if _tone == 1 else (14.0 if _tone == 2 else 0.0)), out, up, ps * 0.6, ps * 1.3, pl, true)
	# The column: the tower's height in dust, floor by floor. Each puff waits its turn, top of the tower first, over about
	# half a second, as the floors give way.
	var ncol: int = int(round(clampf(h / 200.0, 5.0, 20.0) * heavy))
	var cs: float = base * 1.2
	for k in range(ncol):
		var fr: float = (float(k) + _rd.next()) / float(ncol)
		var kp: float = _rd.next()
		var vx: float = _rd.range_(-160.0, 160.0)
		var vy: float = _rd.range_(80.0, 400.0)
		var s: float = cs * _rd.range_(0.7, 1.3)
		var pl: float = _rd.range_(2.6, 4.6)
		var px: float = bx + _rd.range_(-0.4, 0.4) * w
		var pz: float = _rd.range_(8.0, 40.0)
		if kp < q:
			var j := Job.new()
			j.at = now + 0.5 * (1.0 - fr)
			j.kind = "colpuff"
			j.a = {"x": px, "y": g + h * (0.05 + 0.85 * fr), "z": a.z + pz, "vx": vx, "vy": vy, "s0": s * 0.6, "s1": s * 1.4, "life": pl, "tone": k % 3}
			jobs.append(j)
	_tone = 0
	_ring(bx, g + 6.0, a.z + 8.0, w * 0.35, w * 1.6, 0.5)


## A dust jet from a fresh fissure: two puffs shot up out of the split at (x, z), when its front reaches it (sim time `at`).
func vent(at: float, x: float, z: float, width: float) -> void:
	var j := Job.new()
	j.at = at
	j.kind = "vent"
	j.a = {"x": x, "z": z, "w": width}
	jobs.append(j)


func _vent(S: SimState, a: Dictionary) -> void:
	var q: float = VfxLook.QUALITY_SHARDS[clampi(quality, 0, 2)] * (0.5 if reduced else 1.0)
	_biome = VfxPalette.biome_key(a.x)
	_tone = 0
	var g: float = WorldTerrain.groundY(S, a.x)
	var s: float = clampf(a.w * 3.0, 60.0, 500.0)
	for k in range(2):
		var kp: float = _rd.next()
		var vy: float = _rd.range_(350.0, 800.0)
		var vx: float = _rd.range_(-80.0, 80.0)
		var pl: float = _rd.range_(1.0, 1.7)
		if kp < q:
			_puff_at(a.x, g, a.z, vx, vy, s * 0.5, s * 1.2, pl, false)


## Scorch embers for a beam's ground contact (the sim's scorch event), by the beam's variant: glass flecks over a glass
## trench, cinders over a burning forest, spray over the sea, chips and sparks elsewhere. Small, bright, few.
func embers(S: SimState, x: float, y: float, power: float, variant: String) -> void:
	var q: float = VfxLook.QUALITY_SHARDS[clampi(quality, 0, 2)] * (0.5 if reduced else 1.0)
	var n: int = 2 + int(power * 1.5)
	for k in range(n):
		var kp: float = _rs.next()
		var vx: float = _rs.range_(-90.0, 90.0)
		var vy: float = _rs.range_(200.0, 380.0 + 90.0 * power)
		var life: float = _rs.range_(0.8, 1.6)
		var sz: float = _rs.range_(30.0, 80.0)
		var px: float = x + _rs.range_(-60.0, 60.0)
		if kp >= q or _ember_tick >= VfxLook.EMBER_PER_TICK or _ember_alive >= VfxLook.EMBER_CAP:
			continue
		var b: Bit
		match variant:
			"GLASS TRENCH":
				b = _bit(EMBER, px, y + 6.0, RenderLook.Z_BEAMS + 8.0, vx, vy, 0.5, life)
				b.col = VfxPalette.glass("light")
				b.col2 = Color.WHITE
				b.glass = true
			"HORIZON CLEAVE":
				if _ember_tick >= VfxLook.EMBER_PER_TICK / 4:
					continue
				_biome = "ocean"
				_tone = 2
				_puff_at(px, y, RenderLook.Z_BEAMS + 8.0, vx * 0.6, vy * 0.6, 40.0, 150.0, life * 1.4, false)
				_ember_tick += 1
				_ember_alive += 1
				_tone = 0
				continue
			_:
				b = _bit(EMBER, px, y + 6.0, RenderLook.Z_BEAMS + 8.0, vx, vy, 0.5, life)
				b.col = VfxPalette.ember("hot")   # the view steps it through Art's ramp by age
		b.sx = sz * (2.2 if variant == "FIRESTORM" else 1.4)
		b.sy = 9.0
		_ember_tick += 1
		_ember_alive += 1
		b.grav = 160.0
		b.spin = 0.0
		b.rot = atan2(vy, vx)
		_add(b)


func _chips(S: SimState, a: Dictionary) -> void:
	_biome = VfxPalette.biome_key(a.x)
	var q: float = VfxLook.QUALITY_SHARDS[clampi(quality, 0, 2)] * (0.5 if reduced else 1.0)
	var bx: float = a.x
	var w: float = a.w
	var h: float = a.h
	var g: float = WorldTerrain.groundY(S, bx)
	var kscale: float = clampf(sqrt(maxf(h, 100.0)) / 40.0, 0.7, 2.4)
	var n: int = int(round(clampf(h / 220.0, 6.0, 30.0)))
	for k in range(n):
		var px: float = bx + _rs.range_(-0.5, 0.5) * w
		var py: float = g + _rs.range_(0.1, 1.0) * h
		var kind: int = GLASS if _rs.next() < 0.6 else (STEEL if _rs.next() < 0.6 else CHUNK)
		var keep: bool = _rs.next() < q
		var b: Bit = _bit(kind, px, py, a.z + VfxLook.Z_SHARD_OVER + _rs.range_(0.0, 30.0), _rs.range_(-160.0, 160.0), -_rs.range_(150.0, 700.0), kscale, _rs.range_(1.0, 2.2))
		if keep:
			_add(b)


# ------------------------------------------------------------------------------------------------------------ pieces

## One shard flying out from (x, y) around direction dir with spread `spread` (radians, half angle) at about `speed`.
func _shard(kind: int, x: float, y: float, z: float, dir: Vector2, speed: float, spread: float, kscale: float, q: float, life_jitter: float) -> void:
	# All draws happen whatever the quality, so the stream is independent of it.
	var ang: float = atan2(dir.y, dir.x) + _rs.range_(-spread, spread)
	var sp: float = speed * _rs.range_(0.35, 1.0)
	var b: Bit = _bit(kind, x + _rs.range_(-40.0, 40.0), y + _rs.range_(-_yspread, _yspread), z + VfxLook.Z_SHARD_OVER + _rs.range_(0.0, 30.0), cos(ang) * sp, sin(ang) * sp + _rs.range_(0.0, 220.0), kscale, _rs.range_(1.1, 2.4))
	var keep: bool = _rs.next() < q
	if keep:
		_add(b)


func _bit(kind: int, x: float, y: float, z: float, vx: float, vy: float, kscale: float, life: float) -> Bit:
	var b := Bit.new()
	b.kind = kind
	b.x = SimWrap.wrap(x)
	b.y = y
	b.z = z
	b.vx = vx
	b.vy = vy
	b.rot = _rs.range_(0.0, TAU)
	b.spin = _rs.range_(-9.0, 9.0)
	b.life = life
	b.seed = _rs.next()
	match kind:
		GLASS:
			b.sx = _rs.range_(26.0, 64.0) * kscale
			b.sy = _rs.range_(6.0, 14.0) * kscale
			b.col = VfxPalette.glass("mid")
			b.col2 = VfxPalette.glass("light")
		TRI:
			b.sx = _rs.range_(22.0, 46.0) * kscale
			b.sy = b.sx * _rs.range_(0.6, 1.0)
			b.col = VfxPalette.glass("mid")
			b.col2 = VfxPalette.glass("light")
		STEEL:
			b.sx = _rs.range_(50.0, 150.0) * kscale
			b.sy = _rs.range_(9.0, 18.0) * kscale
			b.col = VfxPalette.steel("mid")
			b.col2 = VfxPalette.steel("light")
		_:
			b.sx = _rs.range_(28.0, 70.0) * kscale
			b.sy = b.sx * _rs.range_(0.6, 1.0)
			b.col = VfxPalette.steel("light")
			b.col2 = VfxPalette.steel("light")
	return b


## Dust puffs around (x, y): n of them, sizes between s0 and s1 (world units), rising and spreading.
func _puffs(x: float, y: float, z: float, n: int, s0: float, s1: float, q: float, life_scale: float) -> void:
	for k in range(n):
		var ang: float = _rd.range_(0.0, TAU)
		var sp: float = _rd.range_(40.0, 260.0)
		var sz: float = _rd.range_(s0, s1)
		var keep: bool = _rd.next() < q
		if keep:
			_puff_at(x + _rd.range_(-30.0, 30.0), y + _rd.range_(-30.0, 30.0), z + _rd.range_(-4.0, 30.0), cos(ang) * sp, sin(ang) * sp * 0.6 + 60.0, sz * 0.6, sz, _rd.range_(1.2, 2.2) * life_scale, false)


func _puff_at(x: float, y: float, z: float, vx: float, vy: float, s0: float, s1: float, life: float, big: bool) -> void:
	var b := Bit.new()
	b.kind = PUFF
	b.x = SimWrap.wrap(x)
	b.y = y
	b.z = z
	b.vx = vx
	b.vy = vy
	b.sx = s0
	b.sy = s0
	b.grow = (s1 - s0) / maxf(life, 0.1)
	b.life = life
	b.grav = -40.0 if big else -20.0      # dust drifts up a little
	b.drag = 0.035
	b.col = VfxPalette.dust(_biome, "shadow" if _tone == 1 else ("light" if _tone == 2 else "mid"))
	if _tint.a > 0.0:
		b.col = _tint.darkened(0.25) if _tone == 1 else (_tint.lightened(0.2) if _tone == 2 else _tint)
	b.col2 = VfxPalette.dust(_biome, "shadow")
	b.seed = _rd.next()
	_add(b)


func _ring(x: float, y: float, z: float, r0: float, growth: float, life: float, flat: bool = false) -> void:
	var b := Bit.new()
	b.kind = RING
	b.x = SimWrap.wrap(x)
	b.y = y
	b.z = z
	b.sx = r0 * 2.0
	b.sy = r0 * 2.0
	b.grow = growth * 2.0
	b.life = life
	b.mode = 3 if flat else 0     # 3: lies on the ground, drawn as a flat ellipse (an entrance landing's ring)
	b.grav = 0.0
	b.col = VfxPalette.dust(_biome, "light")
	b.col2 = Color(VfxLook.STEEL_HI)
	_add(b)


## Add to the pool. When it is full a shard or chip drops the oldest puff first; a puff at the puff cap drops the oldest puff.
func _add(b: Bit) -> void:
	_spawned_tick += 1
	if _spawned_tick > VfxLook.SPAWN_PER_TICK + VfxLook.SHARD_PER_TICK and b.kind != RING:
		dropped += 1
		return
	if _spawned_tick > VfxLook.SPAWN_PER_TICK and b.kind == PUFF:
		dropped += 1
		return
	spawned += 1
	if bits.size() >= VfxLook.DEBRIS_CAP:
		for i in range(bits.size()):
			if bits[i].kind == PUFF:
				bits[i] = bits[bits.size() - 1]
				bits.pop_back()
				dropped += 1
				break
		if bits.size() >= VfxLook.DEBRIS_CAP:
			dropped += 1
			return
	bits.append(b)


# --------------------------------------------------------------------------------------------------- floors

## A brunt on floors of a skyscraper (floor_hit): the burst-through confined to the band of floors struck (ym its middle,
## half_band its half height), a row of windows blowing out along the facade, and less for a crack or a dent. The tunnel
## itself is Rendering's (cut from fmask); this throws glass, steel and dust.
func floor_hit(S: SimState, bx: float, w: float, front_z: float, xi: float, xo: float, ym: float, half_band: float, dx: float, dy: float, sp: float, outcome: String) -> void:
	_biome = VfxPalette.biome_key(bx)
	_tone = 0
	_yspread = clampf(half_band, 40.0, 220.0)
	match outcome:
		"punch":
			burst_through(S, bx, w, 2500.0, front_z, xi, ym, xo, ym, dx, dy, sp, "heavy", 1)
			window_row(bx, w, ym, half_band, front_z, 1.0)
		"crack":
			_puffs(xi, ym, front_z, 3, 60.0, 160.0, VfxLook.QUALITY_SHARDS[clampi(quality, 0, 2)], 1.0)
			window_row(bx, w, ym, half_band, front_z, 1.6)
			_ring(xi, ym, front_z + 6.0, 25.0, 420.0, 0.22)
		_:
			_puffs(xi, ym, front_z, 2, 50.0, 120.0, VfxLook.QUALITY_SHARDS[clampi(quality, 0, 2)], 1.0)
			for k in range(3):
				_shard(CHUNK, xi, ym, front_z, -Vector2(dx, dy), sp * 0.08, 0.7, 0.6, VfxLook.QUALITY_SHARDS[clampi(quality, 0, 2)], 0.3)
	_yspread = 60.0


## Window glass blowing out along a band of the facade and falling: one sliver about every window width.
func window_row(bx: float, w: float, ym: float, half_band: float, front_z: float, scale: float) -> void:
	var q: float = VfxLook.QUALITY_SHARDS[clampi(quality, 0, 2)] * (0.5 if reduced else 1.0)
	var n: int = int(round(clampf(w / 70.0, 6.0, 40.0) * scale))
	for k in range(n):
		var px: float = bx + ((float(k) + _rs.next()) / float(n) - 0.5) * w
		var py: float = ym + _rs.range_(-half_band, half_band)
		var kp: float = _rs.next()
		var b: Bit = _bit(GLASS if k % 4 != 0 else TRI, px, py, front_z + _rs.range_(6.0, 40.0), _rs.range_(-70.0, 70.0), _rs.range_(-60.0, 200.0), 1.0, _rs.range_(1.0, 1.9))
		if kp < q:
			_add(b)


## The stack above a cleared span pancaked (floors_fall): floors `from` to `to` (inclusive) broke. Each broken floor gives a
## burst of dust and glass and steel at its height, top floor first over about 0.4 s of sim time, then a ring at the base.
## x, w: the building's centre and width; fh: a floor's height; g: the ground; front_z: its facade.
func pancake(S: SimState, x: float, w: float, fh: float, g: float, from: int, to: int, front_z: float) -> void:
	var n: int = maxi(to - from + 1, 1)
	var m: int = mini(n, 14)
	for i in range(m):
		var f: int = to - int(floor(float(i) * float(n) / float(m)))
		var j := Job.new()
		j.at = now + 0.4 * float(i) / float(m)
		j.kind = "pflr"
		j.a = {"x": x, "w": w, "y": g + (float(f) + 0.5) * fh, "fh": fh, "z": front_z, "g": g}
		jobs.append(j)
	var r := Job.new()
	r.at = now + 0.45
	r.kind = "pring"
	r.a = {"x": x, "w": w, "y": g + 6.0, "z": front_z}
	jobs.append(r)


func _pflr(S: SimState, a: Dictionary) -> void:
	var q: float = VfxLook.QUALITY_SHARDS[clampi(quality, 0, 2)] * (0.5 if reduced else 1.0)
	_biome = VfxPalette.biome_key(a.x)
	_yspread = clampf(a.fh * 0.5, 40.0, 200.0)
	var ps: float = clampf(a.w * 0.5, 150.0, 600.0)
	for k in range(2):
		_tone = k * 2
		var px: float = a.x + _rd.range_(-0.45, 0.45) * a.w
		var kp: float = _rd.next()
		var s: float = ps * _rd.range_(0.7, 1.2)
		var pl: float = _rd.range_(1.8, 3.2)
		if kp < q:
			_puff_at(px, a.y, a.z + _rd.range_(8.0, 40.0), _rd.range_(-200.0, 200.0), _rd.range_(40.0, 240.0), s * 0.6, s * 1.4, pl, true)
	_tone = 0
	for k in range(5):
		_shard(GLASS if k % 3 != 0 else TRI, a.x + _rs.range_(-0.45, 0.45) * a.w, a.y, a.z, Vector2(0.0, -1.0), 500.0, 1.4, 1.3, q, 0.3)
	for k in range(2):
		_shard(STEEL, a.x + _rs.range_(-0.45, 0.45) * a.w, a.y, a.z, Vector2(0.0, -1.0), 400.0, 1.4, 1.3, q, 0.3)
	_yspread = 60.0


func _pring(S: SimState, a: Dictionary) -> void:
	_ring(a.x, a.y, a.z + 8.0, a.w * 0.3, a.w * 1.4, 0.5)


# ---------------------------------------------------------------------------------------------------------- water

## A spray streak: a cel droplet stretched along its velocity, falling at the water's gravity, gone when it is back down
## at kill_y (the surface). Colours are Art's ocean dust.
func spray(x: float, y: float, vx: float, vy: float, len: float, life: float, kill_y: float) -> void:
	var b := Bit.new()
	b.kind = SPRAY
	b.x = SimWrap.wrap(x)
	b.y = y
	b.z = -5.0
	b.vx = vx
	b.vy = vy
	b.sx = len
	b.sy = maxf(len * 0.2, 7.0)
	b.life = life
	b.grav = 1200.0
	b.ky = kill_y - 4.0
	b.col = VfxPalette.dust("ocean", "light")
	b.col2 = VfxPalette.dust("ocean", "mid")
	b.seed = _rd.next()
	b.rot = atan2(vy, vx)
	_spray_alive += 1   # counted at once, so one tick's throws cannot pass the cap before the next step recounts
	_add(b)


## A foam puff: a cel cloud in the ocean's colours that rises, spreads and fades.
func foam(x: float, y: float, vx: float, vy: float, size: float, life: float) -> void:
	_biome = "ocean"
	_tone = 2 if _rd.next() < 0.5 else 0
	_puff_at(x, y, -8.0, vx, vy, size * 0.6, size * 1.3, life, false)
	_tone = 0


# ------------------------------------------------------------------------------------------------------------ the world reacts

## One piece of rubble lifted off the ground by a high-tier fighter (react.gd): a chunk of the biome's earth that rises
## slowly, with weight (a small upward acceleration and drag, a heavy slow spin), and is gone in a couple of seconds. Not a
## ring: react.gd scatters them. size in units; accel the upward acceleration.
func rubble(x: float, y: float, z: float, vx: float, vy: float, size: float, life: float, accel: float, biome: String) -> void:
	var b := Bit.new()
	b.kind = CHUNK
	b.x = SimWrap.wrap(x)
	b.y = y
	b.z = z
	b.vx = vx
	b.vy = vy
	b.rot = _rd.range_(0.0, TAU)
	b.spin = _rd.range_(-1.6, 1.6)
	b.sx = size
	b.sy = size * _rd.range_(0.55, 0.9)
	b.life = life
	b.grav = -accel
	b.drag = 0.012
	b.col = VfxPalette.dust(biome, "mid")
	b.col2 = VfxPalette.dust(biome, "light")
	b.seed = _rd.next()
	_rubble_alive += 1
	_add(b)


## A wave of windows blowing out of one building (react.gd): glass shards thrown out of a few floors' rows. a: x, w (the
## building), base (its foot), fh (a floor's height), z (its facade), floors (the floor numbers), scale.
func _blow(_S: SimState, a: Dictionary) -> void:
	for fl in a.floors:
		window_row(a.x, a.w, a.base + (float(fl) + 0.5) * a.fh, a.fh * 0.3, a.z, a.scale)


# ------------------------------------------------------------------------------------------------- material chunks and flame

## One chunk of earth, paving, rock or whatever the event named, tumbling: it flies under gravity, spins, bounces off the
## ground twice and fades. tones: [mid, light, shadow] colours of its material. mode 2 draws it with a lit and a shaded side of
## its own colour (the shared concrete rim is only for steel and concrete).
func chunk(x: float, y: float, z: float, vx: float, vy: float, size: float, life: float, tones: Array, mode: int, spin: float = 9.0) -> void:
	var b := Bit.new()
	b.kind = CHUNK
	b.x = SimWrap.wrap(x)
	b.y = y
	b.z = z
	b.vx = vx
	b.vy = vy
	b.rot = _rd.range_(0.0, TAU)
	b.spin = _rd.range_(-spin, spin)
	b.sx = size
	b.sy = size * _rd.range_(0.6, 0.95)
	b.life = life
	b.mode = mode
	b.col = tones[0]
	b.col2 = tones[1]
	b.seed = _rd.next()
	_add(b)


## A cel flame: a three-banded tongue that rises with a wobble and shrinks as it burns out. size: its width (the tongue is
## 1.35 times as tall). Counted for the cap (the caller checks it).
func flame(x: float, y: float, z: float, vx: float, vy: float, size: float, life: float) -> void:
	var b := Bit.new()
	b.kind = FLAME
	b.x = SimWrap.wrap(x)
	b.y = y
	b.z = z
	b.vx = vx
	b.vy = vy
	b.rot = 0.0
	b.spin = _rd.range_(-0.5, 0.5)
	b.sx = size
	b.sy = size * 1.35
	b.life = life
	b.grav = -30.0
	b.drag = 0.03
	b.col = Color("#ff9a2e")
	b.seed = _rd.next()
	_flame_alive += 1
	_add(b)


## A wisp of smoke: a dark soft puff that drifts up and spreads. (The dust ramp's shadow step, so it never leaves Art's colours.)
func smoke(x: float, y: float, z: float, size: float, life: float) -> void:
	_biome = "city"
	_tone = 1
	_puff_at(x, y, z, _rd.range_(-14.0, 14.0), _rd.range_(40.0, 90.0), size * 0.7, size * 1.6, life, false)
	_tone = 0


## A dust puff in a biome's colours (the contact and settle effects, earth.gd): size s0 to s1 over its life.
func dust_puff(biome: String, x: float, y: float, z: float, vx: float, vy: float, s0: float, s1: float, life: float, tone: int = 0, tint: Color = Color(0.0, 0.0, 0.0, 0.0)) -> void:
	_biome = biome
	_tone = tone
	_tint = tint
	_puff_at(x, y, z, vx, vy, s0, s1, life, tone == 2)
	_tone = 0
	_tint = Color(0.0, 0.0, 0.0, 0.0)
