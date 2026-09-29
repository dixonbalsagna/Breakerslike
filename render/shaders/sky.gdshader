// Screen-locked sky gradient. The camera always looks straight down -z with a fixed field of view, so EYEDIR.y maps
// to screen height: span is sin(fov / 2), the value at the top edge. space (0 to 1, from the camera height) darkens
// the upper sky toward space and brings the stars up. The stars are screen-fixed like the gradient (a drift tied to
// the camera's x would jump at the wrap seam). High up, the planet's limb rises into view: a big curved horizon
// (a circle in screen space, dipping below eye level as the camera climbs) with a glowing atmosphere rim. Low down
// it sits behind the ridges and far land; it is only drawn where no geometry covers the sky.
shader_type sky;

uniform vec4 top : source_color;
uniform vec4 upper : source_color;
uniform vec4 lower : source_color;
uniform vec4 horizon : source_color;
uniform float span = 0.2588;
uniform float space = 0.0;
uniform vec4 space_col : source_color = vec4(0.01, 0.012, 0.035, 1.0);
uniform vec4 limb_surface : source_color = vec4(0.23, 0.27, 0.45, 1.0);
uniform vec4 limb_glow : source_color = vec4(0.62, 0.84, 1.0, 1.0);
uniform float limb_radius = 4.0;    // in half-screen-heights

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

void sky() {
	float t = clamp(0.5 - EYEDIR.y / (2.0 * span), 0.0, 1.0);
	vec3 c;
	if (t < 0.5) {
		c = mix(top.rgb, upper.rgb, t / 0.5);
	} else if (t < 0.76) {
		c = mix(upper.rgb, lower.rgb, (t - 0.5) / 0.26);
	} else {
		c = mix(lower.rgb, horizon.rgb, (t - 0.76) / 0.24);
	}
	c = mix(c, space_col.rgb, space * clamp(1.0 - t * 1.1, 0.0, 1.0));
	vec2 p = EYEDIR.xy / max(0.2, -EYEDIR.z);
	vec2 g = p * 260.0;
	float h = hash21(floor(g));
	float d = length(fract(g) - 0.5);
	float star = step(0.994, h) * (1.0 - smoothstep(0.08, 0.2, d));
	float fade = clamp(1.0 - t * 1.6, 0.0, 1.0);
	c += vec3(star * fade * mix(0.25, 1.0, space) * (0.6 + 0.4 * fract(h * 97.0)));
	// The limb: q is the screen position in half-screen-heights (y up), the circle's top sits dip below eye level.
	vec2 q = p / (span / sqrt(1.0 - span * span));
	float dip = 0.05 + 0.25 * space;
	float r = length(q - vec2(0.0, -dip - limb_radius)) - limb_radius;
	float show = smoothstep(0.1, 0.6, space);
	vec3 surface = mix(limb_glow.rgb, limb_surface.rgb, clamp(-r * 5.0, 0.0, 1.0));
	vec3 lit = r < 0.0 ? surface : c + limb_glow.rgb * exp(-r * 18.0) * 0.9;
	COLOR = mix(c, lit, show);
}
