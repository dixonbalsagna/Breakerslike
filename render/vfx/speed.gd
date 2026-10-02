class_name VfxSpeed
extends RefCounted
## Speed lines alone (docs/vfx/react-plan.md; rule-of-cool row 11, impact treatment B, Orb's pick): on every launch and every
## heavy that lands, a 6-tick streak of thin lines running toward the hit, with no cut. It is meant for about 20 hits a minute
## (8 landed heavies and 12 launches in QA's reading), so it is quiet: seven thin lines at half strength that never cover a
## fighter (they stop short of the hit point), at most four alive, and a minimum gap between two. The panel cut-in is Camera's
## and UI's, not this. Presentation only: it reads two events the sim already sends and writes nothing.
##
## The clock is the host's tick and it runs on every tick, a hit-stop's included (a landed heavy is followed by a few frozen
## ticks, and the streak should play through them). Everything drawn is a function of a streak's age, so a frame between two
## ticks is interpolated.

## One streak: where it points, and its lines.
class Streak:
	var x: float = 0.0          # the hit point (wrapped world x) and height
	var y: float = 0.0
	var dx: float = 1.0         # unit direction of travel, toward the hit
	var dy: float = 0.0
	var z: float = 0.0          # the hit fighter's depth
	var slot: int = -1          # the fighter hit (for the dedupe)
	var age: float = 0.0        # ticks played
	var lines := PackedFloat32Array()   # per line: offset across (in fighter heights), length, gap before the hit, start delay in ticks

const LINE_STRIDE := 4

var streaks: Array = []         # Streak, oldest first
var made: int = 0               # counters for the tests
var skipped: int = 0
var _tick: int = 0
var _last_tick: int = -1000
var _last_hit := PackedInt32Array([-1000, -1000])   # per slot: the tick of the last streak on that fighter
var _rng: SimRng


func reset(seed: int) -> void:
	streaks.clear()
	made = 0
	skipped = 0
	_tick = 0
	_last_tick = -1000
	_last_hit = PackedInt32Array([-1000, -1000])
	_rng = SimRng.new(SimRng.deriveSeed(seed, "vfx.speed"))
	cur_n = -1
	ended_tick = -1
	excl = false
	streaked = false
	launched = false
	launch_tick = -1000
	pend = {}
	suppressed = 0
	capped = 0
	cur_tag = ""
	VfxReact.warm()


## Once per consume(): the clock. Runs on frozen ticks too.
func step() -> void:
	_tick += 1
	var i: int = 0
	while i < streaks.size():
		var s: Streak = streaks[i]
		s.age += 1.0
		if s.age >= VfxReact.p("speed", "ticks"):
			streaks.remove_at(i)
		else:
			i += 1


## A streak at (x, y) travelling along (dx, dy) toward it, on fighter `slot` (the one hit), at depth z.
func add(x: float, y: float, dx: float, dy: float, slot: int, z: float) -> void:
	var l: float = sqrt(dx * dx + dy * dy)
	if l < 1e-4:
		dx = 1.0
		dy = 0.0
		l = 1.0
	# One streak a hit: a heavy that launches sends both events in the same tick or two.
	if slot >= 0 and slot < 2 and _tick - _last_hit[slot] < int(VfxReact.p("speed", "dedupe_ticks")):
		skipped += 1
		return
	if _tick - _last_tick < int(VfxReact.p("speed", "min_gap_ticks")) or streaks.size() >= int(VfxReact.p("speed", "alive_max")):
		skipped += 1
		return
	var s := Streak.new()
	s.x = x
	s.y = y
	s.dx = dx / l
	s.dy = dy / l
	s.z = z
	s.slot = slot
	var n: int = int(VfxReact.p("speed", "lines"))
	s.lines.resize(n * LINE_STRIDE)
	var spread: float = VfxReact.p("speed", "spread_bh")
	for k in range(n):
		var o: int = k * LINE_STRIDE
		# Evenly spread across the width, a little jittered, so the set reads as a sheet and not a clump.
		s.lines[o] = ((float(k) + _rng.range_(0.15, 0.85)) / float(n) * 2.0 - 1.0) * spread
		s.lines[o + 1] = _rng.range_(VfxReact.p("speed", "len_min_bh"), VfxReact.p("speed", "len_max_bh"))
		s.lines[o + 2] = _rng.range_(VfxReact.p("speed", "gap_min_bh"), VfxReact.p("speed", "gap_max_bh"))
		s.lines[o + 3] = _rng.range_(0.0, 1.5)
	streaks.append(s)
	made += 1
	_last_tick = _tick
	if slot >= 0 and slot < 2:
		_last_hit[slot] = _tick


# ------------------------------------------------------------------------------------------------ one streak an exchange
## Game Design's rule (rule-of-cool.md row 11, balance-targets.md section 22), widened on the EP's word (Orb asked for flashier combo
## trading, 2026-10-02): an exchange has a streak on its launch if it has one AND on its last landed heavy, a heavy that is not the blow
## that launched (a follow-up after the launch keeps its own); never on a hit that gets a panel (a signature, a finisher, a crippling
## blow, the KO, a clash won, a riposte that launches). Two streaks an exchange at most. The exchange is read from `S.dirS.ex` (its index `n`, its `kind` and `tag`); a heavy waits for the end
## of its exchange to learn whether it was the last (a launch cancels it), and fires after 45 ticks at the latest.
const PENDING_TICKS: int = 45
const BLOW_TICKS: int = 8        # a heavy this close to a launch is the same blow
const CONTEXT_GRACE: int = 2     # an exchange that has just ended still owns the events of its last ticks

var cur_n: int = -1              # the exchange index last seen
var ended_tick: int = -1         # the tick it was seen ending, -1 while it runs
var excl: bool = false           # this exchange's hit gets a panel
var cur_tag: String = ""         # the running exchange's tag (RIPOSTE, HEAVY CLASH, ...)
var streaked: bool = false       # this exchange has had its heavy's streak
var launched: bool = false       # this exchange has had its launch's streak
var launch_tick: int = -1000     # when (the host's tick): a heavy within BLOW_TICKS of it is the blow that launched
var pend: Dictionary = {}        # the last landed heavy, waiting: x, y, dx, dy, slot, z, tick
var suppressed: int = 0          # hits left without a streak because they get a panel (the tests)
var capped: int = 0              # hits left without one because the exchange already had its streak


func _in_exchange() -> bool:
	return cur_n >= 0 and (ended_tick < 0 or _tick - ended_tick <= CONTEXT_GRACE)


func _begin(n: int) -> void:
	_flush()
	cur_n = n
	ended_tick = -1
	excl = false
	streaked = false
	launched = false
	launch_tick = -1000
	cur_tag = ""
	pend = {}


func _flush() -> void:
	if not pend.is_empty() and not excl and not streaked:
		add(pend.x, pend.y, pend.dx, pend.dy, pend.slot, pend.z)
		streaked = true
	pend = {}


## Once a tick, after step(): follow the running exchange (a new one, an end, a panel kind) and fire a waiting heavy that is due.
func observe(S: SimState) -> void:
	var ex = S.dirS.ex
	if ex != null:
		if int(ex.n) != cur_n or ended_tick >= 0:
			_begin(int(ex.n))
		var tag: String = String(ex.tag)
		cur_tag = tag
		# A signature gets a panel whole; a riposte only if it launches (offer_launch), a clash only if it is won (a decisive event).
		if ex.kind == "sig":
			excl = true
			pend = {}
	elif cur_n >= 0 and ended_tick < 0:
		ended_tick = _tick
		_flush()
	if not pend.is_empty() and _tick - int(pend.tick) >= PENDING_TICKS:
		_flush()


## A hit that gets a panel (limb_break, ko, finisher_start, a decisive clash or beam): no streak for this exchange.
func panel() -> void:
	if _in_exchange():
		excl = true
		pend = {}


## A launch: it is the exchange's launch streak, and cancels the waiting heavy that is the same blow.
func offer_launch(x: float, y: float, dx: float, dy: float, slot: int, z: float) -> void:
	if _in_exchange():
		if cur_tag.begins_with("RIPOSTE") and not excl:
			excl = true          # a riposte that launches gets a panel
			pend = {}
		if excl:
			suppressed += 1
			return
		if launched:
			capped += 1
			return
		# The heavy that sent him flying is this streak; an earlier heavy in the exchange keeps its own.
		if not pend.is_empty() and _tick - int(pend.tick) <= BLOW_TICKS:
			pend = {}
		launched = true
		launch_tick = _tick
	add(x, y, dx, dy, slot, z)


## A landed heavy: it waits for the exchange's end and the last one gets a streak, unless it is the blow that launched.
func offer_heavy(x: float, y: float, dx: float, dy: float, slot: int, z: float) -> void:
	if _in_exchange():
		if excl:
			suppressed += 1
			return
		if streaked or (launched and _tick - launch_tick <= BLOW_TICKS):
			capped += 1
			return
		pend = {"x": x, "y": y, "dx": dx, "dy": dy, "slot": slot, "z": z, "tick": _tick}
		return
	add(x, y, dx, dy, slot, z)
