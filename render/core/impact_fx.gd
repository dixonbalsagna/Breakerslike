class_name ImpactFx
extends RefCounted
## Render-side live effects for World's events (docs/architecture/fx-events.md). A crater throws ejecta, raises dust
## on its rim and sends a shock ring across the ground. A scorch sample heats its groove, drawn as a glow by the
## terrain shader from `heat`: hotter and longer-lasting for stronger beams. It also sheds embers. A splash on a water
## surface leaves ripple rings, and a fighter skimming low over water throws spray, so a skim reads as a skipping
## stone. Cosmetic only: its random numbers come from its own streams seeded from the match seed. Nothing here is
## needed to rebuild the world: the persistent marks (bowls, char, water) come from state (ground_field.gd).
## Reads the sim only; never writes it.

const CAP := 1200
const HEAT_TAU := 1.6          # seconds for a groove's glow to fall to 1/e

var parts: Array = []          # SimFxView.Part, the same records the reference consumer uses
var heat := PackedFloat32Array()
var heat_changed: bool = false   # set when heat moves; the renderer clears it after uploading
var _hot: bool = false
var _ticks: int = 0
var _re: SimRng
var _rm: SimRng
var _rw: SimRng


func _init() -> void:
	heat.resize(SimConst.NC)
	reset(1)


func reset(seed: int) -> void:
	parts.clear()
	heat.fill(0.0)
	heat_changed = true
	_hot = false
	_ticks = 0
	_re = SimRng.new(SimRng.deriveSeed(seed, "render.ejecta"))
	_rm = SimRng.new(SimRng.deriveSeed(seed, "render.embers"))
	_rw = SimRng.new(SimRng.deriveSeed(seed, "render.water"))


## One tick's events, in order (after the reference consumer has seen them).
func consume(S: SimState, events: Array) -> void:
	var dt: float = 0.0
	var frozen: bool = true
	for e in events:
		match e.type:
			"crater":
				_crater(e)
			"scorch":
				_scorch(e)
			"splash":
				_splash(S, e)
			"tick":
				dt = e.dt
				frozen = e.frozen
	if not frozen:
		_wake(S)
		_cool(dt)
	_step(S, dt * 0.1 if frozen else dt)


func _crater(e) -> void:
	var E: float = e.energy
	var col: String = RenderLook.CRATER_DESERT if WorldBiomes.biomeAt(e.x) == "desert" else "#6e5c46"
	var sp: float = 260.0 + 90.0 * sqrt(E)
	for k in range(clampi(int(3.0 + E * 2.0), 3, 30)):
		var off: float = _re.range_(-0.6, 0.6) * e.r
		var p := _part("deb", e.x + off, e.y, col)
		p.vx = (1.0 if off >= 0.0 else -1.0) * _re.range_(0.3, 1.0) * sp
		p.vy = _re.range_(0.6, 1.4) * sp
		p.grav = 900.0
		p.life = _re.range_(0.9, 1.8)
		p.size = _re.range_(3.0, 7.0 + sqrt(E))
	for k in range(clampi(int(4.0 + e.r / 20.0), 4, 18)):
		var side: float = 1.0 if k % 2 == 0 else -1.0
		var p := _part("dust", e.x + side * e.r * _re.range_(0.8, 1.25), e.y + e.rim, "#9b8f7e")
		p.vx = side * _re.range_(20.0, 90.0)
		p.vy = _re.range_(20.0, 100.0)
		p.life = _re.range_(1.0, 2.2)
		p.size = _re.range_(18.0, 36.0)
		p.drag = 0.02
	var s := _part("shock", e.x, e.y + 2.0, "#f2e6c9")
	s.r = 0.3 * e.r
	s.gr = 3.2 * e.r
	s.life = 0.45
	if e.cause == "beam":
		_heat_at(e.x, e.r, minf(1.6, 0.6 + 0.08 * E))


func _scorch(e) -> void:
	var P: float = e.power
	var hw: float = e.w * 0.5
	_heat_at(e.x, hw, minf(1.6, 0.35 + 0.28 * P))
	var col: String = "#ffe08a" if P > 2.5 else "#ff9a3c"
	for k in range(1 + int(P * 0.8)):
		var p := _part("spark", e.x + _rm.range_(-0.5, 0.5) * hw, e.y + 3.0, col)
		p.vx = _rm.range_(-60.0, 60.0)
		p.vy = _rm.range_(140.0, 240.0 + 70.0 * P)
		p.grav = 120.0
		p.life = _rm.range_(0.4, 0.9)
		p.size = _rm.range_(2.0, 3.0)


## A splash that lands on a water surface leaves two ripple rings on it.
func _splash(S: SimState, e) -> void:
	var s: float = WorldWater.surfaceAt(S, e.x)
	if s == WorldWater.DRY or absf(e.y - s) > 60.0:
		return
	for k in range(2):
		var p := _part("ripple", e.x, s + 1.0, "#e8f6ff")
		p.r = 4.0
		p.gr = (70.0 + e.n * 5.0) * (1.0 if k == 0 else 0.6)
		p.life = 1.0 + 0.3 * k


## A launched fighter flying fast just over water throws spray behind it, and marks the surface every few ticks.
func _wake(S: SimState) -> void:
	_ticks += 1
	for f in S.fighters:
		if f.state != "launched" or absf(f.vx) < 400.0:
			continue
		var s: float = WorldWater.surfaceAt(S, f.x)
		if s == WorldWater.DRY or f.y - s > 30.0 or f.y - s < -10.0:
			continue
		var back: float = -1.0 if f.vx > 0.0 else 1.0
		for k in range(2):
			var p := _part("splash", f.x, s, "#e8f6ff")
			p.vx = back * _rw.range_(60.0, 220.0)
			p.vy = _rw.range_(150.0, 420.0)
			p.grav = 1200.0
			p.life = _rw.range_(0.5, 0.9)
			p.size = _rw.range_(2.0, 4.0)
		if _ticks % 3 == 0:
			var r := _part("ripple", f.x, s + 1.0, "#e8f6ff")
			r.r = 3.0
			r.gr = 55.0
			r.life = 0.8


func _heat_at(x: float, hw: float, h0: float) -> void:
	var nc: int = SimConst.NC
	var c0: int = int(floor(SimWrap.wrap(x) / SimConst.COL))
	var n: int = int(ceil(hw / SimConst.COL))
	for k in range(-n, n + 1):
		var u: float = absf(float(k) * SimConst.COL) / hw
		if u >= 1.0:
			continue
		var i: int = (c0 + k + nc) % nc
		var v: float = h0 * (1.0 - u * u)
		if v > heat[i]:
			heat[i] = v
	heat_changed = true
	_hot = true


func _cool(dt: float) -> void:
	if not _hot:
		return
	var f: float = exp(-dt / HEAT_TAU)
	var any: bool = false
	for i in range(SimConst.NC):
		var v: float = heat[i]
		if v > 0.0:
			v *= f
			if v < 0.02:
				v = 0.0
			else:
				any = true
			heat[i] = v
	heat_changed = true
	_hot = any


func _part(type: String, x: float, y: float, col: String) -> SimFxView.Part:
	var p := SimFxView.Part.new()
	p.type = type
	p.x = SimWrap.wrap(x)
	p.y = y
	p.col = col
	if parts.size() < CAP:
		parts.append(p)
	return p


## The reference consumer's particle step (sim/core/view/fx.gd), for these particles.
func _step(S: SimState, dt: float) -> void:
	for i in range(parts.size() - 1, -1, -1):
		var p = parts[i]
		p.age += dt
		if p.age >= p.life:
			parts[i] = parts[parts.size() - 1]
			parts.pop_back()
			continue
		p.vy -= p.grav * dt
		if p.drag != 0.0:
			var d: float = pow(1.0 - p.drag, dt * 60.0)
			p.vx *= d
			p.vy *= d
		p.x = SimWrap.wrap(p.x + p.vx * dt)
		p.y += p.vy * dt
		p.r += p.gr * dt
		if p.type == "deb":
			var g: float = WorldTerrain.groundY(S, p.x)
			if p.y < g:
				p.y = g
				p.vy *= -0.3
				p.vx *= 0.6
