class_name RenderMats
extends RefCounted
## Greybox materials: flat (opaque and translucent) and additive glow, all from the shaders in render/shaders/.
## An instance is one camera's material state (docs/camera/split-screen.md section 11): each PaneWorld owns one, so
## two panes never share a material that carries per-camera values (the curvature, the sky and fog). Its flat
## materials are shared through its cache, and it pushes this pane's bend and sky uniforms to them and to the
## materials it tracks (the terrain and water). A fighter's materials and the glows are per object, so they are
## plain static constructors.

const FLAT: Shader = preload("res://render/shaders/flat.gdshader")
const FLAT_ALPHA: Shader = preload("res://render/shaders/flat_alpha.gdshader")
const GLOW: Shader = preload("res://render/shaders/glow.gdshader")

var _cache: Dictionary = {}
var _tracked: Array = []      # other materials whose shader includes bend.gdshaderinc
var _bend: float = 0.0
var _dist: float = 3000.0
var _sky: Dictionary = {}     # sky uniforms the tracked (fogging) materials share


## This pane's opaque flat material. shade 0 is fully flat (no fake light).
func flat(c: Color, shade: float = 0.35) -> ShaderMaterial:
	var key := "f|%s|%s" % [c.to_html(), shade]
	var m = _cache.get(key)
	if m == null:
		m = ShaderMaterial.new()
		m.shader = FLAT
		m.set_shader_parameter("albedo", c)
		m.set_shader_parameter("shade", shade)
		m.set_shader_parameter("bend", _bend)
		m.set_shader_parameter("cam_dist", _dist)
		_cache[key] = m
	return m


## This pane's translucent flat material.
func flat_alpha(c: Color, alpha: float, shade: float = 0.35) -> ShaderMaterial:
	var key := "a|%s|%s|%s" % [c.to_html(), alpha, shade]
	var m = _cache.get(key)
	if m == null:
		m = ShaderMaterial.new()
		m.shader = FLAT_ALPHA
		m.set_shader_parameter("albedo", Color(c, alpha))
		m.set_shader_parameter("shade", shade)
		m.set_shader_parameter("bend", _bend)
		m.set_shader_parameter("cam_dist", _dist)
		_cache[key] = m
	return m


## A fighter's own flat material (not shared): drawn with the hybrid projection (render/shaders/ortho.gdshaderinc),
## the owner setting its "anchor" every frame. alpha below 1 gives the translucent variant (hidden fighters).
static func fighter_flat(c: Color, alpha: float = 1.0, shade: float = 0.35) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = FLAT if alpha >= 1.0 else FLAT_ALPHA
	m.set_shader_parameter("albedo", Color(c, alpha))
	m.set_shader_parameter("shade", shade)
	m.set_shader_parameter("ortho", 1.0)
	return m


## A skinned fighter mesh's body (render/shaders/fighter_body.gdshader; the mesh baked by OutlineBake): faceted from
## the position's derivatives, since the baked NORMAL is the outline's. Its outline (fighter_hull) is the next pass.
static func fighter_body(c: Color, shade: float = 0.35, outline: bool = true) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = preload("res://render/shaders/fighter_body.gdshader")
	m.set_shader_parameter("albedo", c)
	m.set_shader_parameter("shade", shade)
	m.set_shader_parameter("ortho", 1.0)
	if outline:
		m.next_pass = fighter_hull()
	return m


## A fighter mesh's outline pass (render/shaders/fighter_hull.gdshader; the mesh baked by OutlineBake): set it as the
## body material's next_pass. Like fighter_flat it uses the hybrid projection, the owner setting its "anchor" every frame.
static func fighter_hull(px: float = RenderLook.OUTLINE_PX) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = preload("res://render/shaders/fighter_hull.gdshader")
	m.set_shader_parameter("outline_px", px)
	m.set_shader_parameter("col", RenderLook.col(RenderLook.OUTLINE))
	m.set_shader_parameter("ortho", 1.0)
	return m


## A new additive glow material; the owner animates it with set_glow().
static func glow(c: Color, alpha: float = 1.0, soft: float = 1.5) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = GLOW
	m.set_shader_parameter("albedo", Color(c, alpha))
	m.set_shader_parameter("soft", soft)
	return m


func clear() -> void:
	_cache.clear()
	_tracked.clear()


## Register a material (built elsewhere) whose shader bends with the planet curvature and fogs into the sky.
func track(m: ShaderMaterial) -> void:
	_tracked.append(m)
	m.set_shader_parameter("bend", _bend)
	m.set_shader_parameter("cam_dist", _dist)
	for k in _sky:
		m.set_shader_parameter(k, _sky[k])


## This pane's planet curvature for the frame (render/shaders/bend.gdshaderinc): bend and the camera's distance to the
## fighter plane, pushed to every bending material when they change.
## How far the planet's bend lowers a point at camera-relative x and depth z this frame: the CPU twin of bent_world()
## in render/shaders/bend.gdshaderinc, for what is placed rather than bent in a shader (a fighter at depth).
func sag(x: float, z: float) -> float:
	var back: float = maxf(-z, 0.0)
	var k: float = clampf((back - 60.0) / 1200.0, 0.0, 1.0) * _dist / (_dist + back)
	return _bend * x * x * k


func set_bend(b: float, dist: float) -> void:
	if absf(b - _bend) <= 1e-4 * absf(_bend) + 1e-12 and absf(dist - _dist) <= 1e-4 * _dist:
		return
	_bend = b
	_dist = dist
	for m in _cache.values():
		m.set_shader_parameter("bend", b)
		m.set_shader_parameter("cam_dist", dist)
	for m in _tracked:
		m.set_shader_parameter("bend", b)
		m.set_shader_parameter("cam_dist", dist)


## A sky uniform (render/shaders/skycol.gdshaderinc) for this pane's fogging materials: set once for constants, per
## frame for space and horizon.
func set_sky(name: String, v) -> void:
	if _sky.get(name) == v:
		return
	_sky[name] = v
	for m in _tracked:
		m.set_shader_parameter(name, v)


static func set_glow(m: ShaderMaterial, c: Color, alpha: float) -> void:
	m.set_shader_parameter("albedo", Color(c, alpha))
