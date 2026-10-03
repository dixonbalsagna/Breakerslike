class_name SimShots
## Shots (docs/architecture/shots.md): energy blasts in flight. A shot is sim state (S.shots, hashed): it has an owner, a
## kind, a position that wraps with the planet, a power and a time to live. The director fires them (fire) and decides
## what a hit means; this module moves them and finds what they meet: each other, a fighter, the ground, the water.
##
## Three ways of travelling:
##   LINE  a straight line at the kind's speed until something stops it or its life runs out
##   SEEK  toward a fighter, arriving on a set tick whatever he does (the rush's rule): energy reaches at any range, so
##         a seeking shot is not stopped by the ground or the water between them
##   LOB   a fixed-time arc to a point
## Shots of opposing owners that meet trade: each loses the other's power, and one with none left ends. So volleys cancel
## in pairs and what is left of the bigger one lands.
## A meeting is a swept test over the tick's movement, so a fast shot never passes through a fighter or another shot.
## A fourth kind does not travel: a MINE stays where it is laid, arms, and blows when a rival comes within its trigger
## radius, a shot hits it, a blow lands on it (trip, tripNear) or another mine's blast reaches it.
## A deflected shot flies wild (deflect): an arc to a seeded spot on the ground, hitting whoever or whatever is in its way.
## A straight or lobbed shot stops at a standing building in its path (hitStructure).
## Two things are seeded, both stateless (SimRng.keyed on the match seed and the shot's id, never S.rng): the spray's aim
## and where a wild shot goes.
## Timers are whole live ticks. A shot fired this tick sits at its start until the next tick, then moves.
## Nothing here draws from S.rng. Speeds and sizes are data/fight/shots.json.

const PATH: String = "res://data/fight/shots.json"
const LINE: int = 0
const SEEK: int = 1
const LOB: int = 2
const MINE: int = 3
const TPS: float = 60.0

static var _loaded: bool = false
static var _hash: String = ""
static var _errors: Array = []
static var cap: int = 0             # live shots at once; fire() refuses past it
static var arriveTicks: int = 0     # a SEEK shot arrives within this many ticks, however far
static var chest: float = 0.0       # a fighter's centre above his feet
static var bodyR: float = 0.0       # ... and his radius, for a shot's contact
static var kinds: Dictionary = {}   # name -> {speed (units a tick), r, power, dmg, lifeTicks, lobTicks, lobArc, mine (a Dictionary, or null)}
static var structures: bool = false # a straight or lobbed shot stops at a building its path crosses
static var scatter: bool = false    # a deflect sends the shot wild (else back at its owner)
static var defl: Dictionary = {}    # ... nearMin, nearMax, farMin, farMax, farChance, awayChance, speed, minTicks, arcPer, safeTicks, backCos
static var mineCap: int = 0         # mines one fighter may have laid at once (one more fizzles his oldest)
static var mineGap: float = 0.0     # a mine cannot be laid within this of another


# ---------------------------------------------------------------- data

static func _ensure() -> void:
	if _loaded:
		return
	_loaded = true
	_errors = []
	var j = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if not (j is Dictionary):
		_err("data/fight/shots.json is missing or not valid JSON")
		j = {}
	var h := SimHash.Hasher.new()
	h.text("shots")
	FighterData._canon(h, j)
	_hash = h.hex()
	cap = int(_num("cap", j.get("cap"), 1.0))
	arriveTicks = int(_num("arriveTicks", j.get("arriveTicks"), 1.0))
	chest = _num("chest", j.get("chest"), 0.0)
	bodyR = _num("bodyR", j.get("bodyR"), 0.0)
	kinds = {}
	var kj = j.get("kinds", {})
	if not (kj is Dictionary) or kj.is_empty():
		_err("kinds: at least one kind is needed")
		kj = {}
	for name in kj:
		if String(name).begins_with("_"):
			continue
		var k: Dictionary = kj[name]
		var where: String = "kinds." + name + "."
		kinds[name] = {"speed": _num(where + "speed", k.get("speed"), 0.0), "r": _num(where + "r", k.get("r"), 0.0),
			"power": _num(where + "power", k.get("power"), 0.0), "dmg": _num(where + "dmg", k.get("dmg"), 0.0),
			"lifeTicks": _num(where + "lifeTicks", k.get("lifeTicks"), 1.0), "lobTicks": _num(where + "lobTicks", k.get("lobTicks", 36), 1.0),
			"lobArc": _num(where + "lobArc", k.get("lobArc", 0.0), 0.0)}
		var mj = k.get("mine")
		if mj is Dictionary:
			var md := {"tierR": [1.0, 1.0, 1.0, 1.0]}
			for key in ["trigR", "blastR", "chainR", "ownShare"]:
				md[key] = _num(where + "mine." + key, mj.get(key), 0.0)
			for key in ["armTicks", "fuseTicks"]:
				md[key] = int(_num(where + "mine." + key, mj.get(key), 0.0))
			md.chainTicks = int(_num(where + "mine.chainTicks", mj.get("chainTicks"), 1.0))
			var tr = mj.get("tierR")
			if tr is Array and tr.size() == 4:
				for ti in range(4):
					md.tierR[ti] = _num(where + "mine.tierR", tr[ti], 0.0)
			else:
				_err(where + "mine.tierR: four numbers are needed, one per tier")
			kinds[name].mine = md
		else:
			kinds[name].mine = null
		if not ((kinds[name].speed > 0.0 or kinds[name].mine != null) and kinds[name].power > 0.0):
			_err(where + "speed and power must be above 0 (a mine needs no speed)")
	structures = j.get("structures", false) == true
	var dj = j.get("deflect", {})
	if not (dj is Dictionary):
		dj = {}
	scatter = dj.get("scatter", false) == true
	defl = {}
	for key in ["nearMin", "nearMax", "farMin", "farMax", "farChance", "awayChance", "arcPer", "backCos"]:
		defl[key] = _num("deflect." + key, dj.get(key, 0.0), 0.0)
	defl.speed = _num("deflect.speed", dj.get("speed", 1.0), 0.001)
	defl.minTicks = int(_num("deflect.minTicks", dj.get("minTicks", 1), 1.0))
	defl.safeTicks = int(_num("deflect.safeTicks", dj.get("safeTicks", 0), 0.0))
	if scatter and not (defl.nearMax >= defl.nearMin and defl.farMax >= defl.farMin and defl.nearMin > 0.0):
		_err("deflect: the distance bands must be ordered and above 0")
	mineCap = int(_num("mineCap", j.get("mineCap", 0), 0.0))
	mineGap = _num("mineGap", j.get("mineGap", 0.0), 0.0)


static func dataHash() -> String:
	_ensure()
	return _hash


static func errors() -> Array:
	_ensure()
	return _errors


static func _err(msg: String) -> void:
	_errors.append(msg)
	push_error("SimShots: " + msg)


static func _num(where: String, x, lo: float) -> float:
	if not (x is float or x is int) or float(x) < lo:
		_err(where + ": must be a number of at least " + str(lo) + ", got " + str(x))
		return lo
	return float(x)


# ---------------------------------------------------------------- firing

## A new match (sim.gd newMatch).
static func reset(S: SimState) -> void:
	_ensure()
	S.shots = []
	S.shotSeq = 0


## Fire a shot of the kind for the fighter in slot owner. o chooses how it travels and may override what the kind gives:
##   "target": slot     SEEK that fighter (it arrives within arriveTicks, at the kind's speed if that is sooner)
##   "ux", "uy"         LINE along this direction (it need not be a unit vector)
##   "px", "py"         LOB to this point
##   "power", "dmg"     the trade strength and the damage a plain hit does (the kind's own by default)
##   "group"            a number shared by the shots of one volley, so it counts once (0: none)
##   "x", "y", "z"      where it starts (the owner's centre by default)
##   "aim": slot        LINE at where that fighter's centre is now (it does not follow him)
##   "spread": slope    the spray cone: the aim is off by up to this slope either side (0.1 is about 6 degrees, 0.32 about
##                      18), by a seeded draw. A straight shot leaves along the turned direction. A seeking shot still
##                      seeks, aimed beside its target by the distance times that draw: it lands only if that is within
##                      reach of him, and otherwise passes him and flies on
##   "ground": true     a mine rests on the ground under where it is laid (else it hovers there)
## A mine kind (it has a mine block in the data) is laid, not fired: it stays put. One too near another mine (mineGap)
## is refused; one more than mineCap fizzles its owner's oldest. Mines count toward the cap.
## Returns the shot, or null when the cap is reached, the kind is unknown or a mine is too near another (the press is then
## spent without a shot).
static func fire(S: SimState, owner: int, kind: String, o: Dictionary = {}):
	_ensure()
	if not kinds.has(kind) or S.shots.size() >= cap:
		return null
	var kd: Dictionary = kinds[kind]
	var f = S.fighters[owner]
	var sh := SimState.Shot.new()
	S.shotSeq += 1
	sh.id = S.shotSeq
	sh.owner = owner
	sh.kind = kind
	sh.x = SimWrap.wrap(float(o.get("x", f.x)))
	sh.y = float(o.get("y", f.y + chest))
	sh.z = float(o.get("z", f.z))
	sh.power = float(o.get("power", kd.power))
	sh.dmg = float(o.get("dmg", kd.dmg))
	sh.group = int(o.get("group", 0))
	sh.fresh = true
	var sps: float = kd.speed * TPS   # units a second
	# the spray: a seeded draw in [-1, 1) times the slope, from the match seed and the shot's id (no stream is read)
	var off: float = 0.0
	if o.has("spread"):
		off = float(o.spread) * (SimRng.keyed(int(S.game.seed), "shot.spray", sh.id) * 2.0 - 1.0)
	if kd.mine != null:
		sh.mode = MINE
		sh.ground = o.get("ground", false) == true
		if sh.ground:
			sh.y = WorldTerrain.groundY(S, sh.x) + kd.r
		var own: Array = []
		for q in S.shots:
			if q.mode != MINE or q.dead:
				continue
			var gx: float = SimWrap.sdx(sh.x, q.x)
			var gy: float = q.y - sh.y
			if gx * gx + gy * gy < mineGap * mineGap and absf(q.z - sh.z) < mineGap:
				S.shotSeq -= 1
				return null
			if q.owner == owner:
				own.append(q)
		if own.size() >= mineCap:
			if mineCap <= 0:
				S.shotSeq -= 1
				return null
			end(S, own[0], "life")   # his oldest fizzles
		sh.left = int(kd.lifeTicks)
		sh.total = sh.left
		sh.arm = int(kd.mine.armTicks)
	elif o.has("target"):
		sh.mode = SEEK
		sh.tgt = int(o.target)
		var t = S.fighters[sh.tgt]
		var tdx: float = SimWrap.sdx(sh.x, t.x)
		var tdy: float = t.y + chest - sh.y
		sh.ax = -tdy * off   # beside the target, across the line of fire: the cone widens with the distance
		sh.ay = tdx * off
		sh.left = _seekTicks(sh, t, kd.speed)
		sh.total = sh.left
		sh.vx = (tdx + sh.ax) / (float(sh.left) / TPS)
		sh.vy = (tdy + sh.ay) / (float(sh.left) / TPS)
	elif o.has("px"):
		sh.mode = LOB
		sh.x0 = sh.x
		sh.y0 = sh.y
		sh.px = SimWrap.wrap(float(o.px))
		sh.py = float(o.get("py", sh.y))
		sh.arc = kd.lobArc
		sh.left = int(kd.lobTicks)
		sh.total = sh.left
	else:
		sh.mode = LINE
		var ux0: float = float(o.get("ux", f.face))
		var uy0: float = float(o.get("uy", 0.0))
		if o.has("aim"):
			var at = S.fighters[int(o.aim)]
			ux0 = SimWrap.sdx(sh.x, at.x)
			uy0 = at.y + chest - sh.y
		var ux: float = ux0 - uy0 * off   # the spray turns the direction by the slope
		var uy: float = uy0 + ux0 * off
		var d: float = SimDetMath.hypot(ux, uy)
		if d <= 0.0:
			ux = f.face
			uy = 0.0
			d = 1.0
		sh.vx = ux / d * sps
		sh.vy = uy / d * sps
		sh.left = int(kd.lifeTicks)
		sh.total = sh.left
	S.shots.append(sh)
	SimFx.shotFire(S, sh)
	return sh


## Whole ticks for a shot to reach fighter t at the given speed (units a tick): at least 1, at most arriveTicks.
static func _seekTicks(sh, t, speed: float) -> int:
	var dist: float = SimDetMath.hypot(SimWrap.sdx(sh.x, t.x), t.y + chest - sh.y)
	return int(clampf(ceil(dist / speed), 1.0, float(arriveTicks)))


## A perfect block or a swat deflects a shot (newOwner: the slot that deflected it). The caller reports the deflect itself
## (a shot_hit with its own outcome).
## With deflect.scatter the shot flies wild: an arc to a seeded spot on the ground, in the near band or (farChance) the far
## one, on the side away from the shooter (awayChance) or toward him, never launched within 30 degrees of the line back to
## him. It stays the shooter's (he answers for what it does), it can hit either fighter or a building on the way (the
## deflector not for safeTicks), and World's blast goes off where it lands. shot_deflect says where it is going.
## Without scatter it flies back: it becomes newOwner's and seeks its old owner, at its kind's speed.
static func deflect(S: SimState, sh, newOwner: int) -> void:
	if scatter:
		var seed: int = int(S.game.seed)
		var key: int = sh.id * 16 + (sh.deflected & 15)
		var far: bool = SimRng.keyed(seed, "shot.deflect.far", key) < defl.farChance
		var u: float = SimRng.keyed(seed, "shot.deflect.dist", key)
		var dist: float = (defl.farMin + (defl.farMax - defl.farMin) * u) if far else (defl.nearMin + (defl.nearMax - defl.nearMin) * u)
		var shooter = S.fighters[sh.owner]
		var tx: float = SimWrap.sdx(sh.x, shooter.x)   # the line back to the shooter
		var ty: float = shooter.y + chest - sh.y
		var tl: float = SimDetMath.hypot(tx, ty)
		var away: float = 1.0 if tx < 0.0 else (-1.0 if tx > 0.0 else -S.fighters[newOwner].face)
		var side: float = away if SimRng.keyed(seed, "shot.deflect.side", key) < defl.awayChance else -away
		# the first launch that is not back at the shooter: the drawn side, the other side, then each without the arc
		var bestC: float = 2.0
		var bSide: float = side
		var bArc: float = 0.0
		for c in range(4):
			var cs: float = side if (c & 1) == 0 else -side
			var ca: float = dist * defl.arcPer if c < 2 else 0.0
			var lx: float = cs * dist
			var ly: float = _landY(S, SimWrap.wrap(sh.x + lx)) - sh.y + 4.0 * ca
			var ll: float = SimDetMath.hypot(lx, ly)
			var cosv: float = (lx * tx + ly * ty) / (ll * tl) if ll > 0.0 and tl > 0.0 else -1.0
			if cosv < bestC:
				bestC = cosv
				bSide = cs
				bArc = ca
			if cosv <= defl.backCos:
				break
		sh.mode = LOB
		sh.tgt = -1
		sh.ax = 0.0
		sh.ay = 0.0
		sh.x0 = sh.x
		sh.y0 = sh.y
		sh.px = SimWrap.wrap(sh.x + bSide * dist)
		sh.py = _landY(S, sh.px)
		sh.arc = bArc
		sh.left = maxi(defl.minTicks, int(ceil(SimDetMath.hypot(dist, sh.py - sh.y) / defl.speed)))
		sh.total = sh.left
		sh.deflected += 1
		sh.wild = true
		sh.safe = newOwner
		sh.safeT = defl.safeTicks
		sh.passed = 0
		sh.lastB = -1
		SimFx.shotDeflect(S, sh, newOwner, float(sh.left) / TPS)
		return
	var old: int = sh.owner
	sh.owner = newOwner
	sh.mode = SEEK
	sh.tgt = old
	sh.left = _seekTicks(sh, S.fighters[old], kinds[sh.kind].speed)
	sh.total = sh.left
	sh.deflected += 1
	sh.passed = 0


## A seeking shot loses its target (a dodge, or the director's call): it flies on as a straight shot at its last
## velocity, for the kind's life, and from then on the ground and the water stop it like any straight shot.
static func release(_S: SimState, sh) -> void:
	var kd: Dictionary = kinds[sh.kind]
	if SimDetMath.hypot(sh.vx, sh.vy) <= 0.0:   # released before it moved: straight ahead of its owner
		sh.vx = _S.fighters[sh.owner].face * kd.speed * TPS
		sh.vy = 0.0
	sh.mode = LINE
	sh.tgt = -1
	sh.left = int(kd.lifeTicks)
	sh.total = sh.left


## End a shot now (the director, or a rule here). cause: hit, clash, ground, water, life, or the caller's own word.
static func end(S: SimState, sh, cause: String) -> void:
	if sh.dead:
		return
	sh.dead = true
	SimFx.shotEnd(S, sh, cause)


# ---------------------------------------------------------------- the hooks other owners fill

## A shot has met a fighter. Returns true if the shot ends there. The rule here is the plain one: its damage, and it
## ends. The director's blasts replace this body with their own (guard, the perfect block's deflect, the dodge).
## sh may be a mine (mode MINE: every fighter within its blast is offered, and the mine ends whatever is returned).
## f may be the shot's own owner (his wild shot, or his own mine's blast): that case takes the plain rule here and is not
## handed to the director, whose rule reads the owner as the attacker (a knock-back, a barrage, a finisher).
static func hitFighter(S: SimState, sh, f) -> bool:
	if DirBlast.rules(S) and f != S.fighters[sh.owner]:
		return DirBlast.hit(S, sh, f)   # the director's blast rules: the dodge, the perfect block's deflect, the guard, a charge
	var dmg: float = sh.dmg
	if sh.mode == MINE and f == S.fighters[sh.owner]:
		dmg *= kinds[sh.kind].mine.ownShare
	SimDamage.hurt(S, f, dmg, S.fighters[sh.owner], "spread", "blast", "", true)
	SimFx.shotHit(S, sh, f, "hit")
	return true


## A straight or lobbed shot has met a standing building (b, of S.buildings) at its position, on the building's face.
## Returns true if the shot ends there. The rule here ends it and does the building nothing; World fills in what a shot of
## this kind and power does to it (and may return false for a shot that levels the building and flies on).
static func hitStructure(_S: SimState, _sh, _b) -> bool:
	return true


## Set a mine off: it blows after its fuse (delay: after that many ticks instead). cause: fighter, shot, blow or chain;
## slot: who set it off, or -1. Returns false, and nothing happens, for a mine already set off, or one not armed yet
## (only another mine's blast sets off an unarmed mine). The director calls this for a blow landed on a mine.
static func trip(S: SimState, sh, cause: String, slot: int = -1, delay: int = -1) -> bool:
	if sh.mode != MINE or sh.dead or sh.fuse >= 0 or (sh.arm > 0 and cause != "chain"):
		return false
	sh.fuse = delay if delay >= 0 else int(kinds[sh.kind].mine.fuseTicks)
	SimFx.mineTrip(S, sh, cause, slot, float(sh.fuse) / TPS)
	return true


## Set off every armed mine within r of a point (a blow's contact, a blast). Returns how many.
static func tripNear(S: SimState, x: float, y: float, r: float, cause: String, slot: int = -1) -> int:
	var c: int = 0
	for sh in S.shots:
		if sh.mode != MINE or sh.dead or sh.fuse >= 0:
			continue
		var dx: float = SimWrap.sdx(x, sh.x)
		var dy: float = sh.y - y
		if dx * dx + dy * dy <= r * r and trip(S, sh, cause, slot):
			c += 1
	return c


## A mine blows: every fighter within its blast radius is offered the hit (hitFighter: the plain rule gives its owner the
## owner's share), World's blast goes off at the spot, and the mines within the chain radius follow, nearest first, one
## chain delay apart.
static func _explode(S: SimState, sh) -> void:
	var md: Dictionary = kinds[sh.kind].mine
	var grow: float = md.tierR[clampi(int(S.fighters[sh.owner].tier), 1, 4) - 1]
	var rr: float = md.blastR * grow * md.blastR * grow
	if S.game.ko == null:
		for f in S.fighters:
			if f.state == "intro":
				continue
			var dx: float = SimWrap.sdx(sh.x, f.x)
			var dy: float = f.y + chest - sh.y
			if dx * dx + dy * dy <= rr:
				hitFighter(S, sh, f)
	hitWorld(S, sh, "mine")
	var cr: float = md.chainR * grow * md.chainR * grow
	var near: Array = []   # [distance squared, the mine], nearest first, ties in the order they were laid
	for q in S.shots:
		if q == sh or q.mode != MINE or q.dead or q.fuse >= 0:
			continue
		var qx: float = SimWrap.sdx(sh.x, q.x)
		var qy: float = q.y - sh.y
		var d2: float = qx * qx + qy * qy
		if d2 > cr or absf(q.z - sh.z) > md.chainR * grow:
			continue
		var at: int = near.size()
		while at > 0 and near[at - 1][0] > d2:
			at -= 1
		near.insert(at, [d2, q])
	for n in range(near.size()):
		trip(S, near[n][1], "chain", sh.owner, int(md.chainTicks) * (n + 1))
	end(S, sh, "mine")


## Where a falling shot lands at x: the ground, or the water over it.
static func _landY(S: SimState, x: float) -> float:
	return maxf(WorldTerrain.groundY(S, x), WorldWater.surfaceAt(S, x))


## The first standing building in reach of the shot's depth (WorldStructures.Z_REACH, as for any blast) that the tick's
## movement (mx, my, ending at the shot's position) enters, or -1. The shot is moved to the crossing. A building the
## movement starts inside is not met: a shot fired from within one, or released there, flies out of it.
static func _building(S: SimState, sh, mx: float, my: float, rad: float) -> int:
	if S.buildings.is_empty():
		return -1
	var x0: float = sh.x - mx
	var y0: float = sh.y - my
	var best: int = -1
	var bt: float = 2.0
	var ylo: float = minf(y0, sh.y) - rad
	var xm: float = SimWrap.wrap(x0 + mx * 0.5)   # the middle of the movement, and its half length with the radius
	var hx: float = absf(mx) * 0.5 + rad
	var zr: float = WorldStructures.Z_REACH
	var half: float = SimConst.HALF
	for bi in WorldStructures.near(S, xm, hx):
		var b = S.buildings[bi]
		var cm: float = b.x - xm   # (the shortest arc, written out: most of the buildings near are rejected here)
		if cm > half:
			cm -= SimConst.W
		elif cm < -half:
			cm += SimConst.W
		var hw: float = b.w * 0.5 + rad
		if absf(cm) > hw + hx:
			continue
		# World's rule for a blast: the building's nearest face is within Z_REACH in depth of the shot
		if absf(sh.z - b.z) - b.d * 0.5 > zr or not b.alive or bi == sh.lastB:
			continue
		var cx: float = cm + mx * 0.5   # the building's centre from the segment's start
		# the segment against the box, in x and then in y (the slab test), for the time t0 it enters
		var t0: float = 0.0
		var t1: float = 1.0
		if mx > 0.0 or mx < 0.0:
			var ta: float = (cx - hw) / mx
			var tb: float = (cx + hw) / mx
			t0 = maxf(t0, minf(ta, tb))
			t1 = minf(t1, maxf(ta, tb))
		elif absf(cx) > hw:
			continue
		if t0 > t1:
			continue
		if ylo > WorldTerrain.groundY(S, b.x) + b.h + 200.0:   # well above it (World's cheap reject: the ground at its centre, its full height, a heap's worth)
			continue
		var base: float = WorldStructures.baseY(S, b)
		var top: float = base + WorldStructures.curH(b) + rad
		if my > 0.0 or my < 0.0:
			var tc: float = (base - y0) / my
			var td: float = (top - y0) / my
			t0 = maxf(t0, minf(tc, td))
			t1 = minf(t1, maxf(tc, td))
		elif y0 < base or y0 > top:
			continue
		if t0 > t1 or t0 <= 0.0:   # (t0 of 0: it starts inside this one, fired or let pass in there. Only entering counts)
			continue
		if t0 < bt:
			bt = t0
			best = bi
	if best >= 0:
		sh.x = SimWrap.wrap(x0 + mx * bt)
		sh.y = y0 + my * bt
	return best


## A shot has met the world at its position (cause: ground or water; mine for a mine's blast, which may be in the air).
## Nothing happens here beyond its end; World adds what a blast does to the ground, the water and the structures around it.
static func hitWorld(S: SimState, sh, cause: String) -> void:
	WorldBlast.shotHit(S, sh.owner, sh.kind, sh.x, sh.y, sh.z, sh.vx, sh.vy, cause)   # World's blast on the ground, the structures and the water


# ---------------------------------------------------------------- the step

## One live tick (SimCore.step, after the director and the beams): every shot moves, opposing shots that meet trade, a
## shot that hits a mine sets it off, and each shot is tested against the fighters, the buildings, the ground and the
## water, in the order they were fired. A mine's timers run, a rival near an armed one sets it off, and it blows.
static func step(S: SimState, dt: float) -> void:
	if S.shots.is_empty():
		return
	var n: int = S.shots.size()
	var mx := PackedFloat64Array()   # this tick's movement per shot (x unwrapped)
	var my := PackedFloat64Array()
	mx.resize(n)
	my.resize(n)
	var rad := PackedFloat64Array()  # each shot's radius
	rad.resize(n)
	var arrived: Array = []
	arrived.resize(n)
	for i in range(n):
		var sh = S.shots[i]
		arrived[i] = false
		mx[i] = 0.0
		my[i] = 0.0
		rad[i] = kinds[sh.kind].r
		if sh.fresh or sh.dead:   # fired this tick: it starts to move on the next
			sh.fresh = false
			continue
		if sh.mode == MINE:   # it stays put (a ground mine on the ground as it is now): its timers run
			if sh.ground:
				sh.y = WorldTerrain.groundY(S, sh.x) + rad[i]
			if sh.arm > 0:
				sh.arm -= 1
			if sh.fuse > 0:
				sh.fuse -= 1
			sh.left -= 1
			arrived[i] = sh.left <= 0
			continue
		var ox: float = sh.x
		var oy: float = sh.y
		if sh.mode == LINE:
			sh.x = SimWrap.wrap(sh.x + sh.vx * dt)
			sh.y += sh.vy * dt
			mx[i] = sh.vx * dt
			arrived[i] = sh.left <= 1
		elif sh.mode == SEEK:
			var t = S.fighters[sh.tgt]
			var k: float = 1.0 / float(maxi(sh.left, 1))
			var dx: float = (SimWrap.sdx(sh.x, t.x) + sh.ax) * k   # (the spray's offset: it aims beside him)
			var dy: float = (t.y + chest + sh.ay - sh.y) * k
			sh.x = SimWrap.wrap(sh.x + dx)
			sh.y += dy
			sh.vx = dx / dt
			sh.vy = dy / dt
			mx[i] = dx
			arrived[i] = sh.left <= 1
		else:
			var p: float = 1.0 - float(maxi(sh.left - 1, 0)) / float(maxi(sh.total, 1))
			var nx: float = SimWrap.wrap(sh.x0 + SimWrap.sdx(sh.x0, sh.px) * p)
			var ny: float = sh.y0 + (sh.py - sh.y0) * p + sh.arc * 4.0 * p * (1.0 - p)
			mx[i] = SimWrap.sdx(ox, nx)
			sh.vx = mx[i] / dt
			sh.vy = (ny - oy) / dt
			sh.x = nx
			sh.y = ny
			arrived[i] = sh.left <= 1
		sh.left -= 1
		my[i] = sh.y - oy
	# trades: opposing shots whose paths come within their radii this tick. Only pairs of different owners are walked
	# (each owner's shots in firing order), from the positions at the tick's start, kept in arrays for the inner loop.
	var mine: Array = [PackedInt32Array(), PackedInt32Array()]
	var laid := PackedInt32Array()   # the mines
	var fly := PackedInt32Array()    # every shot that is not a mine, in firing order
	var sx := PackedFloat64Array()
	var sy := PackedFloat64Array()
	sx.resize(n)
	sy.resize(n)
	for i in range(n):
		var q = S.shots[i]
		sx[i] = q.x - mx[i]
		sy[i] = q.y - my[i]
		if q.dead:
			continue
		if q.mode == MINE:
			laid.append(i)
			continue
		fly.append(i)
		if q.owner >= 0 and q.owner < 2:
			mine[q.owner].append(i)
	for i in mine[0]:
		var a = S.shots[i]
		for j in mine[1]:
			if a.dead:
				break
			var ry: float = sy[j] - sy[i]
			var vy: float = my[j] - my[i]
			var rr: float = rad[i] + rad[j]
			if absf(ry) > rr + absf(vy):
				continue   # too far apart in height to meet this tick
			var rx: float = sx[j] - sx[i]   # the shortest arc (SimWrap.sdx, written out: this is the inner loop)
			if rx > SimConst.HALF:
				rx -= SimConst.W
			elif rx < -SimConst.HALF:
				rx += SimConst.W
			var vx: float = mx[j] - mx[i]
			if absf(rx) > rr + absf(vx):
				continue
			var b = S.shots[j]
			if b.dead:
				continue
			var s: float = _closest(rx, ry, vx, vy)
			var cx: float = rx + vx * s
			var cy: float = ry + vy * s
			if cx * cx + cy * cy > rr * rr or absf(a.z - b.z) > rr:
				continue
			var p: float = minf(a.power, b.power)
			a.power -= p
			b.power -= p
			SimFx.shotClash(S, a, b, SimWrap.wrap(sx[i] + mx[i] * s + cx * 0.5), sy[i] + my[i] * s + cy * 0.5, p)
			if a.power <= 0.0:
				end(S, a, "clash")
			if b.power <= 0.0:
				end(S, b, "clash")
	# a shot that hits an armed mine, whoever fired it, sets the mine off and ends there
	for i in laid:
		var m = S.shots[i]
		if m.arm > 0 or m.fuse >= 0:
			continue
		var mr: float = rad[i]
		var mpx: float = m.x
		var mpy: float = m.y
		for j in fly:
			var ry: float = mpy - sy[j]
			var rr: float = mr + rad[j]
			if absf(ry) > rr + absf(my[j]):
				continue
			var rx: float = mpx - sx[j]
			if rx > SimConst.HALF:
				rx -= SimConst.W
			elif rx < -SimConst.HALF:
				rx += SimConst.W
			if absf(rx) > rr + absf(mx[j]):
				continue
			var q = S.shots[j]
			if q.dead:
				continue
			var s: float = _closest(-rx, -ry, mx[j], my[j])
			var cx: float = mx[j] * s - rx
			var cy: float = my[j] * s - ry
			if cx * cx + cy * cy > rr * rr or absf(m.z - q.z) > rr:
				continue
			q.x = SimWrap.wrap(sx[j] + mx[j] * s)
			q.y = sy[j] + my[j] * s
			trip(S, m, "shot", q.owner)
			end(S, q, "clash")
			break
	# fighters, then the buildings, the ground, the water and the life
	for i in range(n):
		var sh = S.shots[i]
		if sh.dead:
			continue
		if sh.mode == MINE:
			if sh.fuse < 0 and sh.arm <= 0 and S.game.ko == null:
				var tr: float = kinds[sh.kind].mine.trigR
				for k in range(S.fighters.size()):
					if k == sh.owner or S.fighters[k].state == "intro":
						continue
					var ty: float = S.fighters[k].y + chest - sh.y
					if absf(ty) > tr:
						continue
					var tx: float = SimWrap.sdx(sh.x, S.fighters[k].x)
					if tx * tx + ty * ty <= tr * tr and absf(S.fighters[k].z - sh.z) <= tr:
						trip(S, sh, "fighter", k)
						break
			if sh.fuse == 0:
				_explode(S, sh)
			elif arrived[i] and sh.fuse < 0:
				end(S, sh, "life")   # it fizzles
			continue
		var safeNow: bool = sh.safeT > 0   # (a wild shot's first ticks: it cannot hit who deflected it)
		if safeNow:
			sh.safeT -= 1
		var r: float = rad[i] + bodyR
		var hitOne: bool = false
		if S.game.ko == null:
			for k in range(S.fighters.size()):
				if (k == sh.owner and not sh.wild) or (sh.passed & (1 << k)) != 0 or (k == sh.safe and safeNow):
					continue
				var f = S.fighters[k]
				if f.state == "intro":
					continue
				var met: bool = arrived[i] and sh.mode == SEEK and sh.tgt == k and sh.ax * sh.ax + sh.ay * sh.ay <= r * r
				if not met:
					# the fighter's centre against the tick's segment, from the segment's start
					var fy: float = f.y + chest - (sh.y - my[i])
					if absf(fy) > r + absf(my[i]):
						continue   # too far above or below him this tick
					var fx: float = SimWrap.sdx(sh.x - mx[i], f.x)
					if absf(fx) > r + absf(mx[i]):
						continue
					var s: float = _closest(-fx, -fy, mx[i], my[i])
					var cx: float = mx[i] * s - fx
					var cy: float = my[i] * s - fy
					met = cx * cx + cy * cy <= r * r and absf(sh.z - f.z) <= r
				if met:
					hitOne = true
					var dn: int = sh.deflected
					if hitFighter(S, sh, f):
						end(S, sh, "hit")
					elif sh.deflected == dn:   # (not if he deflected it: it is already on its way, back or wild)
						sh.passed |= 1 << k   # he let it pass: it flies on, and is not offered to him again
						if sh.mode == SEEK:
							release(S, sh)
					break
		if sh.dead or hitOne:
			continue
		if structures and (sh.mode == LINE or sh.mode == LOB):
			var hb: int = _building(S, sh, mx[i], my[i], rad[i])
			if hb >= 0:
				if hitStructure(S, sh, S.buildings[hb]):
					end(S, sh, "building")
					continue
				sh.lastB = hb   # let through: it is not offered to this building again
		if sh.mode == LOB and sh.wild:
			# a wild shot lands where it meets the ground or the water, at its spot or before it
			var gy: float = WorldTerrain.groundY(S, sh.x)
			var wy: float = WorldWater.surfaceAt(S, sh.x)
			if arrived[i] or sh.y <= maxf(gy, wy):
				var wet: bool = wy > gy
				sh.y = maxf(gy, wy)
				hitWorld(S, sh, "water" if wet else "ground")
				end(S, sh, "water" if wet else "ground")
		elif sh.mode == LOB and arrived[i]:
			hitWorld(S, sh, "ground")
			end(S, sh, "ground")
		elif sh.mode == SEEK:
			if arrived[i]:
				release(S, sh)   # it reached where its target was and could not hit him: it flies on, straight
		elif sh.mode == LINE and sh.y <= WorldTerrain.groundY(S, sh.x):
			sh.y = WorldTerrain.groundY(S, sh.x)
			hitWorld(S, sh, "ground")
			end(S, sh, "ground")
		elif sh.mode == LINE and sh.y < WorldWater.surfaceAt(S, sh.x):
			hitWorld(S, sh, "water")
			end(S, sh, "water")
		elif arrived[i]:
			end(S, sh, "life")
	var live: Array = []
	for sh in S.shots:
		if not sh.dead:
			live.append(sh)
	S.shots = live


## The time s in [0, 1] at which the point (rx, ry) + s (vx, vy) is nearest the origin.
static func _closest(rx: float, ry: float, vx: float, vy: float) -> float:
	var vv: float = vx * vx + vy * vy
	if vv <= 0.0:
		return 0.0
	return clampf(-(rx * vx + ry * vy) / vv, 0.0, 1.0)
