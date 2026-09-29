class_name RenderMats
## Greybox materials: flat (opaque and translucent) and additive glow, all from the shaders in render/shaders/.
## Flat materials are shared through a cache; glow materials are per user, because their alpha animates.

const FLAT: Shader = preload("res://render/shaders/flat.gdshader")
const FLAT_ALPHA: Shader = preload("res://render/shaders/flat_alpha.gdshader")
const GLOW: Shader = preload("res://render/shaders/glow.gdshader")

static var _cache: Dictionary = {}


## Shared opaque flat material. shade 0 is fully flat (no fake light).
static func flat(c: Color, shade: float = 0.35) -> ShaderMaterial:
	var key := "f|%s|%s" % [c.to_html(), shade]
	var m = _cache.get(key)
	if m == null:
		m = ShaderMaterial.new()
		m.shader = FLAT
		m.set_shader_parameter("albedo", c)
		m.set_shader_parameter("shade", shade)
		_cache[key] = m
	return m


## Shared translucent flat material (for hidden fighters).
static func flat_alpha(c: Color, alpha: float, shade: float = 0.35) -> ShaderMaterial:
	var key := "a|%s|%s|%s" % [c.to_html(), alpha, shade]
	var m = _cache.get(key)
	if m == null:
		m = ShaderMaterial.new()
		m.shader = FLAT_ALPHA
		m.set_shader_parameter("albedo", Color(c, alpha))
		m.set_shader_parameter("shade", shade)
		_cache[key] = m
	return m


## A new additive glow material; the owner animates it with set_glow().
static func glow(c: Color, alpha: float = 1.0, soft: float = 1.5) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = GLOW
	m.set_shader_parameter("albedo", Color(c, alpha))
	m.set_shader_parameter("soft", soft)
	return m


static func clear_cache() -> void:
	_cache.clear()


static func set_glow(m: ShaderMaterial, c: Color, alpha: float) -> void:
	m.set_shader_parameter("albedo", Color(c, alpha))
