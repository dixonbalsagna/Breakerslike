class_name VfxLayer
extends Node3D
## One pane's VFX (docs/vfx/plan.md section 5): motion trails, ground cracks, and the destruction effects (holes in
## facades, shrapnel, collapse dust). It is a child of a PaneWorld ("Vfx"), so it draws in that pane's world with that
## pane's camera. The hub (host.vfx: the history and the effects' state) is shared by every pane; main sets `hub`
## before the pane builds. The layer only reads: update() draws, it never steps anything (the one thing it does for the
## hub is build a queued crack mesh, which is drawing work). It finds its pane's curvature state and the planet's ground
## field itself, through its parent, so the hooks in Rendering stay three lines.

var hub: VfxHub
var trail_view := VfxTrailView.new()
var transform_view := VfxTransformView.new()
var crack_view := VfxCrackView.new()
var hole_view := VfxHoleView.new()
var shard_view := VfxShardView.new()
var stat_update_usec: int = 0      # time spent in update(), for the bench and the budget table
var stat_update_n: int = 0
var stat_update_max: int = 0


func _init() -> void:
	name = "Vfx"
	crack_view.name = "Cracks"
	hole_view.name = "Holes"
	shard_view.name = "Shards"
	trail_view.name = "Trails"
	transform_view.name = "Transform"
	add_child(crack_view)
	add_child(hole_view)
	add_child(shard_view)
	add_child(trail_view)
	add_child(transform_view)


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
	var t0: int = Time.get_ticks_usec()
	_update(host, a, cam_x, zoom, vw)
	var dt_us: int = Time.get_ticks_usec() - t0
	stat_update_usec += dt_us
	stat_update_n += 1
	stat_update_max = maxi(stat_update_max, dt_us)


func _update(host: SimHost, a: float, cam_x: float, zoom: float, vw: float) -> void:
	if hub == null or not hub.enabled:
		trail_view.visible = false
		transform_view.visible = false
		crack_view.visible = false
		hole_view.visible = false
		shard_view.visible = false
		return
	trail_view.visible = true
	crack_view.visible = hub.cracks_enabled
	hole_view.visible = hub.destruction_enabled
	shard_view.visible = hub.destruction_enabled or hub.cracks_enabled or hub.embers_enabled or hub.water_enabled or hub.react_enabled
	var half_w: float = vw * 0.5 / maxf(zoom, 1e-6)
	if hub.cracks_enabled:
		crack_view.update(hub, host.S, cam_x, half_w, zoom)
	if hub.destruction_enabled:
		hole_view.update(hub, cam_x, half_w)
	if hub.destruction_enabled or hub.cracks_enabled or hub.embers_enabled or hub.water_enabled or hub.react_enabled:
		shard_view.update(hub, cam_x, zoom, half_w)
	var pw = get_parent()
	if pw != null and pw.get("cam_rig") != null:
		trail_view.cam_dist = pw.cam_rig.dist   # the camera's distance to the fighter plane (position.z is not once the camera pitches)
	trail_view.update(hub, host, a, cam_x, zoom, half_w)
	transform_view.visible = hub.transform_enabled
	if hub.transform_enabled:
		transform_view.update(hub, host, a, cam_x, zoom, half_w)
