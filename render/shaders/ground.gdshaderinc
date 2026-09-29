// The ground band's height field, shared by the terrain and water shaders. Data layout and the reasoning are in
// render/core/ground_field.gd (whose offset_at() is the CPU twin of ground_offset() below). The crater profile is
// WorldCrater.profile from sim/world/crater.gd. Every size is a uniform set from the sim's constants (WorldCrater)
// or RenderLook by planet_view.gd, so nothing here assumes today's world scale.
uniform sampler2D heights : filter_nearest, repeat_disable;   // RF, NC x 12
uniform sampler2D craters : filter_nearest, repeat_disable;   // RGBAF, 400 x 2
uniform int nc = 1200;
uniform float col_w = 8.0;
uniform float world_w = 9600.0;
uniform float rim_in = 0.3;          // WorldCrater.RIM_IN
uniform float rim_out = 1.0;         // WorldCrater.RIM_OUT
uniform float groove_w0 = 30.0;      // WorldCrater.SCORCH_HW0 and SCORCH_HW_P: a groove's half width from P
uniform float groove_wp = 22.0;
uniform float groove_i0 = 0.35;      // WorldCrater.SCORCH_INT0 and SCORCH_INT_P: burn intensity from P
uniform float groove_ip = 0.15;
uniform float groove_pmin = 0.5;     // the beam-power range
uniform float groove_pmax = 4.5;
uniform float spread_w = 60.0;       // RenderLook.GROUND_SPREAD
uniform float furrow_wr = 0.3;       // RenderLook.FURROW_W_R and FURROW_W_MIN
uniform float furrow_wmin = 20.0;

float gf(int i, int row) {
	return texelFetch(heights, ivec2(i, row), 0).r;
}

// (height, d height / du) of WorldCrater.profile.
vec2 crater_profile(float u, float d, float hr) {
	if (u < 1.0) {
		float t = 1.0 - u * u;
		vec2 h = vec2(-d * t * t, 4.0 * d * u * t);
		float lo = 1.0 - rim_in;
		if (u > lo) {
			float a = (u - lo) / rim_in;
			h += vec2(hr * a * a * (3.0 - 2.0 * a), hr * 6.0 * a * (1.0 - a) / rim_in);
		}
		return h;
	} else if (u < 1.0 + rim_out) {
		float b = (u - 1.0) / rim_out;
		return vec2(hr * (1.0 - b * b * (3.0 - 2.0 * b)), -hr * 6.0 * b * (1.0 - b) / rim_out);
	}
	return vec2(0.0);
}

// (height, d/dx, d/dz) of a glancing impact's furrow.
vec3 furrow(float dx, float z, float r, float skid, float sd) {
	if (sd <= 0.0 || skid == 0.0 || dx * skid < 0.0) {
		return vec3(0.0);
	}
	float L = abs(skid);
	float q = 1.0 - abs(dx) / L;
	if (q <= 0.0) {
		return vec3(0.0);
	}
	float wf = max(furrow_wmin, furrow_wr * r);
	float t = 1.0 - z * z / (wf * wf);
	if (t <= 0.0) {
		return vec3(0.0);
	}
	return vec3(-sd * q * q * t * t, 2.0 * sd * q * t * t * sign(dx) / L, 4.0 * sd * q * q * t * z / (wf * wf));
}

float groove_half(float s) {
	return s <= 0.01 ? spread_w : groove_w0 + groove_wp * clamp((s - groove_i0) / groove_ip, groove_pmin, groove_pmax);
}

// (height offset added to base, d/dx, d/dz) at column i, world x xw, depth z; the height is not used on the
// fighter-plane row, which reads the sim's deform directly. The gradient gives the terrain smooth normals.
vec3 ground_offset3(int i, float xw, float z) {
	vec3 s = vec3(0.0);
	for (int k = 0; k < 6; k++) {
		float fi = gf(i, 6 + k);
		if (fi < 0.0) {
			break;
		}
		int ci = int(fi + 0.5);
		vec4 a = texelFetch(craters, ivec2(ci, 0), 0);
		vec4 b = texelFetch(craters, ivec2(ci, 1), 0);
		float dx = xw - a.x;
		dx -= world_w * round(dx / world_w);
		float rho = sqrt(dx * dx + z * z);
		vec2 p = crater_profile(rho / a.y, a.z, a.w);
		float k2 = rho > 0.0001 ? p.y / (a.y * rho) : 0.0;
		s += vec3(p.x, k2 * dx, k2 * z) + furrow(dx, z, a.y, b.x, b.y);
	}
	float w = groove_half(gf(i, 3));
	float t = 1.0 - z * z / (w * w);
	if (t > 0.0) {
		float gl = gf((i + nc - 1) % nc, 2);
		float gr = gf((i + 1) % nc, 2);
		float g = gf(i, 2);
		s += vec3(g * t * t, (gr - gl) / (2.0 * col_w) * t * t, -4.0 * g * t * z / (w * w));
	}
	return s;
}

float ground_offset(int i, float xw, float z) {
	return ground_offset3(i, xw, z).x;
}
