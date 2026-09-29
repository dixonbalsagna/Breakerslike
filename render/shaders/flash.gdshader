// Head flashes (render/core/flash_view.gd; Art's spec docs/art/flash-prototype-spec.md): every shape is one quad of a
// MultiMesh, placed by the vertex stage from its instance data and filled in the fragment stage by a signed distance,
// so a whole flash is one draw call with no textures. Units are layout units (hundredths of a body height, u world
// units each) in the flash's own frame: x forward (the node mirrors with the facing), y up, the origin just above the
// head centre. The fighters' hybrid projection places it, like every other fighter part.
// INSTANCE_CUSTOM, a layout shape: (angle in radians, distance, size, flags); a glyph: (x, y, 0, flags).
// flags: 1 inward, 2 ground, 4 round tip, 8 core layer, 16 info, 32 glyph, 64 question (else a bang).
// COLOR: the layer's colour and opacity.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;

#include "res://render/shaders/ortho.gdshaderinc"

uniform int family = 0;          // 0 circles, 1 blades, 2 wedges, 3 steps
uniform float u = 0.9;           // world units per layout unit
uniform float k = 1.0;           // the envelope, 0 to 1
uniform float fade = 1.0;        // a forced fade (preempted, the crown came up, hidden)
uniform float grow = 0.45;       // size 1 - grow + grow k (0 with reduced motion: a plain fade)
uniform float sweep = 0.0;       // radians the layout sweeps forward over its attack (rage) ...
uniform float sweep_k = 1.0;     // ... and how far through its attack it is
uniform float jitter = 0.0;      // layout units of irregular jitter per shape (hurt)
uniform float jitter_step = 0.0; // steps a few times a second
uniform float seed = 0.0;        // from the cosmetic vfx.flash stream
uniform float ground_y = -60.0;  // the ground under the fighter, in this frame
uniform float blade_w = 3.8;     // half widths: blades and wedges (spec section 3)
uniform float wedge_w = 8.5;
uniform float min_r = 2.5;       // the smallest disc radius and square half side
uniform float min_q = 3.0;
uniform float grid = 3.0;        // steps snap to this grid
uniform vec2 head_c = vec2(0.0, -2.0);   // the head's disc in this frame, cut out of every flash so none covers the
uniform float head_r = 11.0;             // face (the flash draws in front of the head and hair)
uniform float glyph_lift = 0.0;          // glyphs rise above a head larger than Art's
uniform float mirror = 1.0;              // the node's mirror: a glyph's place mirrors with the facing, its shape never

varying vec2 v_p;        // the point in the shape's frame (layout units; glyph units for glyphs)
varying vec4 v_col;
varying flat vec4 v_s;   // x: 0 disc, 1 triangle, 2 box, 3 bang, 4 question; y, z: length and half width (radius;
                         // half sides); w: round tip, or a glyph's rim pad
varying flat float v_sc; // a glyph's scale (layout units per glyph unit)
varying vec2 v_w;        // the point in the flash's frame (layout units)

// The question mark's hook (gen.mjs glyphPolys), glyph units, y up; the wedges' own is squarer.
const vec2 QA[8] = vec2[8](vec2(-3.6, 10.6), vec2(-3.4, 13.6), vec2(-0.8, 15.4), vec2(2.4, 14.2), vec2(3.2, 11.6), vec2(1.6, 9.2), vec2(0.0, 7.2), vec2(0.0, 5.0));
const vec2 QE[6] = vec2[6](vec2(-3.6, 10.6), vec2(-2.4, 14.8), vec2(2.6, 14.8), vec2(3.6, 10.8), vec2(0.0, 7.4), vec2(0.0, 5.0));

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	int fl = int(INSTANCE_CUSTOM.w + 0.5);
	bool glyph = (fl & 32) != 0;
	vec2 f = VERTEX.xy + 0.5;
	vec2 pos;
	float op;
	if (glyph) {
		float sc = 1.7 * (1.0 - grow * 0.66 + grow * 0.66 * k);   // (0.7 + 0.3 k) x 1.7, as Art draws it
		float pad = (fl & 8) != 0 ? 0.0 : 0.66;
		vec2 p = mix(vec2(-6.5, -2.5), vec2(6.5, 18.0), f);
		v_p = p;
		v_s = vec4((fl & 64) != 0 ? 4.0 : 3.0, 0.0, 0.0, pad);
		v_sc = sc;
		pos = INSTANCE_CUSTOM.xy + vec2(0.0, glyph_lift) + vec2(p.x * mirror, p.y) * sc;
		op = min(1.0, 1.4 * k);
	} else {
		float a = INSTANCE_CUSTOM.x + sweep * (1.0 - sweep_k);
		vec2 dir = vec2(cos(a), sin(a));
		vec2 base = (fl & 2) != 0 ? vec2(dir.x * INSTANCE_CUSTOM.y, ground_y) : dir * INSTANCE_CUSTOM.y;
		if (jitter > 0.0) {
			// Per shape: a layout's rim and core are instances 2i and 2i + 1, and move together.
			float sid = float(INSTANCE_ID / 2);
			base += (vec2(hash(vec2(sid, jitter_step + seed)), hash(vec2(sid + 17.0, jitter_step + seed))) - 0.5) * 2.0 * jitter;
		}
		float L = INSTANCE_CUSTOM.z * (1.0 - grow + grow * k);
		vec2 e = dir * ((fl & 1) != 0 ? -1.0 : 1.0);
		vec2 o;
		vec2 lo;
		vec2 hi;
		if (family == 0) {
			float r = max(min_r, L * 0.3);
			o = base + e * L * 0.5;
			e = vec2(1.0, 0.0);
			lo = vec2(-r - 1.0);
			hi = vec2(r + 1.0);
			v_s = vec4(0.0, r, r, 0.0);
		} else if (family == 3) {
			float q = max(min_q, L * 0.3);
			vec2 c0 = round((base - q) / grid) * grid;
			vec2 c1 = max(round((base + q) / grid) * grid, c0 + grid);
			o = (c0 + c1) * 0.5 + e * L * 0.5;
			e = vec2(1.0, 0.0);
			vec2 h = (c1 - c0) * 0.5;
			lo = -h - 1.0;
			hi = h + 1.0;
			v_s = vec4(2.0, h, 0.0);
		} else {
			float w = (family == 1 ? blade_w : wedge_w) * ((fl & 8) != 0 ? ((fl & 16) != 0 ? 0.84 : 0.6) : 1.0);
			o = base;
			lo = vec2(-1.0, -w - 1.0);
			hi = vec2(L + 1.0, w + 1.0);
			v_s = vec4(1.0, L, w, (fl & 4) != 0 ? 1.0 : 0.0);
		}
		vec2 p = mix(lo, hi, f);
		v_p = p;
		v_sc = 1.0;
		pos = o + e * p.x + vec2(-e.y, e.x) * p.y;
		op = k;
	}
	v_col = vec4(COLOR.rgb, COLOR.a * op * fade);
	v_w = pos;
	VERTEX = vec3(pos * u, 0.0);
	POSITION = ortho_clip(MODEL_MATRIX, VIEW_MATRIX, PROJECTION_MATRIX, VERTEX);
}

float sd_seg(vec2 p, vec2 a, vec2 b) {
	vec2 pa = p - a;
	vec2 ba = b - a;
	return length(pa - ba * clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0));
}

float sd_box(vec2 p, vec2 h) {
	vec2 d = abs(p) - h;
	return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
}

// A triangle's signed distance (either winding).
float sd_tri(vec2 p, vec2 p0, vec2 p1, vec2 p2) {
	vec2 e0 = p1 - p0;
	vec2 e1 = p2 - p1;
	vec2 e2 = p0 - p2;
	vec2 v0 = p - p0;
	vec2 v1 = p - p1;
	vec2 v2 = p - p2;
	vec2 q0 = v0 - e0 * clamp(dot(v0, e0) / dot(e0, e0), 0.0, 1.0);
	vec2 q1 = v1 - e1 * clamp(dot(v1, e1) / dot(e1, e1), 0.0, 1.0);
	vec2 q2 = v2 - e2 * clamp(dot(v2, e2) / dot(e2, e2), 0.0, 1.0);
	float s = sign(e0.x * e2.y - e0.y * e2.x);
	vec2 d = min(min(vec2(dot(q0, q0), s * (v0.x * e0.y - v0.y * e0.x)), vec2(dot(q1, q1), s * (v1.x * e1.y - v1.y * e1.x))), vec2(dot(q2, q2), s * (v2.x * e2.y - v2.y * e2.x)));
	return -sqrt(d.x) * sign(d.y);
}

// A blade or wedge: the base across the origin (half width w), the tip at x = L; round: Legal's rounded end
// (radius 0.95 w).
float sd_blade(vec2 p, float L, float w, bool round_tip) {
	if (!round_tip) {
		return sd_tri(p, vec2(0.0, w), vec2(L, 0.0), vec2(0.0, -w));
	}
	float r = 0.95 * w;
	float cx = max(L - r, 0.05);
	float d = length(p - vec2(cx, 0.0)) - r;
	d = min(d, sd_tri(p, vec2(0.0, w), vec2(cx, r), vec2(cx, -r)));
	return min(d, sd_tri(p, vec2(0.0, w), vec2(cx, -r), vec2(0.0, -w)));
}

// A glyph's dot at (0, 1.4), in the family's primitive: disc, diamond, triangle or square.
float g_dot(vec2 p) {
	vec2 q = p - vec2(0.0, 1.4);
	float r = 1.9;
	if (family == 0) {
		return length(q) - r * 1.05;
	}
	if (family == 3) {
		return sd_box(q, vec2(1.6));
	}
	if (family == 1) {
		return min(sd_tri(q, vec2(0.0, -1.2 * r), vec2(0.9 * r, 0.0), vec2(0.0, 1.2 * r)), sd_tri(q, vec2(0.0, -1.2 * r), vec2(0.0, 1.2 * r), vec2(-0.9 * r, 0.0)));
	}
	return sd_tri(q, vec2(-1.2 * r, -0.8 * r), vec2(1.2 * r, -0.8 * r), vec2(0.0, 1.2 * r));
}

// The bang: a stem (capsule, blade, wedge or bar) over the dot.
float g_bang(vec2 p) {
	float s;
	if (family == 0) {
		s = sd_seg(p, vec2(0.0, 5.4), vec2(0.0, 12.6)) - 1.7;
	} else if (family == 1) {
		s = sd_tri(p, vec2(-2.6, 14.0), vec2(2.6, 14.0), vec2(0.0, 4.6));
	} else if (family == 2) {
		s = sd_tri(p, vec2(-3.8, 14.0), vec2(3.8, 14.0), vec2(0.0, 4.6));
	} else {
		s = sd_box(p - vec2(0.0, 9.7), vec2(2.0, 4.3));
	}
	return min(s, g_dot(p));
}

// The question: the hook (dots, a swelling blade, a wedge band or snapped squares) over the dot.
float g_question(vec2 p, float sc) {
	float d = 1.0e9;
	if (family == 2) {
		for (int i = 0; i < 5; i++) {
			d = min(d, sd_seg(p, QE[i], QE[i + 1]) - 1.7);
		}
	} else if (family == 0) {
		for (int i = 0; i < 8; i++) {
			d = min(d, length(p - QA[i]) - 1.8);
		}
	} else if (family == 3) {
		for (int i = 0; i < 8; i++) {
			vec2 g = round(QA[i] * sc / grid) * grid / sc;
			d = min(d, sd_box(p - g, vec2(1.7)));
		}
	} else {
		for (int i = 0; i < 7; i++) {
			vec2 pa = p - QA[i];
			vec2 ba = QA[i + 1] - QA[i];
			float h = clamp(dot(pa, ba) / dot(ba, ba), 0.0, 1.0);
			d = min(d, length(pa - ba * h) - (0.7 + 1.3 * sin(3.14159265 * (float(i) + h) / 7.0)));
		}
	}
	return min(d, g_dot(p));
}

void fragment() {
	if (length(v_w - head_c) < head_r) {
		discard;
	}
	int t = int(v_s.x + 0.5);
	float d;
	if (t == 0) {
		d = length(v_p) - v_s.y;
	} else if (t == 2) {
		d = sd_box(v_p, v_s.yz);
	} else if (t == 1) {
		d = sd_blade(v_p, v_s.y, v_s.z, v_s.w > 0.5);
	} else if (t == 3) {
		d = g_bang(v_p) - v_s.w;
	} else {
		d = g_question(v_p, v_sc) - v_s.w;
	}
	float aa = max(fwidth(d), 1.0e-4);
	float cov = 1.0 - smoothstep(-aa, aa, d);
	if (cov <= 0.002) {
		discard;
	}
	ALBEDO = v_col.rgb;
	ALPHA = v_col.a * cov;
}
