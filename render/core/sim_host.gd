class_name SimHost
extends RefCounted
## The game-side host of one sim: the fixed-step accumulator loop of docs/architecture/overview.md section 2, the
## keyboard state that becomes intents, draining the feed and fx outputs after each tick, and the two snapshots the
## renderer interpolates between. It is the only render-side code that calls into the sim, and it only does what a
## host must: step, toggle AI, start matches and drain S.out. Nothing it does depends on frame timing except how
## many ticks run per frame, so the tick sequence (and every gameplay hash) is the same at any frame rate.

const FEED_KEEP := 40

## After every tick, with the tick count (render/tools/determinism.gd hashes on it).
signal ticked(n: int)
## Every tick, with that tick's fx events and new feed lines, just before S.out is cleared: the hook for other
## render-side readers (UI's HUD). Listeners only read.
signal drained(events: Array, lines: Array)
## A player joined or left: {kind: "joined" | "left", slot, device} (UI's "P2 joined" line), from the input hub.
signal input_note(note: Dictionary)

var S: SimState
var cam := SimCamera.new()      # reference camera (sim/core/view/camera.gd), stepped after every tick
var fxv := SimFxView.new(1)     # reference fx consumer (sim/core/view/fx.gd)
var impact := ImpactFx.new()    # render-side crater, scorch and water effects (render/core/impact_fx.gd)
var audio_cues := AudioCues.new()   # Audio's event reader (audio/audio_cues.gd); its own stream, seeded per match
var pending_cues: Array = []    # cues made this frame's ticks, for the scene to play
var vfx := VfxHub.new()         # VFX's state (render/vfx/, docs/vfx/plan.md): trails and the rest, from each tick's events
var cam_rng: SimRng             # the 'camera' cosmetic stream: shake jitter
var seed: int = 1
var acc: float = 0.0
var ticks: int = 0
var paused: bool = false
var _was_paused: bool = false   # the last advance() found the sim paused
var hub := SimInputHub.new()    # every device's input and the intent v2 per human slot (sim/input/hub.gd)
var touch: SimTouch = hub.touch  # the hub's touch layer, for the host's hit tests and UI's button state
var feed: Array = []            # recent SimState.FeedLine, oldest first
var jitter := Vector2.ZERO      # screen shake offset in pixels for the current tick
var tick_usec: int = 0          # cost of the last SimCore.step
var fx_usec: int = 0            # cost of the last fx consume and camera step
var _prev := PackedFloat64Array()
var _cur := PackedFloat64Array()
var _skip_intro: bool = false   # skip_intro() was asked for and the intro has not ended yet


func _init() -> void:
	S = SimCore.createSim()


## A new match. ai is {"p1": bool, "p2": bool}; missing entries keep the current setting (both AI at first). setup adds
## to the match setup: the intro phase's "intro" (true plays it, "skip" starts from its state at the clock).
func new_match(p_seed: int, ai: Dictionary = {}, setup: Dictionary = {}) -> void:
	seed = p_seed & 0xFFFFFFFF
	var su: Dictionary = hub.setup()   # both slots are v2; a Simple layout sets its assists
	su.merge(setup, true)
	_skip_intro = false
	SimCore.newMatch(S, seed, ai, su)
	cam.reset()
	fxv.reset(seed)
	impact.reset(seed)
	audio_cues.reset(seed)
	vfx.reset(S, seed)
	pending_cues.clear()
	cam_rng = SimRng.new(SimRng.deriveSeed(seed, "camera"))
	acc = 0.0
	ticks = 0
	feed.clear()
	hub.release_all()
	jitter = Vector2.ZERO
	_cur = _capture()
	_prev = _cur


## Run as many fixed ticks as the frame time allows (overview.md: acc += min(0.1, frame)). Returns the tick count.
func advance(frame_dt: float, vw: float, vh: float) -> int:
	if paused:
		_was_paused = true
		return 0
	if _was_paused:
		# The pause (P, or an overlay) ended: nothing pressed during it fires, and every hold is read as if it began now
		# (Controls' SimInputHub.resume).
		_was_paused = false
		hub.resume()
	acc += minf(0.1, maxf(0.0, frame_dt))
	var n: int = 0
	while acc >= SimConst.DT:
		tick(vw, vh)
		acc -= SimConst.DT
		n += 1
	return n


## Interpolation factor between the previous and the current tick, for the frame being drawn.
func alpha() -> float:
	return clampf(acc / SimConst.DT, 0.0, 1.0)


## Whether the intro phase is running (docs/architecture/intro-phase.md): the match's pre-clock ticks, in which the
## fighters fall in and stare. False on a sim without the phase.
func intro_running() -> bool:
	return "intro" in S and S.intro != null and int(S.intro.left) > 0


## Ask for the intro to be skipped. The sim skips on a press from a human slot, so the next pre-clock ticks carry one
## in the first human slot's intent until the intro ends (a press before the sim's skipFrom tick is ignored). Outside
## the intro, and with no human slot, it does nothing.
func skip_intro() -> void:
	_skip_intro = intro_running()


## One fixed tick: intents for human slots, step, camera, then drain the feed and the fx events.
func tick(vw: float, vh: float) -> void:
	var inputs: Array = [null, null]
	take_players()
	hub.set_humans(S.fighters[0].ai == null, S.fighters[1].ai == null)
	for k in range(2):
		if S.fighters[k].ai == null:
			inputs[k] = hub.intent(k)
	var pausing: bool = S.pause.left > 0   # Q10: this tick is one of a pausing set piece's frozen ticks
	var pre: bool = intro_running()        # the intro phase: this tick is a pre-clock tick
	if pre and _skip_intro:
		for k in range(2):
			if inputs[k] != null:
				inputs[k].dash = true      # read only as "skip": nothing else runs on a pre-clock tick
				break
	elif not pre:
		_skip_intro = false
	var t0: int = Time.get_ticks_usec()
	if SimCore.step(S, inputs):
		hub.consumed()
	elif pausing or pre:
		# A set piece runs for seconds: what is pressed during it is dropped, and on its last frozen tick every hold is
		# read as if it began now, so no pile of presses fires when the fight resumes (Controls' rule). A hit-stop is a
		# few frames: its presses are kept for the next live tick, as before. The intro's pre-clock ticks are the
		# same: a press is read on its own tick (it skips), and the press that skipped fires nothing at the clock.
		if S.pause.left > 0 or intro_running():
			hub.drop_edges()
		else:
			hub.resume()
	var t1: int = Time.get_ticks_usec()
	cam.camStep(S, S.dt, vw, vh)
	var lines: Array = S.out.feed.duplicate()
	for l in lines:
		feed.append(l)
	while feed.size() > FEED_KEEP:
		feed.pop_front()
	S.out.feed.clear()
	# VFX draws some of the reference consumer's effects itself; those events are kept from the consumer so nothing
	# is drawn twice: a fall's debris while its collapses are on, and debris, fire and dust while its earth effects
	# are on (VfxHub.reference_events).
	fxv.consume(S, vfx.reference_events(_without_fall_debris(S, S.out.fx) if vfx.enabled and vfx.destruction_enabled else S.out.fx))
	impact.scorch_sparks = not (vfx.enabled and vfx.embers_enabled)
	impact.water_marks = not (vfx.enabled and vfx.water_enabled)
	impact.ejecta_marks = not (vfx.enabled and vfx.earth_enabled)
	impact.consume(S, S.out.fx)
	pending_cues.append_array(audio_cues.consume(S, S.out.fx))
	drained.emit(S.out.fx, lines)
	vfx.consume(S, S.out.fx)
	S.out.fx.clear()
	if fxv.shake > 0.5:
		jitter = Vector2((cam_rng.next() - 0.5) * fxv.shake, (cam_rng.next() - 0.5) * fxv.shake)
	else:
		jitter = Vector2.ZERO
	fx_usec = Time.get_ticks_usec() - t1
	tick_usec = t1 - t0
	ticks += 1
	_prev = _cur
	_cur = _capture()
	ticked.emit(ticks)


## A tick's events less the dust and debris of the buildings that fell in it, for the particle consumer while VFX
## draws the collapses itself (VfxHub.destruction_enabled), so a fall is not drawn twice. A fall's dust and debris sit
## at its building's x, and a fallen building takes no more damage, so any at a fallen building's x are the fall's;
## the dead buildings are read too, for the falls past the event cap that fold into one summary (b = -1).
static func _without_fall_debris(S: SimState, fx: Array) -> Array:
	var falls: bool = false
	for e in fx:
		if e.type == "building_fall":
			falls = true
			break
	if not falls:
		return fx
	var xs: Dictionary = {}
	for e in fx:
		if e.type == "building_fall":
			xs[snappedf(e.x, 0.01)] = true
	for b in S.buildings:
		if not b.alive:
			xs[snappedf(b.x, 0.01)] = true
	return fx.filter(func(e): return not ((e.type == "debris" or e.type == "dust") and xs.has(snappedf(e.x, 0.01))))


## Re-frame without stepping: the camera follows the current state for one tick and the snapshots shift, as after
## a tick. Only for tools that pose a state by hand (render/tools/seam_sweep.gd); the game never calls it.
func follow(vw: float, vh: float) -> void:
	cam.camStep(S, SimConst.DT, vw, vh)
	_prev = _cur
	_cur = _capture()


func key_down(code: String) -> void:
	hub.key(code, true)


func key_up(code: String) -> void:
	hub.key(code, false)


func release_all() -> void:
	hub.release_all()


func toggle_ai(idx: int) -> void:
	SimCore.toggleAI(S, idx)


## Local two-player (docs/controls/local-two-player.md): the hub asks for a second player when a new device presses a
## button, and hands the slot back to the AI when the player leaves or unplugs. Every tick takes them before its
## intents; the main scene also calls this when the pause menu hands player two back, so it shows at once.
func take_players() -> void:
	for s in hub.take_joins():
		if S.fighters[s].ai != null:
			toggle_ai(s)
	for s in hub.take_leaves():
		if S.fighters[s].ai == null:
			toggle_ai(s)
	for n in hub.take_notes():
		input_note.emit(n)


## Interpolated fighter pose [x, y, rot]; x follows the shortest arc, so crossing the seam never lerps the long way.
func fighter_pose(i: int, a: float) -> Vector3:
	var o: int = i * 3
	return Vector3(_wlerp(_prev[o], _cur[o], a), lerpf(_prev[o + 1], _cur[o + 1], a), lerpf(_prev[o + 2], _cur[o + 2], a))


## Interpolated reference camera [x, y, zoom], x wrapped like a fighter's.
func camera(a: float) -> Vector3:
	var o: int = S.fighters.size() * 3
	return Vector3(_wlerp(_prev[o], _cur[o], a), lerpf(_prev[o + 1], _cur[o + 1], a), lerpf(_prev[o + 2], _cur[o + 2], a))


## Wrapped world x of the interpolated camera, at full float64 precision (Vector3 is float32).
func camera_x(a: float) -> float:
	var o: int = S.fighters.size() * 3
	return _wlerp(_prev[o], _cur[o], a)


func fighter_x(i: int, a: float) -> float:
	return _wlerp(_prev[i * 3], _cur[i * 3], a)


## Interpolated depth of a fighter (World's B2: a brunt launch carries him into the building rows; 0 on the plane,
## positive toward the camera).
func fighter_z(i: int, a: float) -> float:
	var o: int = S.fighters.size() * 3 + 3 + i
	return lerpf(_prev[o], _cur[o], a) if o < _prev.size() and o < _cur.size() else 0.0


func _capture() -> PackedFloat64Array:
	var v := PackedFloat64Array()
	for f in S.fighters:
		v.append(f.x)
		v.append(f.y)
		v.append(f.rot)
	v.append(cam.x)
	v.append(cam.y)
	v.append(cam.z)
	for f in S.fighters:
		v.append(f.z)
	return v


static func _wlerp(a: float, b: float, t: float) -> float:
	return SimWrap.wrap(a + SimWrap.sdx(a, b) * t)
