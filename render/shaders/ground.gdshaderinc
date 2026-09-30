// The ground band's height field, shared by the terrain and water shaders. Data layout and the reasoning are in
// render/core/ground_field.gd (whose offset_at() is the CPU twin of ground_offset() below). The crater profile is
// WorldCrater.profile from sim/world/crater.gd. Every size is a uniform set from the sim's constants (WorldCrater)
// or RenderLook by planet_view.gd, so nothing here assumes today's world scale.
uniform sampler2D heights : filter_nearest, repeat_disable;   // RF: 21 data rows of NC, each as rpl texture rows of tw
uniform sampler2D craters : filter_nearest, repeat_disable;   // RGBAF, 400 x 2
uniform int nc = 1200;
uniform int tw = 1200;
uniform int rpl = 1;
uniform float far_scale = 1.0;       // WS: the far relief's depth wavelengths grow with the world
uniform float sea_base = -30.0;      // WorldWater.RESERVOIR_BASE: base ground below this is the sea
uniform float wet_min = 0.5;         // WorldWater.MIN_DEPTH: water shallower than this counts as dry
uniform float dent_min = 6.0;        // a dent deeper than this colours as a crater floor (6 x WS)
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
uniform float z_band_back = -520.0;  // RenderLook: rows behind this are the far terrain ...
uniform float far_blend = 900.0;     // ... which blends in from the band's heights over this depth
uniform float rubble_edge = 240.0;   // RenderLook.RUBBLE_EDGE: a heap eases off over this depth past its range
uniform float meander_amp = 600.0;   // RenderLook.MEANDER: how far (in x) the far land's biomes wander with depth
uniform vec4 biome_colors[7] : source_color;   // RenderLook.BIOME in ground_field.gd's BIOME_ORDER
uniform vec3 fore_cam = vec3(0.0, 0.0, 3000.0);  // the camera's world position, every frame (planet_view.gd)
uniform float fore_drop = 0.03;                  // RenderLook.FORE_DROP

float gf(int i, int row) {
	return texelFetch(heights, ivec2(i % tw, row * rpl + i / tw), 0).r;
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

// ground_field.gd groove_half(): a slide trench's own half width, else a beam groove's (from its burn), else spread_w.
float groove_half_at(int i) {
	float s = gf(i, 3);
	float tr = gf(i, 16);
	float w = s > 0.01 ? groove_w0 + groove_wp * clamp((s - groove_i0) / groove_ip, groove_pmin, groove_pmax) : 0.0;
	if (tr > 0.0) {
		return max(w, tr);
	}
	return w > 0.0 ? w : spread_w;
}

// A heap's share in depth and its slope: 1 on [lo, hi], easing to 0 over rubble_edge beyond (ground_field.gd heap()).
vec2 heap_at(float z, float lo, float hi) {
	float out_d = max(lo - z, z - hi);
	if (out_d <= 0.0) {
		return vec2(1.0, 0.0);
	}
	float u = clamp(out_d / rubble_edge, 0.0, 1.0);
	float du = u < 1.0 ? 6.0 * u * (1.0 - u) / rubble_edge : 0.0;
	return vec2(1.0 - u * u * (3.0 - 2.0 * u), z > hi ? -du : du);
}

// The heap's height at column i, depth z (for the rubble tint).
float rubble_at(int i, float z) {
	float r = gf(i, 17);
	return r > 0.0 ? r * heap_at(z, gf(i, 18), gf(i, 19)).x : 0.0;
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
	// The residual less the heap, spread across the band; the heap as its own plateau in depth (ground_field.gd).
	int il = (i + nc - 1) % nc;
	int ir = (i + 1) % nc;
	float r = gf(i, 17);
	float w = groove_half_at(i);
	float t = 1.0 - z * z / (w * w);
	if (t > 0.0) {
		float gl = gf(il, 2) - gf(il, 17);
		float gr = gf(ir, 2) - gf(ir, 17);
		float g = gf(i, 2) - r;
		s += vec3(g * t * t, (gr - gl) / (2.0 * col_w) * t * t, -4.0 * g * t * z / (w * w));
	}
	if (r > 0.0) {
		vec2 h = heap_at(z, gf(i, 18), gf(i, 19));
		s += vec3(r * h.x, (gf(ir, 17) - gf(il, 17)) / (2.0 * col_w) * h.x, r * h.y);
	}
	return s;
}


float ground_offset(int i, float xw, float z) {
	return ground_offset3(i, xw, z).x;
}

// Far relief noise (n, dn/dx, dn/dz), n in about [-1, 1]: whole harmonics of the planet's circumference along x, so it
// wraps with the planet, and free along the depth.
vec3 far_noise3(float x, float z) {
	float t = 6.2831853 / world_w;
	vec3 n = vec3(0.0);
	vec4 k[3] = vec4[3](vec4(5.0, 0.00061 / far_scale, 0.3, 0.45), vec4(17.0, -0.0013 / far_scale, 1.7, 0.3), vec4(43.0, 0.0029 / far_scale, 4.1, 0.25));
	for (int j = 0; j < 3; j++) {
		float fx = k[j].x * t;
		float p = fx * x + k[j].y * z + k[j].z;
		float c = cos(p) * k[j].w;
		n += vec3(sin(p) * k[j].w, c * fx, c * k[j].y);
	}
	return n;
}

// Behind the crater rows, a far point at world x reads the terrain column of a shifted x, the shift wandering smoothly
// with depth (and with x, in whole harmonics of the planet so it wraps), weighted by the far blend: coastlines,
// ranges and forests meander into the distance instead of running straight back, and the fighter plane is untouched.
float far_x(float xw, float z, float s) {
	float t = 6.2831853 / world_w;
	float m = 0.6 * sin(3.0 * t * xw + 0.00047 / far_scale * z + 0.4) + 0.4 * sin(8.0 * t * xw - 0.00083 / far_scale * z + 2.2);
	float xs = xw + meander_amp * m * s * s;
	return xs - world_w * floor(xs / world_w);
}

// A far row's value at the shifted x, linear between columns so the meander never steps a coast into a cliff.
float gfx(float xs, int row) {
	float c = xs / col_w;
	int i = int(c) % nc;
	return mix(gf(i, row), gf((i + 1) % nc, row), fract(c));
}

// The biome at the shifted x (nearest column).
float far_biome(float xs) {
	return gf(int(xs / col_w + 0.5) % nc, 14);
}

vec3 biome_rgb(float xs) {
	return biome_colors[int(far_biome(xs) + 0.5)].rgb;
}

// Base-terrain slope at column i.
float base_slope(int i) {
	return (gf((i + 1) % nc, 0) - gf((i + nc - 1) % nc, 0)) / (2.0 * col_w);
}

// The far terrain (h, dh/dx, dh/dz) read at the shifted x (far_x): that place's own base height (scaled per biome)
// with its biome's relief (rows 12 and 13, smoothed across biome borders), so the land far away is the same land as
// near. The slope ignores the meander's own variation, which is gentle.
vec3 far_height3(float xs, float xw, float z) {
	float amp = gfx(xs, 12);
	float mul = gfx(xs, 13);
	vec3 n = far_noise3(xw, z);
	return vec3(gfx(xs, 0) * mul + amp * n.x, base_slope(int(xs / col_w) % nc) * mul + amp * n.y, amp * n.z);
}

// 0 in the crater rows, rising smoothly to 1 at far_blend beyond them, behind the fighter plane or in front of it.
float far_weight(float z) {
	float s = clamp((abs(z) + z_band_back) / far_blend, 0.0, 1.0);
	return s * s * (3.0 - 2.0 * s);
}

// The fighter-plane row at column i: its ground, and its top (the standing water over the ground, if any).
float fp_ground(int i) {
	return gf(i, 0) + gf(i, 1);
}

float fp_top(int i) {
	float wd = gf(i, 4);
	return fp_ground(i) + (wd >= wet_min ? wd : 0.0);
}

// The foreground rule. In front of the fighter plane (z > 0) nothing rises above the sight line from the camera to the
// fighter-plane row behind it, less fore_drop of its depth. So nothing in front hides the fighter plane, and the camera
// is never inside the ground or under a water sheet. Where land or water would rise into view it falls away instead,
// and from the camera it lies just under the fighter plane's own profile, as the old front face did. xr: world x (the
// camera sits near 0); ox: the planet copy's offset (planet-local x = world x - ox); top: the sight line to the row's
// top (its water) rather than its ground. Returns (cap, d cap/dx, d cap/dz).
vec3 fore_cap3(float xr, float z, float ox, bool top) {
	float t = z / fore_cam.z;
	if (t >= 1.0) {
		return vec3(fore_cam.y - fore_drop * z, 0.0, -fore_drop);
	}
	float xs = fore_cam.x + (xr - fore_cam.x) / (1.0 - min(t, 0.9));   // where the sight line meets the fighter plane
	float c = (xs - ox) / col_w;
	float c0 = floor(c);
	int i0 = int(mod(c0, float(nc)));
	int i1 = (i0 + 1) % nc;
	float y0 = top ? fp_top(i0) : fp_ground(i0);
	float y1 = top ? fp_top(i1) : fp_ground(i1);
	float yp = mix(y0, y1, c - c0);
	float dy = (y1 - y0) / col_w;
	return vec3(mix(yp, fore_cam.y, t) - fore_drop * z, dy, (dy * (xs - fore_cam.x) + fore_cam.y - yp) / fore_cam.z - fore_drop);
}

// Applies the foreground rule at world x xr, depth z to a ground h (with its gradient) and the top over it (its water
// surface, or h where dry): both fall by what the top must, then the ground alone if it still rises above the sight
// line to the fighter plane's own ground. The water keeps at least its depth.
void fore_fall(inout float h, inout vec2 grad, inout float top, float xr, float z, float ox) {
	if (z <= 0.0) {
		return;
	}
	bool dry = top <= h;
	vec3 ct = fore_cap3(xr, z, ox, true);
	float cut = top - ct.x;
	if (cut > 0.0) {
		h -= cut;
		top = ct.x;
		grad = dry ? ct.yz : grad + ct.yz;
	}
	vec3 cg = fore_cap3(xr, z, ox, false);
	if (h > cg.x) {
		h = cg.x;
		grad = cg.yz;
		if (dry) {
			top = h;
		}
	}
}

// The ground at column i, world x xw, depth z: (height, d/dx, d/dz, dent), dent being the crater-and-groove offset
// that the terrain colours by. exact: the fighter-plane row, which reads the sim's deform directly. ox: the planet
// copy's world offset, for the foreground rule (fore_fall), which sees the water the water shader draws there.
vec4 ground4(int i, float xw, float z, bool exact, float ox) {
	float b = gf(i, 0);
	vec3 o = abs(z) <= -z_band_back + 0.5 ? ground_offset3(i, xw, z) : vec3(0.0);
	float off = exact ? gf(i, 1) : o.x;
	float h = b + off;
	vec2 grad = vec2(base_slope(i) + o.y, o.z);
	float s = far_weight(z);
	float top = h;
	if (s > 0.0) {
		float xs = far_x(xw, z, s);
		vec3 f = far_height3(xs, xw, z);
		h = mix(h, f.x, s);
		grad = mix(grad, f.yz, s);
		top = (h < 0.0 && mix(b, gfx(xs, 0), s) < sea_base) ? 0.0 : h;
	} else {
		float wd = gf(i, 4);
		float surf = b + gf(i, 1) + wd;
		top = (wd >= wet_min && (b < sea_base || off < -wet_min) && surf > h) ? surf : h;
	}
	fore_fall(h, grad, top, xw + ox, z, ox);
	return vec4(h, grad, off * (1.0 - s));
}

// A vertex's ground: UV.x its column, flag 1 the exact row, a flag of 2 or more a run's boundary row that snaps to that
// coarser column stride (linear between the coarse columns), so the finer and the coarser run meet without a crack.
// ox: the planet copy's world offset (MODEL_MATRIX's translation).
vec4 ground_vertex(float col, float flag, float z, float ox) {
	if (flag > 1.5) {
		float st = floor(flag + 0.5);
		float c0 = floor(col / st + 0.0001) * st;
		float fr = (col - c0) / st;
		vec4 g0 = ground4(int(c0) % nc, c0 * col_w, z, false, ox);
		vec4 g1 = ground4(int(c0 + st) % nc, (c0 + st) * col_w, z, false, ox);
		return mix(g0, g1, fr);
	}
	return ground4(int(col + 0.5) % nc, col * col_w, z, flag > 0.5, ox);
}
