// The ground: one surface from the band's front face to the horizon. A grid of terrain columns by rows in depth,
// heights from the ground field (ground.gdshaderinc). The crater rows (front to RenderLook.Z_TERRAIN_BACK) carry the
// round bowls, furrows and grooves; the row on the fighter plane reads the sim's deform directly (exact). Behind
// them the far terrain blends in: the same columns' base heights and biomes with relief, fading into the sky's own
// colour toward the far edge, so there is no backdrop, no gap and no edge.
// UV.x: terrain column (NC wraps to 0). UV.y: 1 if the vertex follows the ground height (0 on the floor).
// UV2.x: 1 on the top grid, 0 on the front face. UV2.y: 1 on the fighter-plane row. COLOR: biome colour, alpha 1 in
// desert. Scorch chars the ground from S.scorch; heat (fresh grooves) glows.
shader_type spatial;
render_mode unshaded, cull_disabled;

#include "res://render/shaders/color.gdshaderinc"
#include "res://render/shaders/bend.gdshaderinc"
#include "res://render/shaders/ground.gdshaderinc"
#include "res://render/shaders/skycol.gdshaderinc"

uniform vec4 sea_floor : source_color;
uniform vec4 crater : source_color;
uniform vec4 crater_desert : source_color;
uniform vec4 ejecta : source_color;
uniform vec4 char_col : source_color;
uniform vec4 heat_lo : source_color;
uniform vec4 heat_hi : source_color;
uniform vec4 snow : source_color;
uniform float snow_from = 560.0;
uniform float snow_full = 900.0;
uniform float z_front = 140.0;
uniform float fog_near = 700.0;
uniform float fog_far = 12000.0;

varying float v_base;
varying vec3 v_col;
varying float v_desert;
varying float v_dent;
varying float v_h;
varying float v_below;
varying float v_scorch;
varying float v_heat;
varying float v_back;
varying vec3 v_view;
varying float v_wz;

void vertex() {
	int i = int(UV.x + 0.5) % nc;
	float xw = UV.x * col_w;
	float z = VERTEX.z;
	float b = gf(i, 0);
	vec3 o = z >= z_band_back - 0.5 ? ground_offset3(i, xw, z) : vec3(0.0);
	float off = UV2.y > 0.5 ? gf(i, 1) : o.x;
	float h = b + off;
	vec2 grad = vec2(base_slope(i) + o.y, o.z);
	float s = far_weight(z);
	v_col = COLOR.rgb;
	v_desert = COLOR.a;
	v_base = b;
	if (s > 0.0) {
		float xs = far_x(xw, z, s);
		vec3 f = far_height3(xs, xw, z);
		h = mix(h, f.x, s);
		grad = mix(grad, f.yz, s);
		v_col = mix(COLOR.rgb, biome_rgb(xs), s);
		v_desert = abs(far_biome(xs) - 5.0) < 0.5 ? 1.0 : 0.0;
		v_base = mix(b, gfx(xs, 0), s);
	}
	if (UV.y > 0.5) {
		VERTEX.y = h;
	}
	if (UV2.x > 0.5) {
		NORMAL = normalize(vec3(-grad.x, 1.0, -grad.y));
	}
	v_dent = off * (1.0 - s);
	v_h = h;
	v_below = h - VERTEX.y;
	float w = groove_half(gf(i, 3));
	float t = clamp(1.0 - z * z / (w * w), 0.0, 1.0);
	v_scorch = gf(i, 3) * t;
	v_heat = gf(i, 5) * t;
	v_back = clamp((z_front - z) / (z_front - z_band_back), 0.0, 1.0);
	vec4 bw = bent_world(MODEL_MATRIX, VERTEX);
	v_view = (VIEW_MATRIX * bw).xyz;
	v_wz = bw.z;
	POSITION = PROJECTION_MATRIX * vec4(v_view, 1.0);
}

void fragment() {
	vec3 c = v_col;
	if (v_base < -30.0 && v_h < -30.0) {
		c = sea_floor.rgb;
	}
	if (v_dent < -6.0) {
		c = v_desert > 0.5 ? crater_desert.rgb : crater.rgb;
	} else if (v_dent > 3.0) {
		c = mix(c, ejecta.rgb, clamp(v_dent / 30.0, 0.0, 0.6));
	}
	c = mix(c, snow.rgb, smoothstep(snow_from, snow_full, v_h));
	c = mix(c, char_col.rgb, clamp(v_scorch * 1.1, 0.0, 0.92));
	if (UV2.x > 0.5) {
		c = flat_shade(c, NORMAL, 0.55) * mix(1.2, 0.95, v_back);
	} else {
		c *= mix(1.0, 0.45, clamp(v_below / 900.0, 0.0, 1.0));
	}
	float hh = clamp(v_heat, 0.0, 1.6);
	vec3 glow = mix(heat_lo.rgb, heat_hi.rgb, clamp(hh - 0.6, 0.0, 1.0));
	c = mix(c, glow, clamp(hh, 0.0, 1.0) * 0.85) + glow * max(0.0, hh - 1.0) * 0.6;
	// Aerial perspective: hazing toward the horizon, the ground takes the sky's colour in its own direction.
	float fog = ground_fog(elevation(v_view), -v_wz, fog_near, fog_far);
	ALBEDO = mix(c, sky_color(elevation(v_view)), fog);
}
