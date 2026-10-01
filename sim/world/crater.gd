class_name WorldCrater
## Craters and beam scorch (GDScript only; the frozen JS core keeps the prototype's cos-squared notch).
##
## One scalar, the impact energy E, sets a crater's size: bowl radius R = R_BASE * sqrt(E), capped at R_MAX. Every
## source maps to E with a small polynomial (impactEnergy, powerupEnergy, explodeEnergy, beamStrikeEnergy). A crater is
## a smooth bowl with a raised rim and a thin ejecta apron; it is added to the heightfield (S.deform), so repeated hits
## pile up, but the depth of each hit is limited by the relief the spot already has (RELIEF_MAX_RATIO * R), so no
## amount of hitting one place digs a shaft. Beams do not dig a crater per sample any more: they carve a groove of
## fixed target depth along the ground (scorch), and dig one strike crater where a steep beam first meets the ground.
## The numbers and the reasoning: docs/world/craters-scorch-water.md. Events and the record list: fx-events.md.

# ---- energy to size ----
const WS: float = SimConst.WS         # feature scale: craters are world features (docs/world/scale.md)
const R_BASE: float = 20.0 * WS       # bowl radius (units) at E = 1: an ordinary impact leaves a modest bowl
const ORD_R_MAX: float = 8.0 * 75.0   # the largest bowl an ordinary blow leaves (8 fighter heights)
const R_MAX: float = 1040.0 * WS      # the largest bowl of all: a special blow or a tier-4 power-up
const SPECIAL_E_MULT: float = 9.0     # a signature, finisher, break launch or beam clash has 9 times the energy (3 times the radius)
const DEPTH_RATIO: float = 0.22       # bowl depth / bowl radius for a straight-down hit
const RELIEF_MAX_RATIO: float = 0.26  # depth of any spot below its surroundings, per unit of the new crater's R
const RING_K: float = 1.2             # the surroundings are sampled at +-RING_K * R from the centre
const MIN_DEPTH: float = 0.75 * WS    # a dig shallower than this is not a crater (no record, no event)
# ---- rim and ejecta ----
const RIM_IN: float = 0.3             # the rim starts to rise this far (in R) inside the lip
const RIM_OUT: float = 1.0            # the apron ends this far (in R) beyond the lip
const RIM_H_FRAC: float = 0.5         # rim height / bowl depth at the volume fraction of RIM_VOL_PER_HEIGHT (kept for reference)
## Rim height scales with the energy (W-R): the rim and apron carry RIM_VOL_LOW of the bowl's volume at E <= RIM_E_LOW and
## RIM_VOL_HIGH at E >= RIM_E_HIGH, smoothstep between. Rim height = depth * volume fraction * RIM_H_PER_VOL, where
## RIM_H_PER_VOL = 0.5 / 0.6 is the measured height per unit of volume (rim 0.5 of depth carries 0.6 of the bowl).
const RIM_VOL_LOW: float = 0.4
const RIM_VOL_HIGH: float = 1.0
const RIM_E_LOW: float = 1.0
const RIM_E_HIGH: float = 16.0
const RIM_H_PER_VOL: float = 0.5 / 0.6
# ---- heightfield limits ----
const DEFORM_FLOOR: float = -260.0 * WS   # deform never goes below this (the prototype's floor, scaled)
const DEFORM_CEIL: float = 120.0 * WS     # nor above this: rims, aprons and rubble stack up to here
const TREE_FELL_K: float = 1.05       # trees within this many R of the centre fall
## The angle of repose (docs/world/terrain-audit.md, T2): no step between neighbouring columns may exceed REPOSE_SLOPE times the
## column width, unless the original ground already had a steeper step there. A crater's bowl and rim are well inside it, so
## they stay as dug; heaps, grooves and trenches that are steeper than loose material would lie are relaxed, conserving volume.
const REPOSE_SLOPE: float = 1.25
const REPOSE_PASSES: int = 64       # a forward and a backward sweep each; a quiet pass ends the loop early
const REPOSE_PAD: int = 12          # columns past a change the relaxation may reach
const REPOSE_EPS: float = 2.0       # a step this much over the limit is left (a tenth of a column): the sweeps end when a pass moves less than this in all
const LIST_MAX: int = 400             # persistent crater records; the oldest is dropped when full
# ---- glancing impacts: the bowl gets shallower, and a diagonal one skids a furrow into it ----
const GRAZE_MIN: float = 0.6          # bowl depth factor for a fully horizontal hit (1 for straight down)
const SKID_DIRX_MIN: float = 0.35     # horizontal share of the impact velocity below which there is no furrow
const SKID_DIRX_FULL: float = 0.85    # ... and at which the furrow is full length
const SKID_LEN_R: float = 1.1         # full furrow length in R
const SKID_DEPTH_FRAC: float = 0.35   # furrow depth at the bowl / bowl depth
# ---- energy scalars per source (E in "energy units"; 1 is a scuff, 15 a planet-scarring blow) ----
const IMPACT_SPEED_REF: float = 900.0 # a launched fighter hitting the ground at this speed on tier 1 has E = 1
const IMPACT_TIER_E: float = 0.25     # +25 percent energy per tier above 1
const POWERUP_E: float = 1.0          # ground-level power-up: E = POWERUP_E * tier^POWERUP_E_EXP (tier 4 is a district)
const POWERUP_E_EXP: float = 3.2
const EXPLODE_E: float = 1.6          # beam-clash blast: E = EXPLODE_E * tier * (1 + 0.25 * tier)
const EXPLODE_E_TIER: float = 0.25
const CLASH_E0: float = 0.8           # heavy-clash shockwave: E = CLASH_E0 + CLASH_E_TIER * tier
const CLASH_E_TIER: float = 0.9
const BEAM_STRIKE_E: float = 2.0      # beam ground strike: E = BEAM_STRIKE_E * P * (1 + 0.4 * P)
const BEAM_STRIKE_E_P: float = 0.4
const BEAM_STRIKE_SLOPE: float = 0.25 # a beam must descend at least this steeply (|uy|) to dig a strike crater
# ---- beam power scalar ----
const BEAM_P_BASE: float = 0.5        # P = BEAM_P_BASE + power / BEAM_P_POWER: equals the tier at the middle of a tier band
const BEAM_P_POWER: float = 25.0
# ---- scorch: a groove along the ground, target depth (carved to, not added) and permanent burn intensity ----
const SCORCH_REACH0: float = 40.0 * WS    # the beam scorches ground within reach of it: reach = REACH0 + REACH_P * P
const SCORCH_REACH_P: float = 12.0 * WS
const SCORCH_HW0: float = 30.0 * WS       # groove half width = (HW0 + HW_P * P) * variant width factor
const SCORCH_HW_P: float = 22.0 * WS
const SCORCH_D0: float = 3.0 * WS         # groove target depth = (D0 + D_P * P) * variant depth factor
const SCORCH_D_P: float = 2.2 * WS
const SCORCH_INT0: float = 0.35       # burn intensity = clamp(INT0 + INT_P * P, 0, 1)
const SCORCH_INT_P: float = 0.15
## Per beam variant: [depth factor, width factor]. Ridge bore drills, glass trench fuses a wide shallow strip.
const SCORCH_VARIANT: Dictionary = {"RIDGE BORE": [1.6, 0.8], "GLASS TRENCH": [0.8, 1.3], "FIRESTORM": [1.0, 1.1], "BOULEVARD RAZE": [0.8, 1.0], "MERIDIAN SCAR": [1.0, 1.0], "HORIZON CLEAVE": [1.0, 1.0]}


## The beam-power scalar: charge and tier in one number. power runs 0 to 100 and the tier is 1 + floor(power / 25),
## so P equals the tier in the middle of each band and rises smoothly through it: 0.5 at power 0, 4.5 at power 100.
static func beamPower(A) -> float:
	return BEAM_P_BASE + A.power / BEAM_P_POWER


## sp is the unboosted speed: the launch's horizontal traversal factor is divided out before the energy is taken.
static func impactEnergy(sp: float, tier: float) -> float:
	var v: float = sp / IMPACT_SPEED_REF
	return v * v * (1.0 + IMPACT_TIER_E * (tier - 1.0))


static func powerupEnergy(tier: float) -> float:
	return POWERUP_E * SimDetMath.pow(tier, POWERUP_E_EXP)


static func explodeEnergy(tier: float) -> float:
	return EXPLODE_E * tier * (1.0 + EXPLODE_E_TIER * tier)


static func clashEnergy(tier: float) -> float:
	return CLASH_E0 + CLASH_E_TIER * tier


static func beamStrikeEnergy(P: float) -> float:
	return BEAM_STRIKE_E * P * (1.0 + BEAM_STRIKE_E_P * P)


static func beamReach(P: float) -> float:
	return SCORCH_REACH0 + SCORCH_REACH_P * P


static func radiusOf(energy: float, uncapped: bool = false) -> float:
	return minf(R_MAX if uncapped else ORD_R_MAX, R_BASE * sqrt(energy))


## Height change at distance u (in R) from a crater centre for bowl depth d and rim height hr: a smooth bowl inside
## the lip, a rim rising from RIM_IN inside it to a crest at the lip, and an apron falling to nothing at RIM_OUT beyond.
## Polynomials only, so it is exact and cheap. The renderer uses this same function for the z = 0 slice of a bowl.
static func profile(u: float, d: float, hr: float) -> float:
	var h: float = 0.0
	if u < 1.0:
		var t: float = 1.0 - u * u
		h = -d * t * t
		var lo: float = 1.0 - RIM_IN
		if u > lo:
			var a: float = (u - lo) / RIM_IN
			h += hr * a * a * (3.0 - 2.0 * a)
	elif u < 1.0 + RIM_OUT:
		var b: float = (u - 1.0) / RIM_OUT
		h = hr * (1.0 - b * b * (3.0 - 2.0 * b))
	return h


static func _slot(S: SimState, cause) -> float:
	for i in range(S.fighters.size()):
		if S.fighters[i] == cause:
			return float(i)
	return -1.0


static func _col(x: float) -> int:
	return int(floor(SimWrap.wrap(x) / SimConst.COL))


## Dig a crater of energy E at x. kind is "impact", "beam" or "powerup". special marks the blows that are meant to leave the
## big marks: a signature, a finisher, a break launch, a beam clash; its energy is multiplied by SPECIAL_E_MULT (bowl radius
## times its square root) and its radius may reach R_MAX, where an ordinary blow is held to ORD_R_MAX (a power-up is its
## own ladder and is held only by R_MAX). dirx is the impact velocity's signed horizontal share (vx / speed) and vert its
## vertical share (|vy| / speed); both only matter for impacts. Returns the record, or null when the spot was already too
## dented to take a crater of this size.
static func dig(S: SimState, x: float, energy: float, cause, kind: String, dirx: float = 0.0, vert: float = 1.0, special: bool = false):
	if energy <= 0.0:
		return null
	var E: float = energy * (SPECIAL_E_MULT if special else 1.0)
	var NC: int = SimConst.NC
	var COL: float = SimConst.COL
	var R: float = radiusOf(E, special or kind == "powerup")
	var xw: float = SimWrap.wrap(x)
	var c0: int = _col(xw)
	var y0: float = WorldTerrain.groundY(S, xw)
	var nr: int = int(round(RING_K * R / COL))
	var ring: float = (S.deform[(c0 - nr + NC) % NC] + S.deform[(c0 + nr) % NC]) * 0.5
	var relief: float = ring - S.deform[c0]
	var dRaw: float = R * DEPTH_RATIO * (GRAZE_MIN + (1.0 - GRAZE_MIN) * clampf(vert, 0.0, 1.0))
	var d: float = minf(dRaw, RELIEF_MAX_RATIO * R - relief)
	if d < MIN_DEPTH:
		return null
	var rt: float = clampf((E - RIM_E_LOW) / (RIM_E_HIGH - RIM_E_LOW), 0.0, 1.0)
	var volFrac: float = RIM_VOL_LOW + (RIM_VOL_HIGH - RIM_VOL_LOW) * rt * rt * (3.0 - 2.0 * rt)
	var hr: float = d * volFrac * RIM_H_PER_VOL
	var n: int = int(ceil(R * (1.0 + RIM_OUT) / COL)) + 1
	var minG: float = 1e9
	var pre := PackedFloat32Array()   # the deform before this crater, for the furrow's target
	pre.resize(2 * n + 1)
	for k in range(-n, n + 1):
		var i: int = (c0 + k + NC) % NC
		# u from the true distance to the centre, so the profile is centred on x and not on its column
		var u: float = absf(SimWrap.sdx(xw, float(i) * COL)) / R
		var old: float = S.deform[i]
		pre[k + n] = old
		var h: float = profile(u, d, hr)
		# A rim that lands on ground that is already raised merges with it (the higher of the two) instead of stacking.
		var v: float = maxf(old, h) if (h > 0.0 and old > 0.0) else old + h
		var nv: float = clampf(v, DEFORM_FLOOR, DEFORM_CEIL)
		if nv < old and S.rubble[i] > 0.0:
			S.rubble[i] = maxf(0.0, S.rubble[i] - (old - nv))   # a dig removes the heap first
		S.deform[i] = nv
		minG = minf(minG, S.base[i] + S.deform[i])
	var skid: float = 0.0
	var sdepth: float = 0.0
	if kind == "impact":
		var ax: float = absf(dirx)
		if ax > SKID_DIRX_MIN:
			var kk: float = minf(1.0, (ax - SKID_DIRX_MIN) / (SKID_DIRX_FULL - SKID_DIRX_MIN))
			var len: float = SKID_LEN_R * R * kk
			sdepth = d * SKID_DEPTH_FRAC * kk
			var dir: float = 1.0 if dirx > 0.0 else -1.0
			var m: int = int(ceil(len / COL))
			for j in range(m + 1):
				var q: float = 1.0 - float(j) * COL / len
				if q <= 0.0:
					break
				var k2: int = -int(dir) * j
				var i2: int = (c0 + k2 + NC) % NC
				# The furrow cuts toward a target below the ground as it was before the crater, so it opens a channel
				# through the rim and never digs deeper than the bowl floor it runs into.
				var before: float = pre[k2 + n] if absi(k2) <= n else S.deform[i2]
				var target: float = clampf(before - sdepth * q * q, DEFORM_FLOOR, DEFORM_CEIL)
				if target < S.deform[i2]:
					if S.rubble[i2] > 0.0:
						S.rubble[i2] = maxf(0.0, S.rubble[i2] - (S.deform[i2] - target))
					S.deform[i2] = target
			skid = -dir * len
	for t in S.trees:
		if t.alive and absf(SimWrap.sdx(xw, t.x)) < R * TREE_FELL_K:
			t.alive = false
			SimFx.debris(S, t.x, WorldTerrain.groundY(S, t.x) + 10.0, 3, "#2f4a25", 300.0)
	S.world.craters += 1.0
	var rec := SimState.Crater.new()
	rec.x = xw; rec.y = y0; rec.r = R; rec.depth = d; rec.rim = hr; rec.energy = E
	rec.cause = kind; rec.owner = _slot(S, cause); rec.t = S.T; rec.skid = skid; rec.sdepth = sdepth
	rec.special = 1.0 if special else 0.0
	S.craters.append(rec)
	if S.craters.size() > LIST_MAX:
		S.craters.remove_at(0)
	SimFx.crater(S, rec)
	var cols: int = n + int(ceil(absf(skid) / COL)) + REPOSE_PAD
	minG = minf(minG, relax(S, c0, cols))
	WorldWater.touched(S, c0, cols, minG)
	return rec


## A beam sample within reach of the ground: carve the groove toward its target depth (never deeper than that however
## many samples cross it), raise the permanent burn mark, and emit the scorch event. Half width and depth grow with P.
static func scorch(S: SimState, x: float, P: float, variant: String, cause) -> void:
	var NC: int = SimConst.NC
	var COL: float = SimConst.COL
	var vk: Array = SCORCH_VARIANT.get(variant, [1.0, 1.0])
	var hw: float = (SCORCH_HW0 + SCORCH_HW_P * P) * vk[1]
	var depth: float = (SCORCH_D0 + SCORCH_D_P * P) * vk[0]
	var inten: float = clampf(SCORCH_INT0 + SCORCH_INT_P * P, 0.0, 1.0)
	var y0: float = WorldTerrain.groundY(S, x)
	var c0: int = _col(x)
	var n: int = int(ceil(hw / COL))
	var minG: float = 1e9
	var carved: bool = false
	var base: PackedFloat32Array = S.base
	var dfm: PackedFloat32Array = S.deform   # local copies are written back below (packed arrays copy on write)
	var scm: PackedFloat32Array = S.scorch
	var inv: float = COL / hw
	for k in range(-n, n + 1):
		var u: float = absf(float(k)) * inv
		if u >= 1.0:
			continue
		var i: int = (c0 + k + NC) % NC
		var t: float = 1.0 - u * u
		var target: float = maxf(-depth * t * t, DEFORM_FLOOR)
		if target < dfm[i]:
			if S.rubble[i] > 0.0:
				S.rubble[i] = maxf(0.0, S.rubble[i] - (dfm[i] - target))
			dfm[i] = target
			carved = true
		var sc: float = inten * t
		if sc > scm[i]:
			scm[i] = sc
		minG = minf(minG, base[i] + dfm[i])
	S.deform = dfm
	S.scorch = scm
	SimFx.scorchEvent(S, x, y0, hw * 2.0, P, variant, _slot(S, cause))
	if carved:
		minG = minf(minG, relax(S, c0, n + REPOSE_PAD))
	WorldWater.touched(S, c0, n + REPOSE_PAD, minG)


## Relax the ground around column c0 (half columns each side) to the angle of repose: forward and backward sweeps move half
## of any excess step from the high column to the low one (volume conserved, rubble moves with the material, the clamps hold),
## until a sweep moves nothing or REPOSE_PASSES is reached. A step the original ground already had is allowed, and the columns
## under a standing building's footing (WorldStructures.pinned) may be lowered but never raised. Returns the lowest
## ground in the window. Deterministic (fixed order, no draws); the cost is one pass over the window per call.
static func relax(S: SimState, c0: int, half: int) -> float:
	var NC: int = SimConst.NC
	var limit: float = REPOSE_SLOPE * SimConst.COL
	var base: PackedFloat32Array = S.base
	var dfm: PackedFloat32Array = S.deform
	var rub: PackedFloat32Array = S.rubble
	var cnt: int = mini(2 * half + 1, NC)
	var lo: int = c0 - half
	# Most calls find nothing to do: look first, before the footing mask is built.
	var need: bool = false
	for k in range(cnt - 1):
		var i0: int = posmod(lo + k, NC)
		var j0: int = posmod(lo + k + 1, NC)
		var d0: float = (base[j0] + dfm[j0]) - (base[i0] + dfm[i0])
		if absf(d0) - maxf(limit, absf(base[j0] - base[i0])) > REPOSE_EPS:
			need = true
			break
	if not need:
		var m0: float = 1.0e9
		for k in range(cnt):
			var c0m: int = posmod(lo + k, NC)
			m0 = minf(m0, base[c0m] + dfm[c0m])
		return m0
	var pin: PackedByteArray = WorldStructures.pinned(S, c0, half)   # a standing building's footing is never moved
	for pass_n in range(REPOSE_PASSES):
		var moved: float = 0.0
		for sweep in range(2):
			for k in range(cnt - 1):
				var kk: int = k if sweep == 0 else cnt - 2 - k
				var i: int = posmod(lo + kk, NC)
				var j: int = posmod(lo + kk + 1, NC)
				var d: float = (base[j] + dfm[j]) - (base[i] + dfm[i])
				var ex: float = absf(d) - maxf(limit, absf(base[j] - base[i]))
				if ex <= REPOSE_EPS:
					continue
				var e: float = ex * 0.5
				var hi: int = j if d > 0.0 else i
				var lw: int = i if d > 0.0 else j
				if pin[kk + 1 if lw == j else kk] == 1:
					continue   # a footing may be lowered but never raised
				dfm[hi] = maxf(DEFORM_FLOOR, dfm[hi] - e)
				dfm[lw] = minf(DEFORM_CEIL, dfm[lw] + e)
				var rm: float = minf(rub[hi], e)
				if rm > 0.0:
					rub[hi] -= rm
					rub[lw] += rm
				moved += e
		if moved < REPOSE_EPS:
			break
	S.deform = dfm
	S.rubble = rub
	var minG: float = 1.0e9
	for k in range(cnt):
		var c: int = posmod(lo + k, NC)
		minG = minf(minG, base[c] + dfm[c])
	return minG


## Carve the trench of a slide along the path from xa to xb (the columns the fighter has just passed over) to the given
## depth: never deeper than the target, so a trench does not dig shafts however often it is crossed. The ground ahead of
## the fighter is untouched, so he rides the undug surface and the trench opens behind and under his feet. paved raises
## S.crack over the same columns by the given intensity. Used by the knockback slide.
static func carveSegment(S: SimState, xa: float, xb: float, depth: float, paved: bool, crack: float) -> void:
	var NC: int = SimConst.NC
	var COL: float = SimConst.COL
	var dx: float = SimWrap.sdx(xa, xb)
	var dir: int = 1 if dx >= 0.0 else -1
	var ca: int = _col(xa)
	var cb: int = _col(xb)
	# The columns from xa's up to but not including xb's, in the direction of travel: the ground ahead stays undug.
	var n: int = posmod((cb - ca) * dir, NC)
	if n == 0:
		return
	var base: PackedFloat32Array = S.base
	var dfm: PackedFloat32Array = S.deform
	var crk: PackedFloat32Array = S.crack
	var target: float = maxf(-depth, DEFORM_FLOOR)
	var minG: float = 1e9
	var carved: bool = false
	for k in range(n):
		var i: int = (ca + dir * k + NC) % NC
		if paved and crack > crk[i]:
			crk[i] = crack
		# A slide rides over a heap of rubble: it cracks it but never cuts a slot through it (T3).
		if S.rubble[i] <= 0.0 and target < dfm[i]:
			dfm[i] = target
			carved = true
		minG = minf(minG, base[i] + dfm[i])
	S.deform = dfm
	S.crack = crk
	var mid: int = posmod(ca + dir * (n / 2), NC)
	var half: int = n / 2 + REPOSE_PAD
	if carved:
		minG = minf(minG, relax(S, mid, half))
	WorldWater.touched(S, mid, half, minG)


## A small raised lip where a slide ends: two columns ahead in the direction of travel.
static func berm(S: SimState, x: float, vx: float, hw: float, h: float) -> void:
	var NC: int = SimConst.NC
	var c0: int = _col(x)
	var dir: int = 1 if vx >= 0.0 else -1
	for k in range(0, 3):
		var i: int = (c0 + dir * k + NC) % NC
		S.deform[i] = minf(DEFORM_CEIL, S.deform[i] + h * (1.0 - float(k) / 3.0))
