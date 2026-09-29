// Flat-coloured greybox surface: albedo uniform times the vertex or instance colour, lit by the fixed fake light.
#include "res://render/shaders/color.gdshaderinc"
#include "res://render/shaders/bend.gdshaderinc"
#include "res://render/shaders/ortho.gdshaderinc"

uniform vec4 albedo : source_color = vec4(1.0);
uniform float shade : hint_range(0.0, 1.0) = 0.35;

void vertex() {
	POSITION = ortho > 0.5 ? ortho_clip(MODEL_MATRIX, VIEW_MATRIX, PROJECTION_MATRIX, VERTEX) : bent_clip(MODEL_MATRIX, VIEW_MATRIX, PROJECTION_MATRIX, VERTEX);
}

void fragment() {
	ALBEDO = flat_shade(albedo.rgb * COLOR.rgb, NORMAL, shade);
#ifdef FLAT_ALPHA
	ALPHA = albedo.a * COLOR.a;
#endif
}
