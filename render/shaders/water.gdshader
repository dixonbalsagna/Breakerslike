// Water: the sea and crater lakes, one surface from the band's front face to the horizon. In the crater rows it comes
// from S.water (the sim's per-column depth): a surface at each wet column's standing level, depth-tested against the
// ground, so a lake shows only inside its bowl; off the sea (base below -30) the ground there must also be dug, so
// low coastal land beside a lake stays dry. Behind the crater rows the far terrain decides, in the sea's columns (base
// below -30, the sim's sea rule): sea level wherever the far ground is below it, so the sea runs on to the horizon
// with one shoreline, and islands rise where the far sea floor does.
// A front face drops from the surface to the ground at the band's front edge. It fogs into the sky like the ground.
// UV.x: terrain column. UV.y (front face): 1 on the bottom edge. UV2.x: 1 on the surface grid. UV2.y: 1 on the
// fighter-plane row. Same data as the terrain (ground.gdshaderinc).
shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;

#include "res://render/shaders/bend.gdshaderinc"
#include "res://render/shaders/ground.gdshaderinc"
#include "res://render/shaders/skycol.gdshaderinc"

uniform vec4 water : source_color;
uniform vec4 surface : source_color;
uniform float z_front = 141.0;
uniform float fog_near = 700.0;
uniform float fog_far = 12000.0;

varying float v_wet;
varying float v_depth;
varying float v_ok;
varying vec3 v_view;
varying float v_wz;

void vertex() {
	int i = int(UV.x + 0.5) % nc;
	float xw = UV.x * col_w;
	float b = gf(i, 0);
	float d0 = gf(i, 1);
	float wd = gf(i, 4);
	float zq = UV2.x > 0.5 ? VERTEX.z : z_front;
	float s = far_weight(zq);
	float surf;
	float ground;
	if (s <= 0.0) {
		v_wet = wd >= wet_min ? 1.0 : 0.0;
		surf = b + d0 + wd;
		float off = d0;
		if (v_wet > 0.5 && UV2.y < 0.5) {
			off = ground_offset(i, xw, zq);
		}
		ground = b + off;
		v_ok = (b < sea_base || off < -wet_min) ? 1.0 : 0.0;
	} else {
		float xs = far_x(xw, zq, s);
		ground = mix(b, far_height3(xs, xw, zq).x, s);
		surf = 0.0;
		v_wet = (ground < 0.0 && mix(b, gfx(xs, 0), s) < sea_base) ? 1.0 : 0.0;
		v_ok = 1.0;
	}
	if (UV2.x > 0.5) {
		VERTEX.y = surf;
	} else {
		VERTEX.y = UV.y > 0.5 ? min(ground, surf) : surf;
	}
	v_depth = surf - ground;
	vec4 bw = bent_world(MODEL_MATRIX, VERTEX);
	v_view = (VIEW_MATRIX * bw).xyz;
	v_wz = bw.z;
	POSITION = PROJECTION_MATRIX * vec4(v_view, 1.0);
}

void fragment() {
	if (v_wet < 0.5 || v_depth <= 0.0 || v_ok < 0.5) {
		discard;
	}
	vec3 c;
	float a;
	if (UV2.x > 0.5) {
		c = surface.rgb;
		a = surface.a;
	} else {
		c = water.rgb;
		a = 0.5 + 0.25 * clamp(v_depth / 340.0, 0.0, 1.0);
	}
	float fog = ground_fog(elevation(v_view), -v_wz, fog_near, fog_far);
	ALBEDO = mix(c, sky_color(elevation(v_view)), fog);
	ALPHA = mix(a, 1.0, fog);
}
