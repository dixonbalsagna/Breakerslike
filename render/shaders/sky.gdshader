// The sky: the horizon-anchored gradient (skycol.gdshaderinc), screen-fixed stars that come up high above the
// horizon and brighten as the camera climbs toward space, and a band of long clouds above the horizon. No painted
// planet: seen from high up, the planet is the real ground below, curving away (bend.gdshaderinc) under a thin rim of
// glow.
// The clouds are two octaves of value noise over (across, height above the horizon), stretched along the horizon. They
// move with the camera's place round the planet (cloud_shift, in cells; the pattern repeats every cloud_period cells,
// so it wraps with the planet) and a slow wind. None at the horizon line, where the ground's haze meets the sky, and
// none in space. cloud_on 0: no clouds (--noclouds). cloud_part 0 is the calm version for reduced motion: the clouds
// stand still and do not part.
// From tier 3 the clouds part for a fighter (docs/design/rule-of-cool.md feature 12): sky_react gives the direction
// from the camera to him and a strength (tier 3 half, tier 4 full; 0 when he is off this pane's screen). A gap opens
// in the cloud band above him, wider than tall, and the clouds round it are lit in his colour. That is all of it:
// no cloud is made and nothing is drawn where there is none, the sky inside the gap is the sky as it was, and the
// gap stays inside the cloud band, clear of the horizon (it used to pale the sky in a tall opening down to the
// horizon, which read as a pillar from a high camera: QA's GB-002). It only ever lightens a cloud, and never to
// white: nothing darkens and there is no lightning (Legal's screen of the list). pane_world.gd sets both each frame.
shader_type sky;

#include "res://render/shaders/skycol.gdshaderinc"

uniform float cloud_on = 1.0;
uniform float cloud_part = 1.0;
uniform float cloud_shift = 0.0;
uniform float cloud_period = 32.0;   // RenderLook.CLOUD_PERIOD
uniform float cloud_cover = 0.52;    // RenderLook.CLOUD_COVER
uniform vec2 react_r = vec2(0.7, 0.24);   // RenderLook.SKY_REACT_R: the gap's half width and half height, in half screen heights
uniform vec3 react_at = vec3(0.45, 0.46, 1.0);   // RenderLook.SKY_REACT_AT: how far above him the gap sits, and the lowest and highest its middle goes (heights above the horizon, as the cloud band's)
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
	c += vec3(star * fade * mix(0.25, 1.0, space) * (0.6 + 0.4 * fract(hs * 97.0)));
	if (cloud_on > 0.5 && h > 0.0 && space < 0.98) {
		// The reaction: a gap in the cloud band above each fighter at tier 3 or more (see the header). gap: how far
		// the clouds are cleared here; rim: the bank round the gap; both fade out toward the band's lower edge.
		float gap = 0.0;
		float rim = 0.0;
		float tw = 0.0;
		vec3 tint = vec3(0.0);
		if (cloud_part > 0.5) {
			for (int k = 0; k < 2; k++) {
				float w = sky_react[k].w;
				if (w <= 0.0) {
					continue;
				}
				vec3 d = sky_react[k].xyz;
				float fx = d.x / max(0.2, -d.z);
				float hc = clamp(sky_height(elevation(d)) + react_at.x, react_at.y, react_at.z);
				float r = length(vec2((p.x - fx) / (react_r.x * sky_tan), (h - hc) / react_r.y)) / (0.7 + 0.3 * w);
				float low = smoothstep(0.14, 0.32, h);   // nothing parts in the last of the band above the horizon
				float inside = w * low * (1.0 - smoothstep(0.6, 1.0, r));
				float edge = w * low * smoothstep(0.6, 1.0, r) * (1.0 - smoothstep(1.0, 1.6, r));
				gap = max(gap, inside);
				rim = max(rim, edge);
				tint += sky_react_col[k].rgb * edge;
				tw += edge;
			}
			tint /= max(tw, 0.0001);   // where two gaps meet, their colours blend by weight: never their sum
		}
		vec2 cp = vec2(p.x * 2.2 + cloud_shift, h * 5.0);
		float n = cloud_noise(cp, cloud_period) * 0.65 + cloud_noise(vec2(cp.x * 2.0, cp.y * 2.9 + 11.0), cloud_period * 2.0) * 0.35;
		float band = smoothstep(0.04, 0.3, h) * (1.0 - smoothstep(1.3, 2.3, h)) * (1.0 - space);
		// The clouds that are there open: none inside the gap. No cloud is made, so a clear sky shows nothing.
		float a = smoothstep(1.0 - cloud_cover, 1.0 - cloud_cover + 0.16, n) * band * (1.0 - gap);
		// Lit from the horizon: warm below, the sky's own darker tone above. The clouds round a gap take his colour,
		// lighter than they were and never white.
		vec3 cc = mix(c * 0.7, sky_horizon.rgb, clamp(1.0 - h * 0.8, 0.0, 1.0) * 0.75);
		cc = mix(cc, max(cc, mix(cc, tint, 0.5) + 0.06), rim * 0.9);
		c = mix(c, cc, min(1.0, a * (0.82 + 0.18 * rim)));
	}
	COLOR = c;
}
