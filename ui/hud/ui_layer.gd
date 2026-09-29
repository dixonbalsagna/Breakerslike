class_name UiLayer
extends Control
## One cached layer of the HUD. Godot keeps a node's draw commands until it is asked to redraw, so a layer that has not
## changed costs no GDScript at all: the HUD gives each layer a small SIGNATURE every frame (a few numbers), and the layer
## redraws only when its signature changes. A layer with a null signature draws nothing (the crown at rest, the cards
## when none show). This is what keeps the HUD cheap: at rest nothing is redrawn and the fighters' area has no draw calls.

var painter: Callable = Callable()   # called as painter.call(layer) inside _draw, with any bound arguments after it
var sig = null
var redraws: int = 0                 # how many times this layer has been redrawn (the perf counters read it)


var dirty: bool = false
var force: bool = false              # bench only: redraw every frame whatever the signature (the cost of not caching)


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)
	texture_repeat = CanvasItem.TEXTURE_REPEAT_ENABLED   # the bars' tiled stripe texture


## Redraw if the signature changed (or the layer was invalidated). Pass null to clear the layer.
func update_sig(new_sig) -> void:
	if new_sig == null:
		if sig != null or dirty:
			sig = null
			dirty = false
			queue_redraw()
		return
	if force or dirty or typeof(new_sig) != typeof(sig) or new_sig != sig:
		sig = new_sig
		dirty = false
		queue_redraw()


## Force the next update to redraw (a relayout, an option change).
func invalidate() -> void:
	dirty = true


func _draw() -> void:
	if sig == null or not painter.is_valid():
		return
	redraws += 1
	painter.call(self)
