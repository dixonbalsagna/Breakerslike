class_name SplitView
extends Control
## The split-screen compositor (docs/camera/split-screen.md section 11), Camera's half of the plug-in contract in
## docs/rendering/README.md, "Panes and the split screen". Rendering's main scene owns the rig and the panes and draws
## each pane from the rig's camera for it; this control takes the two panes' SubViewports, blends their textures on one
## rect with the mask shader, and answers main's two calls:
##   pane_jitter(i) -> Vector2   the shake for pane i in px (pane 0: the host's jitter; pane 1: a cosmetic stream of
##                               its own), capped at CamParams.SHAKE_CAP of the screen height and scaled by the
##                               player's setting
##   present(frame)              switch off the pane nobody sees, set the mask from the divider
## It sits under UI's HUD (a plain Control in the default canvas layer; the HUD is a CanvasLayer above it), and UI
## draws the divider line, the ring map and the pointer chips over it from the same frame (UiHud.split_fn).
##
##   var view := SplitView.new()
##   main.add_child(view)
##   view.attach(main)          # moves pane 0 into a SubViewport, makes pane 1, sets main.compositor = view
##   view.detach()              # back to one view from the reference camera

const MASK: Shader = preload("res://render/camera/split_mask.gdshader")

var main = null            # Rendering's main scene, or a stand-in with the same calls (render/camera/tests/split_test_main.gd)
var viewports: Array = [null, null]
var shake_pref: float = CamParams.SHAKE_PREF_DEFAULT   # the player's shake setting, 0 to 10 (default 2)
var shake_scale: float = 1.0          # the player's shake scale, 0 to 1 (default 1)
var reduced_motion: bool = false      # the player's reduced-motion setting: shake at a quarter of the scale
var shake_a := PaneShake.new()        # pane 0's cosmetic shake stream ("camera", the host's name for it)
var shake_b := PaneShake.new()        # pane 1's ("camera_b")
var last_frame: SplitFrame = null
var _rect: ColorRect                  # the mask rect: two panes blended by the divider
var _solo: TextureRect                # one pane, no shader: what the screen is when only one pane shows
var _mat: ShaderMaterial
var _host_ticks: int = -1
var _host_seed: int = -1
var _attached: bool = false


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	set_anchors_preset(Control.PRESET_FULL_RECT)


func _ready() -> void:
	_rect = ColorRect.new()
	_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_mat = ShaderMaterial.new()
	_mat.shader = MASK
	_rect.material = _mat
	_rect.visible = false       # nothing to show until pane 0 has been moved into a SubViewport
	add_child(_rect)
	_solo = TextureRect.new()
	_solo.set_anchors_preset(Control.PRESET_FULL_RECT)
	_solo.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_solo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_solo.stretch_mode = TextureRect.STRETCH_SCALE
	_solo.visible = false
	add_child(_solo)
	resized.connect(_on_resized)


## Plug into Rendering's main scene: take pane 0 out of the main world into a SubViewport, make pane 1, and set
## main.compositor. From then on main steps the rig every tick and draws the panes from its cameras.
func attach(m) -> void:
	if _attached:
		return
	main = m
	var sz := Vector2i(maxi(2, int(get_viewport().get_visible_rect().size.x)), maxi(2, int(get_viewport().get_visible_rect().size.y)))
	var v0: SubViewport = main.move_pane0(sz)
	var v1: SubViewport = main.make_pane(sz)
	viewports = [v0, v1]
	add_child(v0)
	add_child(v1)
	if main.host != null and not main.host.ticked.is_connected(_on_ticked):
		main.host.ticked.connect(_on_ticked)
	_attached = true
	if _solo != null:
		_solo.texture = v0.get_texture()
		_solo.visible = true
	main.compositor = self
	_on_resized()


## Back to one view. Pane 0 stays in its SubViewport and is shown unmasked.
func detach() -> void:
	if main != null:
		main.compositor = null
	_attached = false
	if _rect != null:
		_rect.visible = false
		_solo.texture = viewports[0].get_texture()
		_solo.visible = true
	if viewports[0] != null:
		viewports[0].render_target_update_mode = SubViewport.UPDATE_ALWAYS
	if viewports[1] != null:
		viewports[1].render_target_update_mode = SubViewport.UPDATE_DISABLED


func is_attached() -> bool:
	return _attached


## The player's settings (docs/camera/split-screen.md sections 2 and 13). Solo against the AI: split like two players
## (default) or follow the human fighter alone when far. Reduced motion: quicker swing, no tier push, no launch follow.
func set_solo_split(on: bool) -> void:
	if main != null:
		main.split_rig.solo_split = on


## The player's zoom setting, 0 to 10 (default 7): every size target is multiplied by exp(0.08 (pref - 7)). The floor is
## not scaled. Option name for UI: `camera_zoom`, an integer slider 0 to 10, default 7.
func set_zoom_pref(v: float) -> void:
	if main != null:
		main.split_rig.zoom_pref = clampf(v, 0.0, 10.0)


## The player's shake setting, 0 to 10 (default 2). Option name for UI: `camera_shake`, an integer slider 0 to 10, default 2.
func set_shake_pref(v: float) -> void:
	shake_pref = clampf(v, 0.0, 10.0)


func set_reduced_motion(on: bool) -> void:
	reduced_motion = on
	if main != null:
		main.split_rig.reduced_motion = on


## Once per sim tick (the host's `ticked`): pane 1's shake stream advances, reseeded for a new match.
func _on_ticked(n: int) -> void:
	var h = main.host
	if n < _host_ticks or int(h.seed) != _host_seed:
		shake_a.reset(int(h.seed), "camera")
		shake_b.reset(int(h.seed))
		_host_seed = int(h.seed)
	_host_ticks = n
	var vh: float = maxf(get_viewport().get_visible_rect().size.y, 1.0)
	var amounts: PackedFloat64Array = main.split_rig.current().shake
	shake_a.scale = _shake()
	shake_b.scale = _shake()
	shake_a.tick(amounts[0], vh)
	shake_b.tick(amounts[1], vh)


## Called by main for each pane's shake. Pane 0 is the host's jitter; pane 1 has this view's own stream.
func pane_jitter(i: int) -> Vector2:
	return shake_a.jitter if i == 0 else shake_b.jitter


func _shake() -> float:
	# shake_scale is the legacy 0 to 1 multiplier (1 by default); the setting is the strength: 10 of 10 is the old
	# prototype's, so 2 of 10 (the default) is 0.28 of Controls' table, and reduced motion takes a quarter of that.
	return shake_scale * (shake_pref / 10.0 * CamParams.SHAKE_PREF_TOP) * (0.25 if reduced_motion else 1.0)


func _on_resized() -> void:
	var sz := Vector2i(maxi(2, int(size.x)), maxi(2, int(size.y)))
	for v in viewports:
		if v != null and v.size != sz:
			v.size = sz
	if _mat != null:
		_mat.set_shader_parameter("res", size)


## Called by main once per displayed frame, after the panes are drawn: pane 1 only renders while it shows, and the
## mask follows the divider. Pane 0 is always drawn (it applies the world's changes).
func present(fr: SplitFrame) -> void:
	last_frame = fr
	if _mat == null:
		return
	var v0 = viewports[0]
	var v1 = viewports[1]
	# One pane on the screen: draw its texture as it is, with no mask pass. Two: the mask blends them.
	var two: bool = fr.shows(0) and fr.shows(1) and v1 != null
	_rect.visible = two
	_solo.visible = not two
	if not two:
		var only = v1 if (not fr.shows(0) and v1 != null) else v0
		if _solo.texture != only.get_texture():
			_solo.texture = only.get_texture()
	if v0 != null:
		# Pane 0 always runs the world's updates on the CPU (main calls its render), but its GPU frame is skipped
		# while another pane has the whole screen.
		v0.render_target_update_mode = SubViewport.UPDATE_ALWAYS if fr.shows(0) else SubViewport.UPDATE_DISABLED
		_mat.set_shader_parameter("tex0", v0.get_texture())
	if v1 != null:
		v1.render_target_update_mode = SubViewport.UPDATE_ALWAYS if fr.shows(1) else SubViewport.UPDATE_DISABLED
		_mat.set_shader_parameter("tex1", v1.get_texture())
	_mat.set_shader_parameter("c", fr.c)
	_mat.set_shader_parameter("n", fr.n)
	_mat.set_shader_parameter("feather", fr.feather)
	_mat.set_shader_parameter("gap", fr.gap)
	_mat.set_shader_parameter("gap_alpha", fr.line_alpha)
	_mat.set_shader_parameter("dim0", CamParams.CUT_DIM * fr.fade)
	_mat.set_shader_parameter("dim1", CamParams.CUT_DIM * fr.fade)
	_solo.modulate = Color(1.0 - CamParams.CUT_DIM * fr.fade, 1.0 - CamParams.CUT_DIM * fr.fade, 1.0 - CamParams.CUT_DIM * fr.fade)
	_mat.set_shader_parameter("active0", 1.0 if fr.shows(0) else 0.0)
	_mat.set_shader_parameter("active1", 1.0 if (fr.shows(1) and v1 != null) else 0.0)
