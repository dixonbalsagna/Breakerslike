// A skinned fighter mesh's body (baked by render/core/outline_bake.gd): flat-coloured and faceted like every greybox
// part, lit by the fixed fake light. The mesh's NORMAL carries the outline's smoothed direction, so the facet's own
// normal is taken here from the screen-space derivatives of the view-space position: exact per face, whatever the
// skinning does. Drawn with the hybrid projection (ortho.gdshaderinc) like fighter_flat; its outline is the next pass
// (fighter_hull.gdshader).
shader_type spatial;
render_mode unshaded, cull_back;

#include "res://render/shaders/color.gdshaderinc"
#include "res://render/shaders/bend.gdshaderinc"
#include "res://render/shaders/ortho.gdshaderinc"

uniform vec4 albedo : source_color = vec4(1.0);
uniform float shade : hint_range(0.0, 1.0) = 0.35;

void vertex() {
	POSITION = ortho > 0.5 ? ortho_clip(MODEL_MATRIX, VIEW_MATRIX, PROJECTION_MATRIX, VERTEX) : bent_clip(MODEL_MATRIX, VIEW_MATRIX, PROJECTION_MATRIX, VERTEX);
}

void fragment() {
	vec3 n = normalize(cross(dFdx(VERTEX), dFdy(VERTEX)));
	if (dot(n, VERTEX) > 0.0) {
		n = -n;   // toward the camera: the derivatives' sign flips with the render target's y
	}
	ALBEDO = flat_shade(albedo.rgb * COLOR.rgb, n, shade);
}
