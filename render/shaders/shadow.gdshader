// A fighter's ground shadow (B3): a soft dark ellipse lying on the ground as drawn under the fighter, at his depth. It
// says where he is over the ground when a brunt launch carries him into the building rows. World geometry: it takes
// the planet's bend like the ground it lies on (pane_world.gd places and sizes it).
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;

#include "res://render/shaders/bend.gdshaderinc"

uniform float strength = 0.38;

void vertex() {
	POSITION = bent_clip(MODEL_MATRIX, VIEW_MATRIX, PROJECTION_MATRIX, VERTEX);
}

void fragment() {
	vec2 q = UV * 2.0 - 1.0;
	ALBEDO = vec3(0.0);
	ALPHA = strength * smoothstep(1.0, 0.2, dot(q, q));
}
