class_name SimHiding
## Hiding and the ambush setup: the twin of hiding.js (updateHidden).


## spec-wounds.md §1c (S2): hiding is the future stealth fighter's kit (canHide). Everyone else can only break the
## opponent's lock-on in the ESCAPE stance by staying out of line of sight for LOCK_BREAK_T; "hidden" then means "no
## lock on me", with no healing, no ambush and nothing concealed on screen.
const LOCK_BREAK_T: float = 0.9     # seconds out of sight in ESCAPE to break lock
const LOCK_MAX_T: float = 4.0       # lock loss never lasts longer
const LOCK_REBREAK_T: float = 6.0   # after lock returns, no new break for this long
const LOCK_FOUND_R: float = 240.0   # the hunter within this regains lock (120 inside a cloud, when clouds arrive)
const LOS_SAMPLES: int = 48         # terrain line test: samples between the two chests
const CHEST: float = 40.0


static func updateHidden(S: SimState, f, dt: float) -> void:
	if not f.canHide:
		_lockBreak(S, f, dt)
		return
	var o = SimRoster.opp(S, f)
	var dist: float = absf(SimWrap.sdx(f.x, o.x))
	var c = WorldCover.coverAt(S, f)
	var want: bool = f.stance == 3.0 and f.state == "free" and c != null and dist > 170.0 and not f.input.charge and not f.input.dash and SimDetMath.hypot(f.vx, f.vy) < 260.0
	if want:
		f.hideT += dt
		if f.hideT > 0.9 and not f.hidden:
			f.hidden = true
			f.hiddenFor = 0.0
			var ls := SimState.LastSeen.new()
			ls.x = f.x
			ls.y = f.y
			f.lastSeen = ls
			SimFx.hideStart(S, f, c)
			SimEvents.feed(S, f.name + " goes to ground", "Power signature suppressed (" + c + "). Recovering; opponent has no lock-on.")
	else:
		f.hideT = 0.0
		if f.hidden:
			f.hidden = false
			if dist <= 240.0:
				SimFx.found(S, f)
				SimEvents.feed(S, f.name + " found", "Opponent closed within scouting range.")
			elif f.hiddenFor > 1.8:
				f.ambushUntil = S.T + 2.5
	if f.hidden:
		f.hiddenFor += dt


static func _lockBreak(S: SimState, f, dt: float) -> void:
	var o = SimRoster.opp(S, f)
	var dist: float = absf(SimWrap.sdx(f.x, o.x))
	if not f.hidden:
		var want: bool = f.stance == 3.0 and f.state == "free" and S.T - f.lockBackT >= LOCK_REBREAK_T and dist > LOCK_FOUND_R and not lineOfSight(S, o, f)
		if want:
			f.hideT += dt
			if f.hideT > LOCK_BREAK_T * (f.wd.legsLockBreak if SimWounds.broken(f, SimWounds.LEGS) else 1.0):
				f.hidden = true
				f.hiddenFor = 0.0
				var ls := SimState.LastSeen.new()
				ls.x = f.x
				ls.y = f.y
				f.lastSeen = ls
				SimFx.searching(S, o, f, f.x)
				SimEvents.feed(S, f.name + " breaks lock", "Out of sight in ESCAPE; " + o.name + " is searching.")
		else:
			f.hideT = 0.0
		return
	f.hiddenFor += dt
	if lineOfSight(S, o, f) or dist <= LOCK_FOUND_R or f.hiddenFor >= LOCK_MAX_T or f.state != "free":
		regainLock(S, f)


## Lock comes back on f (sight, the hunter close, f attacking, or the time limit): the Found flash, and no new break
## for LOCK_REBREAK_T.
static func regainLock(S: SimState, f) -> void:
	f.hidden = false
	f.hideT = 0.0
	f.lockBackT = S.T
	SimFx.found(S, f)
	SimEvents.feed(S, f.name + " found", "Lock-on regained.")


## True when the hunter can see the target: not under unburnt canopy, and no terrain between their chests (a heightfield
## line test). Clouds and rubble heaps join with World's living destruction (LD1) and buildings in depth (B1).
static func lineOfSight(S: SimState, hunter, target) -> bool:
	if WorldCover.coverAt(S, target) == "canopy":
		return false
	var dx: float = SimWrap.sdx(hunter.x, target.x)
	var y0: float = hunter.y + CHEST
	var y1: float = target.y + CHEST
	for i in range(1, LOS_SAMPLES):
		var t: float = float(i) / float(LOS_SAMPLES)
		if WorldTerrain.groundY(S, hunter.x + dx * t) > y0 + (y1 - y0) * t:
			return false
	return true
