class_name VfxWater
extends RefCounted
## Dramatic water (docs/vfx/water-plan.md): the spray of a skip, the crown and column of a plunge, a beam raking the sea,
## and the wake behind a fast low flight. It turns the sim's `splash`, `skim` and `beamSplash` events and the fighters'
## own state into debris bits (render/vfx/debris.gd: cel spray streaks and foam puffs in Art's ocean colours) and scales
## them with speed and the power tier. The numbers are data (data/vfx/water.json; missing keys fall back to the defaults
## below). Presentation only: it reads the sim and never writes it, and draws from the debris pool's own streams.

const DEFAULTS: Dictionary = {
	"scale": {"ref_speed": 4000.0, "min": 0.45, "max": 3.0, "tier_gain": 0.25},
	"skim": {"streaks_base": 14, "streaks_per_scale": 10, "elev_min_deg": 15.0, "elev_max_deg": 55.0, "len_min": 40.0, "len_max": 110.0, "speed_frac_min": 0.12, "speed_frac_max": 0.38, "speed_cap": 2600.0, "life_min": 0.6, "life_max": 1.2, "tail_puffs_base": 4, "tail_puffs_per_scale": 3, "skip_decay": 0.85},
	"plunge": {"height_per_speed": 0.25, "height_min": 300.0, "height_max": 3500.0, "streaks_base": 22, "streaks_per_scale": 18, "cone_deg": 26.0, "column_puffs_base": 6, "column_puffs_per_scale": 5, "rebound_delay": 0.28, "rebound_share": 0.45},
	"beam": {"throw_chance": 0.3, "throws_per_tick": 4, "streaks_per_throw": 4, "power_gain": 0.35, "puff_every": 2, "forward_deg_min": 20.0, "forward_deg_max": 60.0},
	"wake": {"min_speed": 2200.0, "max_height": 160.0, "streaks_per_tick": 2, "puff_every": 4},
	"caps": {"spray_alive": 260, "per_tick": 60},
}

static var _data: Dictionary = {}
static var _loaded: bool = false

var debris: VfxDebris
var skims: int = 0               # counters for the tests
var plunges: int = 0
var beam_hits: int = 0
var wakes: int = 0
var _tick_n: int = 0             # spray spawned this tick (budget caps.per_tick)
var _wake_t: int = 0
var _beam_tick: int = -1
var _beam_n: int = 0
var _beam_throws: int = 0


static func warm() -> void:
	if _loaded:
		return
	_loaded = true
	var path := "res://data/vfx/water.json"
	if FileAccess.file_exists(path):
		var v = JSON.parse_string(FileAccess.get_file_as_string(path))
		if v is Dictionary:
			_data = v


## One number: group.key from the data file, else the default.
static func p(group: String, key: String) -> float:
	warm()
	var g = _data.get(group)
	if g is Dictionary and g.has(key):
		return float(g[key])
	return float(DEFAULTS[group][key])


func reset() -> void:
	skims = 0
	plunges = 0
	beam_hits = 0
	wakes = 0
	_tick_n = 0
	_wake_t = 0
	_beam_tick = -1
	_beam_n = 0
	_beam_throws = 0


## Called once per tick before the events: the spawn budget starts again.
func begin_tick() -> void:
	_tick_n = 0


## Size of an effect from speed and the power tier: 1 at the reference speed and tier 1.
static func scale_of(speed: float, tier: float) -> float:
	var s: float = speed / p("scale", "ref_speed")
	s *= 1.0 + p("scale", "tier_gain") * maxf(tier - 1.0, 0.0)
	return clampf(s, p("scale", "min"), p("scale", "max"))


func _q() -> float:
	return VfxLook.QUALITY_SHARDS[clampi(debris.quality, 0, 2)] * (0.5 if debris.reduced else 1.0)


func _room() -> bool:
	return _tick_n < int(p("caps", "per_tick"))


## The fighter closest to x (by the shortest arc), the one a splash at x belongs to.
static func nearest_fighter(S: SimState, x: float):
	var best = null
	var bd: float = 1e30
	for f in S.fighters:
		var d: float = absf(SimWrap.sdx(f.x, x))
		if d < bd:
			bd = d
			best = f
	return best


# ------------------------------------------------------------------------------------------------------------ skip

## The sim's skim event: a fighter skipped off the water at (x, y = the surface) at raw speed spd, the n-th skip. A fan of
## spray streaks thrown up and forward along the travel, and a tail of foam thrown up and back; later skips are smaller.
func skim(S: SimState, x: float, y: float, spd: float, n: int) -> void:
	skims += 1
	var f = nearest_fighter(S, x)
	var dir: float = 1.0 if f == null or f.vx >= 0.0 else -1.0
	var tier: float = f.tier if f != null else 1.0
	var s: float = scale_of(spd, tier) * pow(p("skim", "skip_decay"), maxf(float(n) - 1.0, 0.0))
	var q: float = _q()
	var cnt: int = int(round((p("skim", "streaks_base") + p("skim", "streaks_per_scale") * s) * q))
	var cap: float = p("skim", "speed_cap")
	for k in range(cnt):
		var elev: float = deg_to_rad(lerpf(p("skim", "elev_min_deg"), p("skim", "elev_max_deg"), debris._rd.next()))
		var sp: float = minf(spd * lerpf(p("skim", "speed_frac_min"), p("skim", "speed_frac_max"), debris._rd.next()), cap) * (0.6 + 0.4 * s)
		var life: float = lerpf(p("skim", "life_min"), p("skim", "life_max"), debris._rd.next())
		var len: float = lerpf(p("skim", "len_min"), p("skim", "len_max"), debris._rd.next()) * (0.6 + 0.5 * s)
		_streak(x + dir * debris._rd.range_(0.0, 160.0) * s, y, dir * cos(elev) * sp, sin(elev) * sp * 1.3, len, life, y)
	# The tail: foam thrown up and back where the fighter left the water.
	var np: int = int(round((p("skim", "tail_puffs_base") + p("skim", "tail_puffs_per_scale") * s) * q))
	for k in range(np):
		var sz: float = debris._rd.range_(80.0, 240.0) * (0.5 + 0.5 * s)
		_foam(x - dir * debris._rd.range_(0.0, 220.0) * s, y + 10.0, -dir * debris._rd.range_(100.0, 500.0) * s, debris._rd.range_(300.0, 900.0) * s, sz, debris._rd.range_(0.9, 1.6))
	debris._ring(x, y + 20.0, RenderLook.Z_BEAMS + 6.0, 40.0 * s, 700.0 * s, 0.3)


# ---------------------------------------------------------------------------------------------------------- plunge

## A fighter went into the water or a body struck the sea (a `splash` event of 10 or more droplets: 12 a plunge, 14 a
## ground impact at sea). A crown of spray in a narrow cone and a column of foam rising from the impact, then a smaller jet
## when the cavity closes. Smaller splashes (a skip's 8, a beam's 3) are not drawn here.
func plunge(S: SimState, x: float, y: float, n: int) -> void:
	plunges += 1
	var f = nearest_fighter(S, x)
	var speed: float = 2000.0
	var tier: float = 1.0
	if f != null:
		speed = maxf(Vector2(f.vx, f.vy).length(), 600.0)
		tier = f.tier
	var s: float = scale_of(speed, tier)
	var q: float = _q()
	var H: float = clampf(speed * p("plunge", "height_per_speed") * (0.7 + 0.3 * s), p("plunge", "height_min"), p("plunge", "height_max"))
	_column(x, y, s, H, q, 1.0)
	var j := VfxDebris.Job.new()
	j.at = debris.now + p("plunge", "rebound_delay")
	j.kind = "plunge2"
	j.a = {"x": x, "y": y, "s": s, "H": H * p("plunge", "rebound_share")}
	debris.jobs.append(j)
	debris._ring(x, y + 30.0, RenderLook.Z_BEAMS + 6.0, 60.0 * s, 950.0 * s, 0.4)
	debris._ring(x, y + 30.0, RenderLook.Z_BEAMS + 7.0, 30.0 * s, 650.0 * s, 0.55)


func rebound(a: Dictionary) -> void:
	_column(a.x, a.y, a.s * 0.7, a.H, _q(), 0.7)


## A column of spray streaks in a cone and foam puffs rising to height H.
func _column(x: float, y: float, s: float, H: float, q: float, share: float) -> void:
	var cnt: int = int(round((p("plunge", "streaks_base") + p("plunge", "streaks_per_scale") * s) * q * share))
	var cone: float = deg_to_rad(p("plunge", "cone_deg"))
	var vmax: float = sqrt(2.0 * 1200.0 * H)
	for k in range(cnt):
		var a: float = deg_to_rad(90.0) + debris._rd.range_(-cone, cone)
		var sp: float = vmax * debris._rd.range_(0.45, 1.0)
		_streak(x + debris._rd.range_(-60.0, 60.0) * s, y, cos(a) * sp, sin(a) * sp, debris._rd.range_(50.0, 130.0) * (0.6 + 0.5 * s), debris._rd.range_(0.9, 1.7), y)
	var np: int = int(round((p("plunge", "column_puffs_base") + p("plunge", "column_puffs_per_scale") * s) * q * share))
	for k in range(np):
		var fr: float = (float(k) + debris._rd.next()) / float(maxi(np, 1))
		_foam(x + debris._rd.range_(-80.0, 80.0) * s, y + 20.0, debris._rd.range_(-160.0, 160.0), (0.35 + 0.65 * fr) * vmax * 0.5, debris._rd.range_(120.0, 320.0) * (0.5 + 0.5 * s), debris._rd.range_(1.0, 2.0))


# ------------------------------------------------------------------------------------------------------------ beam

## A beam sample low over the sea (beamSplash: x). One burst per beam per tick however many samples it has (a beam has up to
## a dozen), thrown forward along its direction and scaled by its power. dir: +1 or -1 along x; power: the beam's pw.
func beam(S: SimState, x: float, power: float, dir: float, tick: int) -> void:
	if tick != _beam_tick:
		_beam_tick = tick
		_beam_n = 0
	# A beam samples tens of times a tick; only a share of the samples throws, and a tick throws at most a few times, so a
	# long beam fills the spray with fresh streaks along its length instead of exhausting the pool in the first tenth of a second.
	beam_hits += 1
	if debris._rd.next() >= p("beam", "throw_chance") or _beam_n >= int(p("beam", "throws_per_tick")):
		return
	_beam_n += 1
	var every: int = maxi(int(p("beam", "puff_every")), 1)
	var q: float = _q()
	var s: float = clampf(0.6 + p("beam", "power_gain") * power, 0.6, 2.6)
	var sea: float = WorldWater.surfaceAt(S, x)
	if sea == WorldWater.DRY:
		sea = 0.0
	for k in range(int(round(p("beam", "streaks_per_throw") * q + 0.5))):
		var elev: float = deg_to_rad(lerpf(p("beam", "forward_deg_min"), p("beam", "forward_deg_max"), debris._rd.next()))
		var sp: float = debris._rd.range_(700.0, 2000.0) * s
		_streak(x + debris._rd.range_(-80.0, 80.0), sea, dir * cos(elev) * sp * 0.6, sin(elev) * sp, debris._rd.range_(70.0, 170.0) * (0.6 + 0.4 * s), debris._rd.range_(0.7, 1.4), sea)
	_beam_throws += 1
	if _beam_throws % every == 0:
		_foam(x, sea + 15.0, dir * debris._rd.range_(80.0, 400.0), debris._rd.range_(300.0, 800.0) * s, debris._rd.range_(60.0, 150.0) * s, debris._rd.range_(0.9, 1.5))


# ------------------------------------------------------------------------------------------------------------ wake

## Once a tick: a fast fighter low over water leaves a wake, two spray streaks thrown back and up, and a foam puff now and
## then. Scaled by speed. Free flight and launches alike.
func wake(S: SimState) -> void:
	_wake_t += 1
	for f in S.fighters:
		if f.hidden:
			continue
		var speed: float = Vector2(f.vx, f.vy).length()
		if speed < p("wake", "min_speed") or absf(f.vx) < 0.5 * speed:
			continue
		var surf: float = WorldWater.surfaceAt(S, f.x)
		if surf == WorldWater.DRY or f.y - surf > p("wake", "max_height") or f.y < surf - 40.0:
			continue
		wakes += 1
		var back: float = -1.0 if f.vx > 0.0 else 1.0
		var s: float = scale_of(speed, f.tier)
		var q: float = _q()
		for k in range(int(p("wake", "streaks_per_tick"))):
			var kp: float = debris._rd.next()
			var sp: float = debris._rd.range_(300.0, 900.0) * (0.6 + 0.4 * s)
			var el: float = deg_to_rad(debris._rd.range_(25.0, 70.0))
			if kp < q:
				_streak(f.x, surf, back * cos(el) * sp, sin(el) * sp, debris._rd.range_(50.0, 110.0) * (0.6 + 0.4 * s), debris._rd.range_(0.5, 0.9), surf)
		if _wake_t % maxi(int(p("wake", "puff_every")), 1) == 0:
			var kp2: float = debris._rd.next()
			if kp2 < q:
				_foam(f.x, surf + 10.0, back * debris._rd.range_(100.0, 400.0), debris._rd.range_(200.0, 600.0), debris._rd.range_(90.0, 200.0) * (0.5 + 0.5 * s), debris._rd.range_(0.8, 1.3))


# ------------------------------------------------------------------------------------------------------------ pieces

func _streak(x: float, y: float, vx: float, vy: float, len: float, life: float, kill_y: float) -> void:
	if not _room() or debris._spray_alive >= int(p("caps", "spray_alive") * (0.5 + 0.5 * _q())):   # the cap thins with quality too
		return
	_tick_n += 1
	debris.spray(x, y, vx, vy, len, life, kill_y)


func _foam(x: float, y: float, vx: float, vy: float, size: float, life: float) -> void:
	if not _room():
		return
	_tick_n += 1
	debris.foam(x, y, vx, vy, size, life)
