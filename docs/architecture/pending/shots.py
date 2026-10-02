# Shots (docs/architecture/shots.md): energy blasts in flight, as sim state. Usage: python shots.py <repo root> code|hash
#   code  SimShots (copies shots.gd to sim/core/), S.shots, the step, the four events, data/fight/shots.json, the forced
#         parity check. Nothing fires a shot yet, so parity must pass on the untouched goldens.
#   hash  S.shots and the events join the hash; shots.json joins the fight data hash and the replay header. Regenerate:
#         the light digests must not move (sim/core/tools/golden_cmp.py).
# Tools' side (the schema for shots.json) is shots_schema.cjs.
import os, sys, shutil, json, collections
HERE=os.path.dirname(os.path.abspath(__file__))
os.chdir(sys.argv[1])
part=sys.argv[2]
assert part in ('code','hash')
def edit(p, pairs):
    s=open(p,encoding='utf-8').read()
    for a,b in pairs:
        assert s.count(a)==1,(p,a[:80],s.count(a))
        s=s.replace(a,b)
    open(p,'w',encoding='utf-8',newline='\n').write(s)

if part=='code':
    shutil.copy(os.path.join(HERE,'shots.gd'),'sim/core/shots.gd')
    OD=collections.OrderedDict
    d=OD([
     ("schema","fight.shots/1"),
     ("_about","Shots: energy blasts in flight (sim/core/shots.gd; docs/architecture/shots.md). cap: live shots at once (a press past it fires nothing). arriveTicks: a seeking shot arrives within this many ticks however far its target is (moveset-rules section 11 i). chest and bodyR: a fighter's centre above his feet and his radius, for a shot's contact. Per kind: speed in units a tick (a minimum for a seeking shot), r its radius (contact and trades), power what it trades with (opposing shots that meet each lose the other's power), dmg what a plain hit does (a placeholder: the director's blasts set their own), lifeTicks how long a straight shot flies, lobTicks and lobArc a lobbed one's flight time and height."),
     ("cap",32),
     ("arriveTicks",45),
     ("chest",40.0),
     ("bodyR",40.0),
     ("kinds",OD([
       ("bolt",OD([("speed",60.0),("r",14.0),("power",1.0),("dmg",6.0),("lifeTicks",120)])),
       ("charged",OD([("speed",90.0),("r",30.0),("power",3.0),("dmg",30.0),("lifeTicks",120)])),
       ("lob",OD([("speed",40.0),("r",24.0),("power",2.0),("dmg",20.0),("lifeTicks",36),("lobTicks",36),("lobArc",300.0)])),
     ])),
    ])
    open("data/fight/shots.json",'w',encoding='utf-8',newline='\n').write(json.dumps(d,indent=2,ensure_ascii=False)+"\n")

    edit('sim/core/state.gd', [
    ('''var beams: Array = []
''','''var beams: Array = []
var shots: Array = []                 # Shot records in flight, in the order they were fired (sim/core/shots.gd), at most SimShots.cap
var shotSeq: int = 0                  # the last shot id given this match
'''),
    ('''class FeedLine:''','''## An energy blast in flight (sim/core/shots.gd). Timers are whole live ticks.
class Shot:
	var id: int = 0           # unique in the match, in firing order
	var owner: int = 0        # the slot whose shot it is (a deflect changes it)
	var kind: String = ""     # a kind in data/fight/shots.json
	var mode: int = 0         # SimShots.LINE, SEEK or LOB
	var x: float = 0.0        # wrapped
	var y: float = 0.0
	var z: float = 0.0        # depth; 0 until the depth switch-on
	var vx: float = 0.0       # units a second (a seeking or lobbed shot's is its last tick's movement, for the view)
	var vy: float = 0.0
	var tgt: int = -1         # SEEK: the slot it flies to
	var left: int = 0         # ticks left: to the arrival (SEEK, LOB) or of life (LINE)
	var total: int = 0        # ... of how many
	var x0: float = 0.0       # LOB: where it started ...
	var y0: float = 0.0
	var px: float = 0.0       # ... and the point it falls on
	var py: float = 0.0
	var power: float = 1.0    # what it trades with: opposing shots that meet each lose the other's power
	var dmg: float = 0.0      # what a plain hit does
	var group: int = 0        # shared by the shots of one volley (0: none), so a volley counts once
	var deflected: int = 0    # times it was sent back
	var fresh: bool = true    # fired this tick: it moves from the next
	var dead: bool = false    # ended this tick: removed at the end of the shots' step


class FeedLine:'''),
    ('''	var version: String = ""     # pause_start, transform:''','''	var id: int = 0              # shot_fire, shot_hit, shot_clash, shot_end: the shot's id (shot_clash: the first shot's; b is the other's)
	var version: String = ""     # pause_start, transform:'''),
    ])
    edit('sim/core/sim.gd', [
    ('''	DirBeam.beamStep(S, dt)
''','''	DirBeam.beamStep(S, dt)
	SimShots.step(S, dt)   # energy blasts in flight: they move, trade, and meet fighters and the ground
'''),
    ('''	SimPause.reset(S)        # Q10: the pause bank
''','''	SimPause.reset(S)        # Q10: the pause bank
	SimShots.reset(S)        # no shots in flight
'''),
    ])
    edit('sim/core/fx.gd', [
    ('''## The last stand: actor reached the brink''','''## Shots (sim/core/shots.gd). shot_fire: a shot leaves actor (its owner) at x, y, z: kind, id, its speed, its power
## (amount), its volley's group (link), its direction (ux, uy) and the slot it seeks (target, -1 for none). shot_hit: it
## met victim at x, y, z; amount is the damage and outcome what happened (hit by the plain rule; the director's blasts
## send guard, deflect and the rest). shot_clash: two opposing shots traded amount of power at x, y, z (id and b are
## the two ids). shot_end: the shot is gone, at x, y, z; cause is hit, clash, ground, water or life.
static func shotFire(S: SimState, sh) -> void:
	var e := _ev(S, "shot_fire")
	e.actor = float(sh.owner); e.kind = sh.kind; e.id = sh.id; e.x = sh.x; e.y = sh.y; e.z = sh.z
	e.target = float(sh.tgt); e.amount = sh.power; e.link = sh.group
	var d: float = SimDetMath.hypot(sh.vx, sh.vy)
	e.spd = d
	if d > 0.0:
		e.ux = sh.vx / d
		e.uy = sh.vy / d


static func shotHit(S: SimState, sh, f, outcome: String) -> void:
	var e := _ev(S, "shot_hit")
	e.actor = float(sh.owner); e.victim = float(S.fighters.find(f)); e.kind = sh.kind; e.id = sh.id
	e.x = sh.x; e.y = sh.y; e.z = sh.z; e.amount = sh.dmg; e.outcome = outcome; e.link = sh.group


static func shotClash(S: SimState, a, b, x: float, y: float, power: float) -> void:
	var e := _ev(S, "shot_clash")
	e.id = a.id; e.b = float(b.id); e.x = x; e.y = y; e.z = (a.z + b.z) * 0.5; e.amount = power


static func shotEnd(S: SimState, sh, cause: String) -> void:
	var e := _ev(S, "shot_end")
	e.id = sh.id; e.kind = sh.kind; e.x = sh.x; e.y = sh.y; e.z = sh.z; e.cause = cause


## The last stand: actor reached the brink'''),
    ])
    edit('sim/core/view/fx.gd', [
    ('''"pause_start", "pause_end",''','''"pause_start", "pause_end", "shot_fire", "shot_hit", "shot_clash", "shot_end",'''),
    ])
    p='sim/core/tools/parity.gd'
    s=open(p,encoding='utf-8').read()
    def rep(a,b):
        global s
        assert s.count(a)==1,(a[:80],s.count(a))
        s=s.replace(a,b)
    rep('''	check("the last stand", _lastStand())
''','''	check("the last stand", _lastStand())
	check("shots", _shots())
''')
    rep('''## The last stand (sim/core/fighter.gd): the window opens''','''## Shots (sim/core/shots.gd): none in a default match; a straight shot's speed, its life, the ground, and the seam; a
## seeking shot arriving on its tick at a moving target, near and far, with its damage; the fire tick's rest; trades in
## pairs with the rest landing, and a charged shot eating bolts; a deflect; the cap; a lob's arc and landing.
func _shots() -> String:
	if not SimShots.errors().is_empty():
		return "; ".join(SimShots.errors())
	var D := SimCore.createSim()
	SimCore.newMatch(D, 5)
	for t in range(600):
		SimCore.step(D)
		D.out.fx.clear()
		D.out.feed.clear()
		if not D.shots.is_empty():
			return "a default match has a shot in flight"
	SimCore.dispose(D)
	var dt: float = SimConst.DT
	var bolt: Dictionary = SimShots.kinds.bolt
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
	# a straight shot: the fire tick's rest, the speed, the life
	a.x = 40000.0; a.y = 3000.0
	b.x = 70000.0; b.y = 9000.0
	var sh = SimShots.fire(S, 0, "bolt", {"ux": 1.0, "uy": 0.0})
	if sh == null or sh.id != 1 or count.call("shot_fire") != 1:
		return "fire did not make shot 1"
	var x0: float = sh.x
	run.call(1)
	if sh.x != x0:
		return "a shot moved on its fire tick"
	run.call(10)
	if absf(SimWrap.sdx(x0, sh.x) - 10.0 * bolt.speed) > 0.001 or sh.y != a.y + SimShots.chest:
		return "a straight bolt moved %s in 10 ticks, not %s" % [str(SimWrap.sdx(x0, sh.x)), str(10.0 * bolt.speed)]
	run.call(int(bolt.lifeTicks))
	if not S.shots.is_empty() or count.call("shot_end", "cause", "life") != 1:
		return "a straight bolt did not end with its life"
	# the seam
	S.out.fx.clear()
	a.x = SimConst.W - 100.0
	sh = SimShots.fire(S, 0, "bolt", {"ux": 1.0, "uy": 0.0})
	run.call(4)
	if absf(sh.x - (3.0 * bolt.speed - 100.0)) > 0.001:
		return "a bolt across the seam is at %s" % str(sh.x)
	SimShots.end(S, sh, "test")
	run.call(1)
	# the ground stops a straight shot
	S.out.fx.clear()
	a.x = 40000.0
	a.y = WorldTerrain.groundY(S, a.x) + 200.0
	sh = SimShots.fire(S, 0, "bolt", {"ux": 0.3, "uy": -1.0})
	run.call(30)
	if not S.shots.is_empty() or count.call("shot_end", "cause", "ground") != 1:
		return "a bolt fired at the ground did not end on it"
	# a seeking shot: near (the speed sets the time) and far (arriveTicks does), at a target that moves
	for far in [false, true]:
		S.out.fx.clear()
		a.y = 3000.0
		b.x = SimWrap.wrap(a.x + (30000.0 if far else 600.0))
		b.y = 3200.0
		var hp0: float = b.hp
		sh = SimShots.fire(S, 0, "bolt", {"target": 1})
		var want: int = mini(SimShots.arriveTicks, int(ceil(SimDetMath.hypot(SimWrap.sdx(a.x, b.x), b.y - a.y) / bolt.speed)))
		if (far and want != SimShots.arriveTicks) or (not far and want >= SimShots.arriveTicks):
			return "the seeking test's distances no longer straddle arriveTicks"
		if sh.left != want:
			return "a seeking bolt %s away takes %d ticks, not %d" % ["far" if far else "600", sh.left, want]
		run.call(1)
		for t in range(want):
			if S.shots.is_empty():
				return "a seeking bolt ended %d ticks early" % (want - t)
			b.x = SimWrap.wrap(b.x + 150.0)
			b.y += 20.0
			run.call(1)
		if not S.shots.is_empty() or count.call("shot_hit", "victim", 1.0) != 1 or b.hp != hp0 - bolt.dmg:
			return "a seeking bolt did not land on its tick (hits %d, hp %s to %s)" % [count.call("shot_hit"), str(hp0), str(b.hp)]
	# trades: three bolts against two cancel in pairs and one lands; a charged shot eats two bolts and lands
	for charged in [false, true]:
		S.out.fx.clear()
		a.x = 40000.0; a.y = 3000.0
		b.x = 42400.0; b.y = 3000.0
		var hpA: float = a.hp
		var hpB: float = b.hp
		if charged:
			SimShots.fire(S, 0, "charged", {"target": 1})
		else:
			for n in range(3):
				SimShots.fire(S, 0, "bolt", {"target": 1, "group": 7})
		for n in range(2):
			SimShots.fire(S, 1, "bolt", {"target": 0})
		run.call(60)
		var hitsB: int = count.call("shot_hit", "victim", 1.0)
		if not S.shots.is_empty() or count.call("shot_clash") != 2 or hitsB != 1 or a.hp != hpA or b.hp >= hpB:
			return "%s against two bolts: %d clashes, %d hits on the defender, attacker hp %s to %s" % ["a charged shot" if charged else "three bolts", count.call("shot_clash"), hitsB, str(hpA), str(a.hp)]
	# a deflect sends it back to its owner
	S.out.fx.clear()
	var hpA2: float = a.hp
	sh = SimShots.fire(S, 0, "bolt", {"target": 1})
	run.call(5)
	SimShots.deflect(S, sh, 1)
	if sh.owner != 1 or sh.tgt != 0 or sh.deflected != 1:
		return "a deflect did not turn the shot"
	run.call(60)
	if count.call("shot_hit", "victim", 0.0) != 1 or a.hp != hpA2 - bolt.dmg:
		return "a deflected bolt did not land on its old owner"
	# the cap
	b.x = SimWrap.wrap(a.x + 60000.0)
	var made: int = 0
	for n in range(SimShots.cap + 5):
		if SimShots.fire(S, 0, "bolt", {"target": 1}) != null:
			made += 1
	if made != SimShots.cap or S.shots.size() != SimShots.cap:
		return "the cap let %d shots fly, not %d" % [made, SimShots.cap]
	for q in S.shots:
		SimShots.end(S, q, "test")
	run.call(1)
	# a lob: up, over, and down on its point
	S.out.fx.clear()
	a.y = WorldTerrain.groundY(S, a.x) + 100.0
	var lobk: Dictionary = SimShots.kinds.lob
	sh = SimShots.fire(S, 0, "lob", {"px": a.x + 900.0, "py": WorldTerrain.groundY(S, a.x + 900.0)})
	var top: float = sh.y
	run.call(1)
	for t in range(int(lobk.lobTicks)):
		if S.shots.is_empty():
			return "a lob ended %d ticks early" % (int(lobk.lobTicks) - t)
		top = maxf(top, sh.y)
		run.call(1)
	if not S.shots.is_empty() or count.call("shot_end", "cause", "ground") != 1 or top < a.y + SimShots.chest + lobk.lobArc * 0.5:
		return "a lob did not arc and land (top %s)" % str(top)
	SimCore.dispose(S)
	return ""


## The last stand (sim/core/fighter.gd): the window opens''')
    open(p,'w',encoding='utf-8',newline='\n').write(s)

else:
    edit('sim/core/hash.gd', [
    ('''	out.append(float(S.beams.size()))
''','''	out.append(float(S.shotSeq)); out.append(float(S.shots.size()))   # shots in flight (sim/core/shots.gd)
	for sh in S.shots:
		_obj(out, sh, SHOT)
	out.append(float(S.beams.size()))
'''),
    ('''const TREE: Array =''','''const SHOT: Array = ["id", "owner", "kind", "mode", "x", "y", "z", "vx", "vy", "tgt", "left", "total", "x0", "y0", "px", "py", "power", "dmg", "group", "deflected", "fresh", "dead"]
const TREE: Array ='''),
    ('''"pause_end": ["kind"],''','''"pause_end": ["kind"], "shot_fire": ["actor", "kind", "id", "x", "y", "z", "target", "spd", "amount", "link", "ux", "uy"], "shot_hit": ["actor", "victim", "kind", "id", "x", "y", "z", "amount", "outcome", "link"],
	"shot_clash": ["id", "b", "x", "y", "z", "amount"], "shot_end": ["id", "kind", "x", "y", "z", "cause"],'''),
    ])
    edit('sim/core/replay.gd', [
    ('''	h.text(SimIntro.dataHash())   # the intro phase: data/fight/intro.json
''','''	h.text(SimIntro.dataHash())   # the intro phase: data/fight/intro.json
	h.text(SimShots.dataHash())   # shots: data/fight/shots.json
'''),
    ])
    edit('sim/core/tools/golden_recipes.gd', [
    ('''	g.fightHash = SimMood.dataHash() + SimPause.dataHash() + SimIntro.dataHash()''','''	g.fightHash = SimMood.dataHash() + SimPause.dataHash() + SimIntro.dataHash() + SimShots.dataHash()'''),
    ])
    edit('sim/core/tools/parity.gd', [
    ('''	var fh: String = SimMood.dataHash() + SimPause.dataHash() + SimIntro.dataHash()''','''	if not SimShots.errors().is_empty():
		return "data/fight/shots.json: " + "; ".join(SimShots.errors())
	var fh: String = SimMood.dataHash() + SimPause.dataHash() + SimIntro.dataHash() + SimShots.dataHash()'''),
    ])
print("shots applied:", part)
