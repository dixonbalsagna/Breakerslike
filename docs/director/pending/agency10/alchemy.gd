class_name DirAlchemy
## The fight alchemist's press log (docs/director/alchemy-plan.md A1; docs/design/agency-pass.md section 2). Every attack
## press of each fighter is kept with what it carried: weight, family, direction, tilt, when it was let go, its beat (the
## distance to the nearest blow contact of the running exchange) and its charge's flash. Controls' classifier
## (SimPressRead) reads the log: holding, tapping in time, mashing or tapping; perfect, good or off; a steady mash; a
## release on the flash. The director's own rhythm tag on each press (held, mashed, timed) is set from that read.
##
## The log lives in the director's per-fighter integers (f.act.dirI), after DirInterrupt's: a ring of the last RING
## presses (packed presses, their ticks, their release ticks, beats and flashes), the count of presses, the last live
## tick, the held levels of the tick before, Controls' aim latch and the last read.
##
## One clock, S.tick, which runs through hit-stop: a press or a release made in a freeze of h ticks arrives on the first
## live tick, so it is graded at S.tick - h (Controls' rule).

const RING: int = 20                         # presses kept: the running mix
const WINDOW: int = 5                        # the alchemist's window: the last five (Orb, questionnaire 14)
const LIFE: int = 90                         # ticks a press stays in the window
const TILT_DEAD: float = 0.3                 # the stick inside this is no tilt
const BEAT_REACH: int = 12                   # a blow's contact counts as a press's beat this many ticks ahead or behind
const P0: int = DirInterrupt.N               # the ring of packed presses ...
const T0: int = P0 + RING                    # ... the ticks they arrived on ...
const COUNT: int = P0 + 2 * RING             # ... and how many presses he has made
const UP0: int = COUNT + 1                   # the tick each press's button was let go (graded), -1 while it is held
const BEAT0: int = UP0 + RING                # each press's beat (SimPressRead.NO_BEAT outside an exchange)
const FLASH0: int = BEAT0 + RING             # each press's planned flash tick (SimPressRead.NO_FLASH: no charge)
const LIVE_AT: int = FLASH0 + RING           # the last live tick
const HELD_WAS: int = LIVE_AT + 1            # the held levels of the tick before: bit 0 a light button, bit 1 a heavy one
const AIM_S: int = HELD_WAS + 1              # Controls' aim latch (SimAim): the sector, plus 1 (0: nothing aimed) ...
const AIM_T: int = AIM_S + 1                 # ... and the tick it was set
const READ: int = AIM_T + 1                  # the last read, packed (style, timing, steady, streak)
const PIECE_1: int = READ + 1                # the last two pieces picked for him (DirRecipe), as hashes, newest first
const PIECE_2: int = READ + 2
const SIZE: int = READ + 3
const PLAIN: int = 0
const HELD: int = 1
const MASHED: int = 2
const TIMED: int = 3
const RHYTHM: Array = ["", "held", "mashed", "timed"]
const DIRS: Array = ["away", "level", "toward"]
const INTENT: int = 1 << 10                  # the press carries launch intent: a stick direction (a human), or the AI's choice
const FREEZE_SHIFT: int = 12                 # bits 12 to 15 of a packed press: the freeze it was made in, in ticks (0 to 15)
const STYLES: Array = ["none", "hold", "rhythm", "mash", "taps"]   # SimPressRead's styles, as READ packs them
const TIMINGS: Array = ["none", "good", "perfect"]


static func _size(f) -> void:
	DirInterrupt.gi(f, 0)   # DirInterrupt sizes and seeds its own part first
	if f.act.dirI.size() < SIZE:
		f.act.dirI.resize(SIZE)


## The freeze a press or a release that arrives now was made in: the frozen ticks since the last live tick.
static func _freeze(S: SimState, f) -> int:
	var last: int = f.act.dirI[LIVE_AT]
	return clampi(S.tick - last - 1, 0, 15) if last > 0 else 0


## The contact ticks a press graded at `at` is measured against: every blow of the running exchange, either fighter's,
## within BEAT_REACH ticks ahead (the pending strike beats) or behind (the last blow each fighter took).
static func _blows(S: SimState, f, at: int) -> Array:
	var out: Array = []
	var ex = S.dirS.ex
	if ex == null or (f != ex.A and f != ex.D):
		return out
	for b in ex.beats:
		if b.done or (b.op != "strike" and b.op != "chainStrike"):
			continue
		var n: int = maxi(1, int(ceil((b.t - ex.t) * DirData.TICKS_PER_SEC - 0.000001)))
		var c: int = S.tick + n - 1
		if c - at <= BEAT_REACH:
			out.append(c)
	for g in [ex.A, ex.D]:
		var h: int = DirInterrupt.gi(g, DirInterrupt.HIT_AT)
		if h != DirInterrupt.NEVER and at - h >= 0 and at - h <= BEAT_REACH:
			out.append(h)
	return out


## A press: weight (SimAct.LIGHT or HEAVY; a signature is not an ingredient), family (0 physical, 1 energy), and the stick.
static func log(S: SimState, f, weight: int, family: int) -> void:
	if weight != SimAct.LIGHT and weight != SimAct.HEAVY:
		return
	_size(f)
	var o = SimRoster.opp(S, f)
	var i: SimIntent = f.input
	var toward: float = i.mx * SimMathx.jsign(SimWrap.sdx(f.x, o.x))
	var dir: int = 2 if toward > SimAct.awayDead else (0 if toward < -SimAct.awayDead else 1)
	var tilt: int = 0   # 0 none, 1 to 8 clockwise from up (screen directions)
	if SimDetMath.hypot(i.mx, i.my) > TILT_DEAD:
		var ax: int = 1 if i.mx > TILT_DEAD else (-1 if i.mx < -TILT_DEAD else 0)
		var ay: int = 1 if i.my > TILT_DEAD else (-1 if i.my < -TILT_DEAD else 0)
		tilt = [[8, 1, 2], [7, 0, 3], [6, 5, 4]][1 - ay][ax + 1] if not (ax == 0 and ay == 0) else 0
	var n: int = f.act.dirI[COUNT]
	var k: int = n % RING
	var h: int = _freeze(S, f)
	var at: int = S.tick - h
	var held: bool = i.heavyHeld if weight == SimAct.HEAVY else i.lightHeld
	var beat: int = SimPressRead.beat_offset(at, _blows(S, f, at))
	f.act.dirI[P0 + k] = weight | (family << 1) | (dir << 2) | (tilt << 4) | (h << FREEZE_SHIFT)
	f.act.dirI[T0 + k] = S.tick
	f.act.dirI[UP0 + k] = -1 if held else at   # a button that is not down as a level was tapped: it is let go at once
	f.act.dirI[BEAT0 + k] = beat
	f.act.dirI[FLASH0 + k] = SimPressRead.NO_FLASH
	f.act.dirI[COUNT] = n + 1
	# Controls' read of the log, with this press in it.
	var c: Dictionary = read(S, f)
	var timed: bool = (beat != SimPressRead.NO_BEAT and SimPressRead.grade_of(beat) == "perfect") or (String(c.style) == "mash" and c.steady)
	f.act.dirI[READ] = maxi(0, STYLES.find(String(c.style))) | (maxi(0, TIMINGS.find(String(c.timing))) << 3) | ((1 if c.steady else 0) << 5) | (mini(int(c.streak), 7) << 6)
	# The flow count (agency-pass.md section 2): a timed press adds 1, up to FLOW_MAX; a press off the beat sets it back
	# to 0 (and so do FLOW_LIFE ticks without a press: tick).
	if DirInterrupt.on():
		SimAct.setFlow(S, f, mini(FLOW_MAX, f.act.flow + 1) if timed else 0)
	var rhythm: int = TIMED if timed else (MASHED if String(c.style) == "mash" else PLAIN)
	# Launch intent: a human's is his stick (any direction past the dead zone). The AI's stick is its flight path, so its
	# intent is a number: the chance its heavy is thrown to launch (ai.json launchIntent), one draw per heavy press.
	var intent: bool = tilt != 0
	if f.ai != null:
		# How often it uses an earner at all is its level's earnerUse (agency-pass.md section 13, rule 7).
		var use: float = float(DirAI.lv().get("earnerUse", 1.0))
		intent = weight == SimAct.HEAVY and S.rng.next() < float(DirAI.lv().get("launchIntent", 0.0)) * use
		if weight == SimAct.HEAVY and S.rng.next() < float(DirAI.lv().get("heldHeavy", 0.0)) * use:
			rhythm = HELD   # ... and the chance it charges the heavy (heldHeavy)
	f.act.dirI[P0 + k] |= (rhythm << 8) | (INTENT if intent else 0)


const FLOW_MAX: int = 5     # the flow count's ceiling
const FLOW_LIFE: int = 90   # ticks without a press after which it lapses


## Once a live tick: a button let go closes its press, Controls' aim latch takes the stick, a fighter's flow lapses
## FLOW_LIFE ticks after his last press, and the live tick is noted for the next freeze.
static func tick(S: SimState) -> void:
	for f in S.fighters:
		_size(f)
		var i: SimIntent = f.input
		var was: int = f.act.dirI[HELD_WAS]
		var now: int = (1 if i.lightHeld else 0) | (2 if i.heavyHeld else 0)
		if (was & 1) != 0 and (now & 1) == 0:
			_release(S, f, SimAct.LIGHT)
		if (was & 2) != 0 and (now & 2) == 0:
			_release(S, f, SimAct.HEAVY)
		f.act.dirI[HELD_WAS] = now
		var latch: Dictionary = {"sector": f.act.dirI[AIM_S] - 1, "tick": f.act.dirI[AIM_T]}
		SimAim.update(latch, i.mx, i.my, S.tick)
		f.act.dirI[AIM_S] = int(latch.sector) + 1
		f.act.dirI[AIM_T] = int(latch.tick)
		if f.act.flow > 0:
			var n: int = f.act.dirI[COUNT]
			if n == 0 or S.tick - f.act.dirI[T0 + (n - 1) % RING] > FLOW_LIFE:
				SimAct.setFlow(S, f, 0)
		f.act.dirI[LIVE_AT] = S.tick


## The button of that weight was let go: his newest press of it that is still held closes, at the graded tick.
static func _release(S: SimState, f, weight: int) -> void:
	var n: int = f.act.dirI[COUNT]
	for k in range(n - 1, maxi(-1, n - 1 - RING), -1):
		if (f.act.dirI[P0 + k % RING] & 1) == weight and f.act.dirI[UP0 + k % RING] < 0:
			f.act.dirI[UP0 + k % RING] = S.tick - _freeze(S, f)
			return


## A charge of that weight has begun: its flash is planned for `tick` (stamped now, though it may be in the future, so a
## release before it reads early). It goes on his newest press of that weight that is still held.
static func flash(f, weight: int, tick: int) -> void:
	_size(f)
	var n: int = f.act.dirI[COUNT]
	for k in range(n - 1, maxi(-1, n - 1 - RING), -1):
		if (f.act.dirI[P0 + k % RING] & 1) == weight and f.act.dirI[UP0 + k % RING] < 0:
			f.act.dirI[FLASH0 + k % RING] = tick
			return


## The log as Controls' classifier reads it: oldest first, {kind, mode, down, up, beat, flash}.
static func logOf(f) -> Array:
	_size(f)
	var out: Array = []
	var n: int = f.act.dirI[COUNT]
	for k in range(maxi(0, n - RING), n):
		var p: int = f.act.dirI[P0 + k % RING]
		out.append({"kind": p & 1, "mode": (p >> 1) & 1, "down": f.act.dirI[T0 + k % RING] - ((p >> FREEZE_SHIFT) & 15), "up": f.act.dirI[UP0 + k % RING], "beat": f.act.dirI[BEAT0 + k % RING], "flash": f.act.dirI[FLASH0 + k % RING]})
	return out


## Controls' read of his log now (SimPressRead.classify): style, timing, streak, steady, release, the two mixes.
static func read(S: SimState, f) -> Dictionary:
	return SimPressRead.classify(logOf(f), S.tick, {})


## The stick's launch direction (Controls' SimAim): the latched sector if it is fresh, else SimAim.NONE.
static func aim(S: SimState, f) -> int:
	_size(f)
	return SimAim.read({"sector": f.act.dirI[AIM_S] - 1, "tick": f.act.dirI[AIM_T]}, S.tick)


## The layout's hold edge: his newest press was held (a charged blow).
static func held(f) -> void:
	_size(f)
	var n: int = f.act.dirI[COUNT]
	if n > 0:
		var k: int = P0 + (n - 1) % RING
		f.act.dirI[k] = (f.act.dirI[k] & ~(3 << 8)) | (HELD << 8) | SimAct.HEAVY   # held, and the heavy the hold made it


## The press he made on that tick was held (a charge from the far band), and is the weight it ended as (a Simple
## layout's hold turns a light into a heavy on the way).
static func heldAt(f, tick: int, weight: int) -> void:
	_size(f)
	var n: int = f.act.dirI[COUNT]
	for k in range(n - 1, maxi(-1, n - 1 - RING), -1):
		if f.act.dirI[T0 + k % RING] == tick:
			f.act.dirI[P0 + k % RING] = (f.act.dirI[P0 + k % RING] & ~(3 << 8) & ~1) | (HELD << 8) | (weight & 1)
			return


## His newest press as a packed integer, if it is still alive; else -1.
static func last(S: SimState, f) -> int:
	_size(f)
	var n: int = f.act.dirI[COUNT]
	if n == 0 or S.tick - f.act.dirI[T0 + (n - 1) % RING] > LIFE:
		return -1
	return f.act.dirI[P0 + (n - 1) % RING]


## The press he made on this tick (the newest one stamped with it), or -1.
static func at(f, tick: int) -> int:
	_size(f)
	var n: int = f.act.dirI[COUNT]
	for k in range(n - 1, maxi(-1, n - 1 - RING), -1):
		if f.act.dirI[T0 + k % RING] == tick:
			return f.act.dirI[P0 + k % RING]
	return -1


## The window: his last presses still alive, oldest first, as packed integers.
static func window(S: SimState, f) -> Array:
	_size(f)
	var out: Array = []
	var n: int = f.act.dirI[COUNT]
	for k in range(maxi(0, n - WINDOW), n):
		if S.tick - f.act.dirI[T0 + k % RING] <= LIFE:
			out.append(f.act.dirI[P0 + k % RING])
	return out


## The running mix over his last RING presses: {"n", "heavy", "energy", "toward", "away", "held", "mashed", "timed"}.
static func mix(f) -> Dictionary:
	_size(f)
	var m := {"n": 0, "heavy": 0, "energy": 0, "toward": 0, "away": 0, "held": 0, "mashed": 0, "timed": 0}
	var n: int = f.act.dirI[COUNT]
	for k in range(maxi(0, n - RING), n):
		var p: int = f.act.dirI[P0 + k % RING]
		m.n += 1
		m.heavy += p & 1
		m.energy += (p >> 1) & 1
		m.toward += 1 if ((p >> 2) & 3) == 2 else 0
		m.away += 1 if ((p >> 2) & 3) == 0 else 0
		var r: int = (p >> 8) & 3
		m.held += 1 if r == HELD else 0
		m.mashed += 1 if r == MASHED else 0
		m.timed += 1 if r == TIMED else 0
	return m


## One fighter's window in words: "L L H (combo) toward, timed; read: taps, good".
static func describe(S: SimState, f) -> String:
	var w: Array = window(S, f)
	if w.is_empty():
		return "nothing pressed"
	var parts: PackedStringArray = []
	for p in w:
		parts.append("H" if (p & 1) == 1 else "L")
	var last: int = w[w.size() - 1]
	var s: String = " ".join(parts) + " (" + DirRecipe.style(S, f) + ")"
	if (last & INTENT) != 0:
		s += ", with the stick"
	s += " " + DIRS[(last >> 2) & 3]
	var r: int = (last >> 8) & 3
	if r != PLAIN:
		s += ", " + RHYTHM[r]
	if ((last >> 1) & 1) == 1:
		s += ", energy"
	var rd: int = f.act.dirI[READ]
	s += "; read: " + String(STYLES[rd & 7]) + ("" if ((rd >> 3) & 3) == 0 else ", " + String(TIMINGS[(rd >> 3) & 3])) + (", steady" if ((rd >> 5) & 1) == 1 else "")
	return s


## The feed line as an exchange starts: both windows.
static func report(S: SimState, ex) -> void:
	SimEvents.feed(S, "PRESSES", ex.A.name + ": " + describe(S, ex.A) + "  |  " + ex.D.name + ": " + describe(S, ex.D))
