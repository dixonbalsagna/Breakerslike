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

var enabled: bool = true
var quality: int = VfxLook.Q_HIGH
var max_quality: int = VfxLook.Q_HIGH
var auto_quality: bool = true       # step down when frames run slow, and back up when they recover (presentation only)
var force_reduced: bool = false     # tools: reduced motion whatever the player's option says
var reduced_motion: bool = false:   # the player's option (main sets it every frame); force_reduced wins
	set(v):
		reduced_motion = v or force_reduced
var cracks_enabled: bool = VfxLook.CRACKS_DEFAULT   # ground cracks: off in the live build until they are approved
var trails: Array = [VfxTrailState.new(), VfxTrailState.new()]
var accents: Array = [Color.WHITE, Color.WHITE]
var seed: int = 1
var ticks: int = 0                  # unfrozen ticks consumed (for the tests)
var crack_sets: Array = []          # CrackSet, oldest first
var crack_pending: Array = []       # CrackSet waiting for a mesh
var crack_builds: int = 0           # meshes built (for the tests and the bench)
var crack_build_usec: int = 0       # total time spent building them
var _rng_trail: SimRng
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
	var dt: float = SimConst.DT
	var frozen: bool = true
	for e in events:
		if e.type == "tick":
			dt = e.dt
			frozen = e.frozen
	_sync_cracks(S)
	if frozen:
		return
	ticks += 1
	for i in range(mini(trails.size(), S.fighters.size())):
		trails[i].step(S, S.fighters[i], dt, _rng_trail, quality, reduced_motion)


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
