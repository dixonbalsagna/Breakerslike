// Water: a translucent surface at y = 0 over every column whose base height is below SEA_BASE (-30), over the terrain's
// depth span (z = -400 .. +120). A front face (z = +121) and a back face (z = -400) close the water body down to the sea
// floor so that no sky shows under the surface. Same grid and floating origin as the terrain.
// Vertex UV carries (grid column i, kind): 0/1 back face top/bottom, 2/3 surface back/front, 4/5 front face top/bottom.
shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded, shadows_disabled, fog_disabled;

uniform sampler2D heights : filter_nearest, repeat_disable;
uniform sampler2D base_heights : filter_nearest, repeat_disable;
uniform int col0 = 0;
uniform float x_off = 0.0;
uniform vec3 surface_color : source_color = vec3(0.24, 0.52, 0.80);
uniform vec3 deep_color : source_color = vec3(0.06, 0.20, 0.42);

const int NC = 1200;
const float COLW = 8.0;
const float SEA_BASE = -30.0;

varying float v_col;     // grid column, interpolated; floor() names the column a fragment belongs to
varying float v_face;    // 0 back face, 1 surface, 2 front face
varying float v_depth;   // 0 at the surface, 1 at the sea floor

void vertex() {
	int i = int(UV.x + 0.5);
	int kind = int(UV.y + 0.5);
	int cw = (col0 + i) % NC;
	float floor_y = min(texelFetch(heights, ivec2(cw, 0), 0).r, 0.0);
	float x = x_off + float(i) * COLW;
	float y = 0.0;
	float z = 0.0;
	v_depth = 0.0;
	if (kind <= 1) { z = -400.0; v_face = 0.0; if (kind == 1) { y = floor_y; v_depth = 1.0; } }
	else if (kind <= 3) { z = kind == 2 ? -400.0 : 120.0; v_face = 1.0; }
	else { z = 121.0; v_face = 2.0; if (kind == 5) { y = floor_y; v_depth = 1.0; } }
	VERTEX = vec3(x, y, z);
	v_col = float(i);
}

void fragment() {
	int cw = (col0 + int(floor(v_col))) % NC;
	if (texelFetch(base_heights, ivec2(cw, 0), 0).r >= SEA_BASE) {
		discard;
	}
	vec3 c = surface_color;
	float a = 0.55;
	if (v_face < 0.5) { c = deep_color; a = 0.95; }
	else if (v_face > 1.5) { c = mix(surface_color * 0.8, deep_color, v_depth); a = 0.72; }
	ALBEDO = c;
	ALPHA = a;
}
