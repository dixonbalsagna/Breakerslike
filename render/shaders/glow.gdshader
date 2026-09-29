// Additive glow (auras, beams, charge orbs, guard, hidden ripple). Alpha falls off toward silhouette edges, so
// a sphere reads as a radial gradient and a cylinder as a soft-edged beam. Only back faces draw, so a glow around a
// fighter sits behind the body instead of washing over it.
shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_front;

#include "res://render/shaders/ortho.gdshaderinc"

uniform vec4 albedo : source_color = vec4(1.0);
uniform float soft = 1.5;

void vertex() {
	if (ortho > 0.5) {
		POSITION = ortho_clip(MODEL_MATRIX, VIEW_MATRIX, PROJECTION_MATRIX, VERTEX);
	} else {
		POSITION = PROJECTION_MATRIX * (MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
	}
}

void fragment() {
	// With the hybrid projection the glow is drawn orthographically, so its edges are where the normal turns side-on
	// to the camera axis, not to the perspective view ray.
	float facing = abs(dot(normalize(NORMAL), ortho > 0.5 ? vec3(0.0, 0.0, 1.0) : normalize(VIEW)));
	ALBEDO = albedo.rgb;
	ALPHA = albedo.a * pow(facing, soft);
}
