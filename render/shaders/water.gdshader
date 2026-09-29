// Sea water: a front face from sea level down to the sea bed plus a surface band, drawn only where the base terrain
// is below sea level (the sim's seaAt rule) and the ground is still under water. Same layout as terrain.gdshader.
shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;

uniform sampler2D heights : filter_nearest, repeat_disable;
uniform int nc = 1200;
uniform vec4 water : source_color;
uniform vec4 surface : source_color;

varying float v_base;
varying float v_h;

void vertex() {
	int i = int(UV.x + 0.5) % nc;
	float b = texelFetch(heights, ivec2(i, 0), 0).r;
	float h = b + texelFetch(heights, ivec2(i, 1), 0).r;
	if (UV.y > 0.5) {
		VERTEX.y = min(h, 0.0);
	}
	v_base = b;
	v_h = h;
}

void fragment() {
	if (v_base >= -30.0 || v_h >= 0.0) {
		discard;
	}
	if (UV2.x > 0.5) {
		ALBEDO = surface.rgb;
		ALPHA = surface.a;
	} else {
		ALBEDO = water.rgb;
		ALPHA = 0.5 + 0.25 * clamp(-v_h / 340.0, 0.0, 1.0);
	}
}
