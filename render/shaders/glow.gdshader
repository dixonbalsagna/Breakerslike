// Additive glow (auras, beams, charge orbs, guard, hidden ripple). Alpha falls off toward silhouette edges, so
// a sphere reads as a radial gradient and a cylinder as a soft-edged beam. Only back faces draw, so a glow around a
// fighter sits behind the body instead of washing over it.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_front;

uniform vec4 albedo : source_color = vec4(1.0);
uniform float soft = 1.5;

void fragment() {
	float facing = abs(dot(normalize(NORMAL), normalize(VIEW)));
	ALBEDO = albedo.rgb;
	ALPHA = albedo.a * pow(facing, soft);
}
