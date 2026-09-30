class_name VfxCrackGen
extends RefCounted
## Ground cracks, as data (docs/vfx/plan.md section 3). Pure and deterministic: the lines of a crack set are a function
## of one sim record (a crater or a slide), the match seed and the quality level, so a seek, a snapshot restore or a
## late join draws the same cracks as a live match. Lines are polylines in the ground plane, as (dx from the set's
## origin along x, z), with a width at the source end. Nothing here reads or writes the sim.
##
## The camera looks along the ground at a grazing angle, so a line reads best when it runs along x: most spokes are
## drawn within CR_X_SPREAD of the x axis (CR_X_BIAS of them), the rest go anywhere. Nothing is drawn in front of the
## fighter plane (z above Z_CRACK_MAX): the renderer's foreground rule pulls land there down.

class Line:
	var pts := PackedVector2Array()   # (dx, z) from the set's origin; the source end first
	var w0: float = 8.0               # width at the source end, world units
	var fissure: bool = false         # a split: a dark throat with broken edges and a lit lip


## A key for a crater record or a crater event: stable however it arrives (event or S.craters record).
static func crater_key(x: float, r: float, depth: float) -> int:
	return (int(x * 16.0) * 73856093) ^ (int(r * 16.0) * 19349663) ^ (int(depth * 16.0) * 83492791)


static func slide_key(x0: float, x1: float, hw: float) -> int:
	return (int(x0 * 16.0) * 73856093) ^ (int(x1 * 16.0) * 19349663) ^ (int(hw * 16.0) * 83492791) ^ 0x5bd1e995


## The lines of a crater's cracks. r: bowl radius; E: impact energy; special: a special blow (the big marks);
## cause: "impact", "beam" or "powerup" (a power-up cracks all round, an impact along the ground). match_seed and key
## seed the stream; quality is a VfxLook.Q_* level. Returns an Array of Line.
static func crater_lines(match_seed: int, key: int, r: float, E: float, special: bool, cause: String, quality: int) -> Array:
	var out: Array = []
	if E < VfxLook.CR_E_MIN and not special:
		return out
	var rng := SimRng.new(SimRng.deriveSeed(match_seed, "vfx.crack") ^ (key & SimRng.MASK))
	var se: float = sqrt(maxf(E, 0.0))
	var q: float = VfxLook.SPOKES_BY_QUALITY[clampi(quality, 0, 2)]
	var n: int = clampi(int(round((VfxLook.CR_SPOKES_BASE + VfxLook.CR_SPOKES_SQRT_E * se) * q)), 2, VfxLook.CR_SPOKES_MAX)
	var w0: float = clampf(VfxLook.CR_W * r, VfxLook.CR_W_MIN, VfxLook.CR_W_MAX)
	var all_round: bool = cause == "powerup"
	var side0: float = 1.0 if rng.next() < 0.5 else -1.0
	for i in range(n):
		var side: float = side0 if i % 2 == 0 else -side0
		var ang: float
		if all_round or rng.next() >= VfxLook.CR_X_BIAS:
			ang = rng.range_(0.0, TAU)
		else:
			ang = (0.0 if side > 0.0 else PI) + rng.range_(-VfxLook.CR_X_SPREAD, VfxLook.CR_X_SPREAD)
		var length: float = r * minf(VfxLook.CR_LEN_MAX, VfxLook.CR_LEN_BASE + VfxLook.CR_LEN_SQRT_E * se) * rng.range_(0.55, 1.0)
		_spoke(out, rng, r * rng.range_(0.96, 1.04), ang, length, w0 * rng.range_(0.8, 1.2), false, 0)
	# Fissures: a few long, wide splits for a hard blow. They run along x, so they read from the side.
	if E >= VfxLook.FISSURE_E or special:
		var nf: int = clampi(1 + int(E / 12.0), 1, VfxLook.FISSURE_MAX)
		if quality == VfxLook.Q_LOW:
			nf = 1
		var fw: float = clampf(VfxLook.FISSURE_W * r, VfxLook.FISSURE_W_MIN, VfxLook.FISSURE_W_MAX)
		for i in range(nf):
			var side: float = side0 if i % 2 == 0 else -side0
			var ang: float = (0.0 if side > 0.0 else PI) + rng.range_(-0.30, 0.30)
			var length: float = r * minf(VfxLook.FISSURE_LEN_MAX, VfxLook.FISSURE_LEN_BASE + VfxLook.FISSURE_LEN_SQRT_E * se) * rng.range_(0.7, 1.0)
			_spoke(out, rng, r * rng.range_(0.9, 1.0), ang, length, fw * rng.range_(0.8, 1.15), true, 0)
	return out


## The lines of a knockback slide's cracks: two long splits along the trench edges, a herringbone of spurs off them,
## and a fan where it stopped. x0 to x1: the trench (the shortest arc between them); hw: its half width; E: the
## slide's energy; paved: it started in a city or village (more, shorter spurs). The set's origin is x0.
static func slide_lines(match_seed: int, key: int, dx_total: float, hw: float, E: float, paved: bool, quality: int) -> Array:
	var out: Array = []
	if E < VfxLook.CR_E_MIN:
		return out
	var rng := SimRng.new(SimRng.deriveSeed(match_seed, "vfx.crack") ^ (key & SimRng.MASK))
	var dir: float = 1.0 if dx_total >= 0.0 else -1.0
	var len: float = absf(dx_total)
	var se: float = sqrt(E)
	var w0: float = clampf(hw * 0.05, VfxLook.CR_W_MIN, VfxLook.CR_W_MAX)
	var q: float = VfxLook.SPOKES_BY_QUALITY[clampi(quality, 0, 2)]
	# Splits along both edges of the trench, in pieces so each stays a short strip.
	var piece: float = maxf(hw * 4.0, 1.0)
	var np: int = clampi(int(ceil(len / piece)), 1, 24)
	for side in [-1.0, 1.0]:
		var d0: float = 0.0
		for i in range(np):
			var l1: float = minf(len, d0 + piece * rng.range_(0.8, 1.1))
			var pl := Line.new()
			var nseg: int = maxi(3, int((l1 - d0) / maxf(hw * 0.6, 24.0)))
			for k in range(nseg + 1):
				var t: float = float(k) / float(nseg)
				pl.pts.append(Vector2(dir * (d0 + (l1 - d0) * t), side * hw * rng.range_(0.95, 1.25)))
			pl.w0 = w0 * rng.range_(0.8, 1.3)
			_clip_front(pl)
			if pl.pts.size() >= 2:
				out.append(pl)
			d0 = l1 + piece * rng.range_(0.0, 0.35)
			if d0 >= len:
				break
	# A herringbone of spurs, a pair every SL_STEP.
	var ns: int = clampi(int(len / VfxLook.SL_STEP), 1, VfxLook.SL_MAX_SPURS)
	for i in range(ns):
		var d: float = (float(i) + 0.5) * len / float(ns)
		for side in [-1.0, 1.0]:
			if rng.next() > (0.85 if paved else 0.55) * q + 0.1:
				continue
			var ang: float = (0.0 if dir > 0.0 else PI) + side * rng.range_(0.35, 0.8)
			var l: float = hw * rng.range_(VfxLook.SL_SPUR_MIN, VfxLook.SL_SPUR_MAX) * (0.8 if paved else 1.0)
			_spoke_from(out, rng, Vector2(dir * d, side * hw), ang, l, w0 * rng.range_(0.7, 1.1), false, 0)
	# A fan where it stopped: a few cracks radiating from the end.
	var nfan: int = clampi(int(round((2.0 + se) * q)), 2, 8)
	var end := Vector2(dir * len, 0.0)
	for i in range(nfan):
		var ang: float = (0.0 if dir > 0.0 else PI) + rng.range_(-1.0, 1.0)
		_spoke_from(out, rng, end, ang, hw * rng.range_(1.2, 2.8), w0 * rng.range_(0.9, 1.4), false, 0)
	return out


## One crack from the rim: a jointed random walk that keeps roughly its first heading, with the odd fork.
static func _spoke(out: Array, rng: SimRng, r0: float, ang: float, length: float, w0: float, fissure: bool, depth: int) -> void:
	_spoke_from(out, rng, Vector2(cos(ang), sin(ang)) * r0, ang, length, w0, fissure, depth)


static func _spoke_from(out: Array, rng: SimRng, start: Vector2, ang: float, length: float, w0: float, fissure: bool, depth: int) -> void:
	var step: float = maxf(length * (0.16 if fissure else 0.2), 20.0)
	var n: int = clampi(int(length / step) + 1, 2, 9)
	var pl := Line.new()
	pl.w0 = w0
	pl.fissure = fissure
	var p: Vector2 = start
	var heading: float = ang
	pl.pts.append(p)
	var forks: Array = []
	for i in range(n):
		heading = lerpf(heading + rng.range_(-0.5, 0.5), ang, 0.28)
		var s: float = step * rng.range_(0.7, 1.25)
		p += Vector2(cos(heading), sin(heading)) * s
		pl.pts.append(p)
		if depth < 1 and i >= 1 and i < n - 1 and rng.next() < (0.30 if fissure else 0.34):
			forks.append([p, heading + (1.0 if rng.next() < 0.5 else -1.0) * rng.range_(0.5, 0.95), length * rng.range_(0.25, 0.45) * (float(n - i) / float(n)), w0 * 0.6])
	_clip_front(pl)
	if pl.pts.size() >= 2:
		out.append(pl)
	for f in forks:
		_spoke_from(out, rng, f[0], f[1], f[2], f[3], false, depth + 1)


## Drop the part of a line in front of the fighter plane (the first point that passes Z_CRACK_MAX ends it).
static func _clip_front(pl: Line) -> void:
	for i in range(pl.pts.size()):
		if pl.pts[i].y > VfxLook.Z_CRACK_MAX:
			if i < 2:
				pl.pts = PackedVector2Array()
			else:
				pl.pts = pl.pts.slice(0, i)
			return
