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
## setup (D1a; the replay header's `setup`): {"slots": [id, id]} picks the fighters (default: the roster's first two),
## "names": [name, name] renames them (the mirror arms), "flip": true swaps the spawn sides. {} is the default match.
## Fight lanes: "depth": true makes depth physical for this match (S.depthOn).
## The intro phase: "intro": true plays the entrance before the clock; "intro": "skip" (the default) applies its effects at
## once; "intro": false starts flat, as matches did before.
## I2a: "v2": [bool, bool] marks the slots whose intents are v2 (the stance follows the held fields), and "assists":
## [[names], [names]] the Simple layout's assists per slot (SimAct.ASSISTS).
static func newMatch(S: SimState, seed: int, ai: Dictionary = {}, setup: Dictionary = {}) -> void:
	S.game.seed = float(seed & 0xFFFFFFFF)
	S.rng = SimRng.new(seed & 0xFFFFFFFF)
	WorldTerrain.genWorld(S)
	S.contactOn = WorldContact.enabled()   # World's ground contact (world/contact.gd): a copy of the data's switch
	var p1ai: bool = bool(ai["p1"]) if ai.has("p1") and ai["p1"] != null else (S.fighters[0].ai != null if S.fighters.size() > 0 else true)
	var p2ai: bool = bool(ai["p2"]) if ai.has("p2") and ai["p2"] != null else (S.fighters[1].ai != null if S.fighters.size() > 1 else true)
	dispose(S)
	var slots: Array = setup.get("slots", FighterData.order().slice(0, 2))
	var x0: float = SimConst.START_X
	var x1: float = SimConst.START_X + SimConst.START_GAP
	var flip: bool = setup.get("flip", false)
	S.fighters = [SimRoster.createFighter(FighterData.def(slots[0]), x1 if flip else x0, "p1", p1ai), SimRoster.createFighter(FighterData.def(slots[1]), x0 if flip else x1, "p2", p2ai)]
	if setup.has("names"):
		S.fighters[0].name = setup.names[0]
		S.fighters[1].name = setup.names[1]
	S.fighters[0].y = 60.0
	S.fighters[1].y = 60.0
	S.fighters[0].face = -1.0 if flip else 1.0
	S.fighters[1].face = 1.0 if flip else -1.0
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
	S.dirS.sinceBrunt = 0.0   # B2: the pity counter and the last brunt belong to a match
	S.dirS.lastBrunt = -1.0
	S.dirS.exN = 0
	S.dirS.biomeT = PackedFloat64Array()   # location variety (granted line): the director sizes it on the first tick
	S.dirS.craterT = PackedFloat64Array()   # Encounter's slice (a) (granted line)
	SimAct.setup(S, setup)   # I2a: each fighter's action state
	S.depthOn = setup.get("depth", false) == true   # fight lanes: off until the director's switch-on (L4); a setup may force it for probes
	WorldTerrain.initRows(S)   # T: the depth rows exist only when depth is on
	SimPause.reset(S)        # Q10: the pause bank
	SimShots.reset(S)        # no shots in flight
	SimIntro.setup(S, setup) # the intro phase, when the setup asks for it
	SimMood.reset(S)   # M1: the mood, the act and each fighter's style
	S.out.feed.clear()
	S.out.fx.clear()
	S.tick = 0
	S.dt = 0.0


## One fixed step (sim.js step). inputs is [intent or null, intent or null], or null (AI fighters ignore it). Returns
## false during hit-stop (no input consumed; the host keeps its key presses for the next tick), true otherwise.
static func step(S: SimState, inputs = null) -> bool:
	var dtReal: float = SimConst.DT
	var dt: float = dtReal * S.game.ts
	S.dt = dt
	S.tick += 1
	if SimIntro.tick(S, inputs):   # the intro phase: pre-clock ticks; the sim holds as in a pause, and only a skip press is read
		SimFx.tickMark(S, dt, false)   # ... but effects run at full speed (not a pause's tenth), so the landing's dust and debris settle
		return false
	if SimPause.frozenTick(S):   # Q10: a pausing set piece is a run of frozen ticks, ahead of the hit-stop
		SimFx.tickMark(S, dt, true)
		return false
	if S.dirS.stop > 0.0:
		S.dirS.stop -= dtReal
		SimFx.tickMark(S, dt, true)
		return false
	S.T += dt
	SimPause.liveTick(S)   # Q10: the pause bank accrues on match time
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
	SimShots.step(S, dt)   # energy blasts in flight: they move, trade, and meet fighters and the ground
	WorldWater.step(S)
	SimMood.tick(S)   # M1: reads this tick's events; writes only its own state and events
	WorldCollateral.tick(S)
	SimFx.tickMark(S, dt, false)
	if S.game.clash != null:
		var c = S.game.clash
		var p: float = SimMathx.jclamp((S.T - c.t0) / c.dur, 0.0, 1.0)
		var mid: float = 0.5 + (1.0 if c.aw else -1.0) * 0.35 * p
		var ax: float = c.A.x
		var dx: float = SimWrap.sdx(ax, c.D.x)
		var sx: float = SimWrap.wrap(ax + dx * mid)
		var sz: float = c.A.z + (c.D.z - c.A.z) * mid
		SimFx.spark(S, sx, (c.A.y + (c.D.y - c.A.y) * mid) + 38.0, 3, "#ffffff", 700.0, sz)
		SimFx.shake(S, 7.0, sx, sz)
	return true


static func toggleAI(S: SimState, idx: int) -> void:
	var f = S.fighters[idx]
	f.ai = null if f.ai != null else SimState.AiState.new()
