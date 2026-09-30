// Motion trails (docs/vfx/plan.md section 2): tapered blades and thin dashes, hard-edged, one MultiMesh quad each.
// INSTANCE_CUSTOM: x = half-width fraction at the head end (UV.x = 1), y = at the tail end (UV.x = 0), z = shape
// (0 blade: the width runs linearly head to tail; 1 lens: pointed at both ends). COLOR is the colour, alpha the step.
// Cel style: no soft falloff, only a one-pixel anti-aliased edge.
shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;

varying vec4 v_custom;

void vertex() {
	v_custom = INSTANCE_CUSTOM;
}

void fragment() {
	float u = UV.x;
	float v = UV.y * 2.0 - 1.0;
	float hw = mix(v_custom.y, v_custom.x, u);
	if (v_custom.z > 0.5) {
		hw = v_custom.x * sin(3.14159265 * u);
	}
	float aa = max(fwidth(v) * 0.75, 0.002);
	hw = max(hw, aa);
	float a = 1.0 - smoothstep(hw - aa, hw + aa, abs(v));
	ALBEDO = COLOR.rgb;
	ALPHA = COLOR.a * a;
}
