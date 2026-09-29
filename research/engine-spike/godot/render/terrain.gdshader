// Terrain: a static grid of GRID_COLS columns centred on the camera (floating origin). Every vertex reads its height
// from a 1200x1 float texture (base + deform) with texelFetch, so a crater costs one small texture upload, not a mesh
// rebuild. Vertex UV carries (grid column i, kind): 0 top-back, 1 top-front, 2 face-top, 3 face-bottom.
shader_type spatial;
render_mode cull_back, diffuse_lambert, specular_disabled;

uniform sampler2D heights : filter_nearest, repeat_disable;             // 1200x1 RF, base + deform (dynamic)
uniform sampler2D base_heights : filter_nearest, repeat_disable;        // 1200x1 RF, base only (static)
uniform sampler2D biome_colors : source_color, filter_nearest, repeat_disable; // 1200x1 RGBA8 (static)
uniform int col0 = 0;        // planet column shown by grid column 0, in [0, 1200)
uniform float x_off = 0.0;   // render x of grid column 0 = column0 * 8 - camera x, computed in float64 on the CPU

const int NC = 1200;
const float COLW = 8.0;
const float Z_BACK = -400.0;
const float Z_FRONT = 120.0;
const float FACE_BOTTOM = -700.0;

varying vec3 v_color;

int wrap_col(int c) { return (c + NC) % NC; }   // c is never below -1 here
float h_at(int c) { return texelFetch(heights, ivec2(wrap_col(c), 0), 0).r; }

void vertex() {
	int i = int(UV.x + 0.5);
	int kind = int(UV.y + 0.5);
	int c = col0 + i;
	int cw = wrap_col(c);
	float h = texelFetch(heights, ivec2(cw, 0), 0).r;
	float x = x_off + float(i) * COLW;
	vec3 albedo = texelFetch(biome_colors, ivec2(cw, 0), 0).rgb;
	// Snow on high ground (presentation only).
	albedo = mix(albedo, vec3(0.92, 0.93, 0.95), clamp((h - 620.0) / 120.0, 0.0, 1.0));
	// Scorch: darken wherever the ground has been cratered (deform < 0).
	float deform = h - texelFetch(base_heights, ivec2(cw, 0), 0).r;
	float scorch = clamp(-deform / 90.0, 0.0, 1.0);
	albedo = mix(albedo, albedo * vec3(0.30, 0.26, 0.22), scorch);
	if (kind <= 1) {
		VERTEX = vec3(x, h, kind == 0 ? Z_BACK : Z_FRONT);
		float hl = h_at(c - 1);
		float hr = h_at(c + 1);
		NORMAL = normalize(vec3(-(hr - hl) / (2.0 * COLW), 1.0, 0.0));
	} else {
		// Front face: a cross-section of the ground, darker with depth.
		float y = kind == 2 ? h : FACE_BOTTOM;
		VERTEX = vec3(x, y, Z_FRONT);
		NORMAL = vec3(0.0, 0.0, 1.0);
		albedo *= kind == 2 ? 0.8 : 0.35;
	}
	v_color = albedo;
}

void fragment() {
	ALBEDO = v_color;
	ROUGHNESS = 1.0;
	METALLIC = 0.0;
}
