# L2 (fight lanes): depth in the core, switched off. Everything here runs only when S.depthOn is set, so parity must pass
# on L0's goldens untouched. Usage: python l2.py <repo root>
import os, sys
os.chdir(sys.argv[1])
def edit(p, pairs):
    s=open(p,encoding='utf-8').read()
    for a,b in pairs:
        assert s.count(a)==1,(p,a[:80],s.count(a))
        s=s.replace(a,b)
    open(p,'w',encoding='utf-8',newline='\n').write(s)

edit('sim/core/fighter.gd', [
# the rush homes in depth as it does in x and y
('''	if rem <= dt:
		f.x = SimWrap.wrap(tx)
		f.y = SimMathx.jmax(ty, WorldTerrain.groundY(S, tx))
		f.rush = null''','''	var tz: float = r.tgt.z if r.tgt != null else r.pz   # L2: the rush's depth (used only when S.depthOn)
	if rem <= dt:
		f.x = SimWrap.wrap(tx)
		f.y = SimMathx.jmax(ty, WorldTerrain.groundY(S, tx))
		if S.depthOn:
			f.z = clampf(tz, SimConst.Z_BACK, SimConst.Z_FRONT)
			f.zT = f.z   # he stays where the rush took him
		f.rush = null'''),
('''	f.x = SimWrap.wrap(f.x + SimWrap.sdx(f.x, tx) * k)
	f.y += (ty - f.y) * k
''','''	f.x = SimWrap.wrap(f.x + SimWrap.sdx(f.x, tx) * k)
	f.y += (ty - f.y) * k
	if S.depthOn:
		f.z = clampf(f.z + (tz - f.z) * k, SimConst.Z_BACK, SimConst.Z_FRONT)


## Fight lanes (L2; docs/architecture/fight-lanes.md), only when S.depthOn: a fighter's depth outside a rush. The player
## never steers it. In a flight World's waypoint moves z (WorldBrunt.stepZ) and the home depth follows, so he stays where
## the flight leaves him. In an exchange his home is the exchange's depth. Otherwise he eases to his home depth zT, as he
## eased to the plane before. The band (SimConst.Z_BACK to Z_FRONT) clamps both.
static func stepDepth(S: SimState, f, dt: float) -> void:
	if f.state == "launched":
		f.z = clampf(f.z, SimConst.Z_BACK, SimConst.Z_FRONT)
		f.zT = f.z
		return
	var ex = S.dirS.ex
	if ex != null and (ex.A == f or ex.D == f):
		f.zT = ex.z
	f.zT = clampf(f.zT, SimConst.Z_BACK, SimConst.Z_FRONT)
	if f.rush == null and f.z != f.zT:
		f.z = f.zT + (f.z - f.zT) * SimDetMath.pow(0.001, dt)
		if absf(f.z - f.zT) < 0.5:
			f.z = f.zT
	f.z = clampf(f.z, SimConst.Z_BACK, SimConst.Z_FRONT)
'''),
('''	if S.game.ko == null:
		SimHiding.updateHidden(S, f, dt)''','''	if S.depthOn:
		stepDepth(S, f, dt)   # L2: off until the director's switch-on
	if S.game.ko == null:
		SimHiding.updateHidden(S, f, dt)'''),
])

# ---------------------------------------------------------------- parity: the core's depth rules, and no depth in the input
p='sim/core/tools/parity.gd'
s=open(p,encoding='utf-8').read()
def rep(a,b):
    global s
    assert s.count(a)==1,(a[:80],s.count(a))
    s=s.replace(a,b)
rep('''	check("the break", _formBreak())
''','''	check("the break", _formBreak())
	check("depth in the core", _depth())
''')
rep('''## The break (moveset-rules.md section 10.8):''','''## Fight lanes, L0 and L2 (docs/architecture/fight-lanes.md). The player never steers depth: the intent has no depth field
## and nothing in sim/input writes a depth. Depth is off unless the setup or the director's switch asks for it, and a
## default match keeps every home depth at 0. With it on (a forced setup): a free fighter eases to his home depth; a rush
## homes in depth and leaves him there; a fighter in an exchange takes its depth; a flight's end is the new home; and
## nothing leaves the band.
func _depth() -> String:
	for prop in SimIntent.new().get_property_list():
		var pn: String = prop.name
		if pn == "z" or pn == "zT" or pn == "depth" or pn == "lane" or pn == "mz":
			return "SimIntent has a depth field: " + pn
	var rx := RegEx.new()
	rx.compile("\\\\.(z|zT|zWay|aimZ0|aimZ1|pz|oz|zs)\\\\s*(=[^=]|\\\\+=|-=|\\\\*=)")
	var d := DirAccess.open("res://sim/input")
	for fname in d.get_files():
		if not fname.ends_with(".gd"):
			continue
		var src: String = FileAccess.get_file_as_string("res://sim/input/" + fname)
		var m := rx.search(src)
		if m != null:
			return "sim/input/%s writes a depth: %s" % [fname, m.get_string()]
	var P := SimCore.createSim()
	SimCore.newMatch(P, 5)
	if P.depthOn:
		return "depth is on in a default match"
	for t in range(600):
		SimCore.step(P)
		P.out.fx.clear()
		P.out.feed.clear()
		for f in P.fighters:
			if f.zT != 0.0:
				return "with depth off a home depth moved (%s at tick %d)" % [str(f.zT), t]
	SimCore.dispose(P)
	var S := SimCore.createSim()
	SimCore.newMatch(S, 5, {"p1": false, "p2": false}, {"depth": true})
	if not S.depthOn:
		return "the setup's depth switch did not reach the sim"
	var a = S.fighters[0]
	var b = S.fighters[1]
	var dt: float = SimConst.DT
	# the free ease, and the band
	a.z = 300.0
	a.zT = -600.0
	var last: float = a.z
	for t in range(240):
		SimFighter.stepDepth(S, a, dt)
		if a.z > last:
			return "the free ease moved away from the home depth"
		last = a.z
	if a.z != -600.0:
		return "a free fighter did not reach his home depth (%s)" % str(a.z)
	a.zT = -99999.0
	for t in range(600):
		SimFighter.stepDepth(S, a, dt)
	if a.z != SimConst.Z_BACK or a.zT != SimConst.Z_BACK:
		return "the band did not hold the back edge (z %s, home %s)" % [str(a.z), str(a.zT)]
	a.z = 99999.0
	SimFighter.stepDepth(S, a, dt)
	if a.z > SimConst.Z_FRONT:
		return "the band did not hold the front edge"
	# a rush homes in depth and leaves him there
	a.z = 0.0
	a.zT = 0.0
	b.z = -900.0
	b.zT = -900.0
	var r := SimState.Rush.new()
	r.tgt = b
	r.off = -60.0
	r.end = S.T + 0.5
	a.rush = r
	var steps: int = 0
	while a.rush != null and steps < 200:
		SimFighter.stepRush(S, a, dt)
		SimFighter.stepDepth(S, a, dt)
		S.T += dt
		steps += 1
	if a.z != -900.0 or a.zT != -900.0:
		return "a rush did not home in depth (z %s, home %s after %d ticks)" % [str(a.z), str(a.zT), steps]
	var r2 := SimState.Rush.new()
	r2.px = a.x + 400.0
	r2.py = a.y
	r2.pz = -300.0
	r2.end = S.T + 0.3
	a.rush = r2
	steps = 0
	while a.rush != null and steps < 200:
		SimFighter.stepRush(S, a, dt)
		S.T += dt
		steps += 1
	if a.z != -300.0:
		return "a point rush did not reach its depth (%s)" % str(a.z)
	# an exchange's depth is the home of both fighters
	var ex := SimState.Exchange.new()
	ex.A = a
	ex.D = b
	ex.z = -450.0
	S.dirS.ex = ex
	SimFighter.stepDepth(S, a, dt)
	SimFighter.stepDepth(S, b, dt)
	if a.zT != -450.0 or b.zT != -450.0:
		return "an exchange's depth did not become the fighters' home (%s, %s)" % [str(a.zT), str(b.zT)]
	S.dirS.ex = null
	# a flight's end is the new home
	a.state = "launched"
	a.z = -1200.0
	SimFighter.stepDepth(S, a, dt)
	a.state = "free"
	SimFighter.stepDepth(S, a, dt)
	if a.zT != -1200.0 or a.z != -1200.0:
		return "a flight's end did not become the home depth (z %s, home %s)" % [str(a.z), str(a.zT)]
	SimCore.dispose(S)
	return ""


## The break (moveset-rules.md section 10.8):''')
open(p,'w',encoding='utf-8',newline='\n').write(s)
print("L2 applied")
