// The sky: the horizon-anchored gradient (skycol.gdshaderinc), screen-fixed stars that come up high above the
// horizon and brighten as the camera climbs toward space, and a band of long clouds above the horizon. No painted
// planet: seen from high up, the planet is the real ground below, curving away (bend.gdshaderinc) under a thin rim of
// glow.
// The clouds are two octaves of value noise over (across, height above the horizon), stretched along the horizon. They
// move with the camera's place round the planet (cloud_shift, in cells; the pattern repeats every cloud_period cells,
// so it wraps with the planet) and a slow wind. None at the horizon line, where the ground's haze meets the sky, and
// none in space. cloud_on 0 is the reduced version: no clouds.
// From tier 3 the sky reacts to a fighter (docs/design/rule-of-cool.md feature 12): sky_react gives the direction
// from the camera to him and a strength (tier 3 half, tier 4 full). The clouds part in a tall opening above him, their
// edge round it lit in his colour, and the sky inside it pales toward his colour. It only ever lightens: the sky never
// darkens and there is no lightning (Legal's screen of the rule-of-cool list). pane_world.gd sets both each frame.
shader_type sky;

#include "res://render/shaders/skycol.gdshaderinc"

uniform float cloud_on = 1.0;
uniform float cloud_shift = 0.0;
uniform float cloud_period = 32.0;   // RenderLook.CLOUD_PERIOD
uniform float cloud_cover = 0.52;    // RenderLook.CLOUD_COVER
uniform float react_r = 0.2;         // RenderLook.SKY_REACT_R
uniform vec4 sky_react[2];           // xyz: the direction from the camera to a fighter (world axes); w: the reaction, 0 to 1
uniform vec4 sky_react_col[2] : source_color;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

// Value noise, 0 to 1, repeating every `period` cells across.
float cloud_noise(vec2 p, float period) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float x0 = mod(i.x, period);
	float x1 = mod(i.x + 1.0, period);
	return mix(mix(hash21(vec2(x0, i.y)), hash21(vec2(x1, i.y)), f.x), mix(hash21(vec2(x0, i.y + 1.0)), hash21(vec2(x1, i.y + 1.0)), f.x), f.y);
}

void sky() {
	float q = elevation(EYEDIR);
	vec3 c = sky_color(q);
	float h = sky_height(q);
	vec2 p = EYEDIR.xy / max(0.2, -EYEDIR.z);
	vec2 g = p * 260.0;
	float hs = hash21(floor(g));
	float star = step(0.994, hs) * (1.0 - smoothstep(0.08, 0.2, length(fract(g) - 0.5)));
	float fade = clamp((h - 0.35) * 1.5, 0.0, 1.0);
	// The reaction: an opening above each fighter at tier 3 or more, taller than it is wide, lifted to the horizon.
	vec2 pe = vec2(p.x, q);
	float clear = 0.0;
	float rim = 0.0;
	vec3 tint = vec3(0.0);
	for (int k = 0; k < 2; k++) {
		float w = sky_react[k].w;
		if (w <= 0.0) {
			continue;
		}
		vec3 d = sky_react[k].xyz;
		vec2 pf = vec2(d.x / max(0.2, -d.z), max(elevation(d), horizon));
		float r = length((pe - pf) * vec2(1.0, 0.4));
		float rr = react_r * (0.7 + 0.6 * w);
		float inside = w * (1.0 - smoothstep(0.5 * rr, rr, r));
		float edge = w * smoothstep(0.55 * rr, rr, r) * (1.0 - smoothstep(rr, 1.5 * rr, r));
		clear = max(clear, inside);
		rim = max(rim, edge);
		tint += sky_react_col[k].rgb * max(inside, edge);
	}
	// The sky inside an opening pales toward his colour: never darker than it was.
	c = mix(c, max(c, mix(c, vec3(1.0), 0.2) + tint * 0.16), clear * 0.85);
	c += vec3(star * fade * (1.0 - clear) * mix(0.25, 1.0, space) * (0.6 + 0.4 * fract(hs * 97.0)));
	if (cloud_on > 0.5 && h > 0.0 && space < 0.98) {
		vec2 cp = vec2(p.x * 2.2 + cloud_shift, h * 5.0);
		float n = cloud_noise(cp, cloud_period) * 0.65 + cloud_noise(vec2(cp.x * 2.0, cp.y * 2.9 + 11.0), cloud_period * 2.0) * 0.35;
		float band = smoothstep(0.04, 0.3, h) * (1.0 - smoothstep(1.3, 2.3, h)) * (1.0 - space);
		float a = smoothstep(1.0 - cloud_cover, 1.0 - cloud_cover + 0.16, n) * band * (1.0 - clear);
		// Lit from the horizon: warm below, the sky's own darker tone above; the edge of an opening takes his colour.
		vec3 cc = mix(c * 0.7, sky_horizon.rgb, clamp(1.0 - h * 0.8, 0.0, 1.0) * 0.75);
		cc = mix(cc, max(cc, tint + cc * 0.6), rim * 0.6);
		c = mix(c, cc, a * 0.82);
	}
	COLOR = c;
}
