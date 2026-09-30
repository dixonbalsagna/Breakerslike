// The hole a fighter leaves in a building's facade (docs/vfx/plan.md section 3): a ragged dark opening with a torn
// lighter rim, one MultiMesh quad each. INSTANCE_CUSTOM.x is a seed for the outline; COLOR.a fades a hole as its
// building goes. Cel: two steps, a hard edge.
shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;

uniform vec4 dark_col : source_color = vec4(0.08, 0.09, 0.11, 1.0);
uniform vec4 rim_col : source_color = vec4(0.60, 0.64, 0.70, 1.0);

varying vec4 v_custom;

void vertex() {
	v_custom = INSTANCE_CUSTOM;
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float aa = max(fwidth(p.x), fwidth(p.y)) * 0.8 + 0.0005;
	float sd = v_custom.x;
	float ang = atan(p.y, p.x);
	float r = length(p);
	float j = 0.66 + 0.15 * sin(ang * 7.0 + sd * 20.0) + 0.09 * sin(ang * 13.0 + sd * 7.0) + 0.05 * sin(ang * 23.0 + sd * 3.0);
	float inside = 1.0 - smoothstep(j - aa, j + aa, r);
	float ring = (1.0 - smoothstep(j + 0.16 - aa, j + 0.16 + aa, r)) * (1.0 - inside);
	ALBEDO = mix(rim_col.rgb, dark_col.rgb, inside);
	ALPHA = max(inside, ring * 0.9) * COLOR.a;
}
