// Screen-locked sky gradient. The camera always looks straight down -z with a fixed field of view, so EYEDIR.y maps
// to screen height: span is sin(fov / 2), the value at the top edge.
shader_type sky;

uniform vec4 top : source_color;
uniform vec4 upper : source_color;
uniform vec4 lower : source_color;
uniform vec4 horizon : source_color;
uniform float span = 0.2588;

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
	COLOR = c;
}
