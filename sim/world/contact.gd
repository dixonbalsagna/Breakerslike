class_name WorldContact
## How a launched body leaves and meets the ground (docs/world/ground-contact.md; balance-targets.md section 20): a skid or a
## tumble leaves the ground where the terrain curves away faster than gravity pulls (the ballistic step ends above the ground)
## and keeps its velocity; a landing is classed by its angle to the surface and its speed (skid, bounce, tumble, slam); a journey
## is bounded (8 contacts, 4 s) and pays one impact of wear. All decisions are by speed, angle and surface: no random draw, no
## trigonometry (an angle is a ratio), every x wrapped with SimWrap.
##
## The motion is one pure step (Body, moveAir, groundPhase, stepContact) shared by the runtime (stepFighter, which also does the
## side effects: craters, trenches, damage, events) and by the launch predictor (journey), so a predicted journey is the
## journey that is played. Numbers are data (data/biomes/contact.json); data.enabled switches the whole model (S.contactOn).

const PATH: String = "res://data/biomes/contact.json"
const SCHEMA: String = "biomes.contact/1"
const AIR: int = 0
const SKID: int = 1
const TUMBLE: int = 2
const CONTACT_MAX: int = 8            # contactT saturates here
const TICK_CAP: int = 900            # the journey predictor's step cap (15 s): a safety net, the caps end it first
const SURFACES: Array = ["paving", "rock", "soil", "sand", "rubble"]

static var _d: Dictionary = {}
static var _errors: Array = []
static var _loaded: bool = false
static var _parsed: Dictionary = {}
const SURF_NAMES: Array = ["soil", "sand", "rock", "paving"]
static var _colSurf := PackedByteArray()      # per terrain column: the biome's surface (0 soil, 1 sand, 2 rock) | 4 if the biome is paved
static var K_HALF: float = 0.5
static var K_SKIM_MIN: float = 500.0
static var K_SKIM_TAN: float = 0.6
static var K_SKIM_MAX: float = 6.0
static var K_SKIM_LIFT: float = 0.65
static var K_SKIM_KEEP: float = 0.85
static var K_SINK: float = 200.0
static var K_MAXC: int = 8
static var K_MAXT: int = 240
static var K_TUMT: int = 72
static var K_TAILT: int = 18
static var K_TUMBRAKE: float = 2.0
static var K_WALL: float = 0.8
static var K_STOP: float = 60.0
static var K_LIFT: float = 1.0
static var K_CLEAR: float = 1.5
static var K_SK2TU: float = 600.0
static var K_NOTHING: float = 350.0
static var K_SLAM2: float = 0.883
static var K_SKID2: float = 0.25
static var K_TUMBLEBELOW: float = 900.0
static var K_HOPSPEED: float = 2000.0
static var K_HOPLIFT: float = 0.25
static var K_TKEEP: float = 0.8
static var K_VKEEP: Array = [0.45, 0.35, 0.25]
static var K_PERTIER: Array = [1, 2, 3, 3]
static var K_CAPTURNS: Array = [1.5, 3.0, 3.0, 3.0]
static var K_BODYR: float = 60.0
static var K_WPS: float = 0.0126
static var K_WTOUCH: float = 0.3
static var K_WCAP: float = 1.0           # the most wear a journey pays, as a share of the single-impact budget
static var K_AREA_LATER: float = 0.5     # a later contact pays this share of the area damage of the speed it removes
static var K_AREA_SLAM: float = 1.0      # the first contact pays this share of the impact's area damage when it is a slam ...
static var K_AREA_TOUCH: float = 0.5     # ... and this share when it is anything else (the old slide's touch-down)
static var K_AIRDRAG: float = 0.55      # the horizontal drag base per second after a journey's first contact (0.55 is the launch's own flight)
static var K_GMUL: float = 1.0           # gravity after a journey's first contact, times 1000
static var K_RUBBLE_MIN: float = 8.0
static var K_PAVE_DUG: float = -3.0
static var K_BRAKE: Dictionary = {}
static var K_TUMBLEONLY: Dictionary = {}


class Body:
	var x: float = 0.0
	var y: float = 0.0
	var vx: float = 0.0           # raw horizontal velocity (the launch's traversal factor included)
	var vy: float = 0.0
	var launchT: float = 1.0
	var mode: int = 0
	var vN: float = 0.0           # in a skid or a tumble: the normalised horizontal speed
	var dir: float = 1.0
	var bounces: float = 0.0
	var contacts: int = 0
	var t: int = 0                # ticks since the journey's first contact
	var v0: float = 0.0           # the journey's first-contact normalised speed
	var tumbleT: int = -1           # ticks rolled in a tumble, -1 when not tumbling
	var age: float = 0.0          # seconds since the launch (water's sink rule)
	var spin: float = 0.0
	var rot: float = 0.0
	var wet: bool = false
	var hopped: bool = false
	var tier: float = 1.0
	var done: bool = false
	var end: String = ""
	var capped: bool = false
	var slideD: float = 0.0
	var vLost: float = 0.0        # speed removed this tick (the wear)
	var dxStep: float = 0.0       # signed x moved this tick in contact
	var lips: int = 0
	var z: float = 0.0            # depth (T: the row the ground is read on when depth is on)


# ===================================================================== data

static func data() -> Dictionary:
	if not _loaded:
		_load()
	return _d


static func errors() -> Array:
	if not _loaded:
		_load()
	return _errors


static func enabled() -> bool:
	return bool(data().get("enabled", false))


## A hash of the data file's text, for the replay header's data hash.
static func dataHash() -> String:
	if not _loaded:
		_load()
	var h := SimHash.Hasher.new()
	h.text("biomes.contact")
	FighterData._canon(h, _parsed)   # the parsed data without the "_" notes, like the other loaders: a changed note keeps old replays
	return h.hex()


static func _load() -> void:
	_loaded = true
	_errors = []
	_d = {}
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		_errors.append("contact.json: cannot open " + PATH)
		return
	var j = JSON.parse_string(f.get_as_text())
	_parsed = j if j is Dictionary else {}
	if not (j is Dictionary) or j.get("schema", "") != SCHEMA:
		_errors.append("contact.json: not a %s object" % SCHEMA)
		return
	for k in ["bands", "leave", "bounce", "tumble", "journey", "wear", "spin", "surfaces", "water", "biomeSurface", "paving"]:
		if not j.has(k):
			_errors.append("contact.json: missing " + k)
	if _errors.is_empty():
		_d = j
		_cache()


## The numbers of the data file as typed statics, read each tick (a dictionary lookup per number is too slow in a hot step).
static func _cache() -> void:
	var D: Dictionary = _d
	K_HALF = float(D.spin.halfLife)
	var w: Dictionary = D.water
	K_SKIM_MIN = float(w.skimMinSpeed)
	K_SKIM_TAN = float(w.skimMaxTan)
	K_SKIM_MAX = float(w.skimMax)
	K_SKIM_LIFT = float(w.skimLift)
	K_SKIM_KEEP = float(w.skimKeep)
	K_SINK = float(w.sinkBelow)
	K_MAXC = int(D.journey.maxContacts)
	K_MAXT = _ticks(float(D.journey.maxSeconds))
	K_TUMT = _ticks(float(D.tumble.maxSeconds))
	K_TAILT = _ticks(float(D.tumble.cappedTail))
	K_TUMBRAKE = float(D.tumble.brakeMul)
	K_WALL = float(D.leave.wall)
	K_STOP = float(D.leave.stop)
	K_LIFT = float(D.leave.lipLift)
	K_CLEAR = float(D.leave.clear)
	K_SK2TU = float(D.bands.skidToTumble)
	K_NOTHING = float(D.bands.nothingBelow)
	K_SLAM2 = float(D.bands.slamSin2)
	K_SKID2 = float(D.bands.skidSin2)
	K_TUMBLEBELOW = float(D.bands.tumbleBelow)
	K_HOPSPEED = float(D.bounce.hopSpeed)
	K_HOPLIFT = float(D.bounce.hopLift)
	K_TKEEP = float(D.bounce.tangentKeep)
	K_VKEEP = D.bounce.vertKeep
	K_PERTIER = D.bounce.perTier
	K_CAPTURNS = D.spin.capTurns
	K_BODYR = float(D.spin.bodyR)
	K_WPS = float(D.wear.perSpeed)
	K_WTOUCH = float(D.wear.touch)
	K_WCAP = float(D.wear.get("cap", 1.0))
	K_AREA_LATER = float(D.get("area", {}).get("laterShare", 0.5))
	K_AREA_SLAM = float(D.get("area", {}).get("slam", 1.0))
	K_AREA_TOUCH = float(D.get("area", {}).get("touch", 0.5))
	K_GMUL = float(D.bounce.get("gravityMul", 1.0))
	K_AIRDRAG = float(D.bounce.get("airDrag", 0.55))
	K_RUBBLE_MIN = float(D.get("rubbleMin", 8.0))
	K_PAVE_DUG = float(D.paving.dugBelow)
	K_BRAKE = {}
	K_TUMBLEONLY = {}
	for k in D.surfaces:
		K_BRAKE[k] = float(D.surfaces[k].brake)
		K_TUMBLEONLY[k] = bool(D.surfaces[k].tumble)
	# the biome's surface per terrain column: the biome layout is fixed, so this is built once
	_colSurf.resize(SimConst.NC)
	for i in range(SimConst.NC):
		var biome: String = WorldBiomes.biomeAt(float(i) * SimConst.COL)
		var code: int = SURF_NAMES.find(String(D.biomeSurface.get(biome, "soil")))
		code = maxi(code, 0) & 3
		if D.paving.biomes.has(biome):
			code |= 4
		_colSurf[i] = code


## Seconds in data to whole ticks (the caps are integer tick counts: 240 for 4 s, 72 for 1.2 s).
static func _ticks(seconds: float) -> int:
	return int(round(seconds * 60.0))


static func _g(a: String, b: String) -> float:
	return float(data()[a][b])


# ===================================================================== the surface

## The surface class of the ground at x, by priority: rubble heap, paving (inside a paved biome and not dug), the biome's own.
static func surfaceAt(S: SimState, x: float) -> String:
	var col: int = int(floor(SimWrap.wrap(x) / SimConst.COL)) % SimConst.NC
	if S.rubble[col] >= K_RUBBLE_MIN:
		return "rubble"
	var c: int = _colSurf[col]
	if (c & 4) != 0 and S.deform[col] > K_PAVE_DUG:
		return "paving"
	return SURF_NAMES[c & 3]


static func _brake(S: SimState, x: float) -> float:
	return float(K_BRAKE[surfaceAt(S, x)])


static func _gslope(S: SimState, x: float, z: float = 0.0) -> float:
	var e: float = SimConst.COL
	return (WorldTerrain.groundY(S, x + e, z) - WorldTerrain.groundY(S, x - e, z)) / (2.0 * e)


# ===================================================================== the pure step

## The one place rot and spin change in a journey (never assigned, only integrated or eased): in the air and in a tumble the body
## rolls (rot grows by spin, spin halves every spin.halfLife seconds); in a skid it eases upright.
static func spinStep(b: Body, dt: float) -> void:
	if b.mode == SKID:
		b.rot *= SimDetMath.pow(0.001, dt)
		b.spin = 0.0
	else:
		b.rot += b.spin * dt
		b.spin *= SimDetMath.pow(0.5, dt / K_HALF)


## SimFighter.spin hands over here when contact is on (the fighter's rolling outside a journey: in the air, free, stopped). rot is
## only integrated or eased, never assigned.
static func spinFighter(f, dt: float, how: int) -> void:
	if how == 0:       # SimFighter.SPIN_AIR
		f.rot += f.spin * dt
		f.spin *= SimDetMath.pow(0.5, dt / K_HALF)
	elif how == 1:     # SPIN_FREE: ease upright
		f.rot = _wrapRot(f.rot) * SimDetMath.pow(0.001, dt)
	else:              # SPIN_STOP: a stop eases it out quickly
		f.rot = _wrapRot(f.rot) * SimDetMath.pow(0.000001, dt)
		f.spin = 0.0


## rot taken to the nearest whole turn of zero (not a jump, the same pose): the ease upright then goes the short way instead of
## unwinding every turn the body had made.
static func _wrapRot(r: float) -> float:
	return r - TAU * floorf(r / TAU + 0.5)


## The airborne part of a tick: gravity, drag, the move, the water (entry, skim, sink). Appends events {"k": ...}.
static func moveAir(S: SimState, b: Body, dt: float, ev: Array) -> void:
	b.age += dt
	if b.contacts > 0:
		b.t += 1
	var grav: float = 1000.0 * dt * (K_GMUL if b.contacts > 0 else 1.0)
	b.vy -= grav
	b.vx *= SimDetMath.pow(K_AIRDRAG if b.contacts > 0 else 0.55, dt)
	b.x = SimWrap.wrap(b.x + b.vx * dt)
	b.y += b.vy * dt
	spinStep(b, dt)
	var wsurf: float = WorldWater.surfaceAt(S, b.x)
	var inW: bool = b.y < wsurf
	if inW and not b.wet:
		b.wet = true
		ev.append({"k": "enter", "x": b.x, "y": wsurf})
		var wsp: float = SimDetMath.hypot(b.vx, b.vy)
		if b.vy < 0.0 and wsp > K_SKIM_MIN and -b.vy < absf(b.vx) * K_SKIM_TAN and b.bounces < K_SKIM_MAX and b.contacts < K_MAXC and b.t < K_MAXT:
			b.bounces += 1.0
			b.contacts += 1
			if b.contacts == 1:
				b.v0 = wsp / b.launchT
			b.y = wsurf
			b.vy = -b.vy * K_SKIM_LIFT
			b.vx *= K_SKIM_KEEP
			b.wet = false
			inW = false
			ev.append({"k": "skim", "x": b.x, "y": wsurf, "speed": wsp, "n": int(b.bounces)})
	if not inW and b.wet and b.y > wsurf:
		b.wet = false
	if inW:
		b.vy += grav   # water holds him up: it cancels the gravity of this tick, whatever it is
		b.vx *= SimDetMath.pow(0.05, dt)
		b.vy *= SimDetMath.pow(0.1, dt)
		if SimDetMath.hypot(b.vx, b.vy) < K_SINK and b.age > 0.3:
			b.done = true
			b.end = "water"
			ev.append({"k": "sink", "x": b.x, "y": b.y})


## The ground and the ceiling, after the move (and after the building collision, in the runtime).
static func groundPhase(S: SimState, b: Body, ev: Array) -> void:
	if b.done:
		return
	var g: float = WorldTerrain.groundY(S, b.x, b.z)
	if b.y <= g:
		_land(S, b, g, ev)
	if b.y > SimConst.CEILING:
		b.y = SimConst.CEILING
		b.vy = SimMathx.jmin(b.vy, 0.0)


static func _bounceCap(b: Body) -> int:
	return int(K_PERTIER[clampi(int(b.tier), 1, 4) - 1])


static func _spinFor(b: Body, vt: float) -> float:
	var cap: float = float(K_CAPTURNS[clampi(int(b.tier), 1, 4) - 1]) * 6.2831853
	var s: float = minf(absf(vt) / K_BODYR, cap)
	return (1.0 if vt >= 0.0 else -1.0) * s


## The landing: classify by the angle to the surface and the speed (section 20) and change the body.
static func _land(S: SimState, b: Body, g: float, ev: Array) -> void:
	var tv: float = b.launchT
	var vxn: float = b.vx / tv
	var vyn: float = b.vy
	var sp: float = SimDetMath.hypot(vxn, vyn)
	var s: float = _gslope(S, b.x, b.z)
	var q: float = sqrt(1.0 + s * s)
	var vn: float = (vyn - s * vxn) / q
	var vt: float = (vxn + s * vyn) / q
	var sin2: float = vn * vn / maxf(sp * sp, 1.0e-9)
	var surface: String = surfaceAt(S, b.x)
	var sea: bool = WorldTerrain.seaAt(S, b.x)
	b.y = g
	b.contacts += 1
	var first: bool = b.contacts == 1
	if first:
		b.v0 = sp
		b.t = 0
	var info := {"x": b.x, "y": g, "speed": sp, "vn": vn, "vt": vt, "sin2": sin2, "slope": s, "surface": surface, "first": first, "tier": b.tier}
	if sp <= K_NOTHING:
		info["k"] = "stop"
		ev.append(info)
		b.done = true
		b.end = "stop"
		return
	var wasHopped: bool = b.hopped
	# a steep landing is a slam at the first contact, and the landing after a hard slam's hop; a later steep landing after a bounce or a
	# lip launch is a bounce or a skid by the usual rules (a journey makes one mark)
	var slam: bool = sea or (sin2 >= K_SLAM2 and (first or wasHopped))
	var forceTumble: bool = b.contacts >= K_MAXC or b.t >= K_MAXT
	if slam:
		var hop: bool = (not sea) and sp >= K_HOPSPEED and not b.hopped
		info["k"] = "slam"
		info["hop"] = hop
		info["dig"] = not wasHopped
		ev.append(info)
		if hop:
			b.hopped = true
			b.vy = absf(b.vy) * K_HOPLIFT
			ev.append({"k": "left_ground", "cause": "bounce", "x": b.x, "y": g, "vx": b.vx, "vy": b.vy, "speed": sp, "slope": s})
		else:
			b.done = true
			b.end = "slam"
		return
	var tumbleOnly: bool = bool(K_TUMBLEONLY[surface]) or sp < K_TUMBLEBELOW or forceTumble
	var dir: float = 1.0 if vt >= 0.0 else -1.0
	if absf(vt) < 1.0e-6:
		dir = 1.0 if b.vx >= 0.0 else -1.0
	if not tumbleOnly:
		var cap: int = _bounceCap(b)
		if sin2 >= K_SKID2 and int(b.bounces) < cap:
			# a bounce: the normal part is reflected with the bounce's keep, the tangent part keeps its share
			var e: float = float(K_VKEEP[mini(int(b.bounces), K_VKEEP.size() - 1)])
			var vn2: float = -e * vn
			var vt2: float = K_TKEEP * vt
			var vxn2: float = (vt2 - s * vn2) / q
			var vyn2: float = (s * vt2 + vn2) / q
			b.vx = vxn2 * tv
			b.vy = vyn2
			b.bounces += 1.0
			b.spin = _spinFor(b, vt)
			info["k"] = "bounce"
			info["n"] = int(b.bounces)
			info["keep"] = SimDetMath.hypot(vxn2, vyn2) / maxf(sp, 1.0e-9)
			ev.append(info)
			ev.append({"k": "left_ground", "cause": "bounce", "x": b.x, "y": g, "vx": b.vx, "vy": b.vy, "speed": SimDetMath.hypot(vxn2, vyn2), "slope": s})
			return
		# shallow, or no bounce left at skid speed: a skid
		b.mode = SKID
	else:
		b.mode = TUMBLE
		b.tumbleT = 0
		if forceTumble:
			b.tumbleT = maxi(0, K_TUMT - K_TAILT)
			b.capped = true
	b.dir = dir
	b.vN = absf(vt) / q
	b.vx = dir * b.vN * tv
	b.vy = 0.0
	b.spin = 0.0 if b.mode == SKID else _spinFor(b, vt)
	info["k"] = "skid" if b.mode == SKID else "tumble"
	ev.append(info)


## One tick of a skid or a tumble: braking by surface (doubled in a tumble), the wall rule, the leave test, the end.
static func stepContact(S: SimState, b: Body, dt: float, ev: Array) -> void:
	b.age += dt
	b.t += 1
	b.vLost = 0.0
	b.dxStep = 0.0
	spinStep(b, dt)   # rot and spin stay smooth through a journey (a tumble rolls, a skid eases upright)
	var tv: float = b.launchT
	var dir: float = b.dir
	var vN: float = b.vN
	var sl: float = (WorldTerrain.groundY(S, b.x + dir * SimConst.COL, b.z) - b.y) / SimConst.COL
	var a: float = WorldSlide.MU * _brake(S, b.x) + WorldSlide.KV * vN + WorldSlide.GRAV * sl
	if b.mode == TUMBLE:
		a *= K_TUMBRAKE
	var vN2: float = maxf(0.0, vN - a * dt)
	var dx: float = dir * (vN + vN2) * 0.5 * tv * dt
	var x2: float = SimWrap.wrap(b.x + dx)
	var y2: float = WorldTerrain.groundY(S, x2, b.z)
	var run: float = maxf(absf(dx), 1.0e-6)
	var rise: float = (y2 - b.y) / run
	# ground that rises like a wall stops him with a stop-impact
	if rise > K_WALL and vN2 > K_STOP:
		b.done = true
		b.end = "wall"
		ev.append({"k": "wall", "x": b.x, "y": b.y, "speed": vN2})
		return
	# the leave test: would the next ballistic step end above the ground? he keeps his velocity along the ramp
	var sprev: float = _gslope(S, b.x, b.z) * dir
	var vyT: float = sprev * vN2 * K_LIFT
	var xa: float = SimWrap.wrap(b.x + dir * vN2 * tv * SimDetMath.pow(0.55, dt) * dt)
	var yb: float = b.y + (vyT - 1000.0 * dt) * dt
	# past the journey's caps (8 contacts or 4 s) he tumbles to a stop: no more leaving the ground
	var capNow: bool = b.contacts >= K_MAXC or b.t >= K_MAXT
	if not capNow and vN2 > 0.0 and yb - WorldTerrain.groundY(S, xa, b.z) > K_CLEAR:
		var cause: String = "crest"   # natural ground: a hill's or ridge's crest
		if S.rubble[int(floor(SimWrap.wrap(b.x) / SimConst.COL)) % SimConst.NC] > 0.0:
			cause = "heap"
		elif _nearRim(S, b.x):
			cause = "lip"             # a crater's lip
		elif -rise > 1.0:
			cause = "cliff"
		b.mode = AIR
		b.vx = dir * vN2 * tv
		b.vy = vyT
		b.vN = 0.0
		b.tumbleT = -1
		b.lips += 1
		b.vLost = maxf(0.0, vN - vN2)
		ev.append({"k": "left_ground", "cause": cause, "x": b.x, "y": b.y, "vx": b.vx, "vy": b.vy, "speed": SimDetMath.hypot(vN2, vyT), "slope": sprev})
		return
	b.vLost = maxf(0.0, vN - vN2)
	b.dxStep = dx
	b.x = x2
	b.y = y2
	b.vN = vN2
	b.vx = dir * vN2 * tv
	b.vy = 0.0
	b.slideD += absf(dx)
	if b.mode == SKID and vN2 < K_SK2TU:
		b.mode = TUMBLE
		b.tumbleT = 0
		b.spin = _spinFor(b, dir * vN2)
	if b.mode == TUMBLE:
		b.tumbleT += 1
		if b.tumbleT >= K_TUMT:
			b.done = true
			b.end = "tumble"
	if vN2 <= K_STOP and not b.done:
		b.done = true
		b.end = "stop"
	if not b.done and capNow and not b.capped:
		b.capped = true
		b.mode = TUMBLE
		b.tumbleT = maxi(maxi(b.tumbleT, 0), K_TUMT - K_TAILT)


## Is x within a crater's lip zone (from 0.5 R to 1.3 R of a crater's centre)? Only for naming a leave's cause.
static func _nearRim(S: SimState, x: float) -> bool:
	for c in S.craters:
		var d: float = absf(SimWrap.sdx(x, c.x))
		if d > 0.5 * c.r and d < 1.3 * c.r:
			return true
	return false


## The whole step for the predictor: the air, then the ground, or the contact.
static func stepBody(S: SimState, b: Body, dt: float, ev: Array) -> void:
	if b.mode == AIR:
		moveAir(S, b, dt, ev)
		groundPhase(S, b, ev)
	else:
		stepContact(S, b, dt, ev)


# ===================================================================== the journey (the planner's lookahead)

## The body a launch makes: from the launch position and velocity (vx carries the traversal factor launchT), by a launcher of
## the given tier; wet is true when the target starts under the sea (doLaunch sets it).
static func launchBody(x: float, y: float, vx: float, vy: float, launchT: float, tier: float, wet: bool = false, z: float = 0.0) -> Body:
	var b := Body.new()
	b.wet = wet
	b.x = x
	b.y = y
	b.vx = vx
	b.vy = vy
	b.launchT = launchT
	b.z = z
	b.tier = tier
	b.tumbleT = -1
	return b


## Run a body to the end of its journey (the stop, the 8 contacts or 4 s, then the tumble out; or the sea). Returns
## {"contacts": [{t, x, y, kind, speed}...], "end": {x, y, t, kind}, "n", "lips", "bounces", "tumble", "dist", "area": [{x, power}...],
## "ticks"}; pure, no draw, the same step as the runtime. The terrain is read as it is now: a crater or trench dug by the
## journey itself is not seen.
static func journey(S: SimState, b: Body) -> Dictionary:
	var dt: float = SimConst.DT
	var contacts: Array = []
	var area: Array = []
	var ticks: int = 0
	var x0: float = b.x
	var tumbled: bool = false
	while not b.done and ticks < TICK_CAP:
		var ev: Array = []
		stepBody(S, b, dt, ev)
		ticks += 1
		for e in ev:
			var k: String = String(e.k)
			if k in ["skid", "tumble", "bounce", "slam", "stop", "skim", "left_ground", "wall"]:
				contacts.append({"t": float(b.t) * dt, "x": float(e.get("x", b.x)), "y": float(e.get("y", b.y)), "kind": k, "speed": float(e.get("speed", 0.0))})
			if k in ["skid", "tumble", "bounce", "slam"]:
				area.append({"x": float(e.x), "power": float(e.speed)})
			if k == "tumble":
				tumbled = true
		if b.mode == SKID and b.dxStep != 0.0 and ticks % 3 == 0:
			area.append({"x": b.x, "power": b.vN})
	if b.mode == TUMBLE:
		tumbled = true
	return {"contacts": contacts, "end": {"x": b.x, "y": b.y, "t": float(b.t) * dt, "kind": b.end}, "n": b.contacts, "lips": b.lips,
		"bounces": int(b.bounces), "tumble": tumbled, "dist": absf(SimWrap.sdx(x0, b.x)), "area": area, "ticks": ticks}


# ===================================================================== the runtime: one fighter, one tick

static var _tb := Body.new()   # reused each tick (the sim is single threaded): the runtime step allocates nothing
static var _ev: Array = []


static func toBody(S: SimState, f) -> Body:
	var b: Body = _tb
	b.done = false
	b.end = ""
	b.capped = false
	b.vLost = 0.0
	b.dxStep = 0.0
	b.x = f.x
	b.y = f.y
	b.z = f.z
	b.vx = f.vx
	b.vy = f.vy
	b.launchT = f.launchT
	b.vN = f.slide
	b.dir = 1.0 if f.vx >= 0.0 else -1.0
	b.bounces = f.bounces
	b.contacts = f.jContacts
	b.t = f.jT
	b.v0 = f.jV0
	b.tumbleT = f.tumbleT
	b.age = f.stateT
	b.spin = f.spin
	b.rot = f.rot
	b.wet = f.wet
	b.hopped = f.hopped
	var by = f.launchBy if f.launchBy != null else SimRoster.opp(S, f)
	b.tier = by.tier
	b.slideD = f.slideD
	b.lips = f.jLips
	b.mode = AIR
	if f.slide > 0.0:
		b.mode = TUMBLE if f.tumbleT >= 0 else SKID
	return b


static func fromBody(f, b: Body) -> void:
	f.x = b.x
	f.y = b.y
	f.vx = b.vx
	f.vy = b.vy
	f.slide = b.vN if b.mode != AIR else 0.0
	f.bounces = b.bounces
	f.jContacts = b.contacts
	f.jT = b.t
	f.jV0 = b.v0
	f.tumbleT = b.tumbleT if b.mode == TUMBLE else -1
	f.spin = b.spin
	f.rot = b.rot
	f.wet = b.wet
	f.hopped = b.hopped
	f.slideD = b.slideD
	f.jLips = b.lips


## Called from SimFighter.stepLaunched when S.contactOn: one tick of a launched fighter's flight, skid or tumble, with every
## side effect (craters, trenches, damage, dust, events). Replaces the old slide step and impact.
static func stepFighter(S: SimState, f, dt: float) -> void:
	var by = f.launchBy if f.launchBy != null else SimRoster.opp(S, f)
	var b: Body = toBody(S, f)
	var ev: Array = _ev
	ev.clear()
	f.contactT = mini(f.contactT + 1, CONTACT_MAX)   # saturating ticks since the last contact (the early-recovery window)
	if b.mode == AIR:
		var ox: float = b.x
		var oy: float = b.y
		moveAir(S, b, dt, ev)
		fromBody(f, b)
		var hitNow: bool = false
		if not b.done:
			hitNow = WorldBrunt.checkHit(S, f, ox, oy)   # B2: only the building the launch is aimed at can be hit
			if hitNow:
				b = toBody(S, f)   # a hit changed his position and speed
		if not b.done and not (hitNow and f.aimB >= 0):
			groundPhase(S, b, ev)
		fromBody(f, b)
	else:
		var xa: float = b.x
		stepContact(S, b, dt, ev)
		fromBody(f, b)
		if b.dxStep != 0.0:
			_skidEffects(S, f, by, b, xa)
	for e in ev:
		_apply(S, f, by, b, e)
	if b.done:
		_finish(S, f, by, b)


## The effects of one skid or tumble tick: the trench (skid only), cracks, dust, the path damage and the speed-lost wear.
static func _skidEffects(S: SimState, f, by, b: Body, xa: float) -> void:
	var E: float = f.slideE
	var hw: float = WorldSlide.HW0 + WorldSlide.HW_E * sqrt(E)
	var pav: bool = WorldSlide._paved(f.x)
	var depth: float = minf(WorldSlide.D_MAX, WorldSlide.D0 + WorldSlide.D_V * b.vN)
	if b.mode == SKID:
		WorldCrater.carveSegment(S, xa, f.x, depth, pav, WorldSlide.CRACK0 + WorldSlide.CRACK_E * sqrt(E), f.z)
	f.slideAcc += K_WPS * b.vLost
	var idx: int = int(floor(f.slideD / WorldSlide.SAMPLE))
	if idx > int(floor((f.slideD - absf(b.dxStep)) / WorldSlide.SAMPLE)):
		if idx <= WorldSlide.SAMPLE_MAX:
			SimFx.slideDust(S, f.x, f.y, b.vN, hw * 2.0, "paved" if pav else "ground", idx, f.z)
		SimFx.debris(S, f.x, f.y + 4.0, 3 if pav else 2, "#8f8b84" if pav else "#6d6a66", 500.0, f.z)
		WorldStructures.damageArea(S, f.x, f.y + 5.0, hw * 2.0, (0.22 + 0.12 * by.tier) * WorldSlide.PATH_AREA * b.vN, by, false, f.slideEvt)
		if f.slideAcc > 0.0:
			_pay(S, f, by, f.slideAcc)
			f.slideAcc = 0.0


## Wear is paid through here: a journey takes at most K_WCAP of its single-impact budget (the first contact's speed times 0.018) in all.
static func _pay(S: SimState, f, by, amount: float) -> void:
	if amount <= 0.0:
		return
	var a: float = minf(amount, maxf(f.jV0 * 0.018 * K_WCAP - f.slideDmg, 0.0))
	if a > 0.0:
		f.slideDmg += a
		SimDamage.hurt(S, f, a, by)


static func _launchN(f) -> int:
	return int(f.launchN)


## One event of the pure step, made real: damage, craters, dust, the fx events QA, Camera and VFX read.
static func _apply(S: SimState, f, by, b: Body, e: Dictionary) -> void:
	var WS: float = SimConst.WS
	var k: String = String(e.k)
	if k == "enter":
		SimFx.splash(S, e.x, e.y, 12, f.z)
		SimFx.ring(S, e.x, e.y, 500.0, "#bfe6ff", 0.5, 10.0, f.z)
	elif k == "skim":
		SimFx.splash(S, e.x, e.y, 8, f.z)
		SimFx.skim(S, e.x, e.y, e.speed, e.n, f.z)
		var ev1 := SimFx.contactEvent(S, "bounce", f, e.x, e.y, e.speed)
		ev1.k = float(e.n)
		ev1.surface = "water"
		ev1.n = _launchN(f)
		var ev2 := SimFx.contactEvent(S, "left_ground", f, e.x, e.y, e.speed)
		ev2.cause = "bounce"
		ev2.contacts = f.jContacts
	elif k == "sink":
		f.state = "free"
		f.launchT = 1.0
		WorldBrunt.endFlight(S, f)
	elif k in ["skid", "tumble", "bounce", "slam"]:
		_contact(S, f, by, b, e)
	elif k == "stop":
		pass
	elif k == "left_ground":
		var lg := SimFx.contactEvent(S, "left_ground", f, e.x, e.y, e.speed)
		lg.cause = String(e.cause)
		lg.spd = float(e.speed)
		lg.vx = float(e.vx)
		lg.vy = float(e.vy)
		lg.slope = float(e.get("slope", 0.0))
		lg.contacts = f.jContacts
		lg.dur = float(f.jT) * SimConst.DT
	elif k == "wall":
		var E: float = f.slideE
		WorldCrater.dig(S, f.x, E * WorldSlide.STOP_E, by, "impact", 0.0, 1.0, false, f.z)
		_pay(S, f, by, absf(f.vx) / f.launchT * WorldSlide.STOP_DMG)
		SimFx.shake(S, 10.0, f.x, f.z)


## A contact that is not a leave: the area damage, the dust, the wear, the first-contact set-up, the event.
static func _contact(S: SimState, f, by, b: Body, e: Dictionary) -> void:
	var WS: float = SimConst.WS
	var tier: float = by.tier
	var k: String = String(e.k)
	var sp: float = float(e.speed)
	var first: bool = bool(e.first)
	f.contactT = 0
	var sea: bool = WorldTerrain.seaAt(S, f.x)
	var E: float = WorldCrater.impactEnergy(sp, tier)
	if first:
		f.slideE = E
		f.slideX0 = f.x
		f.slideD = 0.0
		f.slideAcc = 0.0
		f.slideEvt = 0.0
		f.slideDmg = 0.0   # the wear this journey has paid (SimFighter.slideDmg is the old slide's and unused here)
	var r: float = (28.0 + sp * 0.05 + tier * 12.0) * WS
	var cArea: float = 0.22 + 0.12 * tier
	var area: float = 0.0
	if first:
		area = sp * cArea * (K_AREA_SLAM if k == "slam" else K_AREA_TOUCH)
	elif not f.hopped:   # after a hard slam's hop the slam has paid the whole budget; otherwise a later contact pays by the speed it removes
		var removed: float = sp
		if k == "bounce":
			removed = sp * (1.0 - float(e.get("keep", 0.0)))
		elif k == "skid" or k == "tumble":
			removed = maxf(0.0, sp - b.vN)
		area = K_AREA_LATER * cArea * removed
	if k == "slam":
		var vert: float = absf(f.vy) / maxf(SimDetMath.hypot(f.vx, f.vy), 0.000001)
		if bool(e.get("dig", true)):
			WorldCrater.dig(S, f.x, E, by, "impact", f.vx / f.launchT / maxf(sp, 0.000001), vert, f.launchSpecial, f.z)
	if sea:
		SimFx.splash(S, f.x, f.y + 10.0, 14, f.z)
	else:
		SimFx.debris(S, f.x, f.y + 8.0, 12 if k == "slam" else 6, "#6d6a66", 500.0, f.z)
		SimFx.dust(S, f.x, f.y, 4 if k == "slam" else 2, "", f.z)
	SimFx.ring(S, f.x, f.y + 10.0, 700.0 + sp * 0.2, "#ffffff", 0.45, 10.0, f.z)
	if area > 0.0:
		WorldStructures.damageArea(S, f.x, f.y + 5.0, r * 1.7, area, by)
	SimFx.shake(S, SimMathx.jmin(30.0, sp * 0.01), f.x, f.z)
	S.dirS.stop = SimMathx.jmax(S.dirS.stop, 0.06)
	# wear: one impact in all. A slam pays all of it; a first touch-down pays its share; each later contact pays by the speed it removes
	var j: float = f.jV0 * 0.018
	if k == "slam":
		_pay(S, f, by, sp * 0.018)
	elif first:
		_pay(S, f, by, j * K_WTOUCH)
	elif k == "bounce":
		_pay(S, f, by, K_WPS * maxf(0.0, sp * (1.0 - float(e.get("keep", 1.0)))))
	if k == "skid" or k == "tumble":
		# the speed the landing removes (the normal part and the slope's share) is paid like any speed lost: with the skid's own braking a
		# journey that halts pays the whole single-impact budget (first touch 30%, the rest by speed removed)
		f.slideAcc += K_WPS * maxf(0.0, sp - b.vN)
		if f.slideEvt == 0.0:
			f.slideEvt = WorldCollateral.beginEvent(S, "slide", by)
	# the events
	var ce := SimFx.contactEvent(S, "bounce" if k == "bounce" else "land", f, f.x, f.y, sp)
	ce.surface = String(e.surface)
	ce.vn = float(e.vn)
	ce.vt = float(e.vt)
	ce.sina = sqrt(float(e.sin2))
	ce.slope = float(e.slope)
	ce.contacts = f.jContacts
	ce.dur = float(f.jT) * SimConst.DT
	if k == "bounce":
		ce.k = float(e.n)
		ce.keep = float(e.keep)
	else:
		ce.kind = k
	ce.n = _launchN(f)
	if k == "slam":
		f.stateT = 0.0


## The end of a journey: the berm and the record, the fighter down, the events.
static func _finish(S: SimState, f, by, b: Body) -> void:
	var how: String = b.end
	var E: float = f.slideE
	if how == "wall":
		pass
	elif how in ["tumble", "stop"] and f.slideEvt != 0.0:
		var hw: float = WorldSlide.HW0 + WorldSlide.HW_E * sqrt(E)
		WorldCrater.berm(S, f.x, f.vx if f.vx != 0.0 else 1.0, hw, minf(WorldSlide.D_MAX, WorldSlide.D0 + WorldSlide.D_V * f.jV0 * 0.25) * WorldSlide.BERM, f.z)
	if f.slideAcc > 0.0:
		_pay(S, f, by, f.slideAcc)
		f.slideAcc = 0.0
	var slid: bool = f.slideEvt != 0.0
	if slid:
		_record(S, f, by)
	if b.mode == TUMBLE:
		var te := SimFx.contactEvent(S, "tumble_end", f, f.x, f.y, b.vN)
		te.kind = "recover" if how == "recover" else ("air" if how == "water" else "stop")
		te.contacts = f.jContacts
		te.dur = float(maxi(f.tumbleT, 0))   # ticks rolled in the tumble (journey_end.dur is the whole journey, in seconds)
		te.n = _launchN(f)
	var je := SimFx.contactEvent(S, "journey_end", f, f.x, f.y, b.vN)
	je.contacts = f.jContacts
	je.lips = f.jLips
	je.nb = int(f.bounces)
	je.dur = float(f.jT) * SimConst.DT
	je.kind = "capped" if (b.capped and how in ["tumble", "stop"]) else how
	je.n = _launchN(f)
	f.slide = 0.0
	f.vx = 0.0
	f.vy = 0.0
	f.tumbleT = -1
	if how == "water":
		return
	f.state = "down"
	f.stateT = (0.75 - WorldSlide.RECOVER) if slid else 0.0
	f.bounces = 0.0
	f.launchBy = null
	f.launchT = 1.0
	f.launchSpecial = false
	f.hopped = false
	WorldBrunt.endFlight(S, f)


static func _record(S: SimState, f, by) -> void:
	var E: float = f.slideE
	var rec := SimState.Slide.new()
	rec.x0 = f.slideX0
	rec.x1 = f.x
	rec.hw = WorldSlide.HW0 + WorldSlide.HW_E * sqrt(E)
	rec.depth = minf(WorldSlide.D_MAX, WorldSlide.D0 + WorldSlide.D_V * f.jV0)
	rec.energy = E
	rec.t = S.T
	rec.owner = WorldCrater._slot(S, by)
	rec.surface = 1.0 if WorldSlide._paved(f.slideX0) else 0.0
	var er: Dictionary = WorldCollateral.endEvent(S, f.slideEvt)
	rec.pop = er.dead
	f.slideEvt = 0.0
	S.slides.append(rec)
	S.world.slides += 1.0
	if S.slides.size() > WorldSlide.LIST_MAX:
		S.slides.remove_at(0)
	SimFx.slideEvent(S, rec)
