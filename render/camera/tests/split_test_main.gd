class_name SplitTestMain
extends RefCounted
## A stand-in for Rendering's main scene in the compositor test: it has the two calls SplitView plugs into
## (move_pane0, make_pane), a `compositor`, and a host with what SplitView reads (ticked, seed, jitter, fxv.shake).
## Its panes are SplitTestPane, flat 2D worlds drawn with the reference camera's mapping.

var pane_a := SplitTestPane.new()
var pane_b := SplitTestPane.new()
var pane_i := SplitTestPane.new()
var split_frame: SplitFrame = null
var host := _Host.new()
var compositor: Object = null
var split_rig := SplitRig.new()


func move_pane0(size: Vector2i) -> SubViewport:
	pane_a.viewport.size = size
	return pane_a.viewport


func make_inset(size: Vector2i) -> SubViewport:
	pane_i.viewport.size = size
	return pane_i.viewport


func make_pane(size: Vector2i) -> SubViewport:
	pane_b.viewport.size = size
	return pane_b.viewport


## What main.render_view does with a compositor: each shown pane aimed at the rig's camera for it, then present().
func render_frame(fr: SplitFrame, fighters: Array) -> void:
	pane_a.fighters = fighters
	pane_b.fighters = fighters
	var panes: Array = [pane_a, pane_b]
	for i in range(2):
		if i == 0 or fr.shows(i):
			var j: Vector2 = compositor.pane_jitter(i) if compositor.has_method("pane_jitter") else Vector2.ZERO
			panes[i].set_view(fr.cam_x[i], fr.cam_y[i], fr.cam_z[i], j)
	split_frame = fr
	if compositor.has_method("inset_view"):
		var iv: Dictionary = compositor.inset_view(1.0)
		if not iv.is_empty():
			pane_i.fighters = fighters
			pane_i.set_view(float(iv["cam_x"]), float(iv["cam_y"]), float(iv["cam_z"]), Vector2.ZERO)
	compositor.present(fr)


class _Fx extends RefCounted:
	var shake: float = 0.0


class _Host extends RefCounted:
	signal ticked(n: int)
	var seed: int = 1
	var jitter := Vector2.ZERO
	var fxv := _Fx.new()
