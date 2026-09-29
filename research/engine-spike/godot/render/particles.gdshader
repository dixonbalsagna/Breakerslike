// Particles: one MultiMesh of quads, drawn in one call, with a stateless ballistic vertex shader.
// Instances are split into three sections of fixed-size bursts (ring buffers of burst slots):
//   crater (event kind 0): 150 per burst, 2.0 s, vx +-300, vy 150..700, size 6   -> 128 slots
//   big crater (kind 1):  3000 per burst, 3.0 s, vx +-900, vy 200..1400, size 8  -> 3 slots
//   beam spark:              5 per burst, 0.8 s, vx +-400, vy 100..600, size 4   -> 320 slots
// The CPU writes one texel per burst when it spawns: (world x, y, spawn tick, +-seed; the sign is the beam owner).
// Each particle's velocity comes from a hash of (burst seed, particle index), so nothing per particle is ever
// uploaded. Position = origin + v*t + g*t^2/2 with g = -900, t in sim time. The shortest-arc offset from the camera
// (sdx) is taken per vertex, so particles stay camera-relative and seamless across x = 0.
shader_type spatial;
render_mode blend_add, unshaded, depth_draw_never, cull_disabled, skip_vertex_transform, shadows_disabled, fog_disabled;

uniform sampler2D bursts : filter_nearest, repeat_disable;  // BURST_TEXELS x 1, RGBA32F
uniform float cam_x = 0.0;      // camera x, wrapped to [0, W)
uniform float now_tick = 0.0;   // current sim tick

const float W = 9600.0;
const float HALF = 4800.0;
const float TPS = 60.0;
const float G = -900.0;
const int CR_N = 150;
const int CR_SLOTS = 128;
const int BG_N = 3000;
const int BG_SLOTS = 3;
const int SP_N = 5;
const int CR_END = 19200;     // CR_N * CR_SLOTS
const int BG_END = 28200;     // CR_END + BG_N * BG_SLOTS

varying vec3 v_color;
varying float v_alpha;

uint hash_u(uint x) {
	x ^= x >> 16u;
	x *= 0x7feb352du;
	x ^= x >> 15u;
	x *= 0x846ca68bu;
	x ^= x >> 16u;
	return x;
}

float rnd(uint seed, uint k) {
	return float(hash_u(seed * 0x9e3779b9u + k) >> 8u) / 16777216.0;
}

void vertex() {
	int id = INSTANCE_ID;
	int texel;
	int k;
	float life;
	float vx_max;
	float vy_lo;
	float vy_hi;
	float size;
	int kind;
	if (id < CR_END) {
		texel = id / CR_N; k = id - texel * CR_N;
		life = 2.0; vx_max = 300.0; vy_lo = 150.0; vy_hi = 700.0; size = 6.0; kind = 0;
	} else if (id < BG_END) {
		int s = (id - CR_END) / BG_N; k = id - CR_END - s * BG_N; texel = CR_SLOTS + s;
		life = 3.0; vx_max = 900.0; vy_lo = 200.0; vy_hi = 1400.0; size = 8.0; kind = 1;
	} else {
		int s = (id - BG_END) / SP_N; k = id - BG_END - s * SP_N; texel = CR_SLOTS + BG_SLOTS + s;
		life = 0.8; vx_max = 400.0; vy_lo = 100.0; vy_hi = 600.0; size = 4.0; kind = 2;
	}
	vec4 b = texelFetch(bursts, ivec2(texel, 0), 0);
	float age = (now_tick - b.z) / TPS;
	if (age < 0.0 || age >= life) {
		// Dead or unused slot: collapse all four corners to one point outside the clip volume.
		POSITION = vec4(-10.0, -10.0, -10.0, 1.0);
		v_color = vec3(0.0);
		v_alpha = 0.0;
	} else {
		uint seed = uint(abs(b.w));
		uint kk = uint(k) * 2u;
		float vx = mix(-vx_max, vx_max, rnd(seed, kk));
		float vy = mix(vy_lo, vy_hi, rnd(seed, kk + 1u));
		float px = b.x - cam_x + vx * age;
		px = px - W * floor((px + HALF) / W);        // shortest-arc offset from the camera, in [-HALF, HALF)
		float py = b.y + vy * age + 0.5 * G * age * age;
		vec3 center = (VIEW_MATRIX * vec4(px, py, 0.0, 1.0)).xyz;
		VERTEX = center + vec3(VERTEX.xy * size, 0.0);
		POSITION = PROJECTION_MATRIX * vec4(VERTEX, 1.0);
		float fade = 1.0 - age / life;
		if (kind == 0) { v_color = vec3(0.95, 0.62, 0.32); }
		else if (kind == 1) { v_color = vec3(1.0, 0.72, 0.30); }
		else if (b.w >= 0.0) { v_color = vec3(0.60, 0.95, 1.0); }
		else { v_color = vec3(1.0, 0.80, 0.50); }
		v_alpha = fade;
	}
}

void fragment() {
	float r = length(UV - vec2(0.5)) * 2.0;
	float a = clamp(1.0 - r * r, 0.0, 1.0);
	ALBEDO = v_color;
	ALPHA = a * v_alpha;
}
