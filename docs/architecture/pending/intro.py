# The intro phase (docs/architecture/intro-phase.md). Usage: python intro.py <repo root> code|hash|flip
#   code  SimIntro, its state, the step hook, the events, the data file, the forced parity check. Nothing is hashed and no
#         match asks for the intro, so parity must pass on the untouched goldens.
#   hash  S.intro and the events join the hash; intro.json joins the fight data hash and the replay header; a golden
#         vector for a match with the intro. Regenerate: the light digests must not move (sim/core/tools/golden_cmp.py).
#   flip  START_GAP 750 to 900 for every match (EP's ruling), and the batch runs the intro skipped. Regenerate.
import os, sys, shutil, json, collections
HERE=os.path.dirname(os.path.abspath(__file__))
os.chdir(sys.argv[1])
part=sys.argv[2]
assert part in ('code','hash','flip')
def edit(p, pairs):
    s=open(p,encoding='utf-8').read()
    for a,b in pairs:
        assert s.count(a)==1,(p,a[:80],s.count(a))
        s=s.replace(a,b)
    open(p,'w',encoding='utf-8',newline='\n').write(s)

if part=='code':
    shutil.copy(os.path.join(HERE,'intro.gd'),'sim/core/intro.gd')
    OD=collections.OrderedDict
    d=OD([
     ("schema","fight.intro/1"),
     ("_about","The intro phase (sim/core/intro.gd; docs/architecture/intro-phase.md; Camera's rule-of-cool row 7): pre-clock ticks at the start of a match that asks for it (the setup's intro). Ticks are sim ticks, 60 a second, from the first step. Fighter A is slot 0. fallA and fallB: a fall starts; landA and landB: the touchdown, where the entrance crater is dug; staredown: both stand; clock: the fight starts (the intro's length). skipFrom: a press on a human slot skips from this tick on. fallHeight: units above the ground a fall starts from. craterEnergy: the entrance crater's energy (World's crater scale; 0 digs none)."),
     ("ticks",OD([("fallA",0),("landA",36),("fallB",84),("landB",114),("staredown",144),("clock",300),("skipFrom",30)])),
     ("fallHeight",6000.0),
     ("craterEnergy",1.5),
    ])
    open("data/fight/intro.json",'w',encoding='utf-8',newline='\n').write(json.dumps(d,indent=2,ensure_ascii=False)+"\n")

    edit('sim/core/state.gd', [
    ('''var pause := PauseState.new()         # Q10 (sim/core/pause.gd): the pausing set pieces' bank and the running pause
''','''var pause := PauseState.new()         # Q10 (sim/core/pause.gd): the pausing set pieces' bank and the running pause
var intro := IntroState.new()         # the intro phase (sim/core/intro.gd): the pre-clock ticks of a match that asks for it
'''),
    ('''## Q10: pausing set pieces (sim/core/pause.gd).''','''## The intro phase (sim/core/intro.gd). Integers.
class IntroState:
	var left: int = 0         # pre-clock ticks left (0: no intro, or it is over)
	var t: int = 0            # pre-clock ticks played
	var landed: int = 0       # a bit per slot: he has touched down


## Q10: pausing set pieces (sim/core/pause.gd).'''),
    ])
    edit('sim/core/sim.gd', [
    ('''	SimPause.reset(S)        # Q10: the pause bank
''','''	SimPause.reset(S)        # Q10: the pause bank
	SimIntro.setup(S, setup) # the intro phase, when the setup asks for it
'''),
    ('''## Fight lanes: "depth": true makes depth physical for this match (S.depthOn).''','''## Fight lanes: "depth": true makes depth physical for this match (S.depthOn).
## The intro phase: "intro": true plays the entrance before the clock; "intro": "skip" applies its effects at once.'''),
    ('''	S.tick += 1
	if SimPause.frozenTick(S):''','''	S.tick += 1
	if SimIntro.tick(S, inputs):   # the intro phase: pre-clock ticks, frozen like a pause; only a skip press is read
		SimFx.tickMark(S, dt, true)
		return false
	if SimPause.frozenTick(S):'''),
    ])
    edit('sim/core/fx.gd', [
    ('''## Q10: a pausing set piece starts:''','''## The intro phase (sim/core/intro.gd). intro_start: the pre-clock window opens, dur seconds long; a press skips it after
## delay seconds. entrance_fall: actor starts to fall toward x, y (the ground), from height y1, for dur seconds.
## entrance_land: he touches down; r is the crater's bowl radius (0 if none was dug). staredown_start: both stand, for
## dur seconds. clock_start: the fight starts with the next tick; kind is full, or skip when a press ended the intro.
static func introStart(S: SimState, dur: float, skipAfter: float) -> void:
	var e := _ev(S, "intro_start")
	e.dur = dur; e.delay = skipAfter


static func entranceFall(S: SimState, f, ground: float, top: float, dur: float) -> void:
	var e := _ev(S, "entrance_fall")
	e.actor = float(S.fighters.find(f)); e.x = f.x; e.y = ground; e.z = f.z; e.y1 = top; e.dur = dur


static func entranceLand(S: SimState, f, top: float, r: float) -> void:
	var e := _ev(S, "entrance_land")
	e.actor = float(S.fighters.find(f)); e.x = f.x; e.y = f.y; e.z = f.z; e.y1 = top; e.r = r


static func staredownStart(S: SimState, dur: float) -> void:
	var e := _ev(S, "staredown_start")
	e.dur = dur


static func clockStart(S: SimState, kind: String) -> void:
	var e := _ev(S, "clock_start")
	e.kind = kind


## Q10: a pausing set piece starts:'''),
    ])
    edit('sim/core/view/fx.gd', [
    ('''"pause_start", "pause_end",''','''"pause_start", "pause_end", "intro_start", "entrance_fall", "entrance_land", "staredown_start", "clock_start",'''),
    ])
    p='sim/core/tools/parity.gd'
    s=open(p,encoding='utf-8').read()
    def rep(a,b):
        global s
        assert s.count(a)==1,(a[:80],s.count(a))
        s=s.replace(a,b)
    rep('''	check("depth in the core", _depth())
''','''	check("depth in the core", _depth())
	check("the intro phase", _intro())
''')
    rep('''## Fight lanes, L0 and L2 (docs/architecture/fight-lanes.md).''','''## The intro phase (sim/core/intro.gd): off unless the setup asks; with it, the timeline's events on their ticks, every
## tick pre-clock (step false, S.T at 0), the falls going down, both craters dug, both fighters free on the ground at the
## clock; a press before skipFrom ignored and one after it skipping; the state at the clock the same whether the intro
## ran, was skipped at any tick, or was applied by the setup's "skip"; AI slots never skipping; a replay through a skip.
func _intro() -> String:
	if not SimIntro.errors().is_empty():
		return "; ".join(SimIntro.errors())
	var D := SimCore.createSim()
	SimCore.newMatch(D, 5)
	if D.intro.left != 0 or not SimCore.step(D, null):
		return "a match that did not ask for the intro got one"
	SimCore.dispose(D)
	var quiet := SimIntent.new()
	var press := SimIntent.new()
	press.light = true
	var clockState := func(S0: SimState) -> String:   # the state at the clock, without the tick counters
		S0.tick = 0
		S0.intro.t = 0
		return SimHash.stateHash(S0).gameplay
	# the full intro, two human slots that press nothing
	var S := SimCore.createSim()
	SimCore.newMatch(S, 5, {"p1": false, "p2": false}, {"intro": true})
	var a = S.fighters[0]
	var b = S.fighters[1]
	if a.state != "intro" or S.intro.left != SimIntro.clock or a.y != WorldTerrain.groundY(S, a.x) + SimIntro.fallHeight:
		return "the intro did not start (state %s, left %d)" % [a.state, S.intro.left]
	var at := {}
	var lastY: Array = [a.y, b.y]
	for t in range(SimIntro.clock):
		S.out.fx.clear()
		if SimCore.step(S, [quiet, quiet]):
			return "pre-clock tick %d was live" % t
		if S.T != 0.0:
			return "the clock moved during the intro"
		for e in S.out.fx:
			if e.type in ["intro_start", "entrance_fall", "entrance_land", "staredown_start", "clock_start"]:
				at["%s%s" % [e.type, ("" if e.actor < 0.0 else str(int(e.actor)))]] = t
		for k in range(2):
			if S.fighters[k].y > lastY[k]:
				return "slot %d rose during his fall" % k
			lastY[k] = S.fighters[k].y
	var want := {"intro_start": 0, "entrance_fall0": SimIntro.fall[0], "entrance_land0": SimIntro.land[0], "entrance_fall1": SimIntro.fall[1],
		"entrance_land1": SimIntro.land[1], "staredown_start": SimIntro.staredown, "clock_start": SimIntro.clock - 1}
	for k in want:
		if at.get(k, -1) != want[k]:
			return "%s came at tick %s, not %d" % [k, str(at.get(k, "never")), want[k]]
	if a.state != "free" or b.state != "free" or a.y != WorldTerrain.groundY(S, a.x) or S.craters.size() != 2 or S.intro.left != 0:
		return "at the clock: states %s and %s, %d craters" % [a.state, b.state, S.craters.size()]
	var full: String = clockState.call(S)
	if not SimCore.step(S, [quiet, quiet]) or S.T <= 0.0:
		return "the tick after the clock was not live"
	SimCore.dispose(S)
	# a press too early is ignored; a press later skips, from any point, to the same state
	for at_tick in [SimIntro.skipFrom, SimIntro.land[0] + 3, SimIntro.land[1] + 3, SimIntro.clock - 1]:
		var K := SimCore.createSim()
		SimCore.newMatch(K, 5, {"p1": false, "p2": false}, {"intro": true})
		for t in range(at_tick):
			SimCore.step(K, [press if t < SimIntro.skipFrom else quiet, quiet])
		if K.intro.left != SimIntro.clock - at_tick:
			return "a press before skipFrom skipped the intro"
		K.out.fx.clear()
		if SimCore.step(K, [quiet, press]) or K.intro.left != 0:
			return "a press at tick %d did not skip" % at_tick
		var kind: String = ""
		for e in K.out.fx:
			if e.type == "clock_start":
				kind = e.kind
		if kind != "skip":
			return "a skip's clock_start kind is '%s'" % kind
		if clockState.call(K) != full:
			return "a skip at tick %d left another state at the clock than the full intro" % at_tick
		SimCore.dispose(K)
	var Q := SimCore.createSim()
	SimCore.newMatch(Q, 5, {"p1": false, "p2": false}, {"intro": "skip"})
	if Q.intro.left != 0 or not Q.out.fx.is_empty() or clockState.call(Q) != full:
		return "the setup's skip did not give the state at the clock"
	SimCore.dispose(Q)
	# AI slots never skip
	var A := SimCore.createSim()
	SimCore.newMatch(A, 5, {}, {"intro": true})
	for t in range(SimIntro.clock - 1):
		SimCore.step(A, [press, press])
	if A.intro.left != 1:
		return "an AI slot's intent skipped the intro"
	SimCore.dispose(A)
	# a replay through a skip
	var R := SimCore.createSim()
	var rec := SimReplay.recorder(R, 9, {"p1": false, "p2": true}, {"intro": true})
	for t in range(400):
		rec.step([press if t == SimIntro.skipFrom + 5 else quiet, null])
		R.out.fx.clear()
		R.out.feed.clear()
	if R.intro.t != SimIntro.skipFrom + 6:
		return "the recorded match did not skip where it pressed (%d)" % R.intro.t
	var rp: Dictionary = rec.finish()
	SimCore.dispose(R)
	var res: Dictionary = SimReplay.play(JSON.parse_string(JSON.stringify(rp)))
	return "" if res.ok else "a replay through a skipped intro: %s at tick %d" % [res.reason, res.firstBadTick]


## Fight lanes, L0 and L2 (docs/architecture/fight-lanes.md).''')
    open(p,'w',encoding='utf-8',newline='\n').write(s)

elif part=='hash':
    edit('sim/core/hash.gd', [
    ('''	out.append(S.depthOn)   # fight lanes (L0)
''','''	out.append(S.depthOn)   # fight lanes (L0)
	_obj(out, S.intro, ["left", "t", "landed"])   # the intro phase
'''),
    ('''"pause_end": ["kind"],''','''"pause_end": ["kind"], "intro_start": ["dur", "delay"], "entrance_fall": ["actor", "x", "y", "z", "y1", "dur"], "entrance_land": ["actor", "x", "y", "z", "y1", "r"], "staredown_start": ["dur"], "clock_start": ["kind"],'''),
    ])
    edit('sim/core/replay.gd', [
    ('''	h.text(SimPause.dataHash())   # Q10: data/fight/pause.json
''','''	h.text(SimPause.dataHash())   # Q10: data/fight/pause.json
	h.text(SimIntro.dataHash())   # the intro phase: data/fight/intro.json
'''),
    ])
    edit('sim/core/tools/golden_recipes.gd', [
    ('''	g.fightHash = SimMood.dataHash() + SimPause.dataHash()''','''	g.fightHash = SimMood.dataHash() + SimPause.dataHash() + SimIntro.dataHash()
	g.intro = introHash()'''),
    ('''## Every golden vector, as the JSON the generator writes.''','''## The intro phase: an AI match that plays the intro (seed 7), every tick's clock, fighters and events through the
## pre-clock ticks and the first ten seconds of the fight.
static func introHash() -> String:
	var S := SimCore.createSim()
	SimCore.newMatch(S, 7, {}, {"intro": true})
	var h := SimHash.Hasher.new()
	for t in range(SimIntro.clock + 600):
		SimCore.step(S)
		h.num(S.T)
		for f in S.fighters:
			h.num(f.x); h.num(f.y); h.num(f.hp); h.text(f.state)
		SimHash.hashFx(h, S.out.fx)
		S.out.fx.clear()
		S.out.feed.clear()
	h.text(SimHash.stateHash(S).gameplay)
	SimCore.dispose(S)
	return h.hex()


## Every golden vector, as the JSON the generator writes.'''),
    ])
    edit('sim/core/tools/parity.gd', [
    ('''	var fh: String = SimMood.dataHash() + SimPause.dataHash()''','''	if not SimIntro.errors().is_empty():
		return "data/fight/intro.json: " + "; ".join(SimIntro.errors())
	var fh: String = SimMood.dataHash() + SimPause.dataHash() + SimIntro.dataHash()'''),
    ('''	check("the intro phase", _intro())
''','''	check("the intro phase", _intro())
	check("the intro phase (golden)", "" if SimGolden.introHash() == g.get("intro", "") else "differs")
'''),
    ])

else:
    edit('sim/core/constants.gd', [
    ('''const START_GAP: float = 750.0''','''const START_GAP: float = 900.0   # was 750: Camera's entrance needs the two landing spots this far apart (EP, 2026-10-02)'''),
    ])
    s=open('sim/core/constants.gd',encoding='utf-8').read()
    s=s.replace("the second is 750 units on","the second is START_GAP units on")
    open('sim/core/constants.gd','w',encoding='utf-8',newline='\n').write(s)
    edit('sim/core/tools/batch.gd', [
    ('''	SimCore.newMatch(S, seed)
	SimGolden.applyArm(arm, S.fighters)''','''	SimCore.newMatch(S, seed, {}, {"intro": "skip"})   # the shipped game plays the intro: batches start from its state at the clock
	SimGolden.applyArm(arm, S.fighters)'''),
    ])
print("intro applied:", part)
