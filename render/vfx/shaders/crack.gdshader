// Ground cracks (docs/vfx/plan.md section 3), draped strips built by render/vfx/crack_mesh.gd.
// VERTEX is on the crack's centre line, exactly on the ground as drawn. CUSTOM0 = (ox, oz, px, 0): the offset to this
// vertex's side of the strip in the ground plane, and the least thickness in pixels this vertex's half of the strip may
// have on screen. UV = (u, born): u the vertex's distance from the set's origin over its reach, born the sim time it
// began. The ground is seen at a grazing angle, so a crack's width across the depth is foreshortened to almost nothing.
// The widening is done in screen space: the offset is projected, and if its projection is shorter than px / 2 pixels it is
// stretched to that length along its own screen direction. The vertex therefore never leaves the ground (an earlier version
// widened the offset in world z and left crack edges hanging in the air on a mountain's flank). The web grows outward from
// the origin over grow_t seconds of sim time (`now` is the sim time, so hit-stop and pause hold it): a vertex the front has
// not yet reached has no width. The curvature is the ground's (bend.gdshaderinc), so a crack sits on the surface at every
// depth, and the strip is lifted a little so it clears the terrain it lies on.
shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;

#include "res://render/shaders/bend.gdshaderinc"

uniform float now = 0.0;
uniform float grow_t = 0.45;
uniform float lift = 6.0;             // units above the ground as drawn (the strips are sampled from the same ground)
uniform float max_px = 14.0;          // the most a vertex is stretched on screen, in pixels of half thickness
uniform float fade_from = 2500.0;     // cracks fade out with depth behind the fighter plane, gone by fade_to (they are only detail up close)
uniform float fade_to = 7000.0;
uniform float fade = 1.0;             // a standing set's own fade in and out (react.gd), 1 for every other set

varying vec4 v_col;

vec4 clip_at(vec3 v, mat4 model, mat4 view, mat4 proj) {
	return proj * (view * bent_world(model, v));
}

void vertex() {
	float g = clamp((now - UV.y) / max(grow_t, 0.001), 0.0, 1.0);
	float wf = clamp((g * 1.15 - UV.x) * 7.0, 0.0, 1.0);
	wf = wf * wf * (3.0 - 2.0 * wf);
	vec3 off = vec3(CUSTOM0.x, 0.0, CUSTOM0.y);
	vec3 base = VERTEX + vec3(0.0, lift, 0.0);
	vec4 p0 = clip_at(base, MODEL_MATRIX, VIEW_MATRIX, PROJECTION_MATRIX);
	float ol = length(off);
	if (ol > 1e-5 && p0.w > 0.0) {
		vec3 dw = off / ol;
		vec4 p1 = clip_at(base + dw * 100.0, MODEL_MATRIX, VIEW_MATRIX, PROJECTION_MATRIX);
		vec2 half_vp = VIEWPORT_SIZE * 0.5;
		vec2 s0 = p0.xy / p0.w * half_vp;
		vec2 s1 = p1.xy / max(p1.w, 0.001) * half_vp;
		vec2 d = s1 - s0;
		float dl = length(d);
		vec2 dn = d / max(dl, 1e-4);
		float phys_px = dl * ol / 100.0;                       // the offset's own projected length
		float want = clamp(max(phys_px, CUSTOM0.z * 0.5), 0.0, max_px);
		p0.xy += dn * want * wf / half_vp * p0.w;
	}
	POSITION = p0;
	float back = max(-(MODEL_MATRIX * vec4(VERTEX, 1.0)).z, 0.0);
	v_col = vec4(COLOR.rgb, COLOR.a * fade * (1.0 - smoothstep(fade_from, fade_to, back)));
}

void fragment() {
	ALBEDO = v_col.rgb;
	ALPHA = v_col.a;
}
