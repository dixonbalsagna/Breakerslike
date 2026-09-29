class_name FlashView
extends Node3D
## Head flashes (docs/art/flash-prototype-spec.md; data: Art's data/art/flashes.json, through FlashSet): brief, iconic
## pops at a fighter's head that say what it senses or feels, then nothing. One per fighter. The fighter view places
## it every frame at the head, facing the camera and mirrored with the body's facing (the head itself turns with the
## cheat-out, so the flash is not its child). It draws in front of the head and hair (FLASH_Z) with the head's own
## disc cut out, so it never covers the face (look.gd says why), and uses the fighter's hybrid projection. One
## MultiMesh of quads is one draw call: every shape of a layout as a rim and a core, or a glyph's rim and core,
## drawn by render/shaders/flash.gdshader from per-instance data written once when a flash starts. Idle, it is
## hidden and costs nothing; its first frame draws one fully transparent quad, so the shader compiles then and not
## at the first flash in a fight (about 210 ms on the web).
##
## The state machine runs on sim time, so hit-stop and pause hold it (spec sections 5 and 7):
## - one flash at a time. A higher priority preempts (the one showing fades in FLASH_OUT); the same flash firing
##   again extends its hold and never replays its attack; a lower one waits up to the data's default wait, then is
##   dropped;
## - never with UI's wear crown. A flash due while the crown is up waits, and a crown that comes up fades the flash
##   showing. The surge is the exception;
## - a flash with a sequence block (Resolve) starts its delay after the crown goes down, waits up to its own wait_max,
##   and only the surge preempts or displaces it;
## - info flashes obey UI's info_flashes setting; a hidden fighter shows none; each flash has its cooldown.
## Legal's rules (round tips, the low crest, the danger ray) are applied from the data when a flash starts, unless
## `legacy` (F8) asks for the shapes as they were. Render-side only: it never writes the sim. The hurt jitter's seed
## comes from the cosmetic 'vfx.flash' stream, seeded from the tick.
##
## In a second pane (render/core/pane_world.gd) a fighter's flash view follows the first pane's (`leader`): it draws
## the same flash from the same MultiMesh with its own material (its camera's anchor), and runs no state machine, so
## the flash, its sound and UI's hooks happen once.

var actor: int = 0
var family: String = "P"
var legacy: bool = false
var reduced_motion: bool = false
## Hooks, set by the scene: crown_fn(actor) -> bool (UI's crown_up), info_fn() -> bool (UI's info_flashes),
## started_fn(actor, id) (Audio's cue), up_fn(actor, up) (UI's set_flash_up). Unset hooks mean no crown, info on.
var crown_fn: Callable
var info_fn: Callable
var started_fn: Callable
var up_fn: Callable
var leader: FlashView = null   # a second pane's copy: the first pane's view it follows

var cur: String = ""           # the flash showing, or ""
var _t0: float = 0.0           # sim time it started
var _hold_end: float = 0.0     # sim time its hold ends (extended when it fires again)
var _out: float = -1.0         # sim time a forced fade started, or -1
var _queue: Array = []         # [id, asked at, crown down since (-1 while up), bearing]: flashes waiting
var _cool: Dictionary = {}     # id -> sim time it may fire again
var _mm := MultiMesh.new()
var _mi := MultiMeshInstance3D.new()
var _mat := ShaderMaterial.new()
var _unit: float = 1.0           # world units per layout unit (set_head)
var _warm: bool = false


func _init() -> void:
	_mat.shader = preload("res://render/shaders/flash.gdshader")
	_mat.set_shader_parameter("ortho", 1.0)
	_mat.set_shader_parameter("u", _unit)
	var quad := QuadMesh.new()
	quad.size = Vector2.ONE
	_mm.transform_format = MultiMesh.TRANSFORM_3D
	_mm.use_colors = true
	_mm.use_custom_data = true
	_mm.mesh = quad
	var n: int = 8
	for id in FlashSet.ids():
		var lay = FlashSet.flash(id).get("layout")
		if lay is Array:
			n = maxi(n, 2 * lay.size())
	_mm.instance_count = n
	for i in range(n):
		_mm.set_instance_transform(i, Transform3D.IDENTITY)
	_mm.custom_aabb = AABB(Vector3(-400.0, -60000.0, -50.0), Vector3(800.0, 60500.0, 100.0))
	_mi.multimesh = _mm
	_mi.material_override = _mat
	_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_mi)
	visible = false


## The head this flash sits on: its radius in world units. It sets the layout unit (a twelfth of the head size), its
## disc is cut out of the flash, and glyphs rise by any excess over Art's head.
func set_head(r: float) -> void:
	_unit = 2.0 * r / 12.0
	_mat.set_shader_parameter("u", _unit)
	var hr: float = r / _unit
	_mat.set_shader_parameter("head_r", hr)
	_mat.set_shader_parameter("head_c", Vector2(0.0, -RenderLook.FLASH_UP))
	_mat.set_shader_parameter("glyph_lift", maxf(0.0, hr - RenderLook.FLASH_ART_HEAD_R))


## Whether a glyph (a bang or a question) is showing.
func glyph_up() -> bool:
	return cur != "" and String(FlashSet.flash(cur).get("kind", "")) == "glyph"


## Ask for a flash at sim time T. bearing: danger sense's threat bearing in the facing frame (degrees, 0 forward, 90
## up), NAN for the data's default.
func fire(id: String, T: float, hidden: bool, bearing: float = NAN) -> void:
	var f: Dictionary = FlashSet.flash(id)
	if f.is_empty() or hidden:
		return
	if String(f.get("class", "")) == "info" and info_fn.is_valid() and not bool(info_fn.call()):
		return
	if id == cur and _out < 0.0:
		_hold_end = maxf(_hold_end, T + float(f.hold))
		return
	if T < float(_cool.get(id, -1.0e9)):
		return
	for q in _queue:
		if q[0] == id:
			return
	_queue.append([id, T, -1.0, bearing])
	_queue.sort_custom(func(a, b): return FlashSet.priority(a[0]) < FlashSet.priority(b[0]))


## Per frame: the queue, the flash showing and its drawing. pos: the flash's place (the head centre, in the fighter
## view's space); m: the body's mirror (+1 or -1); anchor: the projection anchor; ground: the ground's height below
## the fighter, in the same space as pos.
func step(T: float, hidden: bool, pos: Vector3, m: float, anchor: Vector3, ground: float) -> void:
	if leader != null:
		_follow()
	else:
		_run(T, hidden)
	visible = cur != ""
	if not _warm and leader == null:
		_warm = true
		if not visible:
			_mm.visible_instance_count = 1
			_mat.set_shader_parameter("k", 0.0)
			_mat.set_shader_parameter("fade", 0.0)
			visible = true
			return
	if not visible:
		return
	position = pos + Vector3(0.0, RenderLook.FLASH_UP * _unit, RenderLook.FLASH_Z - pos.z)
	basis = Basis.from_scale(Vector3(m, 1.0, 1.0))
	_mat.set_shader_parameter("mirror", m)
	_mat.set_shader_parameter("k", _env(T))
	_mat.set_shader_parameter("fade", maxf(0.0, 1.0 - (T - _out) / RenderLook.FLASH_OUT) if _out >= 0.0 else 1.0)
	_mat.set_shader_parameter("anchor", anchor)
	_mat.set_shader_parameter("ground_y", (ground - position.y) / _unit)
	var f: Dictionary = FlashSet.flash(cur)
	_mat.set_shader_parameter("sweep_k", clampf((T - _t0) / maxf(float(f.attack), 1.0e-3), 0.0, 1.0))
	_mat.set_shader_parameter("jitter_step", floorf((T - _t0) * RenderLook.FLASH_JITTER_HZ))


## Follow the first pane's view: draw from its MultiMesh, with the uniforms it set when its flash started.
func set_leader(l: FlashView) -> void:
	leader = l
	_mi.multimesh = l._mm
	_warm = true


func _follow() -> void:
	if leader.cur != cur or leader._t0 != _t0:
		cur = leader.cur
		_t0 = leader._t0
		for key in ["family", "grow", "sweep", "jitter", "seed"]:
			_mat.set_shader_parameter(key, leader._mat.get_shader_parameter(key))
	_hold_end = leader._hold_end
	_out = leader._out


## The queue, the arbitration and the flash showing (the first pane's view only).
func _run(T: float, hidden: bool) -> void:
	var crown: bool = crown_fn.is_valid() and bool(crown_fn.call(actor))
	var wait: float = FlashSet.default_wait()
	# The waiting flashes: sequenced ones count from the crown going down; the rest are dropped after the wait.
	var keep: Array = []
	for q in _queue:
		var seq: Dictionary = FlashSet.sequence(q[0])
		if seq.is_empty():
			if T - q[1] <= wait:
				keep.append(q)
		elif T - q[1] <= float(seq.get("wait_max", wait)):
			q[2] = (q[2] if q[2] >= 0.0 else T) if not crown else -1.0
			keep.append(q)
	_queue = keep
	if cur != "":
		var surge: bool = cur == "surge"
		if _out < 0.0 and (hidden or (crown and not surge)):
			_out = T
		if _out < 0.0 and not _queue.is_empty() and _can_start(_queue[0], T, crown) and _preempts(_queue[0][0], cur):
			_out = T
		if (_out >= 0.0 and T - _out >= RenderLook.FLASH_OUT) or T >= _hold_end + float(FlashSet.flash(cur).fade):
			_end()
	if cur == "" and not hidden:
		for i in range(_queue.size()):
			var q: Array = _queue[i]
			if _can_start(q, T, crown):
				_queue.remove_at(i)
				_start(q[0], T, q[3])
				break
			if not crown and not FlashSet.sequence(q[0]).is_empty():
				break   # a sequenced flash in its delay after the crown: nothing lower goes first


## Whether a waiting flash may start now: the crown down (the surge excepted), a sequenced one its delay after that.
func _can_start(q: Array, T: float, crown: bool) -> bool:
	if q[0] == "surge":
		return true
	if crown:
		return false
	var seq: Dictionary = FlashSet.sequence(q[0])
	return seq.is_empty() or (q[2] >= 0.0 and T - q[2] >= float(seq.get("delay_after_crown_down", 0.0)) - 1.0e-6)


## Whether a flash preempts the one showing: a higher priority, and only the surge displaces a sequenced one.
func _preempts(id: String, over: String) -> bool:
	if not FlashSet.sequence(over).is_empty():
		return id == "surge"
	return FlashSet.priority(id) < FlashSet.priority(over)


## The envelope: an eased attack, the hold, an eased fade (spec section 5).
func _env(T: float) -> float:
	if cur == "":
		return 0.0
	var f: Dictionary = FlashSet.flash(cur)
	var a: float = float(f.attack)
	var d: float = float(f.fade)
	var t: float = T - _t0
	if t < a:
		return 1.0 - pow(1.0 - maxf(t, 0.0) / a, 2.0)
	if T < _hold_end:
		return 1.0
	if T < _hold_end + d:
		return 1.0 - pow((T - _hold_end) / d, 2.0)
	return 0.0


## The envelope times any forced fade.
func _k(T: float) -> float:
	var e: float = _env(T)
	if _out >= 0.0:
		e *= maxf(0.0, 1.0 - (T - _out) / RenderLook.FLASH_OUT)
	return e


## The flash's visibility now (for tools): 0 at rest.
func level(T: float) -> float:
	return _k(T) if cur != "" else 0.0


func _start(id: String, T: float, bearing: float) -> void:
	var f: Dictionary = FlashSet.flash(id)
	cur = id
	_t0 = T
	_hold_end = T + float(f.attack) + float(f.hold)
	_out = -1.0
	_cool[id] = T + float(f.get("cooldown", 0.0))
	_write(id, f, bearing)
	var fam: int = FlashSet.shape_of(family)
	_mat.set_shader_parameter("family", fam)
	_mat.set_shader_parameter("grow", 0.0 if reduced_motion else 0.45)
	_mat.set_shader_parameter("sweep", 0.0 if reduced_motion else deg_to_rad(float(RenderLook.FLASH_SWEEP.get(id, 0.0))))
	_mat.set_shader_parameter("jitter", 0.0 if reduced_motion else float(RenderLook.FLASH_JITTER.get(id, 0.0)) * FighterView.HEIGHT / _unit)
	_mat.set_shader_parameter("seed", float(SimRng.deriveSeed(int(T * 60.0) * 2 + actor, "vfx.flash") % 10007))
	if started_fn.is_valid():
		started_fn.call(actor, id)
	if up_fn.is_valid():
		up_fn.call(actor, true)


func _end() -> void:
	cur = ""
	_out = -1.0
	visible = false
	if up_fn.is_valid():
		up_fn.call(actor, false)


## The instance data for a flash: a layout's shapes, each a rim and a core, or a glyph's rim and core (two of each for
## a double bang), with Legal's rules from the data.
func _write(id: String, f: Dictionary, bearing: float) -> void:
	var info: bool = String(f.get("class", "")) == "info"
	var ic: Array = FlashSet.info_colours(family)
	var ec: Array = FlashSet.emotion_colours(family)
	var rim: Color = ic[1] if info else ec[0]
	var core: Color = ic[0] if info else ec[1]
	var n: int = 0
	if String(f.get("kind", "")) == "glyph":
		var places: Array = RenderLook.FLASH_GLYPH2_AT if String(f.get("glyph", "")) == "bang2" else RenderLook.FLASH_GLYPH_AT
		var q: int = 64 if String(f.get("glyph", "")) == "question" else 0
		for at in places:
			_mm.set_instance_custom_data(n, Color(at[0], at[1], 0.0, 32 + q + 16))
			_mm.set_instance_color(n, Color(rim, 0.97))
			_mm.set_instance_custom_data(n + 1, Color(at[0], at[1], 0.0, 32 + q + 16 + 8))
			_mm.set_instance_color(n + 1, Color(core, 0.97))
			n += 2
	else:
		var turn: float = 0.0
		if id == "danger":
			var ray: Dictionary = FlashSet.danger_ray()
			var b: float = float(ray.get("default_angle", 132.0)) if is_nan(bearing) else bearing
			var lim: Array = ray.get("clamp", [60.0, 200.0])
			turn = clampf(b, float(lim[0]), float(lim[1])) - float(ray.get("default_angle", 132.0))
		var round_tip: bool = not legacy and FlashSet.rule("round_tip", family, id)
		var crest: bool = not legacy and FlashSet.rule("low_crest", family, id)
		for it in f.get("layout", []):
			var a: float = float(it.a) + turn
			var d: float = float(it.d)
			var s: float = float(it.s)
			var ground: bool = bool(it.get("ground", false))
			if crest and not ground:
				var r: float = deg_to_rad(a)
				a = rad_to_deg(atan2(sin(r) * 0.4, cos(r))) + 42.0
				s *= 0.7
				d += 4.0
			var flags: int = (1 if bool(it.get("inward", false)) else 0) + (2 if ground else 0) + (4 if round_tip else 0) + (16 if info else 0)
			var op: float = float(it.get("op", 1.0))
			_mm.set_instance_custom_data(n, Color(deg_to_rad(a), d, s, flags))
			_mm.set_instance_color(n, Color(rim, op))
			_mm.set_instance_custom_data(n + 1, Color(deg_to_rad(a), d, s * (0.84 if info else 0.58), flags + 8))
			_mm.set_instance_color(n + 1, Color(core, op))
			n += 2
	_mm.visible_instance_count = n
