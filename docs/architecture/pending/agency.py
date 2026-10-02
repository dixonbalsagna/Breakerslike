# The agency pass's small core lines (docs/architecture/shots.md section 10), neutral: nothing sends the events or writes
# the fields yet. Usage: python agency.py <repo root> code|hash. Apply after shots.py (it anchors on lines that script adds).
#   code  the knockback, exchange_end, flow and embed events; ActState.flow with SimAct.setFlow; Fighter.embedT and
#         embedCool; autoCharge in SimAct.ASSISTS; the forced parity check. Parity must pass on the untouched goldens.
#   hash  the three fields and the four events join the hash. Regenerate: the light digests must not move.
import os, sys
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
    edit('sim/core/state.gd', [
    ('''	var hopped: bool = false ''','''	var embedT: int = 0              # World's embed (ground-contact.md): ticks left driven into the ground
	var embedCool: float = -1.0e9    # ... and the match time of his last embed (the cooldown counts from it)
	var hopped: bool = false '''),
    ('''	var breakIn: int = -1  ''','''	var flow: int = 0             # the agency pass: the flow count that timed presses build (the director owns its rule; SimAct.setFlow)
	var breakIn: int = -1  '''),
    ])
    edit('sim/core/act.gd', [
    ('''const ASSISTS: Array = ["autoBurst", "specialAuto", "perfectBlockAssist"]''','''const ASSISTS: Array = ["autoBurst", "specialAuto", "perfectBlockAssist", "autoCharge"]'''),
    ('''## Once per tick for a v2 fighter,''','''## The flow count (the agency pass, 2c): the director sets it; a change is sent as a flow event, for the HUD and QA.
static func setFlow(S: SimState, f, n: int) -> void:
	if f.act.flow != n:
		f.act.flow = n
		SimFx.flow(S, f, n)


## Once per tick for a v2 fighter,'''),
    ])
    edit('sim/core/fx.gd', [
    ('''## Shots (sim/core/shots.gd). shot_fire:''','''## The agency pass. knockback: victim was sent back by attacker, not launched; kind is Combat's piece (a short slide, a
## long slide, a bump, a drift), amount the distance in units, dur its length in seconds and n the tick it ends.
## exchange_end: actor's exchange ended; kind is continue (both stay in reach), knockback or launch. flow: actor's flow
## count is now n. The director sends all three.
static func knockback(S: SimState, f, by, kind: String, dist: float, endTick: int) -> void:
	var e := _ev(S, "knockback")
	e.victim = float(S.fighters.find(f)); e.attacker = float(S.fighters.find(by)) if by != null else -1.0
	e.kind = kind; e.amount = dist; e.n = endTick; e.dur = float(endTick - S.tick) / 60.0
	e.x = f.x; e.y = f.y; e.z = f.z


static func exchangeEnd(S: SimState, f, kind: String) -> void:
	var e := _ev(S, "exchange_end")
	e.actor = float(S.fighters.find(f)); e.kind = kind


static func flow(S: SimState, f, n: int) -> void:
	var e := _ev(S, "flow")
	e.actor = float(S.fighters.find(f)); e.n = n


## World's embed (ground-contact.md): actor is driven into the ground at x, y (the crater's floor), z; depth and r are
## the bowl's, energy the impact's, dur the seconds he stays down and n his launch number. World's contact model sends it.
static func embed(S: SimState, f, x: float, y: float, depth: float, r: float, energy: float, dur: float, n: int) -> void:
	var e := _ev(S, "embed")
	e.actor = float(S.fighters.find(f)); e.x = x; e.y = y; e.z = f.z
	e.depth = depth; e.r = r; e.energy = energy; e.dur = dur; e.n = n


## Shots (sim/core/shots.gd). shot_fire:'''),
    ])
    edit('sim/core/view/fx.gd', [
    ('''"pause_start", "pause_end",''','''"pause_start", "pause_end", "knockback", "exchange_end", "flow", "embed",'''),
    ])
    p='sim/core/tools/parity.gd'
    s=open(p,encoding='utf-8').read()
    def rep(a,b):
        global s
        assert s.count(a)==1,(a[:80],s.count(a))
        s=s.replace(a,b)
    rep('''	check("shots", _shots())
''','''	check("shots", _shots())
	check("agency lines", _agencyLines())
''')
    rep('''## Shots (sim/core/shots.gd): none in a default match;''','''## The agency pass's small core lines: the autoCharge assist reaches a slot from the setup; the flow count is 0 at the
## start and setFlow sends one flow event for a change and none for the same value; the embed fields start clear; the
## four events (knockback, exchange_end, flow, embed) carry their fields; and no default match sends any of them.
func _agencyLines() -> String:
	var S := SimCore.createSim()
	SimCore.newMatch(S, 5, {"p1": false, "p2": false}, {"assists": [["autoCharge"], []]})
	var a = S.fighters[0]
	var b = S.fighters[1]
	if not SimAct.assisted(a, "autoCharge") or SimAct.assisted(b, "autoCharge") or SimAct.assisted(a, "autoBurst"):
		return "the autoCharge assist did not reach its slot alone"
	if a.act.flow != 0 or a.embedT != 0 or a.embedCool > -1.0e8:
		return "the flow count or the embed fields do not start clear"
	S.out.fx.clear()
	SimAct.setFlow(S, a, 3)
	SimAct.setFlow(S, a, 3)
	SimAct.setFlow(S, a, 0)
	var flows: Array = []
	for e in S.out.fx:
		if e.type == "flow" and int(e.actor) == 0:
			flows.append(int(e.n))
	if flows != [3, 0] or a.act.flow != 0:
		return "setFlow sent %s, not [3, 0]" % str(flows)
	S.out.fx.clear()
	SimFx.knockback(S, b, a, "long slide", 450.0, S.tick + 30)
	SimFx.exchangeEnd(S, a, "knockback")
	SimFx.embed(S, b, b.x, 12.0, 130.0, 300.0, 4.0, 1.5, 7)
	var k = S.out.fx[0]
	var x = S.out.fx[1]
	var m = S.out.fx[2]
	if k.type != "knockback" or int(k.victim) != 1 or int(k.attacker) != 0 or k.kind != "long slide" or k.amount != 450.0 or k.dur != 0.5 or k.n != S.tick + 30:
		return "the knockback event's fields"
	if x.type != "exchange_end" or int(x.actor) != 0 or x.kind != "knockback":
		return "the exchange_end event's fields"
	if m.type != "embed" or int(m.actor) != 1 or m.y != 12.0 or m.depth != 130.0 or m.r != 300.0 or m.energy != 4.0 or m.dur != 1.5 or m.n != 7:
		return "the embed event's fields"
	SimCore.dispose(S)
	return ""


## Shots (sim/core/shots.gd): none in a default match;''')
    open(p,'w',encoding='utf-8',newline='\n').write(s)

else:
    edit('sim/core/hash.gd', [
    ('''"formReady", "burstFired", "breakIn"]''','''"formReady", "burstFired", "breakIn", "flow"]'''),
    ('''"lastStandUsed", "lastStandLeft",
''','''"lastStandUsed", "lastStandLeft", "embedT", "embedCool",
'''),
    ('''"pause_end": ["kind"],''','''"pause_end": ["kind"], "knockback": ["victim", "attacker", "kind", "amount", "dur", "n", "x", "y", "z"], "exchange_end": ["actor", "kind"], "flow": ["actor", "n"],
	"embed": ["actor", "x", "y", "z", "depth", "r", "energy", "dur", "n"],'''),
    ])
print("agency lines applied:", part)
