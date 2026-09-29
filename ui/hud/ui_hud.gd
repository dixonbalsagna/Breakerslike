class_name UiHud
extends Control
## The HUD root: a full-rect Control that Rendering's main scene hosts under its CanvasLayer (replacing render/core/hud.gd).
## It reads events and state through its UiEventHub and never writes the sim, never draws from a random stream, and
## animates by wall time only, so it cannot change a match or a replay.
##
## It is a stack of cached layers (UiLayer): each keeps its drawing until a small signature changes, so at rest the HUD
## costs almost no GDScript and the crown layer, the cards and the barks draw nothing at all.
##
## How a host uses it:
##   var hud := preload("res://ui/hud/ui_hud.tscn").instantiate()
##   $HUD.add_child(hud)
##   hud.setup(["kai", "vorr"], ["KAI", "VORR"])          # readout profile ids and display names
##   hud.anchor_fn = func(slot): return {"pos": <fighter torso on screen>, "h": <fighter height in px>, "visible": true}
##   hud.strip_fn = func(): return {...}                  # planet strip data (see UiStrip)
##   every tick:   hud.consume_all(events); UiSimBridge.patch(hud, S)
##   every frame:  hud.advance(delta)                     # pass 0 while the game is paused
## The demo (ui/demo/hud_demo.tscn) shows all of it driven by the mock feed.

signal layout_changed

var hub := UiEventHub.new()
var layout := UiLayout.new()
var anchor_fn: Callable = Callable()   # (slot: int) -> {pos: Vector2, h: float, visible: bool}
var strip_fn: Callable = Callable()    # () -> Dictionary for UiStrip
var opts: Dictionary = {
	"silhouette": false,       # the body figure beside each plate: off by default; the host turns it on in training and as the accessibility default
	"reduced_motion": false,   # no flicker, shimmer, shrinking rings or slide-ins; every cue still has a shape
	"captions": true,          # bracketed gesture tags on barks
	"thickness": 1.0,          # crown arc thickness multiplier (an accessibility option)
	"region_label": false,     # the place name under the planet strip's camera box
	"show_feed": false,        # the director feed (debug toggle)
	"show_clear_zone": false,  # draw the fighter-clear zone (debug)
	"show_crown": true,
	"crown_always": false,     # accessibility: keep the crown up instead of popping it (low vision)
	"brink_cue": true,         # the faint persistent ring on the brink; the one thing left over a fighter at rest
	"force_redraw": false,     # bench only: redraw every layer every frame, to measure what the caching saves
}
var insets := Vector4.ZERO     # left, top, right, bottom safe-area insets from the host (phone notches)

var _t := 0.0
var _lb := 0.0                 # letterbox progress, 0..1
var _last_size := Vector2.ZERO
var _last_sil := false
var _last_insets := Vector4.ZERO
var _frame: int = 0
var _strip_data: Dictionary = {}
# The cached layers, back to front (see UiLayer): each redraws only when its signature changes.
var _l_letter: UiLayer
var _l_strip_base: UiLayer
var _l_crown: UiLayer
var _l_plate: Array = []
var _l_sil: Array = []
var _l_toll: UiLayer
var _l_strip_marks: UiLayer
var _l_events: UiLayer
var _l_feed: UiLayer
var _l_debug: UiLayer


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(func(): _relayout())
	UiData.ensure()
	_l_letter = _layer(_paint_letterbox)
	_l_strip_base = _layer(_paint_strip_base)
	_l_crown = _layer(_paint_crown)
	for i in range(2):
		_l_plate.append(_layer(_paint_plate.bind(i)))
	for i in range(2):
		_l_sil.append(_layer(_paint_sil.bind(i)))
	_l_toll = _layer(_paint_toll)
	_l_strip_marks = _layer(_paint_strip_marks)
	_l_events = _layer(_paint_events)
	_l_feed = _layer(_paint_feed)
	_l_debug = _layer(_paint_debug)
	_relayout()


func _layer(painter: Callable) -> UiLayer:
	var l := UiLayer.new()
	l.painter = painter
	add_child(l)
	return l


func _all_layers() -> Array:
	return [_l_letter, _l_strip_base, _l_crown, _l_toll, _l_strip_marks, _l_events, _l_feed, _l_debug] + _l_plate + _l_sil


## Total redraws of every layer so far, for the perf counters.
func redraw_count() -> int:
	var n := 0
	for l in _all_layers():
		if l != null:
			n += l.redraws
	return n


## Fighters: readout profile ids ("protagonist", "anti_hero", "empress", "cyborg", or a placeholder such as "kai") and names.
func setup(ids: Array, names: Array) -> void:
	hub.setup_fighters(ids, names)
	_last_size = Vector2.ZERO
	_relayout()


func consume(e) -> void:
	hub.consume(e)


func consume_all(events: Array) -> void:
	hub.consume_all(events)


func advance(dt: float) -> void:
	_t += dt
	_frame += 1
	hub.captions_on = bool(opts["captions"])
	hub.reduced_motion = bool(opts["reduced_motion"])
	hub.advance(dt)
	var target: float = 1.0 if hub.mode == UiEventHub.Mode.CINEMATIC else 0.0
	_lb = move_toward(_lb, target, dt * (100.0 if bool(opts["reduced_motion"]) else 4.0))
	_update_layers()


func set_option(key: String, value) -> void:
	opts[key] = value
	if key == "force_redraw":
		for l in _all_layers():
			if l != null:
				l.force = bool(value)
	if key == "silhouette":
		_last_size = Vector2.ZERO
	_relayout()
	for l in _all_layers():
		if l != null:
			l.invalidate()


func _relayout() -> void:
	var sz: Vector2 = size if size.x > 1.0 else get_viewport_rect().size
	var sil: bool = bool(opts["silhouette"])
	if sz == _last_size and sil == _last_sil and insets == _last_insets:
		return
	_last_size = sz
	_last_sil = sil
	_last_insets = insets
	layout.compute(sz, sil, insets)
	hub.cap_limit = 1 if layout.portrait else 99
	for l in _all_layers():
		if l != null:
			l.invalidate()
	layout_changed.emit()


func _plate_alpha(m: UiFighterModel) -> float:
	# In a respected cinematic the plates recede, so the set piece owns the screen (docs/ui/hud-spec.md section 8).
	return 0.45 if (hub.mode == UiEventHub.Mode.CINEMATIC and m.cinematic == "") else 1.0


func _o(plate_alpha: float = 1.0) -> Dictionary:
	return {
		"reduced_motion": bool(opts["reduced_motion"]),
		"thickness": float(opts["thickness"]),
		"region_label": bool(opts["region_label"]),
		"plate_alpha": plate_alpha,
		"crown_always": bool(opts["crown_always"]),
		"brink_cue": bool(opts["brink_cue"]),
		"crown_locked": hub.crown_locked(),
	}


# --- Signatures: what decides whether a layer redraws -----------------------------------------------------------------

func _update_layers() -> void:
	if hub.models.is_empty() or _l_letter == null:
		return
	_relayout()
	var reduced: bool = bool(opts["reduced_motion"])
	var cin: bool = hub.mode == UiEventHub.Mode.CINEMATIC
	_l_letter.update_sig(int(_lb * 40.0) if _lb > 0.01 else null)

	# The crown layer draws only while something is up: a pop, the brink ring, a window, or the accessibility option.
	var crown_on: bool = false
	if bool(opts["show_crown"]) and anchor_fn.is_valid():
		for m in hub.models:
			var pop_on: bool = (m.crown_a > 0.01 or bool(opts["crown_always"])) and not hub.crown_locked()
			if pop_on or m.parry_t >= 0.0 or m.chain_t >= 0.0 or (m.brink and bool(opts["brink_cue"])):
				crown_on = true
	_l_crown.update_sig(_frame if crown_on else null)

	for m in hub.models:
		if m.slot >= _l_plate.size():
			continue
		var full: bool = m.charge >= m.sig_cost
		var pulse: int = int(_t * 8.0) if (not reduced and m.brink) else 0
		_l_plate[m.slot].update_sig([m.name, m.ai, m.stance, m.tier, int(m.momentum), int(m.charge), int(m.ego), m.hidden, m.lost_trail,
			m.charging, m.chain_n if m.chain_t >= 0.0 else 0, m.brink, m.shame, full, _plate_alpha(m), pulse])
		_l_sil[m.slot].update_sig(_sil_sig(m, reduced) if layout.silhouette_on else null)

	var a_toll: float = lerpf(UiLook.TOLL_REST_ALPHA, 1.0, clampf(1.0 - hub.toll_age / UiLook.TOLL_SHOW, 0.0, 1.0)) * (0.45 if cin else 1.0)
	_l_toll.update_sig([hub.toll["civilians"], hub.toll["pop0"], hub.toll["structures"], hub.toll["craters"], int(a_toll * 20.0)])

	if strip_fn.is_valid() and _lb < 0.5:
		_strip_data = strip_fn.call()
		var segs: Array = _strip_data.get("segs", [])
		var dead: Array = _strip_data.get("dead", [])
		_l_strip_base.update_sig([segs.size(), dead.size()])
		_l_strip_marks.update_sig(UiStrip.marks_sig(layout, _strip_data, _t, _o()))
	else:
		_l_strip_base.update_sig(null)
		_l_strip_marks.update_sig(null)

	var events_on: bool = not hub.cards.is_empty() or not hub.barks.is_empty() or not hub.banner.is_empty() or hub.world_card != null
	_l_events.update_sig(_frame if events_on else null)
	_l_feed.update_sig([int(_t * 4.0), hub.feed.size(), hub.mode, hub.cards.size(), hub.barks.size()] if bool(opts["show_feed"]) else null)
	_l_debug.update_sig(1 if bool(opts["show_clear_zone"]) else null)


func _sil_sig(m: UiFighterModel, reduced: bool) -> Array:
	var out: Array = []
	for r in m.regions:
		out.append(m.stage[r])
	out.append_array([m.internal_stage, m.heat_stage, m.brink, m.hidden, m.pride_holds, m.shame, m.chip_station, m.chip_stage,
		m.hatch_open, m.revision, m.patch_region, m.unrestrained])
	var age_anim: bool = m.facade_age < 0.7
	for r in m.regions:
		if float(m.region_age[r]) < UiLook.MEND_SWEEP + 0.05 and int(m.region_dir[r]) != 0:
			age_anim = true
	var pulse_anim: bool = not reduced and (m.brink or m.heat_stage > 0 or m.hatch_open or m.boil_flash > 0.0)
	out.append(int(_t * 15.0) if (age_anim or pulse_anim) else 0)
	return out


# --- Painters: each draws one layer ---------------------------------------------------------------------------------

func _paint_letterbox(ci: CanvasItem) -> void:
	UiBarks.draw_letterbox(ci, layout, _lb)


func _paint_crown(ci: CanvasItem) -> void:
	var o: Dictionary = _o()
	for m in hub.models:
		var a: Dictionary = anchor_fn.call(m.slot)
		if a.is_empty() or not bool(a.get("visible", true)):
			continue
		var R: float = UiCrown.radius(float(a.get("h", 90.0)), layout.s)
		UiCrown.draw(ci, m, a["pos"], R, _t, layout.s, o)


func _paint_plate(ci: CanvasItem, slot: int) -> void:
	if slot >= hub.models.size():
		return
	var m: UiFighterModel = hub.models[slot]
	UiPlate.draw(ci, m, layout.plate[slot], layout.pm, layout.s, _t, _o(_plate_alpha(m)))


func _paint_sil(ci: CanvasItem, slot: int) -> void:
	if slot >= hub.models.size() or not layout.silhouette_on:
		return
	var m: UiFighterModel = hub.models[slot]
	UiSilhouette.draw(ci, m, layout.silhouette[slot], _t, layout.s, _o(_plate_alpha(m)))


func _paint_toll(ci: CanvasItem) -> void:
	UiCenter.draw_toll(ci, hub, layout, layout.s, _o(0.45 if hub.mode == UiEventHub.Mode.CINEMATIC else 1.0))


func _paint_strip_base(ci: CanvasItem) -> void:
	UiStrip.draw_base(ci, layout, _strip_data, _o())


func _paint_strip_marks(ci: CanvasItem) -> void:
	UiStrip.draw_marks(ci, layout, hub, _strip_data, layout.s, _t, _o())


func _paint_events(ci: CanvasItem) -> void:
	var o: Dictionary = _o()
	UiCards.draw(ci, hub, layout, layout.s, _t, o)
	UiCenter.draw_banner(ci, hub, layout, layout.s, o)
	UiBarks.draw(ci, hub, layout, layout.s, _t, o)


func _paint_feed(ci: CanvasItem) -> void:
	UiFeed.draw(ci, hub, layout, layout.s, _o())


func _paint_debug(ci: CanvasItem) -> void:
	ci.draw_rect(layout.clear_zone, Color(0.2, 1.0, 0.4, 0.08))
	ci.draw_rect(layout.clear_zone, Color(0.2, 1.0, 0.4, 0.7), false, 2.0)
	ci.draw_rect(layout.frame_rect, Color(1.0, 0.8, 0.2, 0.6), false, 1.5)
	if layout.touch_reserve.size.y > 0.0:
		ci.draw_rect(layout.touch_reserve, Color(0.4, 0.6, 1.0, 0.12))


## For Rendering's head-flash arbitration (Art: a flash and the crown are never up together): is this fighter's crown up,
## popped or still fading? False while a transformation cinematic holds the crown down.
func crown_up(actor: int) -> bool:
	return hub.crown_up(actor) or (bool(opts["crown_always"]) and not hub.crown_locked())
