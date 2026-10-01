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
