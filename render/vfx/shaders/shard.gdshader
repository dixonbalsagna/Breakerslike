// Shrapnel and collapse dust (docs/vfx/plan.md section 3): one MultiMesh quad per bit, its shape drawn by a signed
// test in the fragment stage, cel style: two value steps and a one-pixel edge, no soft falloff.
// INSTANCE_CUSTOM: x = shape (0 glass sliver, 1 glass triangle, 2 steel bar, 3 chunk, 4 dust puff, 5 ring, 6 ember, 7 water spray, 8 flame), y = a seed for
// the shape's small variations. COLOR is the body colour with the fade in alpha; the lit or rim colour of each material
// is a uniform, so every bit needs only one draw call.
shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;

uniform vec4 rim_glass : source_color = vec4(0.88, 0.96, 0.98, 1.0);
uniform vec4 rim_steel : source_color = vec4(0.67, 0.71, 0.76, 1.0);
uniform vec4 rim_dust : source_color = vec4(0.54, 0.51, 0.46, 1.0);
uniform vec4 rim_conc : source_color = vec4(0.67, 0.71, 0.76, 1.0);
uniform vec4 rim_spray : source_color = vec4(0.55, 0.72, 0.78, 1.0);
uniform vec4 ember_dark : source_color = vec4(0.17, 0.09, 0.06, 1.0);
uniform vec4 ember_light : source_color = vec4(1.0, 0.82, 0.48, 1.0);
uniform vec4 flame_mid : source_color = vec4(1.0, 0.82, 0.48, 1.0);
uniform vec4 flame_core : source_color = vec4(1.0, 0.95, 0.77, 1.0);

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
	if (shape > 7.5) {
		// flame: a cel tongue in three bands (outer, mid, core) that leans and wobbles with its age (mode), a rounded base, a
		// second small lick beside it, and a blunt tip; the outer band is the body colour, the others the flame_mid and flame_core uniforms
		float f = v_custom.z;
		float lean = (sd - 0.5) * 0.9;
		float y = 0.5 - p.y * 0.5;     // 0 at the base, 1 at the tip (UV.y runs down the quad)
		float wob = 0.12 * sin(y * 6.0 + sd * 12.0 + f * 9.0) * y;
		float xx = p.x - wob - lean * y * y;
		float hf = 0.78 * pow(max(1.0 - pow(y, 1.4), 0.0), 0.75) * smoothstep(0.0, 0.18, y + 0.06);
		hf *= 1.0 - 0.3 * f;
		float d1 = abs(xx) - hf;
		// the side lick: a shorter tongue, to the side the seed picks
		float y2 = y / 0.62;
		float side = (sd > 0.5 ? 1.0 : -1.0) * 0.5;
		float xx2 = p.x - side - 0.12 * sin(y2 * 5.0 + sd * 7.0 + f * 11.0) * y2 - 0.3 * side * y2 * y2;
		float hf2 = 0.42 * pow(max(1.0 - pow(y2, 1.4), 0.0), 0.75) * smoothstep(0.0, 0.2, y2 + 0.06);
		float d2 = (y2 > 1.0 || y2 < 0.0) ? 1.0 : abs(xx2) - hf2;
		float d = min(d1, d2);
		d = max(d, abs(p.y) - 1.0);
		a = edge(d, aa);
		float ax = abs(xx);
		if (ax < hf * 0.62 && y < 0.74) {
			base = flame_mid.rgb;
		}
		if (ax < hf * 0.34 && y < 0.5) {
			base = flame_core.rgb;
		}
	} else if (shape > 6.5) {
		// water spray: a droplet streak, round at the head (+x) and tapering to the tail, a 1 px rim
		float w = mix(0.2, 0.55, p.x * 0.5 + 0.5);
		float d = (length(vec2(p.x, p.y / max(w, 0.05))) - 1.0) * w;
		a = edge(d, aa);
		float inner = edge(d + max(fwidth(p.x), fwidth(p.y)) * 1.0, aa);
		base = mix(rim_spray.rgb, base, inner);
	} else if (shape > 5.5) {
		// ember: a solid slanted bar with a 1 px rim: dark on the light steps, light on the spent char chip
		float d = max(abs(p.y) - 1.0, abs(p.x + 0.4 * p.y) - 1.0);
		a = edge(d, aa);
		float inner = edge(d + max(fwidth(p.x), fwidth(p.y)) * 1.1, aa);
		base = mix(v_custom.z > 0.5 ? ember_light.rgb : ember_dark.rgb, base, inner);
	} else if (shape < 0.5) {
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
		float litside = step(0.2, -p.x * 0.6 + p.y * 0.8);
		if (v_custom.z > 1.5) {
			base = mix(base * 0.78, min(base * 1.22, vec3(1.0)), litside);   // earth: its own colour, a lit and a shaded side
		} else {
			base = mix(base, rim_conc.rgb, litside);
		}
	} else if (shape < 4.5) {
		// dust puff: a scalloped disc, a body and a darker rim (two steps, hard edge)
		float ang = atan(p.y, p.x);
		float r = length(p);
		float lump = 0.82 + 0.08 * sin(ang * 5.0 + sd * 12.0) + 0.05 * sin(ang * 9.0 + sd * 5.0);
		a = edge(r - lump, aa);
		float inner = edge(r - lump * 0.62, aa);
		base = mix(base * 0.72, base, inner * step(0.0, p.y * 0.4 - p.x * 0.3 + 0.6));
	} else {
		// ring: a thin cel ring that thins as it fades
		float r = length(p);
		float w = 0.05 + 0.04 * (1.0 - COLOR.a);
		if (v_custom.z > 2.5) {
			w = 0.16;   // a ring lying on the ground (an entrance landing): a band, so it still reads when it is flattened to a sliver
		}
		a = edge(abs(r - (1.0 - w)) - w, aa);
		base = mix(base, rim_steel.rgb, 0.5);
	}
	ALBEDO = base;
	ALPHA = alpha_mul * a;
}
