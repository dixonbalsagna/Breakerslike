// Fighter outlines: the inverted hull, a fighter mesh's next pass (docs/rendering/outline-normals-plan.md). Each
// vertex moves along the direction baked into NORMAL (render/core/outline_bake.gd; skinned with its bone, so it
// follows the pose) by its reach in UV2.x times outline_px pixels, then takes the same projection as the body: the
// hybrid projection (ortho.gdshaderinc) or, with ortho 0, the bent perspective. Under the hybrid projection a fighter
// is orthographic at its anchor's scale, so one world-per-pixel factor holds for the whole fighter and the outline is
// as thick at the screen's edge as at its centre, at any zoom. Back faces only: the body's front always wins the depth.
shader_type spatial;
render_mode unshaded, cull_front;

#include "res://render/shaders/bend.gdshaderinc"
#include "res://render/shaders/ortho.gdshaderinc"

uniform float outline_px = 1.5;   // RenderLook.OUTLINE_PX
uniform vec4 col : source_color = vec4(0.04, 0.05, 0.08, 1.0);
uniform bool face_normals = false;   // an unbaked mesh: push along its faceted NORMAL (the outline check's failing control)

void vertex() {
	vec4 wp = MODEL_MATRIX * vec4(VERTEX, 1.0);
	float w = ortho > 0.5 ? (PROJECTION_MATRIX * (VIEW_MATRIX * vec4(anchor, 1.0))).w : (PROJECTION_MATRIX * (VIEW_MATRIX * wp)).w;
	// abs: drawing into a SubViewport (the panes), the Compatibility renderer flips the projection's y.
	float world_per_px = 2.0 * w / (abs(PROJECTION_MATRIX[1][1]) * VIEWPORT_SIZE.y);
	float s = max(length(MODEL_MATRIX[0].xyz), 1e-6);
	vec3 d = face_normals ? NORMAL : NORMAL * UV2.x;
	vec3 v = VERTEX + d * (outline_px * world_per_px / s);
	POSITION = ortho > 0.5 ? ortho_clip(MODEL_MATRIX, VIEW_MATRIX, PROJECTION_MATRIX, v) : bent_clip(MODEL_MATRIX, VIEW_MATRIX, PROJECTION_MATRIX, v);
}

void fragment() {
	ALBEDO = col.rgb;
}
