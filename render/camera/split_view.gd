class_name SplitView
extends Control
## The split-screen compositor (docs/camera/split-screen.md section 11). It owns nothing of the world: it takes two
## panes, each a full render of the world from its own camera in its own SubViewport (Rendering's PaneWorld), tells each
## its camera every displayed frame from a SplitFrame, and blends the two textures on one rect with the mask shader.
## UI draws the divider line, the ring map and the pointer chips over it (UiHud.split_fn, fed by the frame's
## split_record()).
##
## A pane is anything with:
##   viewport: SubViewport                      its render target; SplitView keeps it the size of this control
##   set_view(cam_x, cam_y, zoom, jitter)       the reference camera's x, y and pixels-per-unit zoom, and the shake in px
##   set_active(on: bool)                       render this frame or not (the viewport's update mode)
## It is a Control, not a Node3D, so it sits under a CanvasLayer beneath the HUD.

const MASK: Shader = preload("res://render/camera/split_mask.gdshader")

var panes: Array = [null, null]
var shake_b := PaneShake.new()       # pane 1's cosmetic shake stream; pane 0 uses the host's jitter
var shake_scale: float = 1.0         # the player's setting, 0 to 1
var last_frame: SplitFrame = null
var _rect: ColorRect
var _mat: ShaderMaterial


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	_rect = ColorRect.new()
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = MASK
	_rect.material = _mat
	add_child(_rect)
	resized.connect(_on_resized)


## Attach the two panes (slot 0's and slot 1's). Their viewports are sized to this control.
func attach(p0, p1) -> void:
	panes = [p0, p1]
	_on_resized()


func reset(match_seed: int) -> void:
	shake_b.reset(match_seed)


## Once per sim tick: the fx consumer's shake amount, for pane 1's stream.
func on_tick(shake_px: float) -> void:
	shake_b.scale = shake_scale
	shake_b.tick(shake_px, maxf(size.y, 1.0))


func _on_resized() -> void:
	for p in panes:
		if p != null:
			p.viewport.size = Vector2i(maxi(2, int(size.x)), maxi(2, int(size.y)))
	if _mat != null:
		_mat.set_shader_parameter("res", size)


## Draw a frame: aim each pane's camera, switch off the pane nobody sees, set the mask.
## host_jitter is pane 0's shake in px (SimHost.jitter); pane 1 uses this view's own stream.
func present(fr: SplitFrame, host_jitter: Vector2 = Vector2.ZERO) -> void:
	last_frame = fr
	var vh: float = maxf(size.y, 1.0)
	var jit: Array = [PaneShake.capped(host_jitter, vh, shake_scale), shake_b.jitter]
	for i in range(2):
		var p = panes[i]
		if p == null:
			continue
		var on: bool = fr.shows(i)
		p.set_active(on)
		if on:
			p.set_view(fr.cam_x[i], fr.cam_y[i], fr.cam_z[i], jit[i])
	if _mat == null:
		return
	if panes[0] != null:
		_mat.set_shader_parameter("tex0", panes[0].viewport.get_texture())
	if panes[1] != null:
		_mat.set_shader_parameter("tex1", panes[1].viewport.get_texture())
	_mat.set_shader_parameter("c", fr.c)
	_mat.set_shader_parameter("n", fr.n)
	_mat.set_shader_parameter("feather", fr.feather)
	_mat.set_shader_parameter("gap", fr.gap)
	_mat.set_shader_parameter("gap_alpha", fr.line_alpha)
	_mat.set_shader_parameter("active0", 1.0 if fr.shows(0) else 0.0)
	_mat.set_shader_parameter("active1", 1.0 if (fr.shows(1) and panes[1] != null) else 0.0)
