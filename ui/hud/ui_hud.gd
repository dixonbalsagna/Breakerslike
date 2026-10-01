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
signal option_changed(key: String, value)   # set_option changed an option's value: the host applies the ones it owns (pad_preset to SimInputHub.pad_preset)
signal settings_opened                     # the Settings screen opened: the host pauses the sim and releases held keys (as for How to play)
signal settings_closed                     # it closed: the host restores the pause it found
signal settings_action_requested(action: String)   # a button on the screen was pressed ("remap"): the host opens what it names
signal remap_changed(layout_id: String, overrides: Array)   # the player changed a layout's controls: the host applies the rows (Controls' applier) and saves
signal pause_menu_opened                   # the pause menu opened: the host freezes the sim and lets go of held keys
signal pause_menu_closed(reason: String)   # it closed: "resume" (the host unfreezes) or "new" (the host unfreezes and starts a match)
signal pause_entry(entry: String)          # an entry was chosen: resume, howto, settings, feedback, new (then new_yes or new_no)
signal new_match_requested                 # New match was confirmed
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
	"control_hints": "auto",   # the legend of the player's controls: auto (match start and first matches), always, off
	"control_scheme": "",      # "" = the scheme of the player's own layout (ui/data/hints.json); a layout id forces one (a preview or a test)
	"camera_zoom": 7,          # Camera's framing, 0 to 10 (render/camera reads it from these opts); the HUD only carries it
	"camera_shake": 2,         # Camera's shake, 0 to 10 (an accessibility option); the HUD only carries it
	"pad_preset": "arena",     # the pad layout in use (arena, brawler or simple-pad); the host keeps it equal to SimInputHub.pad_preset
	"match_end_feedback": true, # the SEND FEEDBACK pill after a KO; the host turns it off if its own results screen has the button
	"keep_hints": false,       # accessibility: a tutorial hint stays up after its beat is done, until the next hint
	"touch_preset": "touch-simple",  # touch-simple (attack, guard, power) or touch-full (nine buttons); the host sets SimInputHub.set_touch_preset from option_changed
	"left_handed": false,      # touch: the buttons on the left, the stick on the right (SimTouch mirrors its layout)
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
var _last_lh := false
var _l_pause: UiLayer
var _l_howto: UiLayer
var _l_settings: UiLayer
var _l_pmenu: UiLayer
var _pm_open := false
var _pm_confirm := false              # New match is asking "Start a new match?"
var _pm_focus := 0                    # index into UiPause.ids(_pm_confirm)
var _pm_down := ""                    # the button a press started on (a release over the same one chooses it)
var _l_remap: UiLayer
var _rm_open := false
var _rm_direct := false               # opened without the Settings screen under it (closing it then closes Settings too)
var _rm_layout := ""                  # the layout being changed (a preset id)
var _rm_focus := 0
var _rm_scroll := 0.0
var _rm_mode := "list"                # "list", "capture" (waiting for a key or button) or "confirm" (a swap is offered)
var _rm_entry := ""                   # the entry being captured (an action id)
var _rm_keys: Array = []              # Fly's keys taken so far, in order up, left, down, right
var _rm_pending: Dictionary = {}      # a conflict waiting for an answer: {control, with}
var _rm_status := ""
var _rm_drag: Dictionary = {}
var _set_open := false
var _set_focus := -1                  # the focused row of UiSettings.rows()
var _set_scroll := 0.0
var _set_drag: Dictionary = {}        # a press in progress: {mode: "slider" | "tap" | "scroll", row, part, y0, scroll0, moved}
var _set_axis: Dictionary = {}        # pad stick axis -> -1, 0 or 1 (a push is one step, like a key press)
var _set_device := "kbd"              # the last device that drove the screen ("kbd" or "pad"): which key hint it shows
var _saved_opts: Dictionary = {}      # the options the player changed on the Settings screen (kept in UiPrefs, applied by load_saved_options)
var _l_fb: UiLayer
var _l_hints: Array = []
var _l_you: UiLayer
var _hint_t0: Array = [0.0, 0.0]       # when each fighter became a human (the legend shows for 12 s from then)
var _prev_ai: Array = [true, true]
var _prev_clock := 0.0
var _l_fbpill: UiLayer
var _fb_open := false
var _fb_state := "write"
var _fb_context := "pause"
var _fb_tags: Dictionary = {}
var _fb_status_ok := false
var _fb_issue: Dictionary = {}          # the prefilled GitHub link the review state offers: {url, fallback, body}
var _fb_opened := false                 # OPEN ISSUE was pressed in this review
var _fb_text: TextEdit
var _fb_prev: TextEdit
var touch_state_fn: Callable = Callable()   # the host's touch state for drawing: {attack: {down, hold}, guard: {down}, power: {down}, stick: {active, base, thumb, sprint}, transform: {down}}
var _l_touchctl: UiLayer
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
		_l_hints.append(_layer(_paint_hints.bind(i)))
	_l_you = _layer(_paint_you)
	_l_touchctl = _layer(_paint_touchctl)
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
	_l_pmenu = _layer(_paint_pmenu)
	_l_howto = _layer(_paint_howto)
	_l_settings = _layer(_paint_settings)
	_l_remap = _layer(_paint_remap)
	_l_fb = _layer(_paint_fb)        # last: over everything
	_fb_text = TextEdit.new()        # the free-text box and the report preview are real text controls, placed by the panel's plan
	_fb_text.visible = false
	_fb_text.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	_fb_text.placeholder_text = str(UiData.feedback().get("placeholder", ""))
	_fb_text.text_changed.connect(_fb_sync)
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
	return [_l_letter, _l_strip_base, _l_crown, _l_struggle, _l_toll, _l_strip_marks, _l_ring_base, _l_ring, _l_events, _l_feed, _l_debug] + _l_plate + _l_sil + _l_prompts + _l_hints + [_l_you, _l_touchctl] + _l_chips + [_l_pause, _l_tele, _l_hint, _l_fbpill, _l_pmenu, _l_howto, _l_settings, _l_remap, _l_fb]


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
	value = UiData.clamp_option(key, value)
	var changed: bool = not opts.has(key) or opts[key] != value
	opts[key] = value
	if changed:
		option_changed.emit(key, value)
	if key == "force_redraw":
		for l in _all_layers():
			if l != null:
				l.force = bool(value)
	if key == "silhouette" or key == "touch_ui" or key == "left_handed" or key == "touch_preset":
		_last_size = Vector2.ZERO
	_relayout()
	for l in _all_layers():
		if l != null:
			l.invalidate()


func _relayout() -> void:
	var sz: Vector2 = size if size.x > 1.0 else get_viewport_rect().size
	var sil: bool = bool(opts["silhouette"])
	var touch: bool = bool(opts["touch_ui"])
	if sz == _last_size and sil == _last_sil and insets == _last_insets and _swapped == _last_swapped and dp == _last_dp and touch == _last_touch and bool(opts["left_handed"]) == _last_lh and (str(opts["touch_preset"]) == "touch-full") == layout.touch_full:
		return
	_last_dp = dp
	_last_touch = touch
	_last_lh = bool(opts["left_handed"])
	layout.dp = dp
	layout.left_handed = bool(opts["left_handed"])
	layout.touch_full = str(opts["touch_preset"]) == "touch-full"
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
	hub.cap_limit = 0 if layout.cards_none else (1 if (layout.portrait or layout.cards_one) else 99)
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
		"control_scheme": str(opts["control_scheme"]),
		"pad_preset": str(opts["pad_preset"]),
		"humans": _humans(),
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
			m.charging, m.chain_n if m.chain_t >= 0.0 else 0, m.brink, m.shame, full, _plate_alpha(m), pulse, m.you_label,
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
	# Who is the player (YOU), and the control legend: it shows for 12 s from the match start, or from the moment a fighter became human.
	if hub.t_now < _prev_clock:
		_hint_t0 = [0.0, 0.0]
	_prev_clock = hub.t_now
	var you_sig: Array = []
	for m in hub.models:
		if m.slot < 2:
			m.you_label = UiHints.you_label(hub.models, m)
			if _prev_ai[m.slot] and not m.ai:
				_hint_t0[m.slot] = hub.t_now
			_prev_ai[m.slot] = m.ai
			var ya: float = UiHints.visible_alpha(m, str(opts["control_hints"]), prompts_on, hub.t_now - float(_hint_t0[m.slot]))
			var ha: float = 0.0 if (touch_on or layout.portrait) else ya   # the legend is for a keyboard or a pad; the YOU marker is for every screen
			if ya > 0.01 and m.you_label != "" and anchor_fn.is_valid():
				var an: Dictionary = anchor_fn.call(m.slot)
				var ap: Vector2 = an.get("pos", Vector2.ZERO)
				you_sig.append([m.slot, m.you_label, int(ap.x * 0.5), int(ap.y * 0.5), int(float(an.get("h", 0.0)) * 0.5), int(ya * 10.0), bool(an.get("visible", true))])
			_l_hints[m.slot].update_sig(UiHints.sig(m, ha, UiHints.preset_id(m, _o())) if (ha > 0.01 and layout.hints[m.slot].size.y > 0.0) else null)
	_l_you.update_sig(you_sig if not you_sig.is_empty() else null)
	# The touch buttons: drawn from SimTouch.layout (UiLayout.touch_ctrl) with the host's state; redrawn only when something about them changes.
	if touch_on and not layout.touch_ctrl.is_empty():
		var tstate: Dictionary = _touch_state()
		_l_touchctl.update_sig(UiTouchControls.sig(layout, tstate, _touch_intro_alpha(), _transform_avail()))
	else:
		_l_touchctl.update_sig(null)
	for m in hub.models:
		if m.slot < _l_prompts.size():
			_l_prompts[m.slot].update_sig(UiPrompts.sig(m, prompts_on, touch_on, UiHints.preset_id(m, _o())) if (UiPrompts.has_content(m, prompts_on, touch_on) and layout.prompts[m.slot].size.y > 0.0) else null)
		_l_pause.update_sig([layout.pause_btn, layout.touch_ui] if layout.pause_btn.size.y > 0.0 else null)
	_l_fbpill.update_sig([layout.feedback_btn, layout.touch_ui] if _pill_visible() else null)
	_l_fb.update_sig(UiFeedback.sig(layout.vp, _fb_state, _fb_tags, _fb_status_ok, dp, layout.s, bool(opts["touch_ui"]), "%s|%s" % [_fb_opened, bool(_fb_issue.get("fallback", false))]) if _fb_open else null)
	_l_tele.update_sig(UiReads.telegraph_sig(hub, bool(opts["show_prompts"]), reduced))
	_l_hint.update_sig(UiReads.hint_sig(hub))
	_l_howto.update_sig(UiHowto.sig(layout.vp, _howto_page, _howto_device(), _howto_slot(), bool(opts["touch_ui"]), dp, layout.s, _howto_preset() + str(opts["glyph_style"])) if _howto_open else null)

	_l_pmenu.update_sig(UiPause.sig(pause_menu_plan()) if _pm_open else null)
	_l_settings.update_sig(_settings_sig() if (_set_open and not _rm_open) else null)
	_l_remap.update_sig(_remap_sig() if _rm_open else null)

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
	if _howto_open or _fb_open or _set_open:
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


## The layout id the controls page describes: the first human's own (touch-simple on touch, kb-solo or a shared half, a pad preset).
func _howto_preset() -> String:
	for m in hub.models:
		if not m.ai:
			return UiHints.preset_id(m, _o())
	return "touch-simple" if bool(opts["touch_ui"]) else UiHints.preset_id(hub.models[0], _o())


func howto_plan() -> Dictionary:
	return UiHowto.plan(layout.vp, layout.s, dp, bool(opts["touch_ui"]), _howto_page, _howto_device(), _howto_slot(), _howto_preset(), str(opts["glyph_style"]))


func _paint_howto(ci: CanvasItem) -> void:
	if not _howto_open:
		return
	UiHowto.draw(ci, howto_plan(), _howto_device(), _howto_slot(), str(opts["glyph_style"]), bool(opts["touch_ui"]))


func _unhandled_input(event: InputEvent) -> void:
	if _pm_open and not (_rm_open or _set_open or _fb_open or _howto_open):
		_pause_input(event)
		return
	if _rm_open:
		_remap_input(event)
		return
	if _set_open:
		_settings_input(event)
		return
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


# --- The pause menu (docs/ui/hud-spec.md section 28) ---------------------------------------------------------------------------------

## Open or close the pause menu: the host's pause key, pause button and Start call this. Opening emits pause_menu_opened (the host freezes the
## sim and lets go of held keys); closing it is a Resume. While the menu is open the HUD takes every key, pad button and click, and the
## How to play card, Settings and Send feedback open over it and give it back when they close. Does nothing while one of those is open.
func toggle_pause_menu() -> void:
	if _pm_open:
		if not (_rm_open or _set_open or _fb_open or _howto_open):
			_pm_close("resume")
	else:
		show_pause_menu()


func show_pause_menu() -> void:
	if _pm_open or _howto_open or _fb_open or _set_open:
		return
	_pm_open = true
	_pm_confirm = false
	_pm_focus = 0
	_pm_down = ""
	_l_pmenu.invalidate()
	pause_menu_opened.emit()


func _pm_close(reason: String) -> void:
	if not _pm_open:
		return
	_pm_open = false
	_pm_confirm = false
	_pm_down = ""
	_l_pmenu.update_sig(null)
	pause_menu_closed.emit(reason)


func is_pause_menu_open() -> bool:
	return _pm_open


func pause_menu_focus() -> int:
	return _pm_focus


func pause_menu_plan() -> Dictionary:
	return UiPause.plan(layout.vp, layout.s, dp, bool(opts["touch_ui"]), {"focus": _pm_focus, "confirm": _pm_confirm})


func _paint_pmenu(ci: CanvasItem) -> void:
	if _pm_open:
		UiPause.draw(ci, pause_menu_plan())


## Choose an entry by id (what a press, a tap or Enter on the focused button does).
func pause_menu_choose(id: String) -> void:
	if not _pm_open:
		return
	pause_entry.emit(id)
	match id:
		"resume":
			_pm_close("resume")
		"howto":
			show_howto(false)
		"settings":
			show_settings()
		"feedback":
			show_feedback("pause")
		"new":
			_pm_confirm = true
			_pm_focus = 1   # Keep playing is where the focus starts: the match is not lost by a stray Enter
		"new_yes":
			_pm_close("new")
			new_match_requested.emit()
		"new_no":
			_pm_confirm = false
			_pm_focus = UiPause.ENTRIES.find("new")
	_l_pmenu.invalidate()


## One of "up", "down", "left", "right", "accept", "back" (what a key, a pad button or a stick push does).
func pause_menu_action(act: String) -> void:
	if not _pm_open:
		return
	var p: Dictionary = pause_menu_plan()
	var list: Array = UiPause.ids(_pm_confirm)
	match act:
		"up":
			_pm_focus = UiPause.moved(p, _pm_focus, 0, -1)
		"down":
			_pm_focus = UiPause.moved(p, _pm_focus, 0, 1)
		"left":
			_pm_focus = UiPause.moved(p, _pm_focus, -1, 0)
		"right":
			_pm_focus = UiPause.moved(p, _pm_focus, 1, 0)
		"accept":
			pause_menu_choose(str(list[clampi(_pm_focus, 0, list.size() - 1)]))
		"back":
			if _pm_confirm:
				pause_menu_choose("new_no")
			else:
				_pm_close("resume")
	_l_pmenu.invalidate()


func _pause_input(event: InputEvent) -> void:
	if event is InputEventKey:
		_set_device = "kbd"
		if event.pressed and not event.echo or (event.pressed and event.echo and event.keycode in [KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT]):
			var act := ""
			match event.keycode:
				KEY_UP, KEY_W:
					act = "up"
				KEY_DOWN, KEY_S, KEY_TAB:
					act = "down"
				KEY_LEFT, KEY_A:
					act = "left"
				KEY_RIGHT, KEY_D:
					act = "right"
				KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
					act = "accept"
				KEY_ESCAPE, KEY_P:
					act = "back"
				KEY_F1:
					pause_menu_choose("howto")
				KEY_N:
					if not _pm_confirm:
						pause_menu_choose("new")
			if act != "":
				pause_menu_action(act)
	elif event is InputEventJoypadButton:
		_set_device = "pad"
		if event.pressed:
			match event.button_index:
				JOY_BUTTON_DPAD_UP:
					pause_menu_action("up")
				JOY_BUTTON_DPAD_DOWN:
					pause_menu_action("down")
				JOY_BUTTON_DPAD_LEFT:
					pause_menu_action("left")
				JOY_BUTTON_DPAD_RIGHT:
					pause_menu_action("right")
				JOY_BUTTON_A:
					pause_menu_action("accept")
				JOY_BUTTON_B, JOY_BUTTON_START:
					pause_menu_action("back")
	elif event is InputEventJoypadMotion:
		var ax: int = event.axis
		if ax == JOY_AXIS_LEFT_X or ax == JOY_AXIS_LEFT_Y:
			var v: float = event.axis_value
			var was: int = int(_set_axis.get(ax, 0))
			var now: int = 0
			if v > 0.6:
				now = 1
			elif v < -0.6:
				now = -1
			elif absf(v) > 0.3:
				now = was
			if now != was:
				_set_axis[ax] = now
				if now != 0:
					_set_device = "pad"
					pause_menu_action(("right" if now > 0 else "left") if ax == JOY_AXIS_LEFT_X else ("down" if now > 0 else "up"))
	elif event is InputEventMouseButton:
		_set_device = "kbd"
		if event.button_index == MOUSE_BUTTON_LEFT:
			var id: String = UiPause.hit(pause_menu_plan(), event.position)
			if event.pressed:
				_pm_down = id
				var list: Array = UiPause.ids(_pm_confirm)
				if id != "" and list.has(id):
					_pm_focus = list.find(id)
					_l_pmenu.invalidate()
			else:
				var started: String = _pm_down
				_pm_down = ""
				if id != "" and id == started:
					pause_menu_choose(id)
	get_viewport().set_input_as_handled()


# --- The Settings screen (docs/ui/hud-spec.md section 26) ---------------------------------------------------------------------

## Open the Settings screen (the host's pause menu entry). While it is open the HUD takes every key, pad button and click (so no fighter
## moves behind it): the host should freeze the sim on settings_opened and restore the pause it found on settings_closed, as for How to
## play, and skip its own pad handling while is_settings_open() (see is_overlay_open()). Every change goes through set_option, so
## option_changed fires as it always does; the changes are kept for the next run (load_saved_options).
func show_settings() -> void:
	if _set_open or _howto_open or _fb_open:
		return
	_set_open = true
	_set_scroll = 0.0
	_set_drag = {}
	_set_axis = {}
	var fo: Array = UiSettings.focusable(UiSettings.rows())
	_set_focus = int(fo[0]) if not fo.is_empty() else -1
	_set_scroll = UiSettings.scroll_to(settings_plan(), _set_focus, 0.0) if _set_focus >= 0 else 0.0
	_l_settings.invalidate()
	settings_opened.emit()


func hide_settings() -> void:
	if not _set_open:
		return
	_rm_open = false
	_rm_mode = "list"
	_l_remap.update_sig(null)
	_set_open = false
	_set_drag = {}
	_l_settings.update_sig(null)
	settings_closed.emit()


func is_settings_open() -> bool:
	return _set_open


## Any of the three overlays (How to play, feedback, Settings) is open: the host leaves keys, pad and touch to the HUD.
func is_overlay_open() -> bool:
	return _howto_open or _fb_open or _set_open or _pm_open


func settings_focus() -> int:
	return _set_focus


func settings_plan() -> Dictionary:
	return UiSettings.plan(layout.vp, layout.s, dp, bool(opts["touch_ui"]), {"focus": _set_focus, "scroll": _set_scroll, "device": _set_device}, opts)


func _settings_sig() -> Array:
	return UiSettings.sig(settings_plan(), opts, bool(opts["touch_ui"])) + [_set_device]


func _paint_settings(ci: CanvasItem) -> void:
	if _set_open:
		UiSettings.draw(ci, settings_plan(), opts)


## Change an option from the screen: through set_option (the clamp and option_changed), and remembered.
func settings_set(key: String, value) -> void:
	set_option(key, value)
	_saved_opts[key] = opts[key]
	UiPrefs.set_value("options", _saved_opts)
	_l_settings.invalidate()


## Apply the options the player saved on the Settings screen (a new run). The host calls it once at startup, after it has connected
## option_changed (so it hears pad_preset and the rest) and after it has pushed its own starting values.
func load_saved_options() -> void:
	var saved = UiPrefs.get_value("options", {})
	if not (saved is Dictionary):
		return
	var od: Dictionary = UiData.options()
	for k in saved:
		if od.has(k):
			_saved_opts[k] = saved[k]
			set_option(k, saved[k])


func _settings_row(i: int) -> Dictionary:
	var rws: Array = UiSettings.rows()
	return rws[i] if i >= 0 and i < rws.size() else {}


func _settings_step(i: int, dir: int) -> void:
	var r: Dictionary = _settings_row(i)
	if r.is_empty() or not bool(r["enabled"]) or r["kind"] == UiSettings.BUTTON or r["kind"] == UiSettings.HEADING:
		return
	var v = UiSettings.stepped(r, opts, dir)
	# A toggle flips, a slider stops at its ends, a choice cycles.
	settings_set(str(r["key"]), v)


func _settings_accept(i: int) -> void:
	var r: Dictionary = _settings_row(i)
	if r.is_empty() or not bool(r["enabled"]):
		return
	match r["kind"]:
		UiSettings.TOGGLE:
			_settings_step(i, 1)
		UiSettings.CHOICE:
			_settings_step(i, 1)
		UiSettings.BUTTON:
			if str(r["action"]) == "remap":
				show_remap()
			else:
				settings_action_requested.emit(str(r["action"]))


## One of "up", "down", "left", "right", "accept", "page_up", "page_down", "home", "end", "close" (what a key, a pad button or a stick push does).
func settings_action(act: String) -> void:
	if not _set_open:
		return
	var fo: Array = UiSettings.focusable(UiSettings.rows())
	var at: int = fo.find(_set_focus)
	match act:
		"close":
			hide_settings()
			return
		"up", "down", "page_up", "page_down", "home", "end":
			if fo.is_empty():
				return
			var n: int = fo.size()
			var jump: int = 5 if act.begins_with("page") else 1
			match act:
				"up", "page_up":
					at = maxi(at - jump, 0) if at >= 0 else 0
				"down", "page_down":
					at = mini(at + jump, n - 1) if at >= 0 else 0
				"home":
					at = 0
				"end":
					at = n - 1
			_set_focus = int(fo[at])
			_set_scroll = UiSettings.scroll_to(settings_plan(), _set_focus, _set_scroll)
		"left":
			_settings_step(_set_focus, -1)
		"right":
			_settings_step(_set_focus, 1)
		"accept":
			_settings_accept(_set_focus)
	_l_settings.invalidate()


func _settings_scroll_by(px: float) -> void:
	var p: Dictionary = settings_plan()
	_set_scroll = clampf(_set_scroll + px, 0.0, float(p["max_scroll"]))
	_l_settings.invalidate()


func _settings_press(pos: Vector2) -> void:
	var p: Dictionary = settings_plan()
	var h: Dictionary = UiSettings.hit(p, pos)
	_set_drag = {}
	if h.is_empty():
		return
	var part: String = str(h["part"])
	if part == "close":
		hide_settings()
		return
	var i: int = int(h["row"])
	if i >= 0 and part != "off":
		_set_focus = i
	if part == "track":
		var rec: Dictionary = (p["rows"] as Array)[i]
		var r: Dictionary = _settings_row(i)
		settings_set(str(r["key"]), UiSettings.slider_at(r, rec["ctl"]["track"], pos.x))
		_set_drag = {"mode": "slider", "row": i}
		return
	_set_drag = {"mode": "tap" if i >= 0 and part != "body" else "scroll", "row": i, "part": part, "y0": pos.y, "scroll0": _set_scroll, "moved": false}
	_l_settings.invalidate()


func _settings_motion(pos: Vector2) -> void:
	if _set_drag.is_empty():
		return
	if str(_set_drag["mode"]) == "slider":
		var p: Dictionary = settings_plan()
		var i: int = int(_set_drag["row"])
		var r: Dictionary = _settings_row(i)
		var rec: Dictionary = (p["rows"] as Array)[i]
		settings_set(str(r["key"]), UiSettings.slider_at(r, rec["ctl"]["track"], pos.x))
		return
	var dy: float = pos.y - float(_set_drag["y0"])
	if absf(dy) > maxf(10.0 * dp, 8.0):
		_set_drag["moved"] = true
	if bool(_set_drag["moved"]):
		var p2: Dictionary = settings_plan()
		_set_scroll = clampf(float(_set_drag["scroll0"]) - dy, 0.0, float(p2["max_scroll"]))
		_l_settings.invalidate()


func _settings_release() -> void:
	var d: Dictionary = _set_drag
	_set_drag = {}
	if d.is_empty() or str(d["mode"]) != "tap" or bool(d["moved"]):
		return
	var i: int = int(d["row"])
	match str(d["part"]):
		"minus", "left":
			_settings_step(i, -1)
		"plus", "right":
			_settings_step(i, 1)
		"tap", "button", "row":
			_settings_accept(i)
	_l_settings.invalidate()


func _settings_input(event: InputEvent) -> void:
	if event is InputEventKey:
		_set_device = "kbd"
		if event.pressed:
			var act := ""
			match event.keycode:
				KEY_UP, KEY_W:
					act = "up"
				KEY_DOWN, KEY_S, KEY_TAB:
					act = "down"
				KEY_LEFT, KEY_A:
					act = "left"
				KEY_RIGHT, KEY_D:
					act = "right"
				KEY_PAGEUP:
					act = "page_up"
				KEY_PAGEDOWN:
					act = "page_down"
				KEY_HOME:
					act = "home"
				KEY_END:
					act = "end"
				KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
					act = "accept" if not event.echo else ""
				KEY_ESCAPE:
					act = "close" if not event.echo else ""
			if act != "":
				settings_action(act)
	elif event is InputEventJoypadButton:
		_set_device = "pad"
		if event.pressed:
			match event.button_index:
				JOY_BUTTON_DPAD_UP:
					settings_action("up")
				JOY_BUTTON_DPAD_DOWN:
					settings_action("down")
				JOY_BUTTON_DPAD_LEFT:
					settings_action("left")
				JOY_BUTTON_DPAD_RIGHT:
					settings_action("right")
				JOY_BUTTON_A:
					settings_action("accept")
				JOY_BUTTON_LEFT_SHOULDER:
					settings_action("page_up")
				JOY_BUTTON_RIGHT_SHOULDER:
					settings_action("page_down")
				JOY_BUTTON_B, JOY_BUTTON_START:
					settings_action("close")
	elif event is InputEventJoypadMotion:
		var ax: int = event.axis
		if ax == JOY_AXIS_LEFT_X or ax == JOY_AXIS_LEFT_Y:
			var v: float = event.axis_value
			var was: int = int(_set_axis.get(ax, 0))
			var now: int = 0
			if v > 0.6:
				now = 1
			elif v < -0.6:
				now = -1
			elif absf(v) > 0.3:
				now = was   # inside the hysteresis band: no new push
			if now != was:
				_set_axis[ax] = now
				if now != 0:
					_set_device = "pad"
					settings_action(("right" if now > 0 else "left") if ax == JOY_AXIS_LEFT_X else ("down" if now > 0 else "up"))
	elif event is InputEventMouseButton:
		_set_device = "kbd"
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_settings_press(event.position)
			else:
				_settings_release()
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_settings_scroll_by(-maxf(48.0 * dp, 44.0) * 1.2)
		elif event.pressed and event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_settings_scroll_by(maxf(48.0 * dp, 44.0) * 1.2)
	elif event is InputEventMouseMotion:
		if (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
			_settings_motion(event.position)
	get_viewport().set_input_as_handled()


# --- The Remap controls screen (docs/ui/hud-spec.md section 27) ----------------------------------------------------------------

## Open the Remap controls screen (from the Settings entry; the host may also call it). `layout_id` is a keyboard or pad preset; "" picks the
## first human's own. While it is open the HUD takes every key, pad button and click. Opened without Settings under it, it opens Settings too
## (the host's pause handling is then the same) and closing it closes both.
func show_remap(layout_id: String = "") -> void:
	if _rm_open or _howto_open or _fb_open:
		return
	if not _set_open:
		show_settings()
		if not _set_open:
			return
		_rm_direct = true
	else:
		_rm_direct = false
	var ids: Array = UiRemapModel.layouts()
	if layout_id == "" or not ids.has(layout_id):
		layout_id = "kb-solo"
		for m in hub.models:
			if not m.ai:
				var pid: String = UiHints.preset_id(m, _o())
				layout_id = pid if ids.has(pid) else (str(opts["pad_preset"]) if m.device != "" and m.device != "kbd" and m.device != "touch" else "kb-solo")
				break
	_rm_open = true
	_rm_layout = layout_id
	_rm_focus = _rm_first_focus()
	_rm_scroll = 0.0
	_rm_mode = "list"
	_rm_status = ""
	_rm_drag = {}
	_l_settings.update_sig(null)
	_l_remap.invalidate()


func hide_remap() -> void:
	if not _rm_open:
		return
	_rm_open = false
	_rm_mode = "list"
	_rm_drag = {}
	_l_remap.update_sig(null)
	_l_settings.invalidate()
	if _rm_direct:
		_rm_direct = false
		hide_settings()


func is_remap_open() -> bool:
	return _rm_open


func remap_layout() -> String:
	return _rm_layout


func remap_mode() -> String:
	return _rm_mode


func _rm_words() -> Dictionary:
	return UiData.settings().get("remap", {})


func _rm_fam() -> String:
	var p: Dictionary = UiRemapModel.preset(_rm_layout)
	if str(p.get("device", "")) == "kb":
		return "kbd"
	var dev: String = _howto_device()
	return dev if dev != "kbd" and dev != "touch" and dev != "" else "xbox"


func _rm_is_kb() -> bool:
	return str(UiRemapModel.preset(_rm_layout).get("device", "")) == "kb"


## What a control is called in a sentence: a key by its name, a pad control by the words in settings.json.
func _rm_control_word(control: String) -> String:
	var name: String = control.get_slice(":", 1)
	if control.begins_with("kb:"):
		return UiGlyphs.key_label(name)
	return str((_rm_words().get("controls", {}) as Dictionary).get(name, name))


func _rm_action_word(id: String) -> String:
	var a: String = id.get_slice("#", 0)
	return str((_rm_words().get("actions", {}) as Dictionary).get(a, a))


## The screen's rows: the layout chooser, a row per entry with the controls it has now, and Reset.
func _rm_rows() -> Array:
	var w: Dictionary = _rm_words()
	var ids: Array = UiRemapModel.layouts()
	var out: Array = []
	out.append({"kind": UiSettings.CHOICE, "key": "layout", "label": str(w.get("layout", "Layout")), "help": str(w.get("layout_help", "")), "enabled": true,
		"o": {"choices": ids, "default": ids[0] if not ids.is_empty() else ""}, "words": w.get("layouts", {})})
	var p: Dictionary = UiRemapModel.preset(_rm_layout)
	var fam: String = _rm_fam()
	var style: String = str(opts["glyph_style"])
	for e in UiRemapModel.rows(p):
		var specs: Array = []
		for c in e["controls"]:
			if not specs.is_empty() and str(e["action"]) != "move":
				specs.append({"kind": "plus", "label": "+"})
			specs.append(UiGlyphs.spec_control(str(c), fam, style))
		out.append({"kind": UiSettings.BIND, "key": str(e["id"]), "label": _rm_action_word(str(e["action"])), "help": str((w.get("helps", {}) as Dictionary).get(str(e["action"]), "")),
			"enabled": not bool(e["fixed"]), "specs": specs})
	out.append({"kind": UiSettings.BUTTON, "key": "", "action": "reset", "label": str(w.get("reset", "Reset")), "value": str(w.get("reset_button", "Reset")),
		"help": str(w.get("reset_help", "")), "enabled": true})
	return out


func _rm_status_text() -> String:
	var w: Dictionary = _rm_words()
	match _rm_mode:
		"capture":
			if _rm_status != "":
				return _rm_status   # a refusal ("kept for the game") stays up until the next press
			var key: String = "capture_key" if _rm_is_kb() else "capture_pad"
			var act: String = _rm_action_word(_rm_entry)
			if _rm_entry == "move":
				act += " " + str((w.get("move_steps", {}) as Dictionary).get(UiRemapModel.MOVE_STEPS[mini(_rm_keys.size(), 3)], ""))
			return str(w.get(key, "")).replace("{action}", act)
		"confirm":
			return str(w.get("conflict", "")).replace("{control}", _rm_control_word(str(_rm_pending["control"]))).replace("{other}", _rm_action_word(str(_rm_pending["with"])))
	return _rm_status


func remap_plan() -> Dictionary:
	var w: Dictionary = _rm_words()
	var rws: Array = _rm_rows()
	var cap := -1
	if _rm_mode == "capture" or _rm_mode == "confirm":
		for i in range(rws.size()):
			if rws[i]["kind"] == UiSettings.BIND and str(rws[i]["key"]) == _rm_entry:
				cap = i
	var conf: Array = []
	if _rm_mode == "capture":
		conf = [str(w.get("cancel", "CANCEL"))]
	elif _rm_mode == "confirm":
		conf = [str(w.get("swap", "SWAP")), str(w.get("cancel", "CANCEL"))]
	var hint: String = str(w.get("hint_pad" if _set_device != "kbd" else "hint_keys", ""))
	if _rm_mode != "list":
		hint = ""
	var st := {"rows": rws, "focus": _rm_focus, "scroll": _rm_scroll, "device": _set_device, "title": str(w.get("title", "REMAP CONTROLS")), "hint_text": hint,
		"status": _rm_status_text(), "confirm": conf, "capture": cap, "capture_word": str(w.get("capture_word", "..."))}
	return UiSettings.plan(layout.vp, layout.s, dp, bool(opts["touch_ui"]), st, {"layout": _rm_layout})


func _remap_sig() -> Array:
	return UiSettings.sig(remap_plan(), opts, bool(opts["touch_ui"])) + [_rm_layout, _rm_mode, _set_device]


func _paint_remap(ci: CanvasItem) -> void:
	if _rm_open:
		UiSettings.draw(ci, remap_plan(), {"layout": _rm_layout})


## The first row an action can be captured on (the layout chooser is row 0).
func _rm_first_focus() -> int:
	var rws: Array = _rm_rows()
	for i in range(1, rws.size()):
		if rws[i]["kind"] != UiSettings.HEADING and bool(rws[i]["enabled"]):
			return i
	return 0


func _rm_focusable() -> Array:
	return UiSettings.focusable(_rm_rows())


func _rm_row_index(id: String) -> int:
	var rws: Array = _rm_rows()
	for i in range(rws.size()):
		if rws[i]["kind"] == UiSettings.BIND and str(rws[i]["key"]) == id:
			return i
	return -1


func _rm_set_layout(id: String) -> void:
	if id == _rm_layout:
		return
	_rm_layout = id
	_rm_mode = "list"
	_rm_status = ""
	_rm_scroll = 0.0
	_rm_focus = _rm_first_focus()
	_l_remap.invalidate()


func _rm_cycle_layout(dir: int) -> void:
	var ids: Array = UiRemapModel.layouts()
	var at: int = ids.find(_rm_layout)
	_rm_set_layout(str(ids[posmod(at + dir, ids.size())]))


## Commit a changed layout: applied to the data and saved to the player's file (UiRemapModel.commit), so every reader of the effective
## preset follows, and announced for the host to rebuild the hub's layouts (SimInputHub.reload_layouts).
func _rm_commit(ovr: Array) -> void:
	UiRemapModel.commit(_rm_layout, ovr)
	remap_changed.emit(_rm_layout, ovr)
	_l_remap.invalidate()
	_l_hints_invalidate()


## The legend, the prompt row and the card read the layout's bindings: ask them to redraw.
func _l_hints_invalidate() -> void:
	for l in _l_hints:
		l.invalidate()
	for l in _l_prompts:
		l.invalidate()
	if _l_howto != null:
		_l_howto.invalidate()


func _rm_start_capture(id: String) -> void:
	_rm_mode = "capture"
	_rm_entry = id
	_rm_keys = []
	_rm_status = ""
	_rm_pending = {}
	_l_remap.invalidate()


func _rm_cancel() -> void:
	if _rm_mode == "list":
		return
	_rm_mode = "list"
	_rm_status = str(_rm_words().get("cancelled", ""))
	_l_remap.invalidate()


## A key or button was pressed while a control is wanted: bind it, ask about a swap, or say why not.
func _rm_try(control: String) -> void:
	if _rm_entry == "move":
		_rm_try_move(control)
		return
	var w: Dictionary = _rm_words()
	var res: Dictionary = UiRemapModel.attempt(_rm_layout, _rm_entry, control)
	var word: String = _rm_control_word(control)
	_rm_status = ""
	match str(res["status"]):
		"ok":
			_rm_commit(res["overrides"])
			_rm_finish(control)
		"same":
			_rm_finish(control, true)
		"conflict":
			_rm_pending = {"control": control, "with": str(res["with"])}
			_rm_mode = "confirm"
		"reserved":
			_rm_status = str(w.get("reserved", "")).replace("{control}", word)
		"pair":
			_rm_status = str(w.get("pair", "")).replace("{control}", word)
		"wrong_device":
			_rm_status = str(w.get("wrong_device_kb" if _rm_is_kb() else "wrong_device_pad", ""))
	_l_remap.invalidate()


## One key of Fly's four: checked at once, collected in order, and when the fourth is in all four are rebound together (no swap for a move key).
func _rm_try_move(control: String) -> void:
	var w: Dictionary = _rm_words()
	var word: String = _rm_control_word(control)
	_rm_status = ""
	var res: Dictionary = UiRemapModel.check_move_key(_rm_layout, _rm_keys, control)
	match str(res["status"]):
		"ok":
			_rm_keys.append(control)
			if _rm_keys.size() == 4:
				var all: Dictionary = UiRemapModel.attempt_move(_rm_layout, _rm_keys)
				var keys: Array = _rm_keys.duplicate()
				_rm_keys = []
				match str(all["status"]):
					"ok":
						_rm_commit(all["overrides"])
						_rm_finish(_rm_keys_word(keys))
					"same":
						_rm_finish(_rm_keys_word(keys), true)
					"taken":
						_rm_status = str(w.get("taken", "")).replace("{control}", _rm_control_word(str(all.get("control", control)))).replace("{other}", _rm_action_word(str(all["with"])))
					"pair":
						_rm_status = str(w.get("pair", "")).replace("{control}", word)
					_:
						_rm_status = str(w.get("reserved", "")).replace("{control}", word)
		"taken":
			_rm_status = str(w.get("taken", "")).replace("{control}", word).replace("{other}", _rm_action_word(str(res["with"])))
		"twice":
			_rm_status = str(w.get("twice", ""))
		"reserved":
			_rm_status = str(w.get("reserved", "")).replace("{control}", word)
		"pair":
			_rm_status = str(w.get("pair", "")).replace("{control}", word)
		"wrong_device":
			_rm_status = str(w.get("wrong_device_kb", ""))
	_l_remap.invalidate()


func _rm_keys_word(keys: Array) -> String:
	var parts := PackedStringArray()
	for k in keys:
		parts.append(_rm_control_word(str(k)))
	return " ".join(parts)


func _rm_finish(control: String, same: bool = false) -> void:
	var w: Dictionary = _rm_words()
	_rm_mode = "list"
	_rm_status = str(w.get("same" if same else "done", "")).replace("{action}", _rm_action_word(_rm_entry)).replace("{control}", control if _rm_entry == "move" else _rm_control_word(control))
	var at: int = _rm_row_index(_rm_entry)
	if at >= 0:
		_rm_focus = at


func _rm_answer_swap() -> void:
	if _rm_mode != "confirm":
		return
	var control: String = str(_rm_pending["control"])
	var res: Dictionary = UiRemapModel.attempt(_rm_layout, _rm_entry, control, true)
	_rm_pending = {}
	if str(res["status"]) == "ok":
		_rm_commit(res["overrides"])
		_rm_finish(control)
	else:
		_rm_mode = "list"
		_rm_status = str(_rm_words().get("reserved", "")).replace("{control}", _rm_control_word(control))
	_l_remap.invalidate()


func _rm_reset() -> void:
	_rm_commit([])
	_rm_status = str(_rm_words().get("reset_done", "")).replace("{layout}", str((_rm_words().get("layouts", {}) as Dictionary).get(_rm_layout, _rm_layout)))
	_l_remap.invalidate()


func _rm_accept(i: int) -> void:
	var rws: Array = _rm_rows()
	if i < 0 or i >= rws.size():
		return
	var r: Dictionary = rws[i]
	match r["kind"]:
		UiSettings.CHOICE:
			_rm_cycle_layout(1)
		UiSettings.BIND:
			_rm_focus = i
			_rm_start_capture(str(r["key"]))
		UiSettings.BUTTON:
			_rm_reset()


## One of "up", "down", "left", "right", "accept", "page_up", "page_down", "home", "end", "close", "swap", "cancel".
func remap_action(act: String) -> void:
	if not _rm_open:
		return
	if _rm_mode == "capture":
		if act == "cancel" or act == "close":
			_rm_cancel()
		return
	if _rm_mode == "confirm":
		if act == "accept" or act == "swap":
			_rm_answer_swap()
		elif act == "cancel" or act == "close":
			_rm_cancel()
		return
	var fo: Array = _rm_focusable()
	var at: int = fo.find(_rm_focus)
	match act:
		"close":
			hide_remap()
			return
		"up", "down", "page_up", "page_down", "home", "end":
			if fo.is_empty():
				return
			var n: int = fo.size()
			var jump: int = 5 if act.begins_with("page") else 1
			match act:
				"up", "page_up":
					at = maxi(at - jump, 0) if at >= 0 else 0
				"down", "page_down":
					at = mini(at + jump, n - 1) if at >= 0 else 0
				"home":
					at = 0
				"end":
					at = n - 1
			_rm_focus = int(fo[at])
			_rm_scroll = UiSettings.scroll_to(remap_plan(), _rm_focus, _rm_scroll)
		"left":
			_rm_cycle_layout(-1)
		"right":
			_rm_cycle_layout(1)
		"accept":
			_rm_accept(_rm_focus)
	_l_remap.invalidate()


func _rm_press(pos: Vector2) -> void:
	var p: Dictionary = remap_plan()
	var h: Dictionary = UiSettings.hit(p, pos)
	_rm_drag = {}
	if h.is_empty():
		return
	var part: String = str(h["part"])
	var i: int = int(h["row"])
	if part == "close":
		if _rm_mode != "list":
			_rm_cancel()
		hide_remap()
		return
	if part == "confirm":
		var labels: Array = p["confirm_labels"]
		var swap_word: String = str(_rm_words().get("swap", "SWAP"))
		if _rm_mode == "confirm" and str(labels[i]) == swap_word:
			_rm_answer_swap()
		else:
			_rm_cancel()
		return
	if _rm_mode != "list":
		return
	if i >= 0 and part != "off":
		_rm_focus = i
	_rm_drag = {"mode": "tap" if (i >= 0 and part != "body") else "scroll", "row": i, "part": part, "y0": pos.y, "scroll0": _rm_scroll, "moved": false}
	_l_remap.invalidate()


func _rm_motion(pos: Vector2) -> void:
	if _rm_drag.is_empty():
		return
	var dy: float = pos.y - float(_rm_drag["y0"])
	if absf(dy) > maxf(10.0 * dp, 8.0):
		_rm_drag["moved"] = true
	if bool(_rm_drag["moved"]):
		_rm_scroll = clampf(float(_rm_drag["scroll0"]) - dy, 0.0, float(remap_plan()["max_scroll"]))
		_l_remap.invalidate()


func _rm_release() -> void:
	var d: Dictionary = _rm_drag
	_rm_drag = {}
	if d.is_empty() or str(d["mode"]) != "tap" or bool(d["moved"]) or _rm_mode != "list":
		return
	var i: int = int(d["row"])
	match str(d["part"]):
		"left":
			_rm_cycle_layout(-1)
		"right":
			_rm_cycle_layout(1)
		"tap", "button", "row":
			_rm_accept(i)
	_l_remap.invalidate()


func _remap_input(event: InputEvent) -> void:
	var capturing: bool = _rm_mode == "capture"
	if event is InputEventKey:
		_set_device = "kbd"
		if event.pressed and not event.echo:
			var code: String = RenderKeys.code(event)
			if capturing:
				if code == "Escape":
					remap_action("cancel")
				elif _rm_is_kb():
					_rm_try("kb:" + code)
			else:
				var act := ""
				match event.keycode:
					KEY_UP, KEY_W:
						act = "up"
					KEY_DOWN, KEY_S, KEY_TAB:
						act = "down"
					KEY_LEFT, KEY_A:
						act = "left"
					KEY_RIGHT, KEY_D:
						act = "right"
					KEY_PAGEUP:
						act = "page_up"
					KEY_PAGEDOWN:
						act = "page_down"
					KEY_HOME:
						act = "home"
					KEY_END:
						act = "end"
					KEY_ENTER, KEY_KP_ENTER, KEY_SPACE:
						act = "accept"
					KEY_ESCAPE:
						act = "close"
				if act != "":
					remap_action(act)
	elif event is InputEventJoypadButton:
		_set_device = "pad"
		if event.pressed:
			if capturing:
				var ctl: String = SimInputNames.pad_control_from_event(event)
				if ctl == "pad:start":
					remap_action("cancel")
				elif ctl != "" and not _rm_is_kb():
					_rm_try(ctl)
			else:
				match event.button_index:
					JOY_BUTTON_DPAD_UP:
						remap_action("up")
					JOY_BUTTON_DPAD_DOWN:
						remap_action("down")
					JOY_BUTTON_DPAD_LEFT:
						remap_action("left")
					JOY_BUTTON_DPAD_RIGHT:
						remap_action("right")
					JOY_BUTTON_A:
						remap_action("accept")
					JOY_BUTTON_LEFT_SHOULDER:
						remap_action("page_up")
					JOY_BUTTON_RIGHT_SHOULDER:
						remap_action("page_down")
					JOY_BUTTON_B, JOY_BUTTON_START:
						remap_action("close")
	elif event is InputEventJoypadMotion:
		var ax: int = event.axis
		if capturing and not _rm_is_kb():
			var tctl: String = SimInputNames.pad_control_from_event(event)
			if tctl != "":
				_set_device = "pad"
				_rm_try(tctl)
		elif not capturing and (ax == JOY_AXIS_LEFT_X or ax == JOY_AXIS_LEFT_Y):
			var v: float = event.axis_value
			var was: int = int(_set_axis.get(ax, 0))
			var now: int = 0
			if v > 0.6:
				now = 1
			elif v < -0.6:
				now = -1
			elif absf(v) > 0.3:
				now = was
			if now != was:
				_set_axis[ax] = now
				if now != 0:
					_set_device = "pad"
					remap_action(("right" if now > 0 else "left") if ax == JOY_AXIS_LEFT_X else ("down" if now > 0 else "up"))
	elif event is InputEventMouseButton:
		_set_device = "kbd"
		if event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_rm_press(event.position)
			else:
				_rm_release()
		elif event.pressed and (event.button_index == MOUSE_BUTTON_WHEEL_UP or event.button_index == MOUSE_BUTTON_WHEEL_DOWN) and _rm_mode == "list":
			var step: float = maxf(48.0 * dp, 44.0) * 1.2
			_rm_scroll = clampf(_rm_scroll + (step if event.button_index == MOUSE_BUTTON_WHEEL_DOWN else -step), 0.0, float(remap_plan()["max_scroll"]))
			_l_remap.invalidate()
	elif event is InputEventMouseMotion:
		if (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
			_rm_motion(event.position)
	get_viewport().set_input_as_handled()


# --- The feedback panel (docs/ui/hud-spec.md section 20) ----------------------------------------------------------------------

## Open the feedback panel. `context` is "pause" (from the pause menu) or "match_end" (from the pill after a KO). While it is open the
## HUD takes every key and click, like the How to play card: the host pauses the sim on feedback_opened and restores the pause it
## found on feedback_closed. Nothing is sent anywhere: COPY REPORT puts plain text on the clipboard.
func show_feedback(context: String = "pause") -> void:
	if _fb_open or _howto_open or _set_open:
		return
	_fb_open = true
	_fb_context = context
	_fb_state = UiFeedback.STATE_WRITE
	_fb_status_ok = false
	_fb_issue = {}
	_fb_opened = false
	_fb_tags = {}
	_fb_text.text = ""
	UiWebClip.install(hide_feedback)
	_fb_place()
	_fb_sync()
	_l_fb.invalidate()
	feedback_opened.emit(context)


func hide_feedback() -> void:
	if not _fb_open:
		return
	_fb_open = false
	_fb_text.visible = false
	_fb_prev.visible = false
	_fb_text.release_focus()
	UiWebClip.clear()
	_l_fb.update_sig(null)
	feedback_closed.emit()


func is_feedback_open() -> bool:
	return _fb_open


func toggle_feedback_tag(id: String) -> void:
	if _fb_open and _fb_state == UiFeedback.STATE_WRITE:
		_fb_tags[id] = not bool(_fb_tags.get(id, false))
		_fb_sync()
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
	UiWebClip.copy(text)   # on the web also from the page itself (see UiWebClip); a no-op elsewhere
	_fb_prev.text = text
	if _fb_state != UiFeedback.STATE_REVIEW:
		_fb_state = UiFeedback.STATE_COPIED
	_fb_status_ok = true
	_fb_place()
	_l_fb.invalidate()
	return text


## SEND: the review of exactly what the open button will hand to the player's email app, form or GitHub issue (the send target, ui/data/
## send.json). Nothing leaves the game until the player submits it there; a GitHub review says the issue is public. With no target
## there is no SEND (the button is hidden) and this returns {}. Returns {url, fallback, body}.
func send_feedback() -> Dictionary:
	if UiFeedback.send_target() == "none":
		return {}
	var text: String = feedback_report()
	_fb_prev.text = text
	_fb_issue = UiFeedback.send_url(text, UiFeedback.issue_title(feedback_selected_tags(), _fb_text.text))
	_fb_state = UiFeedback.STATE_REVIEW
	_fb_status_ok = false
	_fb_opened = false
	UiWebClip.set_report(text)
	_fb_place()
	_l_fb.invalidate()
	return _fb_issue


## The open button (OPEN EMAIL, OPEN FORM or OPEN ISSUE): copy the report (so a link too long to prefill, or a page that ignores it, costs one paste) and open the link. On the web
## the page's own listener normally opens it inside the real click; this is the fallback and the desktop route.
func open_issue() -> String:
	if not _fb_open or _fb_state != UiFeedback.STATE_REVIEW or _fb_issue.is_empty():
		return ""
	var text: String = feedback_report()
	DisplayServer.clipboard_set(text)
	UiWebClip.copy(text)
	UiFeedback.open_url(str(_fb_issue["url"]))
	_fb_opened = true
	_l_fb.invalidate()
	return str(_fb_issue["url"])


func feedback_action(act: String) -> void:
	if not _fb_open:
		return
	match act:
		"copy", "again":
			copy_feedback()
		"send":
			send_feedback()
		"issue":
			open_issue()
		"back":
			_fb_state = UiFeedback.STATE_WRITE
			_fb_status_ok = false
			_fb_opened = false
			_fb_place()
			_l_fb.invalidate()
		"close":
			hide_feedback()


## The status line and small print the review state shows, over the plan's defaults.
func _fb_texts() -> Array:
	var d: Dictionary = UiData.feedback()
	var sd: Dictionary = UiData.send()
	var status := ""
	var note := ""
	if _fb_state == UiFeedback.STATE_REVIEW:
		if _fb_status_ok:
			status = str(d.get("copied", ""))
		if _fb_opened:
			note = UiFeedback.target_word("opened")
		elif bool(_fb_issue.get("fallback", false)):
			note = UiFeedback.target_word("review") + " " + str(sd.get("too_long", ""))
	return [status, note]


func feedback_plan() -> Dictionary:
	var t: Array = _fb_texts()
	return UiFeedback.plan(layout.vp, layout.s, dp, bool(opts["touch_ui"]), _fb_state, str(t[0]), str(t[1]))


## Keep the web page's copy of the report current, so its pointer listener can copy it inside the user's gesture.
func _fb_sync() -> void:
	if _fb_open and UiWebClip.available():
		UiWebClip.set_report(feedback_report())


## Place the two text boxes on the panel's plan and size their type to it. On the web the read-only report is a real DOM textarea over
## its box (native select, Ctrl+C and long-press Copy), removed and placed again here on every layout, so a resize never strands it.
func _fb_place() -> void:
	var p: Dictionary = feedback_plan()
	var write: bool = _fb_state == UiFeedback.STATE_WRITE
	var web: bool = UiWebClip.available()
	_fb_text.visible = _fb_open and write
	_fb_prev.visible = _fb_open and not write and not web
	if web:
		UiWebClip.hide_textarea()
		UiWebClip.set_copy_rect((p["copy"] if write else p["again"]) if _fb_open else Rect2())
		UiWebClip.set_open(p["issue"] if (_fb_open and _fb_state == UiFeedback.STATE_REVIEW) else Rect2(), str(_fb_issue.get("url", "")))
		if _fb_open and not write:
			UiWebClip.show_textarea(p["preview_rect"], float(p["fs_body"]), _fb_prev.text)
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
	return hub.match_over and bool(opts["match_end_feedback"]) and not _fb_open and not _howto_open and not _set_open and not _pm_open and layout.feedback_btn.size.y > 0.0


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
		elif (p["send"] as Rect2).has_point(pos):
			send_feedback()
		elif (p["done"] as Rect2).has_point(pos):
			hide_feedback()
	elif _fb_state == UiFeedback.STATE_REVIEW:
		if (p["issue"] as Rect2).has_point(pos):
			open_issue()
		elif (p["again"] as Rect2).has_point(pos):
			copy_feedback()
		elif (p["back"] as Rect2).has_point(pos):
			feedback_action("back")
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


func _humans() -> int:
	var n := 0
	for m in hub.models:
		if not m.ai:
			n += 1
	return n


func _you_alpha(m: UiFighterModel) -> float:
	return UiHints.visible_alpha(m, str(opts["control_hints"]), bool(opts["show_prompts"]), hub.t_now - float(_hint_t0[m.slot]))


func _touch_state() -> Dictionary:
	if touch_state_fn.is_valid():
		var v = touch_state_fn.call()
		if v is Dictionary:
			return v
	return {}


## The captions on the touch buttons show like the legend does: the first 12 s of a match and while prompts are on.
func _touch_intro_alpha() -> float:
	for m in hub.models:
		if not m.ai:
			return _you_alpha(m)
	return 0.0


func _transform_avail() -> bool:
	for m in hub.models:
		if not m.ai and bool(m.avail["transform"]):
			return true
	return false


func _paint_touchctl(ci: CanvasItem) -> void:
	UiTouchControls.draw(ci, layout, layout.s, _touch_state(), _touch_intro_alpha(), _transform_avail())


func _hint_alpha(m: UiFighterModel) -> float:
	if bool(opts["touch_ui"]) or layout.portrait:
		return 0.0
	return _you_alpha(m)


func _paint_hints(ci: CanvasItem, slot: int) -> void:
	if slot >= hub.models.size():
		return
	var m: UiFighterModel = hub.models[slot]
	UiHints.draw(ci, m, layout.hints[slot], layout.s, _o(), _hint_alpha(m))


func _paint_you(ci: CanvasItem) -> void:
	if not anchor_fn.is_valid():
		return
	for m in hub.models:
		var a: float = _you_alpha(m)
		if a > 0.01 and m.you_label != "":
			UiHints.draw_you(ci, m.you_label, anchor_fn.call(m.slot), layout.s, a, layout.safe)


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
	if layout.pause_btn.size.y > 0.0:
		out["pause"] = layout.pause_btn
	if _pill_visible():
		out["feedback"] = layout.feedback_btn
	if _transform_avail() and not layout.touch_ctrl.is_empty() and not layout.touch_full:
		out["transform"] = UiTouchControls.rect_of(UiTouchControls.circle(layout, "context"))
	return out


## Which target of the HUD's own a screen point is on: {name: pause | feedback | transform, slot: -1}, or {}. The attack, guard and power
## buttons and the stick are Controls' (SimTouch.widget_at, with the same layout); the host asks the HUD first, so pause and feedback win.
func touch_target_at(p: Vector2) -> Dictionary:
	var r: Dictionary = touch_rects()
	for k in ["pause", "feedback", "transform"]:
		if r.has(k) and (r[k] as Rect2).has_point(p):
			return {"name": k, "slot": -1}
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
