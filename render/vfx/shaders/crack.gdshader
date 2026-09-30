// Ground cracks (docs/vfx/plan.md section 3), draped strips built by render/vfx/crack_mesh.gd.
// VERTEX is on the crack's centre line, on the ground as drawn. CUSTOM0 = (ox, oz, px, 0): the offset to this vertex's
// side of the strip, and the least thickness in pixels this vertex's half of the strip may have on screen. UV = (u, born):
// u the vertex's distance from the set's origin over its reach, born the sim time it began. The ground is seen at a
// grazing angle, so a crack's width across the depth is foreshortened to almost nothing: the shader scales the offset up
// until its screen thickness reaches px (at most smax times), so a crack reads as a line at any zoom and any camera
// height, and keeps the physical width where that is already more. The web grows outward from the origin over grow_t
// seconds of sim time (`now` is the sim time, so hit-stop and pause hold it): a vertex the front has not yet reached
// has no width. The curvature is the ground's (bend.gdshaderinc), so a crack sits on the surface at every depth, and
// the strip is lifted a little so it clears the terrain it lies on.
shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;

#include "res://render/shaders/bend.gdshaderinc"

uniform float now = 0.0;
uniform float grow_t = 0.45;
uniform float px_world = 1.6;         // world units per pixel at the fighter plane (1 / zoom), set per pane every frame
uniform float smax = 16.0;
uniform float lift = 6.0;             // units above the ground as drawn (the strips are sampled from the same ground)

varying vec4 v_col;

void vertex() {
	float g = clamp((now - UV.y) / max(grow_t, 0.001), 0.0, 1.0);
	float wf = clamp((g * 1.15 - UV.x) * 7.0, 0.0, 1.0);
	wf = wf * wf * (3.0 - 2.0 * wf);
	vec3 off = vec3(CUSTOM0.x, 0.0, CUSTOM0.y);
	vec3 wc = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float d = max(distance(CAMERA_POSITION_WORLD, wc), 1.0);
	float sin_e = clamp(abs(CAMERA_POSITION_WORLD.y - wc.y) / d, 0.02, 1.0);
	float sx = abs(off.x) / px_world;
	float sz = abs(off.z) * sin_e / px_world;
	float len_px = max(sqrt(sx * sx + sz * sz), 0.0001);
	float s = clamp(CUSTOM0.z * 0.5 / len_px, 1.0, smax);
	vec3 v = VERTEX + off * s * wf + vec3(0.0, lift, 0.0);
	POSITION = PROJECTION_MATRIX * (VIEW_MATRIX * bent_world(MODEL_MATRIX, v));
	v_col = COLOR;
}

void fragment() {
	ALBEDO = v_col.rgb;
	ALPHA = v_col.a;
}
