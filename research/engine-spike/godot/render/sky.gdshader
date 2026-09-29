// Sky: a plain vertical gradient. The camera never pitches or yaws, so EYEDIR.y maps straight to screen height.
shader_type sky;

uniform vec3 top_color : source_color = vec3(0.16, 0.34, 0.66);
uniform vec3 horizon_color : source_color = vec3(0.70, 0.82, 0.93);
uniform vec3 below_color : source_color = vec3(0.55, 0.62, 0.70);

void sky() {
	float y = EYEDIR.y;
	if (y >= 0.0) {
		COLOR = mix(horizon_color, top_color, clamp(y / 0.36, 0.0, 1.0));
	} else {
		COLOR = mix(horizon_color, below_color, clamp(-y / 0.36, 0.0, 1.0));
	}
}
