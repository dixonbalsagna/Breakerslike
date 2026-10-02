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
## Timers are whole live ticks. A shot fired this tick sits at its start until the next tick, then moves.
## Nothing here draws a random number. Speeds and sizes are data/fight/shots.json.

const PATH: String = "res://data/fight/shots.json"
const LINE: int = 0
const SEEK: int = 1
const LOB: int = 2
const TPS: float = 60.0

static var _loaded: bool = false
static var _hash: String = ""
static var _errors: Array = []
static var cap: int = 0             # live shots at once; fire() refuses past it
static var arriveTicks: int = 0     # a SEEK shot arrives within this many ticks, however far
static var chest: float = 0.0       # a fighter's centre above his feet
static var bodyR: float = 0.0       # ... and his radius, for a shot's contact
static var kinds: Dictionary = {}   # name -> {speed (units a tick), r, power, dmg, lifeTicks, lobTicks, lobArc}


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
		if not (kinds[name].speed > 0.0 and kinds[name].power > 0.0):
			_err(where + "speed and power must be above 0")


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
## Returns the shot, or null when the cap is reached or the kind is unknown (the press is then spent without a shot).
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
	if o.has("target"):
		sh.mode = SEEK
		sh.tgt = int(o.target)
		var t = S.fighters[sh.tgt]
		sh.left = _seekTicks(sh, t, kd.speed)
		sh.total = sh.left
		sh.vx = SimWrap.sdx(sh.x, t.x) / (float(sh.left) / TPS)
		sh.vy = (t.y + chest - sh.y) / (float(sh.left) / TPS)
	elif o.has("px"):
		sh.mode = LOB
		sh.x0 = sh.x
		sh.y0 = sh.y
		sh.px = SimWrap.wrap(float(o.px))
		sh.py = float(o.get("py", sh.y))
		sh.left = int(kd.lobTicks)
		sh.total = sh.left
	else:
		sh.mode = LINE
		var ux: float = float(o.get("ux", f.face))
		var uy: float = float(o.get("uy", 0.0))
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


## A perfect block or a swat sends a shot back: it becomes newOwner's and seeks its old owner, at its kind's speed. No
## event is sent here; the caller reports it (a shot_hit with its own outcome).
static func deflect(S: SimState, sh, newOwner: int) -> void:
	var old: int = sh.owner
	sh.owner = newOwner
	sh.mode = SEEK
	sh.tgt = old
	sh.left = _seekTicks(sh, S.fighters[old], kinds[sh.kind].speed)
	sh.total = sh.left
	sh.deflected += 1


## End a shot now (the director, or a rule here). cause: hit, clash, ground, water, life, or the caller's own word.
static func end(S: SimState, sh, cause: String) -> void:
	if sh.dead:
		return
	sh.dead = true
	SimFx.shotEnd(S, sh, cause)


# ---------------------------------------------------------------- the hooks other owners fill

## A shot has met a fighter. Returns true if the shot ends there. The rule here is the plain one: its damage, and it
## ends. The director's blasts replace this body with their own (guard, the perfect block's deflect, the dodge).
static func hitFighter(S: SimState, sh, f) -> bool:
	SimDamage.hurt(S, f, sh.dmg, S.fighters[sh.owner], "spread", "blast", "", true)
	SimFx.shotHit(S, sh, f, "hit")
	return true


## A shot has met the world (cause: ground or water) at its position. Nothing happens here beyond its end; World adds
## what a blast does to the ground, the water and the structures around it.
static func hitWorld(S: SimState, sh, cause: String) -> void:
	WorldBlast.shotHit(S, sh.owner, sh.kind, sh.x, sh.y, sh.z, sh.vx, sh.vy, cause)   # World's blast on the ground, the structures and the water


# ---------------------------------------------------------------- the step

## One live tick (SimCore.step, after the director and the beams): every shot moves, opposing shots that meet trade,
## and each shot is tested against the fighters, the ground and the water, in the order they were fired.
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
			var dx: float = SimWrap.sdx(sh.x, t.x) * k
			var dy: float = (t.y + chest - sh.y) * k
			sh.x = SimWrap.wrap(sh.x + dx)
			sh.y += dy
			sh.vx = dx / dt
			sh.vy = dy / dt
			mx[i] = dx
			arrived[i] = sh.left <= 1
		else:
			var p: float = 1.0 - float(maxi(sh.left - 1, 0)) / float(maxi(sh.total, 1))
			var nx: float = SimWrap.wrap(sh.x0 + SimWrap.sdx(sh.x0, sh.px) * p)
			var ny: float = sh.y0 + (sh.py - sh.y0) * p + kinds[sh.kind].lobArc * 4.0 * p * (1.0 - p)
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
	var sx := PackedFloat64Array()
	var sy := PackedFloat64Array()
	sx.resize(n)
	sy.resize(n)
	for i in range(n):
		var q = S.shots[i]
		sx[i] = q.x - mx[i]
		sy[i] = q.y - my[i]
		if not q.dead and q.owner >= 0 and q.owner < 2:
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
	# fighters, then the ground, the water and the life
	for i in range(n):
		var sh = S.shots[i]
		if sh.dead:
			continue
		var r: float = rad[i] + bodyR
		var hitOne: bool = false
		if S.game.ko == null:
			for k in range(S.fighters.size()):
				if k == sh.owner:
					continue
				var f = S.fighters[k]
				if f.state == "intro":
					continue
				var met: bool = arrived[i] and sh.mode == SEEK and sh.tgt == k
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
					if hitFighter(S, sh, f):
						end(S, sh, "hit")
					break
		if sh.dead or hitOne:
			continue
		if sh.mode == LOB and arrived[i]:
			hitWorld(S, sh, "ground")
			end(S, sh, "ground")
		elif sh.mode == SEEK:
			if arrived[i]:
				end(S, sh, "life")   # it reached where its target was and he was not hit (the director let it pass)
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
