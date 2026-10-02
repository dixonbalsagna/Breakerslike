# Shots, the second round (docs/architecture/shots.md sections 13 to 18; Game Design's rules: agency-pass.md section 15):
# shots meet buildings in flight, a deflect sends the shot wild, the spray cone, mines.
# Usage: python shots2.py <repo root> code|hash|scatter|structures
#   code  everything, with the two rules that change today's matches behind data switches that are off (structures,
#         deflect.scatter) and the two new abilities unused (spread, mines). Parity must pass on the untouched goldens
#         (only the fight data hash moves: regenerate, and the light digests and tick counts must not move).
#   hash  the new shot fields and the two new events join the hash. Regenerate: light digests and tick counts must not move.
#   scatter     deflect.scatter goes on: a deflect sends the shot wild. A behaviour change: regenerate.
#   structures  structures goes on: straight and lobbed shots stop at buildings. A behaviour change, and one
#               to make only together with World's rule in SimShots.hitStructure (until then a building takes nothing
#               from the shot it stops, where today the shot flies through and its blast on the ground reaches it).
# Tools' side (the new keys in the shots schema) is shots2_schema.cjs: run it with the code part.
import os, sys, json, collections
os.chdir(sys.argv[1])
part=sys.argv[2]
assert part in ('code','hash','scatter','structures')
OD=collections.OrderedDict
def edit(p, pairs):
    s=open(p,encoding='utf-8').read()
    for a,b in pairs:
        assert s.count(a)==1,(p,a[:80],s.count(a))
        s=s.replace(a,b)
    open(p,'w',encoding='utf-8',newline='\n').write(s)

BH=75.0   # a body height, in units (sim/director/bands.gd)

if part=='code':
    # ------------------------------------------------------------ data: the switches (off), the deflect, the mine
    p="data/fight/shots.json"
    d=json.load(open(p,encoding='utf-8'),object_pairs_hook=OD)
    assert "structures" not in d and "mine" not in d["kinds"]
    nd=OD()
    for k,v in d.items():
        if k=="kinds":
            nd["structures"]=False
            nd["_structures"]="true: a straight or lobbed shot stops at a standing building its path crosses (one within World's blast reach in depth of the fight plane), and World's rule says what the building takes (a seeking shot is not stopped, as with the ground)"
            nd["deflect"]=OD([("scatter",False),("nearMin",4*BH),("nearMax",20*BH),("farMin",20*BH),("farMax",40*BH),("farChance",0.15),
                ("awayChance",0.75),("speed",50.0),("minTicks",12),("arcPer",0.25),("safeTicks",10),("backCos",0.866),
                ("_note","scatter true: a deflected shot flies wild (agency-pass.md section 15.2): it is knocked off as an arc to a seeded spot on the ground, nearMin to nearMax away (4 to 20 body heights) or, with farChance, farMin to farMax (20 to 40); with awayChance on the side away from the shooter. It still belongs to the shooter, it can hit either fighter or a building on the way (the deflector not for safeTicks), and it explodes where it lands. Its launch is never within the angle whose cosine is backCos (30 degrees) of the line back to the shooter. speed (units a tick), minTicks and arcPer (arc height per unit of distance) shape the flight: Simulation's placeholders. scatter false: the shot flies back at its owner")])
            nd["mineCap"]=6
            nd["mineGap"]=2*BH
            nd["_mines"]="mineCap: mines one fighter may have laid (laying one more fizzles his oldest); they count toward cap. mineGap: a mine cannot be laid within this of another (2 body heights)"
        nd[k]=v
    nd["kinds"]["mine"]=OD([("speed",0.0),("r",20.0),("power",3.0),("dmg",52.8),("lifeTicks",1200),
        ("mine",OD([("trigR",1.5*BH),("blastR",2*BH),("chainR",2*BH),("armTicks",30),("fuseTicks",0),("chainTicks",6),("ownShare",0.3),("tierR",[1.0,1.0,1.25,1.5])])),
        ("_note","a mine (agency-pass.md section 15.5): it stays where it is laid for lifeTicks (20 s) and then fizzles. Armed after armTicks, it is set off by a rival's chest within trigR (1.5 body heights), by any shot that hits it, or by a blow; it blows fuseTicks later and hits every fighter within blastR (2 body heights; its owner for ownShare of the damage); mines within chainR follow, chainTicks apart, nearest first. Radii grow by tierR with the owner's tier. dmg is 0.8 of a heavy (66). r, fuseTicks and chainR are Simulation's placeholders")])
    open(p,'w',encoding='utf-8',newline='\n').write(json.dumps(nd,indent=2,ensure_ascii=False)+"\n")

    # ------------------------------------------------------------ state
    edit('sim/core/state.gd', [
    ('''	var passed: int = 0       # a bit per slot it has passed without stopping (a dodge): it is not offered to him again
''','''	var passed: int = 0       # a bit per slot it has passed without stopping (a dodge): it is not offered to him again
	var ax: float = 0.0       # the spray: a seeking shot aims this far off its target's centre ...
	var ay: float = 0.0
	var arc: float = 0.0      # LOB: the height of its arc above the straight line
	var lastB: int = -1       # the building it last met and was let through (it is not offered to it again)
	var wild: bool = false    # deflected wild: it can hit any fighter, its owner too
	var safe: int = -1        # ... except this slot (who deflected it) ...
	var safeT: int = 0        # ... for this many ticks more
	var arm: int = 0          # MINE: ticks until it is armed
	var fuse: int = -1        # MINE: ticks until it blows, -1 while it is not set off
	var ground: bool = false  # MINE: it rests on the ground (else it hovers where it was laid)
'''),
    ])

    # ------------------------------------------------------------ the module
    p='sim/core/shots.gd'
    s=open(p,encoding='utf-8').read()
    def rep(a,b):
        global s
        assert s.count(a)==1,(a[:80],s.count(a))
        s=s.replace(a,b)
    rep('''const LOB: int = 2
''','''const LOB: int = 2
const MINE: int = 3
''')
    rep('''## Timers are whole live ticks.''','''## A fourth kind does not travel: a MINE stays where it is laid, arms, and blows when a rival comes within its trigger
## radius, a shot hits it, a blow lands on it (trip, tripNear) or another mine's blast reaches it.
## A deflected shot flies wild (deflect): an arc to a seeded spot on the ground, hitting whoever or whatever is in its way.
## A straight or lobbed shot stops at a standing building in its path (hitStructure).
## Two things are seeded, both stateless (SimRng.keyed on the match seed and the shot's id, never S.rng): the spray's aim
## and where a wild shot goes.
## Timers are whole live ticks.''')
    rep('''## Nothing here draws a random number. Speeds and sizes are data/fight/shots.json.''','''## Nothing here draws from S.rng. Speeds and sizes are data/fight/shots.json.''')
    rep('''static var kinds: Dictionary = {}   # name -> {speed (units a tick), r, power, dmg, lifeTicks, lobTicks, lobArc}
''','''static var kinds: Dictionary = {}   # name -> {speed (units a tick), r, power, dmg, lifeTicks, lobTicks, lobArc, mine (a Dictionary, or null)}
static var structures: bool = false # a straight or lobbed shot stops at a building its path crosses
static var scatter: bool = false    # a deflect sends the shot wild (else back at its owner)
static var defl: Dictionary = {}    # ... nearMin, nearMax, farMin, farMax, farChance, awayChance, speed, minTicks, arcPer, safeTicks, backCos
static var mineCap: int = 0         # mines one fighter may have laid at once (one more fizzles his oldest)
static var mineGap: float = 0.0     # a mine cannot be laid within this of another
''')
    rep('''		if not (kinds[name].speed > 0.0 and kinds[name].power > 0.0):
			_err(where + "speed and power must be above 0")
''','''		var mj = k.get("mine")
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
''')
    rep('''##   "x", "y", "z"      where it starts (the owner's centre by default)
## Returns the shot, or null when the cap is reached or the kind is unknown (the press is then spent without a shot).
''','''##   "x", "y", "z"      where it starts (the owner's centre by default)
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
''')
    rep('''	sh.fresh = true
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
''','''	sh.fresh = true
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
''')
    rep('''## A perfect block or a swat sends a shot back: it becomes newOwner's and seeks its old owner, at its kind's speed. No
## event is sent here; the caller reports it (a shot_hit with its own outcome).
static func deflect(S: SimState, sh, newOwner: int) -> void:
	var old: int = sh.owner
''','''## A perfect block or a swat deflects a shot (newOwner: the slot that deflected it). The caller reports the deflect itself
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
''')
    rep('''static func hitFighter(S: SimState, sh, f) -> bool:
	if DirBlast.rules(S):
		return DirBlast.hit(S, sh, f)   # the director's blast rules: the dodge, the perfect block's deflect, the guard, a charge
	SimDamage.hurt(S, f, sh.dmg, S.fighters[sh.owner], "spread", "blast", "", true)
''','''## sh may be a mine (mode MINE: every fighter within its blast is offered, and the mine ends whatever is returned).
## f may be the shot's own owner (his wild shot, or his own mine's blast): that case takes the plain rule here and is not
## handed to the director, whose rule reads the owner as the attacker (a knock-back, a barrage, a finisher).
static func hitFighter(S: SimState, sh, f) -> bool:
	if DirBlast.rules(S) and f != S.fighters[sh.owner]:
		return DirBlast.hit(S, sh, f)   # the director's blast rules: the dodge, the perfect block's deflect, the guard, a charge
	var dmg: float = sh.dmg
	if sh.mode == MINE and f == S.fighters[sh.owner]:
		dmg *= kinds[sh.kind].mine.ownShare
	SimDamage.hurt(S, f, dmg, S.fighters[sh.owner], "spread", "blast", "", true)
''')
    rep('''## A shot has met the world (cause: ground or water) at its position. Nothing happens here beyond its end; World adds
## what a blast does to the ground, the water and the structures around it.
static func hitWorld(S: SimState, sh, cause: String) -> void:
''','''## A straight or lobbed shot has met a standing building (b, of S.buildings) at its position, on the building's face.
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
''')
    # ---- the step
    rep('''## One live tick (SimCore.step, after the director and the beams): every shot moves, opposing shots that meet trade,
## and each shot is tested against the fighters, the ground and the water, in the order they were fired.''','''## One live tick (SimCore.step, after the director and the beams): every shot moves, opposing shots that meet trade, a
## shot that hits a mine sets it off, and each shot is tested against the fighters, the buildings, the ground and the
## water, in the order they were fired. A mine's timers run, a rival near an armed one sets it off, and it blows.''')
    rep('''		if sh.fresh or sh.dead:   # fired this tick: it starts to move on the next
			sh.fresh = false
			continue
		var ox: float = sh.x''','''		if sh.fresh or sh.dead:   # fired this tick: it starts to move on the next
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
		var ox: float = sh.x''')
    rep('''			var dx: float = SimWrap.sdx(sh.x, t.x) * k
			var dy: float = (t.y + chest - sh.y) * k''','''			var dx: float = (SimWrap.sdx(sh.x, t.x) + sh.ax) * k   # (the spray's offset: it aims beside him)
			var dy: float = (t.y + chest + sh.ay - sh.y) * k''')
    rep('''+ kinds[sh.kind].lobArc * 4.0 * p * (1.0 - p)''','''+ sh.arc * 4.0 * p * (1.0 - p)''')
    rep('''	var mine: Array = [PackedInt32Array(), PackedInt32Array()]
''','''	var mine: Array = [PackedInt32Array(), PackedInt32Array()]
	var laid := PackedInt32Array()   # the mines
	var fly := PackedInt32Array()    # every shot that is not a mine, in firing order
''')
    rep('''		if not q.dead and q.owner >= 0 and q.owner < 2:
			mine[q.owner].append(i)''','''		if q.dead:
			continue
		if q.mode == MINE:
			laid.append(i)
			continue
		fly.append(i)
		if q.owner >= 0 and q.owner < 2:
			mine[q.owner].append(i)''')
    rep('''	# fighters, then the ground, the water and the life
	for i in range(n):
		var sh = S.shots[i]
		if sh.dead:
			continue
		var r: float = rad[i] + bodyR''','''	# a shot that hits an armed mine, whoever fired it, sets the mine off and ends there
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
		var r: float = rad[i] + bodyR''')
    rep('''				if k == sh.owner or (sh.passed & (1 << k)) != 0:
					continue''','''				if (k == sh.owner and not sh.wild) or (sh.passed & (1 << k)) != 0 or (k == sh.safe and safeNow):
					continue''')
    rep('''				var met: bool = arrived[i] and sh.mode == SEEK and sh.tgt == k
''','''				var met: bool = arrived[i] and sh.mode == SEEK and sh.tgt == k and sh.ax * sh.ax + sh.ay * sh.ay <= r * r
''')
    rep('''					hitOne = true
					if hitFighter(S, sh, f):
						end(S, sh, "hit")
					elif sh.owner != k:   # (a deflect made it his own shot: it is already on its way back)
						sh.passed |= 1 << k''','''					hitOne = true
					var dn: int = sh.deflected
					if hitFighter(S, sh, f):
						end(S, sh, "hit")
					elif sh.deflected == dn:   # (not if he deflected it: it is already on its way, back or wild)
						sh.passed |= 1 << k''')
    rep('''		if sh.dead or hitOne:
			continue
		if sh.mode == LOB and arrived[i]:
			hitWorld(S, sh, "ground")
			end(S, sh, "ground")''','''		if sh.dead or hitOne:
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
			end(S, sh, "ground")''')
    open(p,'w',encoding='utf-8',newline='\n').write(s)

    # ------------------------------------------------------------ events
    edit('sim/core/fx.gd', [
    ('''static func shotEnd(S: SimState, sh, cause: String) -> void:''','''## shot_deflect: a deflect sent the shot (id, kind) wild from x, y, z: actor deflected it, and it lands at x1, y1 in dur
## seconds unless something is in its way. mine_trip: a mine (id) at x, y, z was set off by actor (a slot, or -1) and blows
## in dur seconds; kind is fighter, shot, blow or chain.
static func shotDeflect(S: SimState, sh, by: int, dur: float) -> void:
	var e := _ev(S, "shot_deflect")
	e.id = sh.id; e.actor = float(by); e.kind = sh.kind; e.x = sh.x; e.y = sh.y; e.z = sh.z; e.x1 = sh.px; e.y1 = sh.py; e.dur = dur


static func mineTrip(S: SimState, sh, cause: String, slot: int, dur: float) -> void:
	var e := _ev(S, "mine_trip")
	e.id = sh.id; e.actor = float(slot); e.kind = cause; e.x = sh.x; e.y = sh.y; e.z = sh.z; e.dur = dur


static func shotEnd(S: SimState, sh, cause: String) -> void:'''),
    ('''the shot is gone, at x, y, z; cause is hit, clash, ground, water or life.''','''the shot is gone, at x, y, z; cause is hit, clash, ground, water, life, building (a
## building stopped it) or mine (a mine's blast).'''),
    ])
    edit('sim/core/view/fx.gd', [
    ('''"shot_fire", "shot_hit", "shot_clash", "shot_end",''','''"shot_fire", "shot_hit", "shot_clash", "shot_end", "shot_deflect", "mine_trip",'''),
    ])

    # ------------------------------------------------------------ the checks
    p='sim/core/tools/parity.gd'
    s=open(p,encoding='utf-8').read()
    rep('''	check("shots", _shots())
	check("agency lines", _agencyLines())''','''	check("shots", _plainShots())
	check("shots: buildings, wild deflects, the spray, mines", _shots2())
	check("agency lines", _agencyLines())''')
    rep('''func _agencyLines() -> String:''','''## The first round's check, with the second round's two rules off whatever the data's switches say.
func _plainShots() -> String:
	if not SimShots.errors().is_empty():
		return "; ".join(SimShots.errors())
	var hadS: bool = SimShots.structures
	var hadD: bool = SimShots.scatter
	SimShots.structures = false
	SimShots.scatter = false
	var res: String = _shots()
	SimShots.structures = hadS
	SimShots.scatter = hadD
	return res


## The second round (docs/architecture/shots.md sections 13 to 17), each rule forced whatever the data's switches say.
func _shots2() -> String:
	if not SimShots.errors().is_empty():
		return "; ".join(SimShots.errors())
	var hadS: bool = SimShots.structures
	var hadD: bool = SimShots.scatter
	var res: String = _shots2Run()
	SimShots.structures = hadS
	SimShots.scatter = hadD
	return res


func _shots2Run() -> String:
	var dt: float = SimConst.DT
	var bolt: Dictionary = SimShots.kinds.bolt
	if not SimShots.kinds.has("mine") or SimShots.kinds.mine.mine == null:
		return "the data has no mine kind"
	var mk: Dictionary = SimShots.kinds.mine
	var md: Dictionary = mk.mine
	var S := SimCore.createSim()
	SimCore.newMatch(S, 5, {"p1": false, "p2": false}, {"intro": false})
	var a = S.fighters[0]
	var b = S.fighters[1]
	var count := func(type: String, key: String = "", val = null) -> int:
		var c: int = 0
		for e in S.out.fx:
			if e.type == type and (key == "" or e.get(key) == val):
				c += 1
		return c
	var run := func(ticks: int) -> void:
		for t in range(ticks):
			SimShots.step(S, dt)
	var clear := func() -> void:
		for q in S.shots:
			q.dead = true
		SimShots.step(S, dt)
		S.out.fx.clear()
	# ---- buildings: a building in a blast's reach of the plane, with clear air on its left
	var bi: int = -1
	for i in range(S.buildings.size()):
		var c = S.buildings[i]
		if not c.alive or WorldStructures.dz(c) > WorldStructures.Z_REACH or WorldStructures.curH(c) < 120.0:
			continue
		var sx0: float = SimWrap.wrap(c.x - c.w * 0.5 - 200.0)
		var free: bool = true
		for o in S.buildings:
			if o != c and o.alive and absf(SimWrap.sdx(sx0, o.x)) < o.w * 0.5 + 220.0:
				free = false
		if free:
			bi = i
			break
	if bi < 0:
		return "no building in reach of the plane with clear air beside it"
	var bd = S.buildings[bi]
	var base: float = WorldStructures.baseY(S, bd)
	var top: float = base + WorldStructures.curH(bd)
	b.x = SimWrap.wrap(bd.x + 60000.0); b.y = 9000.0
	a.x = SimWrap.wrap(bd.x - bd.w * 0.5 - 200.0)
	a.y = (base + top) * 0.5 - SimShots.chest
	SimShots.scatter = false
	SimShots.structures = false
	var sh = SimShots.fire(S, 0, "bolt", {"ux": 1.0, "uy": 0.0})
	run.call(12)
	if sh.dead or SimWrap.sdx(bd.x, sh.x) < bd.w * 0.5:
		return "with structures off a bolt did not fly through the building"
	clear.call()
	SimShots.structures = true
	sh = SimShots.fire(S, 0, "bolt", {"ux": 1.0, "uy": 0.0})
	run.call(12)
	if not sh.dead or count.call("shot_end", "cause", "building") != 1 or absf(SimWrap.sdx(sh.x, bd.x) - (bd.w * 0.5 + bolt.r)) > 0.01:
		return "a bolt did not stop on the building's face (dead %s, %s from its centre, half width %s)" % [str(sh.dead), str(SimWrap.sdx(sh.x, bd.x)), str(bd.w * 0.5)]
	clear.call()
	# over every roof along its way (a taller building of another row may stand behind this one)
	var over: float = top
	for o in S.buildings:
		if o.alive and WorldStructures.dz(o) <= WorldStructures.Z_REACH and absf(SimWrap.sdx(SimWrap.wrap(a.x + 330.0), o.x)) < o.w * 0.5 + 400.0:
			over = maxf(over, WorldStructures.baseY(S, o) + WorldStructures.curH(o))
	a.y = over + bolt.r + 30.0 - SimShots.chest
	sh = SimShots.fire(S, 0, "bolt", {"ux": 1.0, "uy": 0.0})
	run.call(12)
	if sh.dead:
		return "a bolt over the roofs was stopped"
	clear.call()
	# from above, onto the roof
	a.x = bd.x
	a.y = top + 300.0 - SimShots.chest
	sh = SimShots.fire(S, 0, "bolt", {"ux": 0.0, "uy": -1.0})
	run.call(12)
	if not sh.dead or count.call("shot_end", "cause", "building") != 1 or absf(sh.y - (top + bolt.r)) > 0.01:
		return "a bolt from above did not stop on the roof (y %s, roof %s)" % [str(sh.y), str(top)]
	clear.call()
	# fired from inside it: it is let out
	a.x = bd.x
	a.y = (base + top) * 0.5 - SimShots.chest
	sh = SimShots.fire(S, 0, "bolt", {"ux": -1.0, "uy": 0.0})
	run.call(1 + int(ceil((bd.w * 0.5 + 100.0) / bolt.speed)))
	if sh.dead or SimWrap.sdx(sh.x, bd.x) < bd.w * 0.5:
		return "a bolt fired from inside a building did not leave it"
	clear.call()
	# a seeking shot is not stopped by it
	a.x = SimWrap.wrap(bd.x - bd.w * 0.5 - 200.0)
	a.y = (base + top) * 0.5 - SimShots.chest
	b.x = SimWrap.wrap(bd.x + bd.w * 0.5 + 200.0)
	b.y = a.y
	sh = SimShots.fire(S, 0, "bolt", {"target": 1})
	run.call(sh.left + 1)
	if count.call("shot_hit", "victim", 1.0) != 1 or count.call("shot_end", "cause", "building") != 0:
		return "a seeking bolt was stopped by a building"
	clear.call()
	SimShots.structures = false
	# ---- the wild deflect
	SimShots.scatter = true
	var D: Dictionary = SimShots.defl
	var sides: Array = [0, 0]
	var fars: int = 0
	for n in range(60):
		a.x = 40000.0; a.y = 3000.0
		b.x = 40900.0; b.y = 3000.0 + float(n % 5) * 200.0
		sh = SimShots.fire(S, 0, "bolt", {"target": 1})
		run.call(4)
		var x0: float = sh.x
		var y0: float = sh.y
		SimShots.deflect(S, sh, 1)
		if sh.owner != 0 or sh.mode != SimShots.LOB or not sh.wild or sh.safe != 1 or sh.tgt != -1 or sh.deflected != 1:
			return "a wild deflect did not make the shot a wild lob of its shooter's"
		var dist: float = absf(SimWrap.sdx(x0, sh.px))
		if dist < D.nearMin - 0.001 or dist > D.farMax + 0.001 or sh.py != maxf(WorldTerrain.groundY(S, sh.px), WorldWater.surfaceAt(S, sh.px)):
			return "a wild shot is bound %s away, to a point off the ground" % str(dist)
		var key: int = sh.id * 16
		var far: bool = SimRng.keyed(int(S.game.seed), "shot.deflect.far", key) < D.farChance
		var u: float = SimRng.keyed(int(S.game.seed), "shot.deflect.dist", key)
		var want: float = (D.farMin + (D.farMax - D.farMin) * u) if far else (D.nearMin + (D.nearMax - D.nearMin) * u)
		if absf(dist - want) > 0.001:
			return "a wild shot's distance is %s, the seeded draw says %s" % [str(dist), str(want)]
		fars += 1 if far else 0
		sides[0 if SimWrap.sdx(x0, sh.px) < 0.0 else 1] += 1
		var lx: float = SimWrap.sdx(x0, sh.px)
		var ly: float = sh.py - y0 + 4.0 * sh.arc
		var tx: float = SimWrap.sdx(x0, a.x)
		var ty: float = a.y + SimShots.chest - y0
		var cosv: float = (lx * tx + ly * ty) / (SimDetMath.hypot(lx, ly) * SimDetMath.hypot(tx, ty))
		if cosv > D.backCos + 0.000001:
			return "a wild shot left within 30 degrees of the line back to its shooter (cosine %s)" % str(cosv)
		sh.dead = true
	if sides[0] == 0 or sides[1] == 0 or fars == 0 or fars > 30 or sides[1] <= sides[0]:
		return "60 wild deflects: %d toward the shooter, %d away, %d far" % [sides[0], sides[1], fars]
	if count.call("shot_deflect") != 60:
		return "60 wild deflects sent %d shot_deflect events" % count.call("shot_deflect")
	clear.call()
	# it lands and ends there, hitting nobody who is not in its way: not the deflector it starts on
	a.x = 40000.0; a.y = 3000.0
	b.x = 40900.0; b.y = 3000.0
	sh = SimShots.fire(S, 0, "bolt", {"target": 1})
	run.call(4)
	b.x = sh.x; b.y = sh.y - SimShots.chest
	SimShots.deflect(S, sh, 1)
	var px: float = sh.px
	a.x = SimWrap.wrap(a.x + 80000.0)
	run.call(sh.left + 2)
	if not S.shots.is_empty() or count.call("shot_hit") != 0 or count.call("shot_end", "cause", "ground") + count.call("shot_end", "cause", "water") != 1:
		return "a wild shot did not land (hits %d)" % count.call("shot_hit")
	if absf(SimWrap.sdx(sh.x, px)) > 0.001 and sh.y > WorldTerrain.groundY(S, sh.x) + 0.001 and sh.y > WorldWater.surfaceAt(S, sh.x) + 0.001:
		return "a wild shot ended in the air"
	clear.call()
	# its own shooter, standing where it lands, is hit
	a.x = 40000.0; a.y = 3000.0
	b.x = 40900.0; b.y = 3000.0
	sh = SimShots.fire(S, 0, "bolt", {"target": 1})
	run.call(4)
	SimShots.deflect(S, sh, 1)
	a.x = sh.px
	a.y = sh.py
	var hpA: float = a.hp
	run.call(sh.left + 2)
	if count.call("shot_hit", "victim", 0.0) != 1 or a.hp != hpA - bolt.dmg:
		return "a wild shot did not hit its own shooter in its way"
	clear.call()
	# the deflector is safe for safeTicks, and not after
	a.x = 40000.0; a.y = 3000.0
	b.x = 40900.0; b.y = 3000.0
	sh = SimShots.fire(S, 0, "bolt", {"target": 1})
	run.call(4)
	SimShots.deflect(S, sh, 1)
	var hpB: float = b.hp
	for t in range(int(D.safeTicks) + 3):
		b.x = sh.x; b.y = sh.y - SimShots.chest   # he rides on it
		run.call(1)
		if t < int(D.safeTicks) and (sh.dead or b.hp != hpB):
			return "a wild shot hit its deflector %d ticks after the deflect" % (t + 1)
	if b.hp != hpB - bolt.dmg:
		return "a wild shot never hit its deflector, who stayed in its way past the safe ticks"
	clear.call()
	SimShots.scatter = false
	# ---- the spray
	a.x = 40000.0; a.y = 3000.0
	b.x = 41200.0; b.y = 3500.0
	var lo: float = 9.0
	var hi: float = -9.0
	for n in range(40):
		sh = SimShots.fire(S, 0, "bolt", {"aim": 1, "spread": 0.3})
		var ex: float = SimWrap.sdx(sh.x, b.x)
		var ey: float = b.y + SimShots.chest - sh.y
		# the turn's slope: the cross product over the dot product of the exact aim and the shot's direction
		var sl: float = (ex * sh.vy - ey * sh.vx) / (ex * sh.vx + ey * sh.vy)
		var wantS: float = 0.3 * (SimRng.keyed(int(S.game.seed), "shot.spray", sh.id) * 2.0 - 1.0)
		if sh.mode != SimShots.LINE or absf(sl - wantS) > 0.000001 or absf(sl) > 0.3:
			return "a sprayed bolt is turned by %s, the seeded draw says %s" % [str(sl), str(wantS)]
		if absf(SimDetMath.hypot(sh.vx, sh.vy) - bolt.speed * 60.0) > 0.001:
			return "a sprayed bolt's speed is %s" % str(SimDetMath.hypot(sh.vx, sh.vy))
		lo = minf(lo, sl)
		hi = maxf(hi, sl)
		sh.dead = true
		if n % 20 == 19:
			run.call(1)
	if lo > -0.15 or hi < 0.15:
		return "40 sprayed bolts covered only %s to %s of a cone of 0.3" % [str(lo), str(hi)]
	clear.call()
	sh = SimShots.fire(S, 0, "bolt", {"aim": 1})
	if absf(sh.vx * (b.y + SimShots.chest - sh.y) - sh.vy * SimWrap.sdx(sh.x, b.x)) > 0.001:
		return "an aimed bolt with no spread is not on its target"
	clear.call()
	# a seeking shot with a spread: a small one lands, a wide one passes him and flies on
	for wide in [false, true]:
		var hits: int = 0
		var flew: int = 0
		for n in range(12):
			S.out.fx.clear()
			sh = SimShots.fire(S, 0, "bolt", {"target": 1, "spread": 0.5 if wide else 0.02})
			var offD: float = SimDetMath.hypot(sh.ax, sh.ay)
			var reach: float = bolt.r + SimShots.bodyR
			if absf(sh.ax * SimWrap.sdx(sh.x, b.x) + sh.ay * (b.y + SimShots.chest - sh.y)) > 0.001:
				return "a sprayed seeking bolt's offset is not across its line of fire"
			run.call(sh.left + 1)
			var hitN: int = count.call("shot_hit", "victim", 1.0)
			if (offD <= reach) != (hitN == 1):
				return "a seeking bolt aimed %s beside him (reach %s) made %d hits" % [str(offD), str(reach), hitN]
			hits += hitN
			if hitN == 0:
				if sh.dead or sh.mode != SimShots.LINE:
					return "a sprayed seeking bolt that passed him did not fly on"
				flew += 1
			sh.dead = true
		if (not wide and hits != 12) or (wide and flew == 0):
			return "12 seeking bolts with a %s spread: %d hits, %d flew on" % ["wide" if wide else "small", hits, flew]
	clear.call()
	# ---- mines
	a.x = 40000.0; a.y = 3000.0
	b.x = 90000.0; b.y = 3000.0
	var m = SimShots.fire(S, 0, "mine")
	if m == null or m.mode != SimShots.MINE or m.arm != md.armTicks or m.fuse != -1 or m.left != mk.lifeTicks:
		return "a mine was not laid"
	if SimShots.fire(S, 0, "mine", {"x": a.x + SimShots.mineGap - 1.0}) != null or SimShots.fire(S, 1, "mine", {"x": a.x, "y": m.y + SimShots.mineGap - 1.0}) != null:
		return "a mine was laid within the gap of another"
	var idAfter: int = S.shotSeq
	if idAfter != m.id:
		return "a refused mine used up a shot id"
	var mx0: float = m.x
	var my0: float = m.y
	# not armed yet: the rival beside it does not set it off, and neither does a blow
	b.x = a.x + 20.0; b.y = a.y
	run.call(int(md.armTicks) - 2)
	if m.fuse >= 0 or SimShots.trip(S, m, "blow", 1) or count.call("mine_trip") != 0:
		return "an unarmed mine was set off"
	b.x = 90000.0
	run.call(40)
	if m.dead or m.x != mx0 or m.y != my0 or m.arm != 0 or m.fuse >= 0:
		return "a mine moved, or its owner beside it set it off"
	# the rival comes within the trigger radius: it blows, he takes its damage, its owner beside it takes his share
	S.out.fx.clear()
	hpA = a.hp
	hpB = b.hp
	b.x = a.x + md.trigR + 5.0; b.y = a.y
	run.call(2)
	if m.fuse >= 0:
		return "a mine was set off from beyond its trigger radius"
	b.x = a.x + md.trigR - 5.0
	run.call(1 + int(md.fuseTicks))
	if not m.dead or count.call("mine_trip", "kind", "fighter") != 1 or count.call("shot_end", "cause", "mine") != 1:
		return "a rival within the trigger radius did not set the mine off"
	if b.hp != hpB - mk.dmg or absf(a.hp - (hpA - mk.dmg * md.ownShare)) > 0.000001:
		return "a mine's blast: the rival lost %s (its damage is %s), its owner %s" % [str(hpB - b.hp), str(mk.dmg), str(hpA - a.hp)]
	clear.call()
	# the cap per fighter: one more fizzles the oldest
	b.x = 90000.0
	var first = null
	for n in range(SimShots.mineCap + 1):
		var q = SimShots.fire(S, 0, "mine", {"x": 40000.0 + 400.0 * n})
		if q == null:
			return "mine %d of the cap was refused" % (n + 1)
		if n == 0:
			first = q
	run.call(1)
	if not first.dead or S.shots.size() != SimShots.mineCap or count.call("shot_end", "cause", "life") != 1:
		return "one mine past the cap did not fizzle the oldest (%d live)" % S.shots.size()
	clear.call()
	# on the ground
	m = SimShots.fire(S, 0, "mine", {"ground": true})
	if m.y != WorldTerrain.groundY(S, m.x) + mk.r or not m.ground:
		return "a ground mine does not rest on the ground"
	clear.call()
	# a shot that hits it sets it off, the rival's or its owner's, and ends there
	for own in [false, true]:
		S.out.fx.clear()
		a.x = 40000.0; a.y = 3000.0
		b.x = 41000.0; b.y = 3000.0
		m = SimShots.fire(S, 0, "mine", {"x": 40500.0})
		run.call(int(md.armTicks) + 1)
		sh = SimShots.fire(S, 0 if own else 1, "bolt", {"ux": 1.0 if own else -1.0, "uy": 0.0})
		run.call(12 + int(md.fuseTicks))
		if not m.dead or not sh.dead or count.call("mine_trip", "kind", "shot") != 1 or count.call("shot_end", "cause", "mine") != 1 or count.call("shot_end", "cause", "clash") != 1:
			return "%s bolt did not set the mine off" % ("its owner's" if own else "the rival's")
		clear.call()
	# a chain: two mines within the first one's chain radius follow it, the nearer first, one chain delay apart
	a.x = 80000.0
	b.x = 90000.0
	var g: float = SimShots.mineGap
	if md.chainR < g:
		return "the chain radius is under the gap between mines: no chain can happen"
	var m1 = SimShots.fire(S, 0, "mine", {"x": 40000.0, "y": 3000.0})
	var m2 = SimShots.fire(S, 1, "mine", {"x": 40000.0 + g, "y": 3000.0})
	var m3 = SimShots.fire(S, 0, "mine", {"x": 40000.0 - g * 0.8, "y": 3000.0 - g * 0.6})
	var m4 = SimShots.fire(S, 0, "mine", {"x": 40000.0 + g * 2.0, "y": 3000.0})
	if m1 == null or m2 == null or m3 == null or m4 == null:
		return "the chain's mines were not laid"
	run.call(int(md.armTicks) + 1)
	if not SimShots.trip(S, m1, "blow", 1):
		return "a blow did not set off an armed mine"
	var ends: Array = [-1, -1, -1, -1]
	for t in range(int(md.fuseTicks) + 3 * int(md.chainTicks) + 3):
		run.call(1)
		var ms: Array = [m1, m2, m3, m4]
		for n in range(4):
			if ms[n].dead and ends[n] < 0:
				ends[n] = t
	# m2 and m3 are both one gap from m1: the tie goes to the one laid first; m4 is in reach of m2 only
	if ends[0] < 0 or ends[1] - ends[0] != md.chainTicks or ends[2] - ends[0] != 2 * md.chainTicks or ends[3] - ends[1] != md.chainTicks:
		return "the chain blew at ticks %s, a chain delay is %d" % [str(ends), md.chainTicks]
	if count.call("mine_trip", "kind", "chain") != 3 or count.call("shot_end", "cause", "mine") != 4:
		return "the chain sent %d chain events and %d blasts" % [count.call("mine_trip", "kind", "chain"), count.call("shot_end", "cause", "mine")]
	clear.call()
	# its life: it fizzles, and hurts nobody
	m = SimShots.fire(S, 0, "mine", {"x": 40000.0, "y": 3000.0})
	b.x = 40000.0 + md.blastR - 10.0; b.y = 3000.0 - SimShots.chest
	hpB = b.hp
	b.state = "intro"   # (he cannot set it off)
	run.call(int(mk.lifeTicks) + 1)
	b.state = "free"
	if not S.shots.is_empty() or count.call("shot_end", "cause", "life") != 1 or b.hp != hpB:
		return "a mine did not fizzle at the end of its life"
	# mines count toward the cap
	clear.call()
	var made: int = 0
	for n in range(SimShots.cap):
		if SimShots.fire(S, 0, "bolt", {"ux": 1.0, "uy": 0.0}) != null:
			made += 1
	if made != SimShots.cap or SimShots.fire(S, 1, "mine", {"x": 60000.0}) != null:
		return "a mine was laid past the cap on live shots"
	clear.call()
	SimCore.dispose(S)
	return ""


func _agencyLines() -> String:''')
    open(p,'w',encoding='utf-8',newline='\n').write(s)

if part=='hash':
    edit('sim/core/hash.gd', [
    ('''"deflected", "fresh", "dead", "passed"]''','''"deflected", "fresh", "dead", "passed", "ax", "ay", "arc", "lastB", "wild", "safe", "safeT", "arm", "fuse", "ground"]'''),
    ('''"shot_clash": ["id", "b", "x", "y", "z", "amount"],''','''"shot_clash": ["id", "b", "x", "y", "z", "amount"], "shot_deflect": ["id", "actor", "kind", "x", "y", "z", "x1", "y1", "dur"], "mine_trip": ["id", "actor", "kind", "x", "y", "z", "dur"],'''),
    ])

if part in ('scatter','structures'):
    edit("data/fight/shots.json", [('"%s": false,' % part, '"%s": true,' % part)])
print("shots, the second round, applied:", part)
