// Shrapnel and collapse dust (docs/vfx/plan.md section 3): one MultiMesh quad per bit, its shape drawn by a signed
// test in the fragment stage, cel style: two value steps and a one-pixel edge, no soft falloff.
// INSTANCE_CUSTOM: x = shape (0 glass sliver, 1 glass triangle, 2 steel bar, 3 chunk, 4 dust puff, 5 ring), y = a seed for
// the shape's small variations. COLOR is the body colour with the fade in alpha; the lit or rim colour of each material
// is a uniform, so every bit needs only one draw call.
shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;

uniform vec4 rim_glass : source_color = vec4(0.88, 0.96, 0.98, 1.0);
uniform vec4 rim_steel : source_color = vec4(0.67, 0.71, 0.76, 1.0);
uniform vec4 rim_dust : source_color = vec4(0.54, 0.51, 0.46, 1.0);
uniform vec4 rim_conc : source_color = vec4(0.67, 0.71, 0.76, 1.0);

varying vec4 v_custom;

void vertex() {
	v_custom = INSTANCE_CUSTOM;
}

float edge(float d, float aa) {
	return 1.0 - smoothstep(-aa, aa, d);
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float aa = max(fwidth(p.x), fwidth(p.y)) * 0.8 + 0.0005;
	float shape = v_custom.x;
	float sd = v_custom.y;
	vec3 base = COLOR.rgb;
	float a = 0.0;
	float alpha_mul = COLOR.a;
	if (shape < 0.5) {
		// glass sliver: a slanted parallelogram, lit along one long edge
		float d = max(abs(p.y) - 1.0, abs(p.x + 0.35 * p.y * (0.5 + sd)) - 1.0);
		a = edge(d, aa);
		base = mix(base, rim_glass.rgb, step(0.35, p.y));
	} else if (shape < 1.5) {
		// glass triangle
		float d = max(p.y - 0.9, max(-p.y * 0.55 - 0.45 - p.x * (0.6 + 0.4 * sd), -p.y * 0.55 - 0.45 + p.x * (1.0 - 0.4 * sd)));
		a = edge(d, aa);
		base = mix(base, rim_glass.rgb, step(0.0, p.x * 0.7 + p.y * 0.3));
	} else if (shape < 2.5) {
		// steel bar: a rectangle with a lit top edge and a cut end
		float d = max(abs(p.y) - 1.0, max(abs(p.x) - 1.0, (p.x - 0.75) * 1.4 + p.y * 0.6));
		a = edge(d, aa);
		base = mix(base, rim_steel.rgb, step(0.45, p.y));
	} else if (shape < 3.5) {
		// chunk: a block with two cut corners, lit on the upper left
		float d = max(max(abs(p.x) - 0.95, abs(p.y) - 0.95), max(abs(p.x + p.y) - 1.25 - 0.2 * sd, abs(p.x - p.y) - 1.4));
		a = edge(d, aa);
		base = mix(base, rim_conc.rgb, step(0.2, -p.x * 0.6 + p.y * 0.8));
	} else if (shape < 4.5) {
		// dust puff: a scalloped disc, a body and a darker rim (two steps, hard edge)
		float ang = atan(p.y, p.x);
		float r = length(p);
		float lump = 0.82 + 0.08 * sin(ang * 5.0 + sd * 12.0) + 0.05 * sin(ang * 9.0 + sd * 5.0);
		a = edge(r - lump, aa);
		float inner = edge(r - lump * 0.62, aa);
		base = mix(rim_dust.rgb, base, inner * step(0.0, p.y * 0.4 - p.x * 0.3 + 0.6));
	} else {
		// ring: a thin cel ring that thins as it fades
		float r = length(p);
		float w = 0.05 + 0.04 * (1.0 - COLOR.a);
		a = edge(abs(r - (1.0 - w)) - w, aa);
		base = mix(base, rim_steel.rgb, 0.5);
	}
	ALBEDO = base;
	ALPHA = alpha_mul * a;
}
