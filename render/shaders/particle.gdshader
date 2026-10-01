// Cosmetic particles from the fx consumer, one MultiMesh quad each. INSTANCE_CUSTOM.x picks the shape:
// 0 solid rectangle (sparks, debris), 1 disc (flames, splashes), 2 ring (shockwaves; .y is the inner radius as a
// fraction of the outer), 3 soft disc (dust), 4 an afterimage: the outline of a figure, a head on a body, leaning the
// way he faced (.y is the facing, 1 or -1; .z and .w the quad's size in world units). A line and nothing inside it.
// COLOR is the colour with the fade in alpha.
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
	if (shape > 3.5) {
		// World units from the quad's middle, x toward the side he faced, y up; the lean is taken back out.
		vec2 q = p * 0.5 * v_custom.zw;
		q = vec2(q.x * v_custom.y, -q.y);
		q.x -= 0.12 * q.y;
		float head = length(q - vec2(3.0, 27.0)) - 10.0;
		vec2 b = abs(q - vec2(0.0, -8.0)) - vec2(13.0, 28.0) + 9.0;
		float body = length(max(b, 0.0)) + min(max(b.x, b.y), 0.0) - 9.0;
		float d = min(head, body);
		float px = max(fwidth(d), 0.001);
		float w = max(1.0, 1.1 * px);   // the line's half width: a unit, and never under a pixel
		a = 1.0 - smoothstep(w - px, w + px, abs(d));
	} else if (shape > 2.5) {
		a = 1.0 - smoothstep(0.0, 1.0, r);
	} else if (shape > 1.5) {
		a = smoothstep(v_custom.y - aa, v_custom.y + aa, r) * (1.0 - smoothstep(1.0 - 2.0 * aa, 1.0, r));
	} else if (shape > 0.5) {
		a = 1.0 - smoothstep(1.0 - 2.0 * aa, 1.0, r);
	}
	ALBEDO = COLOR.rgb;
	ALPHA = COLOR.a * a;
}
