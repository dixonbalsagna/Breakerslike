// The ground band: a grid of terrain columns by rows in depth, heights from the ground field (ground.gdshaderinc).
// UV.x: terrain column (NC wraps to 0). UV.y: 1 if the vertex follows the ground height (0 on the floor).
// UV2.x: 1 on the top face, 0 on the front face. UV2.y: 1 on the row that lies on the fighter plane, which reads the
// sim's deform directly (exact); every other row sums the round crater bowls, furrows and the groove residual.
// COLOR: biome colour, alpha 1 in desert. Scorch chars the ground from S.scorch; heat (fresh grooves) glows.
shader_type spatial;
render_mode unshaded, cull_disabled;

#include "res://render/shaders/color.gdshaderinc"
#include "res://render/shaders/bend.gdshaderinc"
#include "res://render/shaders/ground.gdshaderinc"

uniform vec4 sea_floor : source_color;
uniform vec4 crater : source_color;
uniform vec4 crater_desert : source_color;
uniform vec4 ejecta : source_color;
uniform vec4 char_col : source_color;
uniform vec4 heat_lo : source_color;
uniform vec4 heat_hi : source_color;
uniform float z_front = 140.0;
uniform float z_back = -520.0;

varying float v_base;
varying float v_off;
varying float v_below;
varying float v_scorch;
varying float v_heat;
varying float v_back;

void vertex() {
	int i = int(UV.x + 0.5) % nc;
	float b = gf(i, 0);
	vec3 o = ground_offset3(i, UV.x * col_w, VERTEX.z);
	float off = UV2.y > 0.5 ? gf(i, 1) : o.x;
	float h = b + off;
	if (UV.y > 0.5) {
		VERTEX.y = h;
	}
	if (UV2.x > 0.5) {
		float db = (gf((i + 1) % nc, 0) - gf((i + nc - 1) % nc, 0)) / (2.0 * col_w);
		NORMAL = normalize(vec3(-(db + o.y), 1.0, -o.z));
	}
	v_base = b;
	v_off = off;
	v_below = h - VERTEX.y;
	float w = groove_half(gf(i, 3));
	float t = clamp(1.0 - VERTEX.z * VERTEX.z / (w * w), 0.0, 1.0);
	v_scorch = gf(i, 3) * t;
	v_heat = gf(i, 5) * t;
	v_back = clamp((z_front - VERTEX.z) / (z_front - z_back), 0.0, 1.0);
	POSITION = bent_clip(MODEL_MATRIX, VIEW_MATRIX, PROJECTION_MATRIX, VERTEX);
}

void fragment() {
	vec3 c = COLOR.rgb;
	if (v_base < -30.0) {
		c = sea_floor.rgb;
	}
	if (v_off < -6.0) {
		c = COLOR.a > 0.5 ? crater_desert.rgb : crater.rgb;
	} else if (v_off > 3.0) {
		c = mix(c, ejecta.rgb, clamp(v_off / 30.0, 0.0, 0.6));
	}
	c = mix(c, char_col.rgb, clamp(v_scorch * 1.1, 0.0, 0.92));
	if (UV2.x > 0.5) {
		c = flat_shade(c, NORMAL, 0.55) * mix(1.2, 0.85, v_back);
	} else {
		c *= mix(1.0, 0.45, clamp(v_below / 900.0, 0.0, 1.0));
	}
	float hh = clamp(v_heat, 0.0, 1.6);
	vec3 glow = mix(heat_lo.rgb, heat_hi.rgb, clamp(hh - 0.6, 0.0, 1.0));
	c = mix(c, glow, clamp(hh, 0.0, 1.0) * 0.85) + glow * max(0.0, hh - 1.0) * 0.6;
	ALBEDO = c;
}
