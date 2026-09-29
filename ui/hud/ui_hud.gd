class_name UiHud
extends Control
## The HUD root: a full-rect Control that Rendering's main scene hosts under its CanvasLayer (replacing render/core/hud.gd).
## It reads events and state through its UiEventHub and never writes the sim, never draws from a random stream, and
## animates by wall time only, so it cannot change a match or a replay.
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
var strip_fn: Callable = Callable()    # () -> Dictionary for UiStrip.draw
var opts: Dictionary = {
	"silhouette": true,        # the body figure beside each plate (on by default in training and as the accessibility default)
	"reduced_motion": false,   # no flicker, shimmer, shrinking rings or slide-ins; every cue still has a shape
	"captions": true,          # bracketed gesture tags on barks
	"thickness": 1.0,          # crown arc thickness multiplier (an accessibility option)
	"region_label": false,     # the place name under the planet strip's camera box
	"show_feed": false,        # the director feed (debug toggle)
	"show_clear_zone": false,  # draw the fighter-clear zone (debug)
	"show_crown": true,
}
var _t := 0.0
var _lb := 0.0                 # letterbox progress, 0..1
var _key := ""
var insets := Vector4.ZERO     # left, top, right, bottom safe-area insets from the host (phone notches)


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(func(): _relayout())
	UiData.ensure()
	_relayout()


## Fighters: readout profile ids ("protagonist", "anti_hero", "empress", "cyborg", or a placeholder such as "kai") and names.
func setup(ids: Array, names: Array) -> void:
	hub.setup_fighters(ids, names)
	_relayout()


func consume(e) -> void:
	hub.consume(e)


func consume_all(events: Array) -> void:
	hub.consume_all(events)


func advance(dt: float) -> void:
	_t += dt
	hub.captions_on = bool(opts["captions"])
	hub.reduced_motion = bool(opts["reduced_motion"])
	hub.advance(dt)
	var target: float = 1.0 if hub.mode == UiEventHub.Mode.CINEMATIC else 0.0
	_lb = move_toward(_lb, target, dt * (100.0 if bool(opts["reduced_motion"]) else 4.0))
	queue_redraw()


func set_option(key: String, value) -> void:
	opts[key] = value
	if key == "silhouette":
		_relayout()
	queue_redraw()


func _relayout() -> void:
	var sz: Vector2 = size if size.x > 1.0 else get_viewport_rect().size
	var key: String = "%d,%d,%s,%s" % [int(sz.x), int(sz.y), str(opts["silhouette"]), str(insets)]
	if key == _key:
		return
	_key = key
	layout.compute(sz, bool(opts["silhouette"]), insets)
	hub.cap_limit = 1 if layout.portrait else 99
	layout_changed.emit()


func _draw() -> void:
	if hub.models.is_empty():
		return
	_relayout()
	var s: float = layout.s
	var mode: int = hub.mode
	var o: Dictionary = {
		"reduced_motion": bool(opts["reduced_motion"]),
		"thickness": float(opts["thickness"]),
		"region_label": bool(opts["region_label"]),
		"plate_alpha": 1.0,
	}
	# In a respected cinematic the plates recede, so the set piece owns the screen (docs/ui/hud-spec.md section 8).
	UiBarks.draw_letterbox(self, layout, _lb)
	if bool(opts["show_crown"]) and anchor_fn.is_valid():
		for m in hub.models:
			var a: Dictionary = anchor_fn.call(m.slot)
			if a.is_empty() or not bool(a.get("visible", true)):
				continue
			var R: float = UiCrown.radius(float(a.get("h", 90.0)), s)
			var c: Vector2 = a["pos"]
			UiCrown.draw(self, m, c, R, _t, s, o)
			UiCrown.draw_marker(self, m, c, R, s, _t)
	for m in hub.models:
		var oo: Dictionary = o.duplicate()
		if mode == UiEventHub.Mode.CINEMATIC and m.cinematic == "":
			oo["plate_alpha"] = 0.45
		UiPlate.draw(self, m, layout.plate[m.slot], layout.pm, s, _t, oo)
		if layout.silhouette_on:
			UiSilhouette.draw(self, m, layout.silhouette[m.slot], _t, s, oo)
	UiCards.draw(self, hub, layout, s, _t, o)
	var oc: Dictionary = o.duplicate()
	if mode == UiEventHub.Mode.CINEMATIC:
		oc["plate_alpha"] = 0.45
	UiCenter.draw_toll(self, hub, layout, s, oc)
	UiCenter.draw_banner(self, hub, layout, s, o)
	if strip_fn.is_valid() and _lb < 0.5:
		# The strip hides during a cinematic: the letterbox band belongs to the set piece.
		UiStrip.draw(self, layout, hub, strip_fn.call(), s, _t, oc)
	UiBarks.draw(self, hub, layout, s, _t, o)
	if bool(opts["show_feed"]):
		UiFeed.draw(self, hub, layout, s, o)
	if bool(opts["show_clear_zone"]):
		draw_rect(layout.clear_zone, Color(0.2, 1.0, 0.4, 0.08))
		draw_rect(layout.clear_zone, Color(0.2, 1.0, 0.4, 0.7), false, 2.0)
		draw_rect(layout.frame_rect, Color(1.0, 0.8, 0.2, 0.6), false, 1.5)
		if layout.touch_reserve.size.y > 0.0:
			draw_rect(layout.touch_reserve, Color(0.4, 0.6, 1.0, 0.12))
