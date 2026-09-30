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
signal howto_opened(first_run: bool)   # the How to play card opened: the host pauses the sim and releases held keys
signal feedback_opened(context: String)   # the feedback panel opened ("pause" or "match_end"): the host pauses the sim and releases held keys
signal feedback_closed()                  # it closed: the host restores the pause it found
signal howto_closed(first_run: bool)   # it closed (from a first run it has then been marked seen)

var hub := UiEventHub.new()
var layout := UiLayout.new()
var anchor_fn: Callable = Callable()   # (slot: int) -> {pos: Vector2, h: float, visible: bool}
var strip_fn: Callable = Callable()    # () -> Dictionary for UiStrip
var split_fn: Callable = Callable()    # () -> Dictionary: Camera's split record (see UiSplit); empty or invalid = one camera
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
	"info_flashes": true,      # Art's danger-sense, found and searching head flashes; Rendering's FlashView reads this (see ui/data/options.json)
	"show_prompts": false,     # control prompts (glyphs on the parry ring, the struggle rings and the prompt row); the host turns it on in training and the first matches
	"glyph_style": "neutral",  # the neutral position-diamond set; "family" (each device family's own letters) stays off until Legal answers
	"hitstop_scale": 1.0,      # Controls' accessibility option, 0.5 to 1.0; the HUD only carries it (see ui/data/options.json)
	"hotseat_alt_layout": false,  # Controls' alternate hot-seat keyboard layout; the HUD only carries it
	"match_end_feedback": true, # the SEND FEEDBACK pill after a KO; the host turns it off if its own results screen has the button
	"keep_hints": false,       # accessibility: a tutorial hint stays up after its beat is done, until the next hint
	"touch_ui": false,         # touch is the last input device (the host sets it; on by default on a phone): a stance ring, a pause button, 48 dp targets
	"vfx_quality": "auto",     # auto, high, medium or low; VFX reads it (docs/vfx/plan.md), the HUD only carries it
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
var _split: Dictionary = {}
var _swapped := false          # slot 0 is on the right (sigma < 0); applied after a 0.1 s fade
var _last_swapped := false
var _swap_fade := 1.0          # the plates' opacity while the columns swap sides
var _anchors: Array = [{}, {}]
var _chips: Array = []
var _chip_text: Array = ["", ""]
var _chip_text_t: Array = [-1.0, -1.0]
var _chip_at: Array = [Vector2.ZERO, Vector2.ZERO]   # where each chip node sits: it eases toward its target so a dodge slides, not pops
var _chip_seen: Array = [false, false]
var _dt := 1.0 / 60.0
var dp := 1.0                  # device pixels per dp (a CSS pixel on the web): set by the host with set_density, else detected
var _last_dp := 1.0
var _last_touch := false
var _l_pause: UiLayer
var _l_howto: UiLayer
var _l_fb: UiLayer
var _l_fbpill: UiLayer
var _fb_open := false
var _fb_state := "write"
var _fb_context := "pause"
var _fb_tags: Dictionary = {}
var _fb_status_ok := false
var _fb_text: TextEdit
var _fb_prev: TextEdit
var feedback_fn: Callable = Callable()   # the host's report context: {commit, date, seed, setup, time, ended}; any key may be missing
var _l_tele: UiLayer
var _l_hint: UiLayer
var _howto_open := false
var _howto_first := false
var _howto_page := 0
# The cached layers, back to front (see UiLayer): each redraws only when its signature changes.
var _l_letter: UiLayer
var _l_strip_base: UiLayer
var _l_crown: UiLayer
var _l_plate: Array = []
var _l_sil: Array = []
var _l_toll: UiLayer
var _l_strip_marks: UiLayer
var _div_dark: ColorRect       # the divider's two bars: transforms only, no draw commands
var _div_light: ColorRect
var _div_key: Array = []
var _l_ring_base: UiLayer
var _l_chips: Array = []       # one small node per pane: an edge pointer chip, moved by position
var _l_ring: UiLayer
var _l_struggle: UiLayer
var _l_prompts: Array = []
var _l_events: UiLayer
var _l_feed: UiLayer
var _l_debug: UiLayer


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(func(): _relayout())
	UiData.ensure()
	opts.merge(UiData.option_defaults(), true)   # the options' defaults live in ui/data/options.json
	_l_letter = _layer(_paint_letterbox)
	_l_strip_base = _layer(_paint_strip_base)
	_div_dark = _bar()
	_div_light = _bar()
	_l_crown = _layer(_paint_crown)
	for i in range(2):
		_l_chips.append(_chip_layer(i))
	_l_struggle = _layer(_paint_struggle)
	for i in range(2):
		_l_prompts.append(_layer(_paint_prompts.bind(i)))
	for i in range(2):
		_l_plate.append(_layer(_paint_plate.bind(i)))
	for i in range(2):
		_l_sil.append(_layer(_paint_sil.bind(i)))
	_l_toll = _layer(_paint_toll)
	_l_strip_marks = _layer(_paint_strip_marks)
	_l_ring_base = _layer(_paint_ring_base)
	_l_ring = _layer(_paint_ring)
	_l_events = _layer(_paint_events)
	_l_feed = _layer(_paint_feed)
	_l_debug = _layer(_paint_debug)
	_l_pause = _layer(_paint_pause)
	_l_tele = _layer(_paint_tele)     # the finisher telegraph and the tutorial hint share the banner slot (telegraph first)
	_l_hint = _layer(_paint_hint)
	_l_fbpill = _layer(_paint_fbpill)
	_l_howto = _layer(_paint_howto)
	_l_fb = _layer(_paint_fb)        # last: over everything
	_fb_text = TextEdit.new()        # the free-text box and the report preview are real text controls, placed by the panel's plan
	_fb_text.visible = false
	_fb_text.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_fb_text.placeholder_text = str(UiData.feedback().get("placeholder", ""))
	add_child(_fb_text)
	_fb_prev = TextEdit.new()
	_fb_prev.visible = false
	_fb_prev.editable = false
	_fb_prev.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	add_child(_fb_prev)
	dp = _detect_density()
	if OS.has_feature("mobile") or OS.has_feature("web_android") or OS.has_feature("web_ios"):
		opts["touch_ui"] = true    # a phone or tablet starts in touch mode; the host flips it with the last input device
	_relayout()


## Device pixels per dp. The host may set it (set_density); otherwise: the browser's devicePixelRatio on the web (a CSS pixel is a
## dp there), the screen's dpi over 160 on a phone, and 1 on a desktop.
func _detect_density() -> float:
	if OS.has_feature("web"):
		var v = JavaScriptBridge.eval("window.devicePixelRatio || 1", true)
		if typeof(v) == TYPE_FLOAT or typeof(v) == TYPE_INT:
			return clampf(float(v), 1.0, 4.0)
		return 1.0
	if OS.has_feature("mobile"):
		return clampf(float(DisplayServer.screen_get_dpi()) / 160.0, 1.0, 4.0)
	return 1.0


func set_density(d: float) -> void:
	dp = clampf(d, 1.0, 4.0)
	_relayout()


func _layer(painter: Callable) -> UiLayer:
	var l := UiLayer.new()
	l.painter = painter
	add_child(l)
	return l


func _bar() -> ColorRect:
	var b := ColorRect.new()
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.visible = false
	add_child(b)
	return b


## An edge pointer chip: a small layer (not full-rect) that the HUD moves with `position`. Moving it redraws nothing.
func _chip_layer(slot: int) -> UiLayer:
	var l: UiLayer = _layer(_paint_chip.bind(slot))
	l.set_anchors_preset(Control.PRESET_TOP_LEFT)
	l.size = UiSplit.pointer_size(1.0)
	l.visible = false
	return l


func _all_layers() -> Array:
	return [_l_letter, _l_strip_base, _l_crown, _l_struggle, _l_toll, _l_strip_marks, _l_ring_base, _l_ring, _l_events, _l_feed, _l_debug] + _l_plate + _l_sil + _l_prompts + _l_chips + [_l_pause, _l_tele, _l_hint, _l_fbpill, _l_howto, _l_fb]


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
	hub.keep_hints = bool(opts["keep_hints"])
	_t += dt
	_dt = dt
	_frame += 1
	hub.captions_on = bool(opts["captions"])
	hub.reduced_motion = bool(opts["reduced_motion"])
	_split = split_fn.call() if split_fn.is_valid() else {}
	_step_swap(dt)
	hub.advance(dt)
	var target: float = 1.0 if hub.mode == UiEventHub.Mode.CINEMATIC else 0.0
	_lb = move_toward(_lb, target, dt * (100.0 if bool(opts["reduced_motion"]) else 4.0))
	_update_layers()


## Which fighter is on the left of the screen: slot 0 unless Camera's sigma says the rival lies to slot 0's left. The plate,
## card and bark columns follow the fighter's side; a swap fades the plates out and in over 0.2 s (instant under reduced motion).
func _want_swapped() -> bool:
	if _split.is_empty():
		return false
	var sg = _split.get("sigma")
	if sg == null and _split.get("ring") is Dictionary:
		sg = (_split["ring"] as Dictionary).get("sigma")
	return sg != null and float(sg) < 0.0


func _step_swap(dt: float) -> void:
	var rate: float = 1000.0 if bool(opts["reduced_motion"]) else 10.0
	if _want_swapped() != _swapped:
		_swap_fade = maxf(0.0, _swap_fade - dt * rate)
		if _swap_fade <= 0.0:
			_swapped = not _swapped
			_relayout()
	else:
		_swap_fade = minf(1.0, _swap_fade + dt * rate)


func set_option(key: String, value) -> void:
	opts[key] = value
	if key == "force_redraw":
		for l in _all_layers():
			if l != null:
				l.force = bool(value)
	if key == "silhouette" or key == "touch_ui":
		_last_size = Vector2.ZERO
	_relayout()
	for l in _all_layers():
		if l != null:
			l.invalidate()


func _relayout() -> void:
	var sz: Vector2 = size if size.x > 1.0 else get_viewport_rect().size
	var sil: bool = bool(opts["silhouette"])
	var touch: bool = bool(opts["touch_ui"])
	if sz == _last_size and sil == _last_sil and insets == _last_insets and _swapped == _last_swapped and dp == _last_dp and touch == _last_touch:
		return
	_last_dp = dp
	_last_touch = touch
	layout.dp = dp
	layout.touch_ui = touch
	_last_size = sz
	_last_sil = sil
	_last_insets = insets
	_last_swapped = _swapped
	layout.compute(sz, sil, insets, _swapped)
	_div_key = [-1]
	# Each model knows which side its column is on (the plate, the cards and the bark lane mirror by it).
	for m in hub.models:
		if m.slot < 2:
			m.left_side = layout.plate[m.slot].position.x < sz.x * 0.5
	hub.cap_limit = 1 if layout.portrait else 99
	for l in _all_layers():
		if l != null:
			l.invalidate()
	if _fb_open:
		_fb_place()
	layout_changed.emit()


func _plate_alpha(m: UiFighterModel) -> float:
	# In a respected cinematic the plates recede, so the set piece owns the screen (docs/ui/hud-spec.md section 8).
	var a: float = 0.45 if (hub.mode == UiEventHub.Mode.CINEMATIC and m.cinematic == "") else 1.0
	return a * _swap_fade


func _o(plate_alpha: float = 1.0) -> Dictionary:
	return {
		"reduced_motion": bool(opts["reduced_motion"]),
		"thickness": float(opts["thickness"]),
		"region_label": bool(opts["region_label"]),
		"plate_alpha": plate_alpha,
		"crown_always": bool(opts["crown_always"]),
		"brink_cue": bool(opts["brink_cue"]),
		"crown_locked": hub.crown_locked(),
		"prompts": bool(opts["show_prompts"]),
		"glyph_style": str(opts["glyph_style"]),
		"touch": bool(opts["touch_ui"]),
		"touch_grid": layout.touch_grid,
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
			m.charging, m.chain_n if m.chain_t >= 0.0 else 0, m.brink, m.shame, full, _plate_alpha(m), pulse,
			m.weight, m.weight_fallback_t < 1.5, m.sig_queued, m.sig_funded, int(m.sig_cap_t * 6.0) if m.sig_funded else 0, m.sig_note if m.sig_note_t < 1.4 else "",
			0 if reduced else int(clampf(1.0 - m.stance_flash_t / 0.8, 0.0, 1.0) * 5.0)])
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

	# Camera's split screen: the divider (only while the panes are open), the ring map (with the strip) and the edge pointers.
	# Cheap by construction: the divider is two bars moved by transform, each chip is a small node moved by position (its
	# picture redraws only when its arrow or number changes), and the ring's disc and track are drawn once.
	_update_divider()
	var ring_on: bool = UiSplit.ring_active(_split) and layout.ring.size.y > 0.0 and _lb < 0.5
	_l_ring_base.update_sig(1 if ring_on else null)
	_l_ring.update_sig(UiSplit.ring_sig(_split) if ring_on else null)
	var chips: Array = []
	if not _split.is_empty() and anchor_fn.is_valid() and _lb < 0.5:
		for i in range(mini(2, hub.models.size())):
			_anchors[i] = anchor_fn.call(i)
		chips = UiSplit.pointers(layout, _split, _anchors, layout.s)
	_chips = chips
	var psz: Vector2 = UiSplit.pointer_size(layout.s)
	for i in range(2):
		var chip: UiLayer = _l_chips[i]
		var found: Dictionary = {}
		for ch in chips:
			if int(ch["slot"]) == i:
				found = ch
		if found.is_empty():
			chip.visible = false
			chip.update_sig(null)
			_chip_seen[i] = false
			continue
		chip.visible = true
		chip.size = psz
		var target: Vector2 = found["pos"]
		if not _chip_seen[i] or bool(opts["reduced_motion"]):
			_chip_at[i] = target
		else:
			_chip_at[i] = (_chip_at[i] as Vector2).lerp(target, 1.0 - exp(-_dt * 20.0))
		_chip_seen[i] = true
		chip.position = (_chip_at[i] as Vector2) - psz * 0.5
		# The number holds for at least a quarter second, so a fast-changing distance redraws the chip at most four times a second.
		if str(found["text"]) != _chip_text[i] and (_t - float(_chip_text_t[i]) >= 0.25 or _chip_text[i] == ""):
			_chip_text[i] = str(found["text"])
			_chip_text_t[i] = _t
		chip.update_sig(UiSplit.chip_sig(i, found["dir"], _chip_text[i], 1.0))

	# The finisher struggle (beat rings on the brink fighter) and each column's prompt row.
	_l_struggle.update_sig(UiStruggle.sig(hub, _frame) if (anchor_fn.is_valid() and not layout.portrait) else null)
	var prompts_on: bool = bool(opts["show_prompts"])
	var touch_on: bool = bool(opts["touch_ui"])
	for m in hub.models:
		if m.slot < _l_prompts.size():
			_l_prompts[m.slot].update_sig(UiPrompts.sig(m, prompts_on, touch_on) if (UiPrompts.has_content(m, prompts_on, touch_on) and layout.prompts[m.slot].size.y > 0.0) else null)
		_l_pause.update_sig([layout.pause_btn, layout.touch_ui] if layout.pause_btn.size.y > 0.0 else null)
	_l_fbpill.update_sig([layout.feedback_btn, layout.touch_ui] if _pill_visible() else null)
	_l_fb.update_sig(UiFeedback.sig(layout.vp, _fb_state, _fb_tags, _fb_status_ok, dp, layout.s, bool(opts["touch_ui"])) if _fb_open else null)
	_l_tele.update_sig(UiReads.telegraph_sig(hub, bool(opts["show_prompts"]), reduced))
	_l_hint.update_sig(UiReads.hint_sig(hub))
	_l_howto.update_sig(UiHowto.sig(layout.vp, _howto_page, _howto_device(), _howto_slot(), bool(opts["touch_ui"]), dp, layout.s) if _howto_open else null)

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


## For Rendering's head-flash arbitration (Art: a flash and the crown are never up together): is this fighter's crown up
## for arbitration, that is popped for wear or still fading? False at rest, false during a transformation cinematic, and
## ALWAYS false with the `crown_always` accessibility option: that option must never remove the flash channel. Instead the
## always-on crown dims under a flash: tell the HUD with set_flash_up.
func crown_up(actor: int) -> bool:
	if bool(opts["crown_always"]):
		return false
	return hub.crown_up(actor)


## Rendering reports whether a head flash is up on a fighter. It only matters with `crown_always` (the crown then dims to
## 30% under the flash); in normal play the arbitration keeps a flash and a pop apart.
func set_flash_up(actor: int, up: bool) -> void:
	var m: UiFighterModel = hub.model(actor)
	if m != null:
		m.flash_up = up


## Whether the player wants the info flashes (danger sense, found, searching). On by default; Rendering's FlashView reads it.
func info_flashes() -> bool:
	return bool(opts["info_flashes"])


func _paint_struggle(ci: CanvasItem) -> void:
	var slot: int = int(hub.struggle.get("actor", -1))
	if slot < 0 or not anchor_fn.is_valid():
		return
	UiStruggle.draw(ci, hub, layout, anchor_fn.call(slot), layout.s, _o())


# --- The How to play card (docs/ui/hud-spec.md section 17) -------------------------------------------------------------------

## Open the card. `first_run` marks it as the first-run overlay (closing it then records that the player has seen it). The host
## calls this at the first match if not howto_seen(), and from the pause menu's "How to play" entry; F1 also toggles it. While it
## is open the HUD takes every key and click (so the fighters do not move behind it): the host should freeze the sim on
## howto_opened and unfreeze on howto_closed.
func show_howto(first_run: bool = false, page: int = 0) -> void:
	if _howto_open or _fb_open:
		return
	_howto_open = true
	_howto_first = first_run
	_howto_page = clampi(page, 0, maxi(UiHowto.page_count() - 1, 0))
	_l_howto.invalidate()
	howto_opened.emit(first_run)


func hide_howto() -> void:
	if not _howto_open:
		return
	_howto_open = false
	var was_first: bool = _howto_first
	_howto_first = false
	if was_first:
		mark_howto_seen()
	_l_howto.update_sig(null)
	howto_closed.emit(was_first)


func is_howto_open() -> bool:
	return _howto_open


func howto_page() -> int:
	return _howto_page


func howto_seen() -> bool:
	return UiPrefs.get_bool("howto_seen")


func mark_howto_seen() -> void:
	UiPrefs.set_bool("howto_seen", true)


## One of "next", "back", "close" (what a key or a tap does). "next" on the last page closes.
func howto_action(act: String) -> void:
	if not _howto_open:
		return
	match act:
		"next":
			if _howto_page >= UiHowto.page_count() - 1:
				hide_howto()
			else:
				_howto_page += 1
				_l_howto.invalidate()
		"back":
			if _howto_page > 0:
				_howto_page -= 1
				_l_howto.invalidate()
		"close":
			hide_howto()


## The glyph family and slot of the first human fighter, for the controls page ("kbd" and slot 0 if none is set).
func _howto_device() -> String:
	for m in hub.models:
		if not m.ai and m.device != "":
			return m.device
	return "kbd"


func _howto_slot() -> int:
	for m in hub.models:
		if not m.ai:
			return m.slot
	return 0


func howto_plan() -> Dictionary:
	return UiHowto.plan(layout.vp, layout.s, dp, bool(opts["touch_ui"]), _howto_page, _howto_device(), _howto_slot())


func _paint_howto(ci: CanvasItem) -> void:
	if not _howto_open:
		return
	UiHowto.draw(ci, howto_plan(), _howto_device(), _howto_slot(), str(opts["glyph_style"]), bool(opts["touch_ui"]))


func _unhandled_input(event: InputEvent) -> void:
	if _fb_open:
		# The panel owns every key and click (the two text boxes take their own before this runs).
		if event is InputEventKey:
			if event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
				hide_feedback()
			get_viewport().set_input_as_handled()
		elif event is InputEventJoypadButton:
			if event.pressed and (event.button_index == JOY_BUTTON_B or event.button_index == JOY_BUTTON_START):
				hide_feedback()
			get_viewport().set_input_as_handled()
		elif event is InputEventMouseButton:
			if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
				_fb_click(event.position)
			get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and _pill_visible() and layout.feedback_btn.has_point(event.position):
		show_feedback("match_end")
		get_viewport().set_input_as_handled()
		return
	# F1 opens or closes the card from anywhere; while it is open the HUD owns every key and click.
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F1:
		if _howto_open:
			hide_howto()
		else:
			show_howto(false)
		get_viewport().set_input_as_handled()
		return
	if not _howto_open:
		return
	if event is InputEventKey:
		if event.pressed and not event.echo:
			match event.keycode:
				KEY_ENTER, KEY_KP_ENTER, KEY_SPACE, KEY_RIGHT:
					howto_action("next")
				KEY_LEFT, KEY_BACKSPACE:
					howto_action("back")
				KEY_ESCAPE:
					howto_action("close")
		get_viewport().set_input_as_handled()
	elif event is InputEventJoypadButton:
		if event.pressed:
			match event.button_index:
				JOY_BUTTON_A, JOY_BUTTON_DPAD_RIGHT:
					howto_action("next")
				JOY_BUTTON_DPAD_LEFT:
					howto_action("back")
				JOY_BUTTON_B, JOY_BUTTON_START:
					howto_action("close")
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton:
		# A tap arrives as a mouse click too (Godot emulates it), so only clicks are handled: one tap, one action.
		if event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			var pl: Dictionary = howto_plan()
			var pos: Vector2 = event.position
			if (pl["close"] as Rect2).has_point(pos):
				howto_action("close")
			elif (pl["next"] as Rect2).has_point(pos):
				howto_action("next")
			elif not pl["is_first"] and (pl["back"] as Rect2).has_point(pos):
				howto_action("back")
		get_viewport().set_input_as_handled()


# --- The feedback panel (docs/ui/hud-spec.md section 20) ----------------------------------------------------------------------

## Open the feedback panel. `context` is "pause" (from the pause menu) or "match_end" (from the pill after a KO). While it is open the
## HUD takes every key and click, like the How to play card: the host pauses the sim on feedback_opened and restores the pause it
## found on feedback_closed. Nothing is sent anywhere: COPY REPORT puts plain text on the clipboard.
func show_feedback(context: String = "pause") -> void:
	if _fb_open or _howto_open:
		return
	_fb_open = true
	_fb_context = context
	_fb_state = UiFeedback.STATE_WRITE
	_fb_status_ok = false
	_fb_tags = {}
	_fb_text.text = ""
	_fb_place()
	_l_fb.invalidate()
	feedback_opened.emit(context)


func hide_feedback() -> void:
	if not _fb_open:
		return
	_fb_open = false
	_fb_text.visible = false
	_fb_prev.visible = false
	_fb_text.release_focus()
	_l_fb.update_sig(null)
	feedback_closed.emit()


func is_feedback_open() -> bool:
	return _fb_open


func toggle_feedback_tag(id: String) -> void:
	if _fb_open and _fb_state == UiFeedback.STATE_WRITE:
		_fb_tags[id] = not bool(_fb_tags.get(id, false))
		_l_fb.invalidate()


func feedback_selected_tags() -> Array:
	var out: Array = []
	for t in UiFeedback.tag_list():
		if bool(_fb_tags.get(str(t["id"]), false)):
			out.append(str(t["id"]))
	return out


## What the report says about this match: the host's context over the build's own info, with the HUD's own facts as the fallback.
func feedback_context() -> Dictionary:
	var ctx: Dictionary = UiFeedback.build_info()
	if feedback_fn.is_valid():
		var h = feedback_fn.call()
		if h is Dictionary:
			ctx.merge(h, true)
	if not ctx.has("setup") or str(ctx["setup"]) == "":
		var parts: PackedStringArray = []
		for m in hub.models:
			parts.append("%s (%s)" % [m.name, UiFeedback.word("ai") if m.ai else UiFeedback.word("you") + (", " + m.device if m.device != "" else "")])
		ctx["setup"] = " vs ".join(parts)
	if not ctx.has("time"):
		ctx["time"] = hub.t_now
	if not ctx.has("ended"):
		ctx["ended"] = hub.match_over
	return ctx


## The report as plain text: the tags and the typed notes, with the platform, the screen and the settings.
func feedback_report() -> String:
	var env := {"screen": layout.vp, "dp": dp, "touch": bool(opts["touch_ui"]), "platform": UiFeedback.platform_info(), "settings": UiFeedback.settings_line(opts)}
	return UiFeedback.build_report(feedback_context(), feedback_selected_tags(), _fb_text.text, env)


## COPY REPORT: put the report on the clipboard and show it in the read-only box too, for a browser that refuses the write.
func copy_feedback() -> String:
	var text: String = feedback_report()
	DisplayServer.clipboard_set(text)
	_fb_prev.text = text
	_fb_state = UiFeedback.STATE_COPIED
	_fb_status_ok = true
	_fb_place()
	_l_fb.invalidate()
	return text


func feedback_action(act: String) -> void:
	if not _fb_open:
		return
	match act:
		"copy", "again":
			copy_feedback()
		"back":
			_fb_state = UiFeedback.STATE_WRITE
			_fb_status_ok = false
			_fb_place()
			_l_fb.invalidate()
		"close":
			hide_feedback()


func feedback_plan() -> Dictionary:
	return UiFeedback.plan(layout.vp, layout.s, dp, bool(opts["touch_ui"]), _fb_state)


## Place the two text boxes on the panel's plan and size their type to it.
func _fb_place() -> void:
	var p: Dictionary = feedback_plan()
	var write: bool = _fb_state == UiFeedback.STATE_WRITE
	_fb_text.visible = _fb_open and write
	_fb_prev.visible = _fb_open and not write
	var fs: int = int(p["fs_body"])
	for box in [_fb_text, _fb_prev]:
		box.add_theme_font_size_override("font_size", fs)
	var r: Rect2 = p["text_rect"] if write else p["preview_rect"]
	var box2: TextEdit = _fb_text if write else _fb_prev
	box2.position = r.position
	box2.size = r.size
	if write and _fb_open and not bool(opts["touch_ui"]):
		_fb_text.grab_focus()   # a touch screen waits for a tap, so its keyboard does not jump up on its own


func _pill_visible() -> bool:
	return hub.match_over and bool(opts["match_end_feedback"]) and not _fb_open and not _howto_open and layout.feedback_btn.size.y > 0.0


func _fb_click(pos: Vector2) -> void:
	var p: Dictionary = feedback_plan()
	if (p["close"] as Rect2).has_point(pos):
		hide_feedback()
		return
	if _fb_state == UiFeedback.STATE_WRITE:
		for chip in p["tags"]:
			if (chip["rect"] as Rect2).has_point(pos):
				toggle_feedback_tag(str(chip["id"]))
				return
		if (p["copy"] as Rect2).has_point(pos):
			copy_feedback()
		elif (p["done"] as Rect2).has_point(pos):
			hide_feedback()
	else:
		if (p["back"] as Rect2).has_point(pos):
			feedback_action("back")
		elif (p["again"] as Rect2).has_point(pos):
			copy_feedback()
		elif (p["done"] as Rect2).has_point(pos):
			hide_feedback()


func _paint_fb(ci: CanvasItem) -> void:
	if _fb_open:
		UiFeedback.draw(ci, feedback_plan(), _fb_tags)


func _paint_fbpill(ci: CanvasItem) -> void:
	UiFeedback.draw_pill(ci, layout.feedback_btn, layout.s, layout.feedback_label, layout.feedback_fs)


func _paint_tele(ci: CanvasItem) -> void:
	UiReads.draw_telegraph(ci, hub, layout, layout.s, bool(opts["show_prompts"]), bool(opts["reduced_motion"]))


func _paint_hint(ci: CanvasItem) -> void:
	UiReads.draw_hint(ci, hub, layout, layout.s)


func _paint_pause(ci: CanvasItem) -> void:
	var r: Rect2 = layout.pause_btn
	if r.size.y <= 0.0:
		return
	UiIcons.rrect(ci, r, r.size.y * 0.25, Color(UiLook.col(UiLook.SCRIM), 0.7), Color(UiLook.col(UiLook.EDGE), 0.6), 1.6)
	var c: Vector2 = r.get_center()
	var bw: float = r.size.x * 0.11
	var bh: float = r.size.y * 0.32
	var ink := Color(UiLook.col(UiLook.INK), 0.95)
	ci.draw_rect(Rect2(c.x - bw * 1.8, c.y - bh, bw, bh * 2.0), ink)
	ci.draw_rect(Rect2(c.x + bw * 0.8, c.y - bh, bw, bh * 2.0), ink)


## The touch targets the HUD owns, name to global rectangle: the stance ring of each human fighter ("stance_0" to "stance_3",
## with a "slot" in touch_target_at) and "pause". Empty unless the touch_ui option is on. Controls hit-tests these; the HUD
## never consumes a touch itself (docs/controls/platform-plan.md section 7).
func touch_rects() -> Dictionary:
	var out: Dictionary = {}
	if not bool(opts["touch_ui"]):
		return out
	for m in hub.models:
		if m.slot < 2 and not m.ai:
			var t: Dictionary = UiPrompts.touch_rects(m, layout.prompts[m.slot], layout.s, _o())
			for k in t:
				out["%s_p%d" % [k, m.slot]] = t[k]
	if layout.pause_btn.size.y > 0.0:
		out["pause"] = layout.pause_btn
	if _pill_visible():
		out["feedback"] = layout.feedback_btn
	return out


## Which target a screen point is on: {name, slot, stance} (slot -1 for the pause button), or {} if none.
func touch_target_at(p: Vector2) -> Dictionary:
	var r: Dictionary = touch_rects()
	for k in r:
		if (r[k] as Rect2).has_point(p):
			if k == "pause":
				return {"name": "pause", "slot": -1}
			if k == "feedback":
				return {"name": "feedback", "slot": -1}
			var parts: PackedStringArray = str(k).split("_p")
			return {"name": "stance", "slot": int(parts[1]), "stance": int(str(parts[0]).get_slice("_", 1))}
	return {}


func _paint_prompts(ci: CanvasItem, slot: int) -> void:
	if slot >= hub.models.size():
		return
	UiPrompts.draw(ci, hub.models[slot], layout.prompts[slot], layout.s, _o())


## The device family that last sent input for a slot (kbd, xbox, ps, switch, deck, generic): prompts use its glyphs.
func set_device(slot: int, family: String) -> void:
	var m: UiFighterModel = hub.model(slot)
	if m != null and m.device != family:
		m.device = family


func _paint_ring_base(ci: CanvasItem) -> void:
	UiSplit.draw_ring_base(ci, layout, layout.s, _o())


func _paint_ring(ci: CanvasItem) -> void:
	UiSplit.draw_ring_marks(ci, layout, hub, _split, layout.s, _o())


func _paint_chip(ci: CanvasItem, slot: int) -> void:
	for ch in _chips:
		if int(ch["slot"]) == slot:
			UiSplit.draw_chip(ci as Control, hub, slot, ch["dir"], _chip_text[slot], layout.s, _o())


## The divider's two bars (a dark edge under a light line): transform only, no draw commands. Updated when its rounded
## geometry changes.
func _update_divider() -> void:
	var geo: Dictionary = {}
	if UiSplit.divider_active(_split) and _lb < 0.5:
		geo = UiSplit.divider_geometry(layout, _split, layout.s)
	var key: Array = UiSplit.divider_key(geo)
	if key == _div_key:
		return
	_div_key = key
	var on: bool = not geo.is_empty()
	_div_dark.visible = on
	_div_light.visible = on
	if not on:
		return
	var len: float = float(geo["len"])
	var w: float = float(geo["w"])
	var a: float = float(geo["a"])
	var slam: float = float(geo["slam"])
	for pair in [[_div_dark, w + 3.0], [_div_light, w]]:
		var bar: ColorRect = pair[0]
		var bw: float = pair[1]
		bar.size = Vector2(len, bw)
		bar.pivot_offset = bar.size * 0.5
		bar.position = (geo["mid"] as Vector2) - bar.size * 0.5
		bar.rotation = float(geo["angle"])
	_div_dark.color = Color(UiLook.col(UiLook.INK_DARK), 0.5 * a)
	_div_light.color = Color(UiLook.col(UiLook.INK), lerpf(0.55, 1.0, slam) * a)


## The clear zone of a fighter's pane while the panes are open (a polygon; empty when there is no divider). The fighter's
## anchor should stay inside it (Camera's test uses this).
func pane_clear_zone(slot: int) -> PackedVector2Array:
	if not UiSplit.divider_active(_split):
		return PackedVector2Array()
	return layout.pane_zone(slot == 1, _split["c"], _split["n"])
