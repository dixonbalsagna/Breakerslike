// The ground band. The mesh is static; heights come from a float texture (row 0: base, row 1: crater deform) that the
// planet view re-uploads only when the sim's deform array changes, so craters never rebuild geometry.
// UV.x: terrain column index (NC wraps to 0). UV.y: 1 if the vertex follows the surface height. UV2.x: 1 on the top
// face, 0 on the front face. UV2.y: 0 at the front edge, 1 at the back edge. COLOR: biome colour, alpha 1 in desert.
shader_type spatial;
render_mode unshaded, cull_disabled;

#include "res://render/shaders/color.gdshaderinc"
#include "res://render/shaders/bend.gdshaderinc"

uniform sampler2D heights : filter_nearest, repeat_disable;
uniform int nc = 1200;
uniform vec4 sea_floor : source_color;
uniform vec4 crater : source_color;
uniform vec4 crater_desert : source_color;

varying float v_base;
varying float v_def;
varying float v_below;

void vertex() {
	int i = int(UV.x + 0.5) % nc;
	float b = texelFetch(heights, ivec2(i, 0), 0).r;
	float d = texelFetch(heights, ivec2(i, 1), 0).r;
	float h = b + d;
	if (UV.y > 0.5) {
		VERTEX.y = h;
	}
	v_base = b;
	v_def = d;
	v_below = h - VERTEX.y;
	POSITION = bent_clip(MODEL_MATRIX, VIEW_MATRIX, PROJECTION_MATRIX, VERTEX);
}

void fragment() {
	vec3 c = COLOR.rgb;
	if (v_base < -30.0) {
		c = sea_floor.rgb;
	}
	if (v_def < -6.0) {
		c = COLOR.a > 0.5 ? crater_desert.rgb : crater.rgb;
	}
	if (UV2.x > 0.5) {
		c *= mix(1.12, 0.78, UV2.y);
	} else {
		c *= mix(1.0, 0.45, clamp(v_below / 900.0, 0.0, 1.0));
	}
	ALBEDO = c;
}
