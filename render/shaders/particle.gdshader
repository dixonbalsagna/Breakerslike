// Cosmetic particles from the fx consumer, one MultiMesh quad each. INSTANCE_CUSTOM.x picks the shape:
// 0 solid rectangle (sparks, debris, afterimages), 1 disc (flames, splashes), 2 ring (shockwaves; .y is the inner
// radius as a fraction of the outer), 3 soft disc (dust). COLOR is the colour with the fade in alpha.
shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;

#include "res://render/shaders/color.gdshaderinc"

varying vec4 v_custom;

void vertex() {
	v_custom = INSTANCE_CUSTOM;
}

void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	float aa = max(fwidth(r), 0.001);
	float shape = v_custom.x;
	float a = 1.0;
	if (shape > 2.5) {
		a = 1.0 - smoothstep(0.0, 1.0, r);
	} else if (shape > 1.5) {
		a = smoothstep(v_custom.y - aa, v_custom.y + aa, r) * (1.0 - smoothstep(1.0 - 2.0 * aa, 1.0, r));
	} else if (shape > 0.5) {
		a = 1.0 - smoothstep(1.0 - 2.0 * aa, 1.0, r);
	}
	ALBEDO = COLOR.rgb;
	ALPHA = COLOR.a * a;
}
