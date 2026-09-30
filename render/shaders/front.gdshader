// Row-0 buildings, the foreground row in front of the fighter plane (docs/world/buildings-in-depth.md section 7):
// flat like every prop, and faded per building by dither (no sorting) while one covers a fighter on screen. The fade
// is this pane's (planet_view.gd fade_front), indexed by the instance: a second pane fades from its own camera.
shader_type spatial;
render_mode unshaded, cull_disabled;

#include "res://render/shaders/color.gdshaderinc"

uniform float fade[64];     // per row-0 building: 1 solid, down to RenderLook.FRONT_FADE

varying flat float v_fade;

void vertex() {
	v_fade = INSTANCE_ID < 64 ? fade[INSTANCE_ID] : 1.0;
}

void fragment() {
	if (v_fade < 0.999 && fract(dot(FRAGCOORD.xy, vec2(0.7548777, 0.5698403))) >= v_fade) {
		discard;
	}
	ALBEDO = flat_shade(COLOR.rgb, NORMAL, 0.35);
}
