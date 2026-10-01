// The transformation's effects (docs/vfx/transform-plan.md): gather streaks, the break ring, a dim disc, a flash disc and
// the form aura. One MultiMesh quad each. INSTANCE_CUSTOM: z = shape, x and y per shape:
//   0 streak: x = half-width at the head (UV.x = 1), y = at the tail; the tail fades
//   1 ring: x = thickness as a share of the radius; the ring's outer edge is the quad's edge
//   2 soft disc: x = falloff power (alpha = (1 - r) ^ x)
//   3 aura: x = lobes (0 none, 1 shoulders, 2 shoulders and a low round crest, 3 shoulders, crest and hips), y = fill alpha; a cel body: a flat fill and a
//     rim line, every tip round (nothing pointed, nothing flame-shaped)
// COLOR is the colour, alpha the step. Cel style: hard edges with a one-pixel anti-aliased edge, except the soft discs.
shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;

varying vec4 v_custom;

float smin(float a, float b, float k) {
	float h = clamp(0.5 + 0.5 * (b - a) / k, 0.0, 1.0);
	return mix(b, a, h) - k * h * (1.0 - h);
}

void vertex() {
	v_custom = INSTANCE_CUSTOM;
}

void fragment() {
	float a = 0.0;
	vec2 p = UV * 2.0 - 1.0;
	if (v_custom.z < 0.5) {
		float v = UV.y * 2.0 - 1.0;
		float hw = mix(v_custom.y, v_custom.x, UV.x);
		float aa = max(fwidth(v) * 0.75, 0.002);
		hw = max(hw, aa);
		a = (1.0 - smoothstep(hw - aa, hw + aa, abs(v))) * mix(0.2, 1.0, UV.x);
	} else if (v_custom.z < 1.5) {
		float r = length(p);
		float aa = max(fwidth(r), 0.001);
		float w = max(v_custom.x, 0.004);
		a = 1.0 - smoothstep(w - aa, w + aa, abs(r - (1.0 - w)));
	} else if (v_custom.z < 2.5) {
		float r = length(p);
		a = pow(max(1.0 - r, 0.0), max(v_custom.x, 0.1));
	} else {
		// Body: an ellipse; shoulders: two round lobes; crest: one low round bump. Smooth union, so no corner anywhere.
		vec2 q = vec2(abs(p.x), p.y);
		float d = length(q / vec2(0.62, 0.86)) - 1.0;
		d *= 0.62;
		if (v_custom.x > 0.5) {
			float ds = length(q - vec2(0.62, 0.22)) - 0.22;
			d = smin(d, ds, 0.10);
		}
		if (v_custom.x > 1.5) {
			float dc = length(p - vec2(0.0, 0.76)) - 0.16;
			d = smin(d, dc, 0.09);
		}
		if (v_custom.x > 2.5) {
			float dh = length(q - vec2(0.52, -0.46)) - 0.20;
			d = smin(d, dh, 0.10);
		}
		float aa = max(fwidth(d), 0.002);
		float inside = 1.0 - smoothstep(-aa, aa, d);
		float rim = 1.0 - smoothstep(0.045 - aa, 0.045 + aa, abs(d + 0.02));
		float edge = smoothstep(-0.35, 0.0, d);
		a = max(inside * v_custom.y * (0.55 + 0.45 * edge), rim);
	}
	ALBEDO = COLOR.rgb;
	ALPHA = COLOR.a * a;
}
