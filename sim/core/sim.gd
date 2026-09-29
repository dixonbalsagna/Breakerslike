class_name SimCore
## The state object and the fixed-step tick: the twin of sim.js (createSim, newMatch, step, toggleAI).
## The GDScript core has one math mode, 'det' (detmath.gd): the JS core's 'native' mode uses V8's Math.sin and friends,
## which no other runtime reproduces, so parity with the prototype stays a JS-only check.


static func createSim(opts: Dictionary = {}) -> SimState:
	var fxRng: String = opts.get("fxRng", "shared")
	if fxRng != "shared":
		push_error("fxRng must be 'shared' (the only mode so far), got " + fxRng)
	var math: String = opts.get("math", "det")
	if math != "det":
		push_error("the GDScript core only has math 'det', got " + math)
	var S := SimState.new()
	S.opts = {"fxRng": fxRng, "math": math}
	S.rng = SimRng.new(7)          # the prototype's stream before its first newMatch
	S.base.resize(SimConst.NC)
	S.deform.resize(SimConst.NC)
	return S


## Break the references between a match's objects so GDScript's reference counting can free them. Fighters can point at
## each other (launchBy, rush.tgt), which is a cycle that JS's garbage collector frees and RefCounted never does.
## newMatch calls this on the outgoing match; a host that drops a sim calls it too.
static func dispose(S: SimState) -> void:
	for f in S.fighters:
		f.launchBy = null
		f.rush = null
	S.game.ko = null
	S.game.clash = null
	S.dirS.ex = null
	S.beams.clear()


## ai is {"p1": bool, "p2": bool}; a missing entry keeps the previous fighter's setting, or true with no fighters yet.
static func newMatch(S: SimState, seed: int, ai: Dictionary = {}) -> void:
	S.game.seed = float(seed & 0xFFFFFFFF)
	S.rng = SimRng.new(seed & 0xFFFFFFFF)
	WorldTerrain.genWorld(S)
	var p1ai: bool = bool(ai["p1"]) if ai.has("p1") and ai["p1"] != null else (S.fighters[0].ai != null if S.fighters.size() > 0 else true)
	var p2ai: bool = bool(ai["p2"]) if ai.has("p2") and ai["p2"] != null else (S.fighters[1].ai != null if S.fighters.size() > 1 else true)
	dispose(S)
	S.fighters = [SimRoster.createFighter(SimRoster.ROSTER[0], 2150.0, "p1", p1ai), SimRoster.createFighter(SimRoster.ROSTER[1], 2900.0, "p2", p2ai)]
	S.fighters[0].y = 60.0
	S.fighters[1].y = 60.0
	S.fighters[1].face = -1.0
	S.fighters[0].stance = 0.0
	S.fighters[1].stance = 0.0
	S.beams.clear()
	S.T = 0.0
	S.game.ko = null
	S.game.koT = 0.0
	S.game.ts = 1.0
	S.game.clash = null
	S.dirS.ex = null
	S.dirS.cool = 0.6
	S.dirS.stop = 0.0
	S.dirS.lastLaunch = ""
	S.dirS.lastLaunch2 = ""
	S.out.feed.clear()
	S.out.fx.clear()
	S.dt = 0.0


## One fixed step (sim.js step). inputs is [intent or null, intent or null], or null (AI fighters ignore it). Returns
## false during hit-stop (no input consumed; the host keeps its key presses for the next tick), true otherwise.
static func step(S: SimState, inputs = null) -> bool:
	var dtReal: float = SimConst.DT
	var dt: float = dtReal * S.game.ts
	S.dt = dt
	if S.dirS.stop > 0.0:
		S.dirS.stop -= dtReal
		SimFx.tickMark(S, dt, true)
		return false
	S.T += dt
	if S.game.ko != null:
		S.game.koT += dt
		if S.game.koT > 2.2:
			S.game.ts = 1.0
	var ord: Array = [0, 1] if S.rng.next() < 0.5 else [1, 0]
	for k in ord:
		SimControl.control(S, S.fighters[k], inputs[k] if inputs != null else null)
	for f in S.fighters:
		SimFighter.stepFighter(S, f, dt)
	DirExchange.dirUpdate(S, dt)
	DirBeam.beamStep(S, dt)
	SimFx.tickMark(S, dt, false)
	if S.game.clash != null:
		var c = S.game.clash
		var p: float = SimMathx.jclamp((S.T - c.t0) / c.dur, 0.0, 1.0)
		var mid: float = 0.5 + (1.0 if c.aw else -1.0) * 0.35 * p
		var ax: float = c.A.x
		var dx: float = SimWrap.sdx(ax, c.D.x)
		SimFx.spark(S, SimWrap.wrap(ax + dx * mid), (c.A.y + (c.D.y - c.A.y) * mid) + 38.0, 3, "#ffffff", 700.0)
		SimFx.shake(S, 7.0)
	return true


static func toggleAI(S: SimState, idx: int) -> void:
	var f = S.fighters[idx]
	f.ai = null if f.ai != null else SimState.AiState.new()
