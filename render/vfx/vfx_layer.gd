class_name VfxLayer
extends Node3D
## One pane's VFX (docs/vfx/plan.md section 5): the motion trails and the ground cracks now; shrapnel and collapse dust
## as they are built. It is a child of a PaneWorld ("Vfx"), so it draws in that pane's world with that pane's camera.
## The hub (host.vfx: the history and the effects' state) is shared by every pane; main sets `hub` before the pane
## builds. The layer only reads: update() draws, it never steps anything (the one thing it does for the hub is build a
## queued crack mesh, which is drawing work). It finds its pane's curvature state and the planet's ground field itself,
## through its parent, so the hooks in Rendering stay three lines.

var hub: VfxHub
var trail_view := VfxTrailView.new()
var crack_view := VfxCrackView.new()


func _init() -> void:
	name = "Vfx"
	crack_view.name = "Cracks"
	trail_view.name = "Trails"
	add_child(crack_view)
	add_child(trail_view)


## A new match (PaneWorld.build, after the planet has built): nothing kept between matches on the drawing side. The
## pane's material state and the planet's ground field are picked up from the parent pane (untyped on purpose: the pane
## class refers to this one).
func build(_S: SimState) -> void:
	crack_view.clear()
	trail_view.visible = true
	var pw = get_parent()
	if pw != null and pw.get("mats") != null and pw.get("planet") != null:
		crack_view.attach(pw.mats, pw.planet.ground)


## Draw this pane's frame. cam_x: this pane's wrapped camera x; zoom: its pixels per unit at the fighter plane;
## vw: the pane's width in pixels.
func update(host: SimHost, a: float, cam_x: float, zoom: float, vw: float) -> void:
	if hub == null or not hub.enabled:
		trail_view.visible = false
		crack_view.visible = false
		return
	trail_view.visible = true
	crack_view.visible = hub.cracks_enabled
	var half_w: float = vw * 0.5 / maxf(zoom, 1e-6)
	if hub.cracks_enabled:
		crack_view.update(hub, host.S, cam_x, half_w, zoom)
	trail_view.update(hub, host, a, cam_x, zoom, half_w)
