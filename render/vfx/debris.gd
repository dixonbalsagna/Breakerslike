class_name VfxDebris
extends RefCounted
## Shrapnel and collapse dust (docs/vfx/plan.md section 3): ballistic bits simulated on the render side, one pool for the
## whole match, drawn by every pane (shard_view.gd). Glass slivers and triangles, steel bars and concrete chunks fly and
## bounce; dust is cel puffs that rise, drift and grow. Spawners cover the burst-through of a building, the tunnel a chain
## leaves between two hits, and a building's fall (implode: a ripple of dust skirts and falling chips; burst: heavier).
## Randomness comes from the vfx.shard and vfx.dust streams; nothing here reads or writes the sim (it reads terrain
## height for the bounce). A fixed number of draws per spawned bit, so the streams do not depend on the quality level:
## quality only decides how many of the drawn bits are kept.

enum { GLASS, TRI, STEEL, CHUNK, PUFF, RING }

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

## A spawn waiting for its time (an implode's ripple delay): sim time to fire, and what to do.
class Job:
	var at: float = 0.0
	var kind: String = ""
	var a: Dictionary = {}

var bits: Array = []          # Bit
var jobs: Array = []          # Job, waiting
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
	spawned = 0
	dropped = 0
	max_live = 0
	_rs = SimRng.new(SimRng.deriveSeed(seed, "vfx.shard"))
	_rd = SimRng.new(SimRng.deriveSeed(seed, "vfx.dust"))


# ---------------------------------------------------------------------------------------------------------- stepping

## dt: seconds of sim time this tick (a tenth in hit-stop). S: for the ground under a bouncing bit and the clock T.
func step(S: SimState, dt: float) -> void:
	# Jobs are on unfrozen sim time (S.T): a hit-stopped ripple waits with the world.
	if not jobs.is_empty():
		var i: int = 0
		while i < jobs.size():
			var j: Job = jobs[i]
			if S.T >= j.at:
				jobs.remove_at(i)
				_run_job(S, j)
			else:
				i += 1
	for i in range(bits.size() - 1, -1, -1):
		var b: Bit = bits[i]
		b.age += dt
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
		if b.kind != PUFF and b.kind != RING and b.z > -200.0:
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
	max_live = maxi(max_live, bits.size())


func _run_job(S: SimState, j: Job) -> void:
	match j.kind:
		"skirt":
			_skirt(S, j.a)
		"chips":
			_chips(S, j.a)


# ---------------------------------------------------------------------------------------------------------- spawners

## The burst-through: in one side, out the other. b: the building {x, w, h, front_z}; the fighter enters at (xi, yi) and
## leaves at (xo, yo) travelling along (dx, dy) at speed sp. size: a scale for the bits from the building's size.
func burst_through(S: SimState, bx: float, w: float, h: float, front_z: float, xi: float, yi: float, xo: float, yo: float, dx: float, dy: float, sp: float, outcome: String, link: int) -> void:
	var q: float = VfxLook.QUALITY_SHARDS[clampi(quality, 0, 2)] * (0.5 if reduced else 1.0)
	var kscale: float = clampf(sqrt(maxf(h, 100.0)) / 40.0, 0.7, 2.4)
	var heavy: float = 1.0 if outcome == "collapse" else (0.7 if outcome == "wreck" else 0.35)
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
	_ring(xi, yi, front_z + 6.0, 80.0 * kscale, 1500.0 * kscale, 0.35)
	if outcome != "crack":
		_ring(xo, yo, front_z + 6.0, 80.0 * kscale, 1900.0 * kscale, 0.4)


## The tunnel between two hits of a chain: dust and small chips streamed along the segment the fighter flies.
func chain_tunnel(x0: float, y0: float, x1: float, y1: float, z: float, link: int, size: float) -> void:
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
	j.at = S.T + delay
	j.kind = "skirt"
	j.a = a
	jobs.append(j)
	var j2 := Job.new()
	j2.at = S.T + delay + 0.05
	j2.kind = "chips"
	j2.a = a
	jobs.append(j2)


## A district of implodes folded into one event past the cap: one big cloud, not n.
func district(S: SimState, x: float, n: float) -> void:
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
	var g: float = WorldTerrain.groundY(S, bx)
	var kscale: float = clampf(sqrt(maxf(h, 100.0)) / 40.0, 0.7, 2.4)
	var heavy: float = 1.4 if a.mode == "burst" else 1.0
	var n: int = int(round(clampf(w / 55.0, 6.0, 28.0) * heavy))
	for k in range(n):
		var t: float = (float(k) + _rd.next()) / float(n) - 0.5
		var px: float = bx + t * w
		var out: float = signf(t) * _rd.range_(80.0, 520.0) * kscale
		var up: float = _rd.range_(120.0, 620.0) * kscale
		var kp: float = _rd.next()
		var pz: float = _rd.range_(4.0, 40.0)
		var ps: float = clampf(w * 0.09, 70.0, 420.0) * _rd.range_(0.7, 1.3)
		var pl: float = _rd.range_(1.6, 3.0)
		var py: float = _rd.range_(0.0, 60.0)
		if kp < q:
			_puff_at(px, g + py, a.z + pz, out, up, ps, ps * 1.25, pl, false)
	# A rising column over the middle, one puff a floor or so up.
	for k in range(int(round(clampf(h / 500.0, 2.0, 10.0) * q))):
		var fy: float = g + h * _rd.range_(0.05, 0.6)
		_puff_at(bx + _rd.range_(-0.35, 0.35) * w, fy, a.z + 30.0, _rd.range_(-120.0, 120.0), _rd.range_(150.0, 500.0), clampf(w * 0.12, 90.0, 520.0), clampf(w * 0.12, 90.0, 520.0) * 1.3, _rd.range_(2.0, 3.6), true)
	_ring(bx, g + 6.0, a.z + 8.0, w * 0.4, w * 2.2, 0.55)


func _chips(S: SimState, a: Dictionary) -> void:
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
	var b: Bit = _bit(kind, x + _rs.range_(-40.0, 40.0), y + _rs.range_(-60.0, 60.0), z + VfxLook.Z_SHARD_OVER + _rs.range_(0.0, 30.0), cos(ang) * sp, sin(ang) * sp + _rs.range_(0.0, 220.0), kscale, _rs.range_(1.1, 2.4))
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
			b.col = Color(VfxLook.GLASS)
			b.col2 = Color(VfxLook.GLASS_HI)
		TRI:
			b.sx = _rs.range_(22.0, 46.0) * kscale
			b.sy = b.sx * _rs.range_(0.6, 1.0)
			b.col = Color(VfxLook.GLASS)
			b.col2 = Color(VfxLook.GLASS_HI)
		STEEL:
			b.sx = _rs.range_(50.0, 150.0) * kscale
			b.sy = _rs.range_(9.0, 18.0) * kscale
			b.col = Color(VfxLook.STEEL)
			b.col2 = Color(VfxLook.STEEL_HI)
		_:
			b.sx = _rs.range_(28.0, 70.0) * kscale
			b.sy = b.sx * _rs.range_(0.6, 1.0)
			b.col = Color(VfxLook.CONCRETE)
			b.col2 = Color(VfxLook.STEEL_HI)
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
	b.col = Color(VfxLook.DUST_A)
	b.col2 = Color(VfxLook.DUST_B)
	b.seed = _rd.next()
	_add(b)


func _ring(x: float, y: float, z: float, r0: float, growth: float, life: float) -> void:
	var b := Bit.new()
	b.kind = RING
	b.x = SimWrap.wrap(x)
	b.y = y
	b.z = z
	b.sx = r0 * 2.0
	b.sy = r0 * 2.0
	b.grow = growth * 2.0
	b.life = life
	b.grav = 0.0
	b.col = Color(VfxLook.DUST_A)
	b.col2 = Color(VfxLook.STEEL_HI)
	_add(b)


## Add to the pool. When it is full a shard or chip drops the oldest puff first; a puff at the puff cap drops the oldest puff.
func _add(b: Bit) -> void:
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
