// The sky: the horizon-anchored gradient (skycol.gdshaderinc) and screen-fixed stars that come up high above the
// horizon and brighten as the camera climbs toward space. No painted planet: seen from high up, the planet is the real
// ground below, curving away (bend.gdshaderinc) under a thin rim of glow.
shader_type sky;

#include "res://render/shaders/skycol.gdshaderinc"

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void sky() {
	float q = elevation(EYEDIR);
	vec3 c = sky_color(q);
	vec2 p = EYEDIR.xy / max(0.2, -EYEDIR.z);
	vec2 g = p * 260.0;
	float h = hash21(floor(g));
	float star = step(0.994, h) * (1.0 - smoothstep(0.08, 0.2, length(fract(g) - 0.5)));
	float fade = clamp((sky_height(q) - 0.35) * 1.5, 0.0, 1.0);
	c += vec3(star * fade * mix(0.25, 1.0, space) * (0.6 + 0.4 * fract(h * 97.0)));
	COLOR = c;
}
