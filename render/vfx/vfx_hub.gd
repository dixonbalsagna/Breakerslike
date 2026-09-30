class_name VfxHub
extends RefCounted
## VFX's per-match state, shared by every pane (docs/vfx/plan.md section 5). The host calls reset() at each match
## start and consume() once per sim tick with that tick's fx events, before they are cleared. Everything here is
## presentation: it reads the sim state and the events, keeps its own history, and draws its randomness from streams
## derived from the match seed (SimRng.deriveSeed(seed, "vfx.<class>")). It never writes the sim and never touches S.rng,
## so no VFX change can alter a match (render/vfx/tools/hash_check.gd proves it).
##
## It holds the motion-trail state and the crack sets. Crack sets come from the sim's own records (S.craters and
## S.slides), not from events, so they are rebuilt identically after a seek or a snapshot restore; the mesh of each is
## built lazily by the first pane to draw (it needs the ground as the renderer has uploaded it).

## One crater's or slide's set of cracks.
class CrackSet:
	var id: int = 0
	var kind: int = 0             # 0 crater, 1 slide
	var key: int = 0
	var x: float = 0.0            # origin, wrapped world x
	var born: float = 0.0         # sim time the record was made
	var lines: Array = []         # VfxCrackGen.Line, until the mesh is built
	var mesh: ArrayMesh = null
	var reach: float = 1.0
	var tris: int = 0
	var fissures: int = 0

## A hole a fighter left in a facade.
class Hole:
	var b: int = -1
	var x: float = 0.0
	var y: float = 0.0
	var z: float = 0.0
	var w: float = 100.0
	var h: float = 100.0
	var seed: float = 0.0

var enabled: bool = true
var quality: int = VfxLook.Q_HIGH
var max_quality: int = VfxLook.Q_HIGH
var auto_quality: bool = true       # step down when frames run slow, and back up when they recover (presentation only)
var force_reduced: bool = false     # tools: reduced motion whatever the player's option says
var reduced_motion: bool = false:   # the player's option (main sets it every frame); force_reduced wins
	set(v):
		reduced_motion = v or force_reduced
var cracks_enabled: bool = VfxLook.CRACKS_DEFAULT   # ground cracks: off in the live build until they are approved
var destruction_enabled: bool = VfxLook.DESTRUCTION_DEFAULT   # shrapnel, collapse dust and holes: off in the live build until approved
var debris := VfxDebris.new()
var holes: Array = []               # Hole
var trails: Array = [VfxTrailState.new(), VfxTrailState.new()]
var accents: Array = [Color.WHITE, Color.WHITE]
var seed: int = 1
var ticks: int = 0                  # unfrozen ticks consumed (for the tests)
var crack_sets: Array = []          # CrackSet, oldest first
var crack_pending: Array = []       # CrackSet waiting for a mesh
var crack_builds: int = 0           # meshes built (for the tests and the bench)
var crack_build_usec: int = 0       # total time spent building them
var _rng_trail: SimRng
var _rng_hole: SimRng
var stat_consume_usec: int = 0     # time spent in consume(), for the bench and the budget table
var stat_consume_n: int = 0
var stat_consume_max: int = 0
var _slow: float = 0.0              # seconds spent below AUTO_DOWN_FPS
var _fast: float = 0.0              # seconds spent at or above AUTO_UP_FPS
var _hold: float = 0.0              # no step up for this long after a step down
var _last_crater = null             # the newest crater record already turned into a set
var _last_slide = null
var _next_id: int = 1

const AUTO_DOWN_FPS: float = 42.0
const AUTO_DOWN_S: float = 2.0
const AUTO_UP_FPS: float = 57.0
const AUTO_UP_S: float = 8.0
const AUTO_HOLD_S: float = 20.0


func reset(S: SimState, p_seed: int) -> void:
	seed = p_seed & 0xFFFFFFFF
	ticks = 0
	_rng_trail = SimRng.new(SimRng.deriveSeed(seed, "vfx.trail"))
	_rng_hole = SimRng.new(SimRng.deriveSeed(seed, "vfx.hole"))
	debris.reset(seed)
	holes.clear()
	for i in range(trails.size()):
		trails[i].reset()
		if i < S.fighters.size():
			accents[i] = VfxLook.trail_accent(String(S.fighters[i].aura))
	crack_sets.clear()
	crack_pending.clear()
	crack_builds = 0
	crack_build_usec = 0
	_last_crater = null
	_last_slide = null


## Once per displayed frame with its wall-clock time: the automatic quality step. Below 42 fps for 2 s drops a level;
## at or above 57 fps for 8 s (and 20 s after the last drop) climbs back. Never affects the sim.
func note_frame(delta: float) -> void:
	if not auto_quality or delta <= 0.0:
		return
	var fps: float = 1.0 / maxf(delta, 1e-4)
	_hold = maxf(0.0, _hold - delta)
	if fps < AUTO_DOWN_FPS:
		_slow += delta
		_fast = 0.0
	else:
		_slow = 0.0
		if fps >= AUTO_UP_FPS:
			_fast += delta
		elif fps < 52.0:
			_fast = 0.0
	if _slow >= AUTO_DOWN_S and quality > VfxLook.Q_LOW:
		quality -= 1
		_slow = 0.0
		_hold = AUTO_HOLD_S
	elif _fast >= AUTO_UP_S and _hold <= 0.0 and quality < max_quality:
		quality += 1
		_fast = 0.0


## One tick's fx events, in order, plus the state after the tick.
func consume(S: SimState, events: Array) -> void:
	if not enabled:
		return
	var t0: int = Time.get_ticks_usec()
	_consume(S, events)
	var dt_us: int = Time.get_ticks_usec() - t0
	stat_consume_usec += dt_us
	stat_consume_n += 1
	stat_consume_max = maxi(stat_consume_max, dt_us)


func _consume(S: SimState, events: Array) -> void:
	if not enabled:
		return
	var dt: float = SimConst.DT
	var frozen: bool = true
	for e in events:
		if e.type == "tick":
			dt = e.dt
			frozen = e.frozen
	_sync_cracks(S)
	if destruction_enabled:
		debris.quality = quality
		debris.reduced = reduced_motion
		for e in events:
			match e.type:
				"building_hit":
					_on_building_hit(S, e)
				"chain_link":
					_on_chain_link(S, e)
				"building_fall":
					_on_building_fall(S, e)
		# Bits fly on sim time: a tenth of a step in hit-stop, like the reference consumer's particles.
		debris.step(S, dt * 0.1 if frozen else dt)
	if frozen:
		return
	ticks += 1
	for i in range(mini(trails.size(), S.fighters.size())):
		trails[i].step(S, S.fighters[i], dt, _rng_trail, quality, reduced_motion)


# ------------------------------------------------------------------------------ buildings: hits, chains and falls

## The depth of a building's facade, where its shrapnel and its holes sit. Rendering draws every building's front face at
## RenderLook.Z_BUILDING_FRONT today; once it draws them at the sim's own depth (buildings-in-depth.md B3) this reads that.
func front_z(_b) -> float:
	return RenderLook.Z_BUILDING_FRONT


## A field of an event that may not carry it yet (building_hit and chain_link are B2's, and their fields may still change):
## the value, or dflt when absent. Works for the sim's FxEvent and for the mock's.
static func _g(e, key: String, dflt = null):
	var v = e.get(key)
	return dflt if v == null else v


## A launched fighter went into a building (B2's building_hit, docs/world/b2-plan.md section 5: b, x, y, z, damage, ratio, outcome, link, n, spd,
## keep, ux, uy, kind, w, h, victim). The direction is the impact vector (ux, uy) or, without it, the launched fighter's velocity, the
## entry point the wall's near edge, the exit the far edge along that line.
func _on_building_hit(S: SimState, e) -> void:
	var bi: int = int(_g(e, "b", -1))
	if bi < 0 or bi >= S.buildings.size():
		return
	var b = S.buildings[bi]
	var dir := Vector2.ZERO
	var sp: float = float(_g(e, "spd", _g(e, "sp", 0.0)))
	if _g(e, "ux") != null:
		dir = Vector2(float(_g(e, "ux", 1.0)), float(_g(e, "uy", 0.0)))
	else:
		var best: float = 1e30
		for f in S.fighters:
			if f.state != "launched":
				continue
			var d: float = absf(SimWrap.sdx(f.x, b.x))
			if d < best:
				best = d
				dir = Vector2(f.vx, f.vy)
				if sp <= 0.0:
					sp = dir.length()
	if dir.length() < 1.0:
		dir = Vector2(1.0, 0.0)
	dir = dir.normalized()
	if sp <= 0.0:
		sp = 4000.0
	var g: float = WorldTerrain.groundY(S, b.x)
	var top: float = g + b.h
	var sgn: float = 1.0 if dir.x >= 0.0 else -1.0
	var yi: float = clampf(float(_g(e, "y", g + b.h * 0.4)), g + 40.0, top - 40.0)
	var xi: float = b.x - sgn * b.w * 0.30   # on the front face, a little in from the near edge
	var run: float = b.w * 0.6
	var yo: float = clampf(yi + (dir.y / maxf(absf(dir.x), 0.15)) * run, g + 40.0, top - 40.0)
	var xo: float = b.x + sgn * b.w * 0.30
	var outcome: String = String(_g(e, "outcome", "collapse"))
	var link: int = int(_g(e, "link", 1))
	var fz: float = front_z(b)
	debris.burst_through(S, b.x, b.w, b.h, fz, xi, yi, xo, yo, dir.x, dir.y, sp, outcome, link)
	# The holes: where it went in, and where it came out (a cracked wall only has the mark going in).
	var size: float = clampf(90.0 + 0.02 * float(_g(e, "h", b.h)), 110.0, 260.0)   # a fighter and a half, more for a tall tower
	if outcome != "collapse":
		_add_hole(bi, xi, yi, fz, size * 0.85, size * 1.1)
	if outcome != "crack" and outcome != "collapse":
		_add_hole(bi, xo, yo, fz, size * 1.1, size * 1.4)


func _on_chain_link(S: SimState, e) -> void:
	var bi: int = int(_g(e, "to", -1))
	var z: float = RenderLook.Z_BUILDING_FRONT
	if bi >= 0 and bi < S.buildings.size():
		z = front_z(S.buildings[bi])
	debris.chain_tunnel(float(_g(e, "x", _g(e, "x0", 0.0))), float(_g(e, "y", _g(e, "y0", 0.0))), float(_g(e, "x1", 0.0)), float(_g(e, "y1", 0.0)), z, int(_g(e, "link", 1)), 1.0)


## A building fell (the sim's building_fall: b, x, y = its depth z, w, depth = its height, mode, delay, cx, rubble, n).
## Its holes go with it. b -1 is a district of implodes folded into one event (n of them).
func _on_building_fall(S: SimState, e) -> void:
	var bi: int = int(_g(e, "b", -1))
	if bi < 0:
		debris.district(S, float(_g(e, "x", 0.0)), float(_g(e, "n", 1.0)))
		return
	holes = holes.filter(func(h): return h.b != bi)
	var w: float = float(_g(e, "w", 300.0))
	var h: float = float(_g(e, "depth", 800.0))
	var fz: float = front_z(null)
	if bi < S.buildings.size():
		fz = front_z(S.buildings[bi])
	debris.building_fall(S, float(_g(e, "x", 0.0)), w, h, fz, String(_g(e, "mode", "implode")), float(_g(e, "delay", 0.0)), float(_g(e, "cx", 0.0)))


func _add_hole(bi: int, x: float, y: float, z: float, w: float, h: float) -> void:
	var n_here: int = 0
	for hl in holes:
		if hl.b == bi:
			n_here += 1
	if n_here >= VfxLook.HOLES_PER_BUILDING:
		for i in range(holes.size()):
			if holes[i].b == bi:
				holes.remove_at(i)
				break
	var hl := Hole.new()
	hl.b = bi
	hl.x = SimWrap.wrap(x)
	hl.y = y
	hl.z = z + 2.5
	hl.w = w
	hl.h = h
	hl.seed = _rng_hole.next()
	holes.append(hl)
	while holes.size() > VfxLook.HOLES_MAX:
		holes.pop_front()


# ---------------------------------------------------------------------------------------------------- crack sets

## Turn the sim's new crater and slide records into crack sets (queued for a mesh). Records are the truth: a list that
## no longer holds the newest record we saw (a new match, a seek, a snapshot restore) is rebuilt from what it holds.
func _sync_cracks(S: SimState) -> void:
	if not cracks_enabled:
		return
	var nc: int = S.craters.size()
	var start: int = 0
	if _last_crater != null:
		var i: int = S.craters.rfind(_last_crater)
		if i >= 0:
			start = i + 1
		else:
			_drop_kind(0)
			start = maxi(0, nc - VfxLook.CRACK_SETS_MAX)
	elif nc > VfxLook.CRACK_SETS_MAX:
		start = nc - VfxLook.CRACK_SETS_MAX
	for j in range(start, nc):
		_queue_crater(S, S.craters[j])
	_last_crater = S.craters[nc - 1] if nc > 0 else null
	var ns: int = S.slides.size()
	start = 0
	if _last_slide != null:
		var i2: int = S.slides.rfind(_last_slide)
		if i2 >= 0:
			start = i2 + 1
		else:
			_drop_kind(1)
			start = maxi(0, ns - VfxLook.CRACK_SETS_MAX)
	elif ns > VfxLook.CRACK_SETS_MAX:
		start = ns - VfxLook.CRACK_SETS_MAX
	for j in range(start, ns):
		_queue_slide(S, S.slides[j])
	_last_slide = S.slides[ns - 1] if ns > 0 else null


func _drop_kind(kind: int) -> void:
	crack_sets = crack_sets.filter(func(cs): return cs.kind != kind)
	crack_pending = crack_pending.filter(func(cs): return cs.kind != kind)


func _queue_crater(S: SimState, c) -> void:
	var sp = c.get("special")
	var special: bool = bool(sp) if sp != null else false
	var key: int = VfxCrackGen.crater_key(c.x, c.r, c.depth)
	var lines: Array = VfxCrackGen.crater_lines(seed, key, c.r, c.energy, special, String(c.cause), quality)
	if lines.is_empty() or WorldWater.surfaceAt(S, c.x) != WorldWater.DRY:
		return
	var cs := CrackSet.new()
	cs.kind = 0
	cs.key = key
	cs.x = SimWrap.wrap(c.x)
	cs.born = c.t
	cs.lines = lines
	_add(cs)


func _queue_slide(S: SimState, sl) -> void:
	var dxt: float = SimWrap.sdx(sl.x0, sl.x1)
	var key: int = VfxCrackGen.slide_key(sl.x0, sl.x1, sl.hw)
	var lines: Array = VfxCrackGen.slide_lines(seed, key, dxt, sl.hw, sl.energy, sl.surface > 0.5, quality)
	if lines.is_empty():
		return
	var cs := CrackSet.new()
	cs.kind = 1
	cs.key = key
	cs.x = SimWrap.wrap(sl.x0)
	cs.born = sl.t
	cs.lines = lines
	_add(cs)


func _add(cs: CrackSet) -> void:
	cs.id = _next_id
	_next_id += 1
	crack_sets.append(cs)
	crack_pending.append(cs)
	while crack_sets.size() > VfxLook.CRACK_SETS_MAX:
		var old: CrackSet = crack_sets.pop_front()
		crack_pending.erase(old)


## Build the next queued set's mesh (the layer calls this, a couple a frame, once the ground is uploaded).
func build_next_crack(S: SimState, ground: GroundField) -> void:
	if crack_pending.is_empty():
		return
	var cs: CrackSet = crack_pending.pop_front()
	var t0: int = Time.get_ticks_usec()
	var b := VfxCrackMesh.new()
	cs.mesh = b.build(S, ground, cs.x, cs.lines, cs.born)
	cs.reach = b.reach
	cs.tris = b.tris
	for ln in cs.lines:
		if ln.fissure:
			cs.fissures += 1
	cs.lines = []
	crack_builds += 1
	crack_build_usec += Time.get_ticks_usec() - t0
	if cs.mesh == null:
		crack_sets.erase(cs)
