// Beams: additive quads in the z = 0 plane, all drawn from one MultiMesh (one draw call for every beam).
// The camera never rotates, so quads in the z = 0 plane always face it.
// Per instance: COLOR = beam colour; INSTANCE_CUSTOM.x = mode (0 glow 44 wide, 1 core 14 wide, 2 impact flare r 60),
// INSTANCE_CUSTOM.y = intensity. The instance transform (set on the CPU in camera-relative space) stretches a unit quad.
shader_type spatial;
render_mode blend_add, unshaded, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;

varying vec3 v_color;
varying float v_mode;
varying float v_intensity;

void vertex() {
	v_color = COLOR.rgb;
	v_mode = INSTANCE_CUSTOM.x;
	v_intensity = INSTANCE_CUSTOM.y;
}

void fragment() {
	float a;
	if (v_mode > 1.5) {
		float r = length(UV - vec2(0.5)) * 2.0;
		a = clamp(1.0 - r, 0.0, 1.0);
		a = a * a;
	} else {
		float v = abs(UV.y - 0.5) * 2.0;
		if (v_mode < 0.5) {
			a = (1.0 - v) * (1.0 - v) * 0.7;
		} else {
			a = clamp(1.0 - v * v * v, 0.0, 1.0);
		}
	}
	ALBEDO = v_color;
	ALPHA = a * v_intensity;
}
