// Water from S.water (the sim's per-column depth): the sea and crater lakes. A surface grid at each wet column's
// standing level (ground + depth) across the band's depth, plus a front face down to the ground at the band's front
// edge. The surface is depth-tested against the ground, so a lake shows only inside its bowl; off the sea (base
// below -30), water also needs the ground there to be dug, so low coastal land beside a lake stays dry.
// UV.x: terrain column. UV.y (front face): 1 on the bottom edge. UV2.x: 1 on the surface grid. UV2.y: 1 on the
// fighter-plane row. Same data as the terrain (ground.gdshaderinc).
shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;

#include "res://render/shaders/bend.gdshaderinc"
#include "res://render/shaders/ground.gdshaderinc"

uniform vec4 water : source_color;
uniform vec4 surface : source_color;
uniform float z_front = 141.0;

varying float v_wet;
varying float v_depth;
varying float v_ok;

void vertex() {
	int i = int(UV.x + 0.5) % nc;
	float b = gf(i, 0);
	float d0 = gf(i, 1);
	float wd = gf(i, 4);
	v_wet = wd >= 0.5 ? 1.0 : 0.0;
	float surf = b + d0 + wd;
	float off = d0;
	if (v_wet > 0.5 && UV2.y < 0.5) {
		off = ground_offset(i, UV.x * col_w, UV2.x > 0.5 ? VERTEX.z : z_front);
	}
	float ground = b + off;
	if (UV2.x > 0.5) {
		VERTEX.y = surf;
	} else {
		VERTEX.y = UV.y > 0.5 ? min(ground, surf) : surf;
	}
	v_depth = surf - ground;
	v_ok = (b < -30.0 || off < -0.5) ? 1.0 : 0.0;
	POSITION = bent_clip(MODEL_MATRIX, VIEW_MATRIX, PROJECTION_MATRIX, VERTEX);
}

void fragment() {
	if (v_wet < 0.5 || v_depth <= 0.0 || v_ok < 0.5) {
		discard;
	}
	if (UV2.x > 0.5) {
		ALBEDO = surface.rgb;
		ALPHA = surface.a;
	} else {
		ALBEDO = water.rgb;
		ALPHA = 0.5 + 0.25 * clamp(v_depth / 340.0, 0.0, 1.0);
	}
}
