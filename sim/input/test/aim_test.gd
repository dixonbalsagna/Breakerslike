extends SceneTree
## Headless checks for the aim helper (sim/input/aim.gd, docs/controls/agency-input.md 1b): the 8-sector snap, the dead zone,
## the keyboard's eight directions and a stick's every sector, the 12-tick latch, the director's snap, the toward, level and
## away pool, and determinism. Pure functions. From the repo root:
##   godot --headless --path . --script res://sim/input/test/aim_test.gd
## Exit 0 if every check passes.

var fails: int = 0
var checks: int = 0


func ok(c: bool, what: String) -> void:
	checks += 1
	if not c:
		fails += 1
		print("FAIL  ", what)


func _init() -> void:
	SimInputData.load_and_apply()
	_data()
	_sectors()
	_keyboard()
	_boundaries()
	_latch()
	_snap()
	_pool()
	_determinism()
	print("aim_test: %d checks, %d failed" % [checks, fails])
	quit(1 if fails > 0 else 0)


func _data() -> void:
	var p: Dictionary = SimAim.params()
	ok(absf(float(p["deadZone"]) - 0.35) < 1e-9 and p["latchTicks"] == 12 and p["snapMax"] == 1, "data: dead zone 0.35, latch 12 ticks, snap within 45 degrees")
	var saved = SimInputData.timing.get("aim", null)
	SimInputData.timing["aim"] = {"deadZone": 0.5, "latchTicks": 6, "snapMax": 2}
	var q: Dictionary = SimAim.params()
	ok(absf(float(q["deadZone"]) - 0.5) < 1e-9 and q["latchTicks"] == 6 and q["snapMax"] == 2, "data: a changed aim block is the helper's")
	if saved == null:
		SimInputData.timing.erase("aim")
	else:
		SimInputData.timing["aim"] = saved


func _sectors() -> void:
	# A full stick in each of the eight directions, y up.
	var dirs: Array = [[1.0, 0.0, 0], [0.7, 0.7, 1], [0.0, 1.0, 2], [-0.7, 0.7, 3], [-1.0, 0.0, 4], [-0.7, -0.7, 5], [0.0, -1.0, 6], [0.7, -0.7, 7]]
	for d in dirs:
		ok(SimAim.sector(d[0], d[1]) == d[2], "sector: (%.1f, %.1f) is sector %d" % [d[0], d[1], d[2]])
	# Bands of 45 degrees: 10 degrees off an axis is still the axis, 35 degrees is the diagonal.
	ok(SimAim.sector(1.0, 0.17) == SimAim.RIGHT, "sector: 10 degrees above right is right")
	ok(SimAim.sector(1.0, 0.70) == SimAim.UP_RIGHT, "sector: 35 degrees above right is up-right")
	ok(SimAim.sector(0.17, 1.0) == SimAim.UP, "sector: 10 degrees off up is up")
	ok(SimAim.sector(-1.0, -0.17) == SimAim.LEFT, "sector: 10 degrees below left is left")
	ok(SimAim.sector(-0.3, -1.0) == SimAim.DOWN, "sector: a stick mostly down is down")
	# The dead zone is a circle.
	ok(SimAim.sector(0.0, 0.0) == SimAim.NONE, "dead zone: centre is no aim")
	ok(SimAim.sector(0.34, 0.0) == SimAim.NONE and SimAim.sector(0.35, 0.0) == SimAim.NONE, "dead zone: up to 0.35 is no aim")
	ok(SimAim.sector(0.36, 0.0) == SimAim.RIGHT, "dead zone: past 0.35 aims")
	ok(SimAim.sector(0.24, 0.24) == SimAim.NONE and SimAim.sector(0.25, 0.25) == SimAim.UP_RIGHT, "dead zone: a circle, so a diagonal of 0.24 on each axis is inside and 0.25 (0.354 long) is out")
	ok(SimAim.sector(0.2, 0.0, 0.1) == SimAim.RIGHT, "dead zone: a caller's own dead zone applies")
	# Steps.
	ok(SimAim.step_x(0) == 1 and SimAim.step_y(0) == 0 and SimAim.step_x(3) == -1 and SimAim.step_y(3) == 1 and SimAim.step_y(6) == -1, "step: unit steps of the sectors, y up")
	ok(SimAim.step_x(SimAim.NONE) == 0 and SimAim.step_y(SimAim.NONE) == 0 and SimAim.step_x(9) == 0, "step: none is (0, 0)")


## A keyboard sends full deflection on each key held: eight directions and nothing else.
func _keyboard() -> void:
	var keys: Array = [[1, 0, 0], [1, 1, 1], [0, 1, 2], [-1, 1, 3], [-1, 0, 4], [-1, -1, 5], [0, -1, 6], [1, -1, 7]]
	for k in keys:
		ok(SimAim.sector(float(k[0]), float(k[1])) == k[2], "keyboard: keys (%d, %d) are sector %d" % [k[0], k[1], k[2]])
	var i := SimIntent.new()
	i.mx = 1.0
	i.my = 1.0
	ok(SimAim.of_intent(i) == SimAim.UP_RIGHT, "keyboard: of_intent reads an intent's stick")
	# The quantised stick values the layout sends (k / 127) read the same as the float stick.
	var q := SimIntent.new()
	q.mx = 127.0 / 127.0
	q.my = 30.0 / 127.0
	ok(SimAim.of_intent(SimIntent.canon(q)) == SimAim.RIGHT, "stick: a canonical intent (30 / 127 up on full right) is right")
	q.my = 60.0 / 127.0
	ok(SimAim.of_intent(SimIntent.canon(q)) == SimAim.UP_RIGHT, "stick: 60 / 127 up on full right is up-right")


## Exactly 22.5 degrees reads as the diagonal; just under is the axis. Mirror images agree.
func _boundaries() -> void:
	var t: float = SimAim.tan_22_5()
	ok(SimAim.sector(1.0, t) == SimAim.UP_RIGHT, "boundary: exactly 22.5 degrees is the diagonal")
	ok(SimAim.sector(1.0, t - 0.0001) == SimAim.RIGHT, "boundary: just under is the axis")
	ok(SimAim.sector(1.0, 1.0 / t - 0.0001) == SimAim.UP_RIGHT and SimAim.sector(1.0, 1.0 / t + 0.01) == SimAim.UP, "boundary: 67.5 degrees is where up-right becomes up")
	# Mirror symmetry in x and y over a sweep.
	var sym: bool = true
	for k in range(-20, 21):
		for m in range(-20, 21):
			var x: float = float(k) / 20.0
			var y: float = float(m) / 20.0
			var s: int = SimAim.sector(x, y)
			var sx: int = SimAim.sector(-x, y)
			if s != SimAim.NONE and (SimAim.step_y(s) != SimAim.step_y(sx) or SimAim.step_x(s) != -SimAim.step_x(sx)):
				sym = false
			if s != SimAim.NONE and SimAim.sector(x, -y) != SimAim.NONE and SimAim.step_x(s) != SimAim.step_x(SimAim.sector(x, -y)):
				sym = false
	ok(sym, "boundary: mirroring the stick in x or y mirrors the sector")


func _latch() -> void:
	var l: Dictionary = SimAim.new_latch()
	ok(SimAim.read(l, 100) == SimAim.NONE, "latch: nothing aimed")
	SimAim.update(l, 0.0, 0.0, 100)
	ok(SimAim.read(l, 100) == SimAim.NONE, "latch: a centred stick latches nothing")
	SimAim.update(l, 1.0, 0.0, 100)
	ok(SimAim.read(l, 100) == SimAim.RIGHT, "latch: an aim reads on its own tick")
	SimAim.update(l, 0.0, 0.0, 101)
	ok(SimAim.read(l, 105) == SimAim.RIGHT, "latch: letting go of the stick keeps the aim")
	ok(SimAim.read(l, 112) == SimAim.RIGHT, "latch: still there 12 ticks later")
	ok(SimAim.read(l, 113) == SimAim.NONE, "latch: gone after 13 ticks")
	SimAim.update(l, 0.1, 1.0, 110)
	ok(SimAim.read(l, 115) == SimAim.UP, "latch: a newer aim replaces the older one")
	SimAim.update(l, 0.2, 0.2, 111)
	ok(SimAim.read(l, 115) == SimAim.UP, "latch: a tremor inside the dead zone changes nothing")
	SimAim.update(l, -1.0, -1.0, 112)
	ok(SimAim.read(l, 112) == SimAim.DOWN_LEFT, "latch: the newest sample wins even a tick later")
	SimAim.clear(l)
	ok(SimAim.read(l, 112) == SimAim.NONE, "latch: clear forgets it")
	# A caller's own window.
	SimAim.update(l, 1.0, 0.0, 200)
	ok(SimAim.read(l, 205, {"latchTicks": 3}) == SimAim.NONE and SimAim.read(l, 203, {"latchTicks": 3}) == SimAim.RIGHT, "latch: a caller's latch window applies")
	# The state is two integers.
	ok(l.size() == 2 and l["sector"] is int and l["tick"] is int, "latch: the state is two integers")


func _snap() -> void:
	ok(SimAim.distance(0, 0) == 0 and SimAim.distance(0, 1) == 1 and SimAim.distance(0, 7) == 1 and SimAim.distance(0, 4) == 4 and SimAim.distance(2, 6) == 4 and SimAim.distance(1, 7) == 2, "snap: circular distances between sectors")
	ok(SimAim.distance(SimAim.NONE, 3) == 99, "snap: no aim is near nothing")
	# Candidates listed most dramatic first: building up-right, water right, crater down.
	var c: Array = [SimAim.UP_RIGHT, SimAim.RIGHT, SimAim.DOWN]
	ok(SimAim.snap(SimAim.UP_RIGHT, c) == 0, "snap: an exact aim takes its target")
	ok(SimAim.snap(SimAim.UP, c) == 0, "snap: up is 45 degrees from up-right, so the building")
	ok(SimAim.snap(SimAim.DOWN_RIGHT, c) == 1, "snap: down-right snaps to right (45 degrees), and the crater (down) is 45 too; the earlier wins")
	ok(SimAim.snap(SimAim.LEFT, c) == -1, "snap: left has nothing within 45 degrees")
	ok(SimAim.snap(SimAim.NONE, c) == -1, "snap: no aim means the director picks freely")
	ok(SimAim.snap(SimAim.UP_RIGHT, []) == -1, "snap: no candidates")
	ok(SimAim.snap(SimAim.LEFT, c, {"snapMax": 4}) == 2, "snap: a wider window takes the nearest (down, 2 sectors from left)")
	# The nearest beats an earlier one that is farther.
	ok(SimAim.snap(SimAim.RIGHT, [SimAim.UP_RIGHT, SimAim.RIGHT]) == 1, "snap: the nearer candidate beats an earlier, farther one")


func _pool() -> void:
	# Rival to the right: right is toward, left is away, vertical is level.
	ok(SimAim.pool(SimAim.RIGHT, 1) == "toward" and SimAim.pool(SimAim.LEFT, 1) == "away", "pool: rival on the right, right is toward and left is away")
	ok(SimAim.pool(SimAim.UP, 1) == "level" and SimAim.pool(SimAim.DOWN, 1) == "level", "pool: straight up or down is level")
	ok(SimAim.pool(SimAim.UP_RIGHT, 1) == "toward" and SimAim.pool(SimAim.DOWN_LEFT, 1) == "away", "pool: a diagonal counts by its horizontal part")
	# Rival to the left: mirrored (the wrap's shortest arc).
	ok(SimAim.pool(SimAim.RIGHT, -1) == "away" and SimAim.pool(SimAim.LEFT, -1) == "toward" and SimAim.pool(SimAim.UP_LEFT, -1) == "toward", "pool: rival on the left, everything mirrors")
	ok(SimAim.pool(SimAim.NONE, 1) == "level", "pool: no aim is level")


func _determinism() -> void:
	var a: Array = []
	var b: Array = []
	for k in range(-10, 11):
		for m in range(-10, 11):
			a.append(SimAim.sector(float(k) / 10.0, float(m) / 10.0))
			b.append(SimAim.sector(float(k) / 10.0, float(m) / 10.0))
	ok(a == b, "determinism: the same stick, the same sector")
	var l1: Dictionary = SimAim.new_latch()
	var l2: Dictionary = SimAim.new_latch()
	for t in range(40):
		var x: float = sin(float(t)) if t % 3 == 0 else 0.0
		SimAim.update(l1, x, 1.0 - float(t % 5) * 0.5, t)
		SimAim.update(l2, x, 1.0 - float(t % 5) * 0.5, t)
	ok(str(l1) == str(l2) and SimAim.read(l1, 41) == SimAim.read(l2, 41), "determinism: the same feed, the same latch")
