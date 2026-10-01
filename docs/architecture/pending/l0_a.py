# L0 (fight lanes, docs/architecture/fight-lanes.md): depth plumbing, everything zero. Step A: the code, with nothing
# new in the hash, so parity must pass on the untouched goldens. Usage: python l0_a.py <repo root>
import os, sys, re
os.chdir(sys.argv[1])
def edit(p, pairs):
    s=open(p,encoding='utf-8').read()
    for a,b in pairs:
        assert s.count(a)==1,(p,a[:80],s.count(a))
        s=s.replace(a,b)
    open(p,'w',encoding='utf-8',newline='\n').write(s)

# ---------------------------------------------------------------- constants: the band, until World's lane table (L1) gives it
edit('sim/core/constants.gd', [
('''const START_GAP: float = 750.0
''','''const START_GAP: float = 750.0
## Fight lanes (ADR 0009, docs/architecture/fight-lanes.md): the band of depth fighters, props and beams live in. z is
## positive toward the camera and the fighter plane is z = 0. Placeholders for World's lane table (S.lanes, L1).
const Z_FRONT: float = 375.0     # +5 fighter heights: the front street's near kerb
const Z_BACK: float = -2025.0    # -27 fighter heights: block row 2's back face
'''),
])

# ---------------------------------------------------------------- state
edit('sim/core/state.gd', [
('''var pause := PauseState.new()         # Q10 (sim/core/pause.gd): the pausing set pieces' bank and the running pause
''','''var pause := PauseState.new()         # Q10 (sim/core/pause.gd): the pausing set pieces' bank and the running pause
var depthOn: bool = false             # fight lanes: depth is physical (the director's depth.json switch, or the setup's "depth"); off until L4
'''),
('''	var z: float = 0.0               # the fighter's depth from the plane, positive toward the camera; a function of his aim
''','''	var z: float = 0.0               # the fighter's depth from the plane, positive toward the camera; a function of his aim
	var zT: float = 0.0              # L0: the home depth a free fighter eases to (where a flight left him, or the director's choice)
	var zWay: bool = false           # L0: a depth waypoint is armed for this flight whether or not it is aimed (aimX0, aimZ0, aimZ1, aimD)
'''),
('''class Rush:
	var tgt = null
	var off: float = 0.0
	var px: float = 0.0
	var py: float = 0.0
''','''class Rush:
	var tgt = null
	var off: float = 0.0
	var px: float = 0.0
	var py: float = 0.0
	var pz: float = 0.0      # L0: a point rush's depth (a fighter rush homes to its target's z)
'''),
('''	var sA: float = 0.0          # S3b (R8): the attacker's stance, frozen at requestAttack; hit() reads it in the exchange
''','''	var z: float = 0.0           # L0: the depth the exchange is fought at (the director sets it at requestAttack)
	var sA: float = 0.0          # S3b (R8): the attacker's stance, frozen at requestAttack; hit() reads it in the exchange
'''),
('''	var struck: bool = false     # has this beam already dug its ground-strike crater?
''','''	var struck: bool = false     # has this beam already dug its ground-strike crater?
	var oz: float = 0.0          # L0: the depth at the beam's origin ...
	var zs: float = 0.0          # ... and its change per unit of length
'''),
('''	var x1: float = 0.0       # where he stopped or left the ground
''','''	var x1: float = 0.0       # where he stopped or left the ground
	var z0: float = 0.0       # L0: the furrow's depth at each end
	var z1: float = 0.0
'''),
])

# ---------------------------------------------------------------- newMatch: the depth switch
edit('sim/core/sim.gd', [
('''	SimAct.setup(S, setup)   # I2a: each fighter's action state
''','''	SimAct.setup(S, setup)   # I2a: each fighter's action state
	S.depthOn = setup.get("depth", false) == true   # fight lanes: off until the director's switch-on (L4); a setup may force it for probes
'''),
('''## I2a: "v2": [bool, bool] marks''','''## Fight lanes: "depth": true makes depth physical for this match (S.depthOn).
## I2a: "v2": [bool, bool] marks'''),
('''		SimFx.spark(S, sx, (c.A.y + (c.D.y - c.A.y) * mid) + 38.0, 3, "#ffffff", 700.0)
		SimFx.shake(S, 7.0, sx)''','''		var sz: float = c.A.z + (c.D.z - c.A.z) * mid
		SimFx.spark(S, sx, (c.A.y + (c.D.y - c.A.y) * mid) + 38.0, 3, "#ffffff", 700.0, sz)
		SimFx.shake(S, 7.0, sx, sz)'''),
])

# ---------------------------------------------------------------- events: z on the positioned ones, the launch's direction
p='sim/core/fx.gd'
s=open(p,encoding='utf-8').read()
def rep(a,b):
    global s
    assert s.count(a)==1,(a[:80],s.count(a))
    s=s.replace(a,b)
rep('''static func spark(S: SimState, x: float, y: float, n: int, col: String, spd: float) -> void:
	var e := _ev(S, "spark")
	e.x = x; e.y = y; e.n = n''','''## L0 (fight lanes): every positioned event carries z, the depth it happens at (0 is the fighter plane). The emitters
## that take a position take z last, 0 by default; the ones that take a fighter read his.
static func spark(S: SimState, x: float, y: float, n: int, col: String, spd: float, z: float = 0.0) -> void:
	var e := _ev(S, "spark")
	e.x = x; e.y = y; e.n = n; e.z = z''')
rep('''static func ring(S: SimState, x: float, y: float, gr: float, col: String, life: float, r0: float) -> void:
	var e := _ev(S, "ring")
	e.x = x; e.y = y; e.gr = gr''','''static func ring(S: SimState, x: float, y: float, gr: float, col: String, life: float, r0: float, z: float = 0.0) -> void:
	var e := _ev(S, "ring")
	e.x = x; e.y = y; e.gr = gr; e.z = z''')
rep('''static func debris(S: SimState, x: float, y: float, n: int, col: String, spd: float) -> void:
	var e := _ev(S, "debris")
	e.x = x; e.y = y; e.n = n''','''static func debris(S: SimState, x: float, y: float, n: int, col: String, spd: float, z: float = 0.0) -> void:
	var e := _ev(S, "debris")
	e.x = x; e.y = y; e.n = n; e.z = z''')
rep('''static func dust(S: SimState, x: float, y: float, n: int, col: String = "") -> void:
	var e := _ev(S, "dust")
	e.x = x; e.y = y; e.n = n''','''static func dust(S: SimState, x: float, y: float, n: int, col: String = "", z: float = 0.0) -> void:
	var e := _ev(S, "dust")
	e.x = x; e.y = y; e.n = n; e.z = z''')
rep('''static func splash(S: SimState, x: float, y: float, n: int) -> void:
	var e := _ev(S, "splash")
	e.x = x; e.y = y; e.n = n''','''static func splash(S: SimState, x: float, y: float, n: int, z: float = 0.0) -> void:
	var e := _ev(S, "splash")
	e.x = x; e.y = y; e.n = n; e.z = z''')
rep('''static func fire(S: SimState, x: float, y: float, n: int) -> void:
	var e := _ev(S, "fire")
	e.x = x; e.y = y; e.n = n''','''static func fire(S: SimState, x: float, y: float, n: int, z: float = 0.0) -> void:
	var e := _ev(S, "fire")
	e.x = x; e.y = y; e.n = n; e.z = z''')
rep('''	e.x = f.x; e.y = f.y; e.life = life; e.col = f.aura; e.face = f.face''','''	e.x = f.x; e.y = f.y; e.z = f.z; e.life = life; e.col = f.aura; e.face = f.face''')
rep('''	e.x = f.x; e.y = f.y + 90.0; e.amount = amount; e.col = col''','''	e.x = f.x; e.y = f.y + 90.0; e.z = f.z; e.amount = amount; e.col = col''')
rep('''static func shake(S: SimState, k: float, x: float) -> void:
	var e := _ev(S, "shake")
	e.k = k
	e.x = x''','''static func shake(S: SimState, k: float, x: float, z: float = 0.0) -> void:
	var e := _ev(S, "shake")
	e.k = k
	e.x = x
	e.z = z''')
rep('''	e.x = f.x; e.y = f.y; e.col = f.aura; e.ground = ground''','''	e.x = f.x; e.y = f.y; e.z = f.z; e.col = f.aura; e.ground = ground''')
rep('''	e.x = r.x0; e.x1 = r.x1; e.w = r.hw * 2.0; e.depth = r.depth; e.energy = r.energy''','''	e.x = r.x0; e.x1 = r.x1; e.z = r.z0; e.z1 = r.z1; e.w = r.hw * 2.0; e.depth = r.depth; e.energy = r.energy''')
rep('''static func slideDust(S: SimState, x: float, y: float, v: float, w: float, surface: String, i: int) -> void:
	var e := _ev(S, "slide_dust")
	e.x = x; e.y = y;''','''static func slideDust(S: SimState, x: float, y: float, v: float, w: float, surface: String, i: int, z: float = 0.0) -> void:
	var e := _ev(S, "slide_dust")
	e.x = x; e.y = y; e.z = z;''')
rep('''static func skim(S: SimState, x: float, y: float, v: float, i: int) -> void:
	var e := _ev(S, "skim")
	e.x = x; e.y = y;''','''static func skim(S: SimState, x: float, y: float, v: float, i: int, z: float = 0.0) -> void:
	var e := _ev(S, "skim")
	e.x = x; e.y = y; e.z = z;''')
rep('''static func scorchEvent(S: SimState, x: float, y: float, w: float, power: float, variant: String, owner: float) -> void:
	var e := _ev(S, "scorch")
	e.x = x; e.y = y;''','''static func scorchEvent(S: SimState, x: float, y: float, w: float, power: float, variant: String, owner: float, z: float = 0.0) -> void:
	var e := _ev(S, "scorch")
	e.x = x; e.y = y; e.z = z;''')
rep('''static func beamSplash(S: SimState, x: float) -> void:
	var e := _ev(S, "beamSplash")
	e.x = x''','''static func beamSplash(S: SimState, x: float, z: float = 0.0) -> void:
	var e := _ev(S, "beamSplash")
	e.x = x
	e.z = z''')
rep('''## Camera: actor was launched by target at speed amount, horizontally toward face (+1 or -1).
static func launch(S: SimState, f, by, speed: float, dir: float) -> void:
	var e := _ev(S, "launch")
	e.actor = float(S.fighters.find(f)); e.target = float(S.fighters.find(by)) if by != null else -1.0
	e.amount = speed; e.face = dir''','''## Camera: actor was launched by target at speed amount, horizontally toward face (+1 or -1). ux, uy: the launch's unit
## direction before the traversal boost (from the fighter's velocity, which the launch has just set), so Animation's first
## frame points the right way. n: the launch number that pairs a journey's events (World's launchN; 0 until it lands).
static func launch(S: SimState, f, by, speed: float, dir: float, n: int = 0) -> void:
	var e := _ev(S, "launch")
	e.actor = float(S.fighters.find(f)); e.target = float(S.fighters.find(by)) if by != null else -1.0
	e.amount = speed; e.face = dir; e.n = n
	var hx: float = f.vx / f.launchT
	var d: float = SimDetMath.hypot(hx, f.vy)
	if d > 0.0:
		e.ux = hx / d
		e.uy = f.vy / d''')
open(p,'w',encoding='utf-8',newline='\n').write(s)

# ---------------------------------------------------------------- the core's own emitters pass the fighter's depth
p='sim/core/fighter.gd'
s=open(p,encoding='utf-8').read()
n0=0
def sub(pat, repl):
    global s, n0
    s, k = re.subn(pat, repl, s)
    n0 += k
sub(r'(SimFx\.(?:spark|ring|debris|splash|skim)\(S, f\.x, [^\n]*?)\)(\s*(?:#[^\n]*)?)\n', r'\1, f.z)\2\n')
sub(r'(SimFx\.shake\(S, [^\n]*?, f\.x)\)\n', r'\1, f.z)\n')
sub(r'(SimFx\.dust\(S, f\.x, g, \d+)\)\n', r'\1, "", f.z)\n')
assert n0==14, n0
open(p,'w',encoding='utf-8',newline='\n').write(s)
edit('sim/core/damage.gd', [
('''	SimFx.spark(S, D.x, D.y + 34.0, 18 if o.get("big", false) else 9, "#fff3c0", 600.0)''','''	SimFx.spark(S, D.x, D.y + 34.0, 18 if o.get("big", false) else 9, "#fff3c0", 600.0, D.z)'''),
('''	SimFx.shake(S, jor(o.get("shake", 0.0), 6.0), D.x)''','''	SimFx.shake(S, jor(o.get("shake", 0.0), 6.0), D.x, D.z)'''),
])
print("L0 step A applied")
