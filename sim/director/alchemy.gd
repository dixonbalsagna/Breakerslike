class_name DirAlchemy
## The fight alchemist, stage 1 (docs/director/agency-evidence.md section 3; docs/design/agency-pass.md section 2): the
## press log. Every attack press of each fighter is kept with what it carried: weight, family, direction, tilt and
## rhythm. This stage records and reports (one feed line as an exchange starts). No string is chosen from it yet; the
## earned launch reads one thing: how the press that started the phrase was made (held, or with a stick direction).
##
## The log lives in the director's per-fighter integers (f.act.dirI), after DirInterrupt's: a ring of the last RING
## presses (one packed integer each), their ticks, and the count of presses so far.

const RING: int = 20                         # presses kept: the running mix
const WINDOW: int = 5                        # the alchemist's window: the last five (Orb, questionnaire 14)
const LIFE: int = 90                         # ticks a press stays in the window
const MASH_TICKS: int = 20                   # three presses inside this many ticks are a mash
const TIMED_TICKS: int = 4                   # a press within this many ticks of one of his own blows landing is timed
const TILT_DEAD: float = 0.3                 # the stick inside this is no tilt
const P0: int = DirInterrupt.N               # the ring of packed presses ...
const T0: int = DirInterrupt.N + RING        # ... their ticks ...
const COUNT: int = DirInterrupt.N + 2 * RING # ... and how many presses he has made
const SIZE: int = DirInterrupt.N + 2 * RING + 1
const PLAIN: int = 0
const HELD: int = 1
const MASHED: int = 2
const TIMED: int = 3
const RHYTHM: Array = ["", "held", "mashed", "timed"]
const DIRS: Array = ["away", "level", "toward"]
const KINDS: Array = ["a flurry", "a blur combo", "a blur combo", "a bruiser string", "a bruiser string", "a power blow"]   # by heavies in the last five; the recipes are still to be ruled
const INTENT: int = 1 << 10                  # the press carries launch intent: a stick direction (a human), or the AI's choice


static func _size(f) -> void:
	DirInterrupt.gi(f, 0)   # DirInterrupt sizes and seeds its own part first
	if f.act.dirI.size() < SIZE:
		f.act.dirI.resize(SIZE)


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
	var rhythm: int = PLAIN
	var timed: bool = _timed(S, f)
	# The flow count (agency-pass.md section 2): a timed press adds 1, up to FLOW_MAX; a press off the beat sets it back
	# to 0 (and so do FLOW_LIFE ticks without a press: tick). Nothing reads it yet but the HUD and QA.
	if DirInterrupt.on():
		SimAct.setFlow(S, f, mini(FLOW_MAX, f.act.flow + 1) if timed else 0)
	if timed:
		rhythm = TIMED
	elif n >= 2 and S.tick - f.act.dirI[T0 + (n - 2) % RING] <= MASH_TICKS:
		rhythm = MASHED
	# Launch intent: a human's is his stick (any direction past the dead zone). The AI's stick is its flight path, so its
	# intent is a number: the chance its heavy is thrown to launch (ai.json launchIntent), one draw per heavy press.
	var intent: bool = tilt != 0
	if f.ai != null:
		intent = weight == SimAct.HEAVY and S.rng.next() < float(DirAI.lv().get("launchIntent", 0.0))
		if weight == SimAct.HEAVY and S.rng.next() < float(DirAI.lv().get("heldHeavy", 0.0)):
			rhythm = HELD   # ... and the chance it charges the heavy (heldHeavy)
	f.act.dirI[P0 + n % RING] = weight | (family << 1) | (dir << 2) | (tilt << 4) | (rhythm << 8) | (INTENT if intent else 0)
	f.act.dirI[T0 + n % RING] = S.tick
	f.act.dirI[COUNT] = n + 1


const FLOW_MAX: int = 5     # the flow count's ceiling
const FLOW_LIFE: int = 90   # ticks without a press after which it lapses


## Once a live tick: a fighter's flow lapses FLOW_LIFE ticks after his last press.
static func tick(S: SimState) -> void:
	for f in S.fighters:
		if f.act.flow <= 0:
			continue
		_size(f)
		var n: int = f.act.dirI[COUNT]
		if n == 0 or S.tick - f.act.dirI[T0 + (n - 1) % RING] > FLOW_LIFE:
			SimAct.setFlow(S, f, 0)


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


## True when one of f's own blows lands within TIMED_TICKS of now (the beat list knows every contact tick).
static func _timed(S: SimState, f) -> bool:
	var ex = S.dirS.ex
	if ex == null or (f != ex.A and f != ex.D):
		return false
	var role: String = "A" if f == ex.A else "D"
	for b in ex.beats:
		if (b.op == "strike" and b.args.a == role) or (b.op == "chainStrike" and role == "A"):
			if absf(b.t - ex.t) * DirData.TICKS_PER_SEC <= float(TIMED_TICKS) + 0.5:
				return true
	return false


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


## One fighter's window in words: "L L H (a blur combo) toward, mashed".
static func describe(S: SimState, f) -> String:
	var w: Array = window(S, f)
	if w.is_empty():
		return "nothing pressed"
	var parts: PackedStringArray = []
	var heavies: int = 0
	for p in w:
		parts.append("H" if (p & 1) == 1 else "L")
		heavies += p & 1
	var last: int = w[w.size() - 1]
	var s: String = " ".join(parts)
	if w.size() == WINDOW:
		s += " (" + KINDS[heavies] + ")"
	if (last & INTENT) != 0:
		s += ", with the stick"
	s += " " + DIRS[(last >> 2) & 3]
	var r: int = (last >> 8) & 3
	if r != PLAIN:
		s += ", " + RHYTHM[r]
	if ((last >> 1) & 1) == 1:
		s += ", energy"
	return s


## The feed line as an exchange starts: both windows. Read-only: the director decides nothing from it yet.
static func report(S: SimState, ex) -> void:
	SimEvents.feed(S, "PRESSES", ex.A.name + ": " + describe(S, ex.A) + "  |  " + ex.D.name + ": " + describe(S, ex.D))
