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
const R_BASE: float = 58.0            # bowl radius (units) at E = 1
const R_MAX: float = 260.0            # largest bowl radius
const DEPTH_RATIO: float = 0.22       # bowl depth / bowl radius for a straight-down hit
const RELIEF_MAX_RATIO: float = 0.26  # depth of any spot below its surroundings, per unit of the new crater's R
const RING_K: float = 1.2             # the surroundings are sampled at +-RING_K * R from the centre
const MIN_DEPTH: float = 0.75         # a dig shallower than this is not a crater (no record, no event)
# ---- rim and ejecta ----
const RIM_IN: float = 0.3             # the rim starts to rise this far (in R) inside the lip
const RIM_OUT: float = 1.0            # the apron ends this far (in R) beyond the lip
const RIM_H_FRAC: float = 0.5         # rim height / bowl depth
# ---- heightfield limits ----
const DEFORM_FLOOR: float = -260.0    # deform never goes below this (the prototype's floor)
const DEFORM_CEIL: float = 60.0       # nor above this: rims and aprons stack up to here
const TREE_FELL_K: float = 1.05       # trees within this many R of the centre fall
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
const POWERUP_E: float = 1.6          # ground-level power-up: E = POWERUP_E * tier^1.5
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
const SCORCH_REACH0: float = 40.0     # the beam scorches ground within reach of it: reach = REACH0 + REACH_P * P
const SCORCH_REACH_P: float = 12.0
const SCORCH_HW0: float = 30.0        # groove half width = (HW0 + HW_P * P) * variant width factor
const SCORCH_HW_P: float = 22.0
const SCORCH_D0: float = 3.0          # groove target depth = (D0 + D_P * P) * variant depth factor
const SCORCH_D_P: float = 2.2
const SCORCH_INT0: float = 0.35       # burn intensity = clamp(INT0 + INT_P * P, 0, 1)
const SCORCH_INT_P: float = 0.15
## Per beam variant: [depth factor, width factor]. Ridge bore drills, glass trench fuses a wide shallow strip.
const SCORCH_VARIANT: Dictionary = {"RIDGE BORE": [1.6, 0.8], "GLASS TRENCH": [0.8, 1.3], "FIRESTORM": [1.0, 1.1], "BOULEVARD RAZE": [0.8, 1.0], "MERIDIAN SCAR": [1.0, 1.0], "HORIZON CLEAVE": [1.0, 1.0]}


## The beam-power scalar: charge and tier in one number. power runs 0 to 100 and the tier is 1 + floor(power / 25),
## so P equals the tier in the middle of each band and rises smoothly through it: 0.5 at power 0, 4.5 at power 100.
static func beamPower(A) -> float:
	return BEAM_P_BASE + A.power / BEAM_P_POWER


static func impactEnergy(sp: float, tier: float) -> float:
	var v: float = sp / IMPACT_SPEED_REF
	return v * v * (1.0 + IMPACT_TIER_E * (tier - 1.0))


static func powerupEnergy(tier: float) -> float:
	return POWERUP_E * tier * sqrt(tier)


static func explodeEnergy(tier: float) -> float:
	return EXPLODE_E * tier * (1.0 + EXPLODE_E_TIER * tier)


static func clashEnergy(tier: float) -> float:
	return CLASH_E0 + CLASH_E_TIER * tier


static func beamStrikeEnergy(P: float) -> float:
	return BEAM_STRIKE_E * P * (1.0 + BEAM_STRIKE_E_P * P)


static func beamReach(P: float) -> float:
	return SCORCH_REACH0 + SCORCH_REACH_P * P


static func radiusOf(energy: float) -> float:
	return minf(R_MAX, R_BASE * sqrt(energy))


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


## Dig a crater of energy E at x. kind is "impact", "beam" or "powerup". dirx is the impact velocity's signed horizontal
## share (vx / speed) and vert its vertical share (|vy| / speed); both only matter for impacts. Returns the record, or
## null when the spot was already too dented to take a crater of this size.
static func dig(S: SimState, x: float, energy: float, cause, kind: String, dirx: float = 0.0, vert: float = 1.0):
	if energy <= 0.0:
		return null
	var NC: int = SimConst.NC
	var COL: float = SimConst.COL
	var R: float = radiusOf(energy)
	var c0: int = _col(x)
	var y0: float = WorldTerrain.groundY(S, x)
	var nr: int = int(round(RING_K * R / COL))
	var ring: float = (S.deform[(c0 - nr + NC) % NC] + S.deform[(c0 + nr) % NC]) * 0.5
	var relief: float = ring - S.deform[c0]
	var dRaw: float = R * DEPTH_RATIO * (GRAZE_MIN + (1.0 - GRAZE_MIN) * clampf(vert, 0.0, 1.0))
	var d: float = minf(dRaw, RELIEF_MAX_RATIO * R - relief)
	if d < MIN_DEPTH:
		return null
	var hr: float = d * RIM_H_FRAC
	var n: int = int(ceil(R * (1.0 + RIM_OUT) / COL))
	var minG: float = 1e9
	for k in range(-n, n + 1):
		var i: int = (c0 + k + NC) % NC
		var u: float = absf(float(k) * COL) / R
		var v: float = S.deform[i] + profile(u, d, hr)
		S.deform[i] = clampf(v, DEFORM_FLOOR, DEFORM_CEIL)
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
				var i2: int = (c0 - int(dir) * j + NC) % NC
				S.deform[i2] = clampf(S.deform[i2] - sdepth * q * q, DEFORM_FLOOR, DEFORM_CEIL)
			skid = -dir * len
	for t in S.trees:
		if t.alive and absf(SimWrap.sdx(x, t.x)) < R * TREE_FELL_K:
			t.alive = false
			SimFx.debris(S, t.x, WorldTerrain.groundY(S, t.x) + 10.0, 3, "#2f4a25", 300.0)
	S.world.craters += 1.0
	var rec := SimState.Crater.new()
	rec.x = SimWrap.wrap(x); rec.y = y0; rec.r = R; rec.depth = d; rec.rim = hr; rec.energy = energy
	rec.cause = kind; rec.owner = _slot(S, cause); rec.t = S.T; rec.skid = skid; rec.sdepth = sdepth
	S.craters.append(rec)
	if S.craters.size() > LIST_MAX:
		S.craters.remove_at(0)
	SimFx.crater(S, rec)
	WorldWater.touched(S, c0, n + int(ceil(absf(skid) / COL)), minG)
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
			dfm[i] = target
		var sc: float = inten * t
		if sc > scm[i]:
			scm[i] = sc
		minG = minf(minG, base[i] + dfm[i])
	S.deform = dfm
	S.scorch = scm
	SimFx.scorchEvent(S, x, y0, hw * 2.0, P, variant, _slot(S, cause))
	WorldWater.touched(S, c0, n, minG)
