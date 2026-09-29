// Civilians: one MultiMesh of a procedural person (render/core/crowd_mesh.gd). UV.x tags each vertex: 0 outline
// shell, 0.5 shirt (INSTANCE_CUSTOM.rgb, linear), 0.8 skin (between two tones by INSTANCE_CUSTOM.a), 1 trousers.
// The shell is the body pushed out along NORMAL with reversed winding, so it shows only around the
// silhouette: a dark outline that keeps them readable on any ground. boost scales each figure about its feet when
// the camera zooms out, so they stay legible (presentation only; the sim has only counts).
shader_type spatial;
render_mode unshaded, cull_back;

#include "res://render/shaders/color.gdshaderinc"

uniform float boost = 1.0;
uniform float outline = 0.7;
uniform vec4 outline_col : source_color = vec4(0.05, 0.05, 0.08, 1.0);
uniform vec4 legs : source_color = vec4(0.17, 0.18, 0.25, 1.0);
uniform vec4 skin_a : source_color = vec4(0.95, 0.79, 0.65, 1.0);
uniform vec4 skin_b : source_color = vec4(0.55, 0.35, 0.23, 1.0);

varying vec4 v_custom;
varying float v_kind;

void vertex() {
	v_kind = UV.x;
	v_custom = INSTANCE_CUSTOM;
	vec3 v = VERTEX;
	if (UV.x < 0.25) {
		v += NORMAL * outline / boost;
	}
	// A small idle hop on about half of them, out of step.
	float ph = fract(float(INSTANCE_ID) * 0.618034);
	v.y += max(0.0, sin(TIME * 4.0 + ph * 40.0)) * 0.9 * step(0.5, ph);
	VERTEX = v * boost;
}

void fragment() {
	vec3 c;
	if (v_kind < 0.25) {
		c = outline_col.rgb;
	} else if (v_kind < 0.65) {
		c = v_custom.rgb;
	} else if (v_kind < 0.9) {
		c = mix(skin_a.rgb, skin_b.rgb, v_custom.a);
	} else {
		c = legs.rgb;
	}
	ALBEDO = v_kind < 0.25 ? c : flat_shade(c, NORMAL, 0.3);
}
