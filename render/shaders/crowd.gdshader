// Civilians: one MultiMesh of a procedural person (render/core/crowd_mesh.gd). UV.x tags each vertex: 0 outline
// shell, 0.5 shirt (INSTANCE_CUSTOM.rgb, linear), 0.8 skin (between two tones by INSTANCE_CUSTOM.a), 1 trousers.
// The shell is the body pushed out along NORMAL with reversed winding, so it shows only around the
// silhouette: a dark outline that keeps them readable on any ground. boost scales each figure about its feet when
// the camera zooms out, so they stay legible (presentation only; the sim has only counts).
// The instance colour carries the flight (render/core/crowd_flight.gd): g is 1 - run, a the fade. A runner's instance
// is turned so its local +x is where it runs (the figure is the same from behind); its legs and arms scissor about the
// hip and shoulder in its own plane, as a runner seen side-on, it bobs and leans into the run, and it fades out by
// dither, with no sorting. Idle figures (white) keep the idle hop. r is 1 - startled: a survivor near a blow throws
// its arms over its head, crouches a little and trembles, with no hop.
shader_type spatial;
render_mode unshaded, cull_back;

#include "res://render/shaders/color.gdshaderinc"

uniform float boost = 1.0;
uniform float outline = 0.7;
uniform vec4 outline_col : source_color = vec4(0.05, 0.05, 0.08, 1.0);
uniform vec4 legs : source_color = vec4(0.17, 0.18, 0.25, 1.0);
uniform vec4 skin_a : source_color = vec4(0.95, 0.79, 0.65, 1.0);
uniform vec4 skin_b : source_color = vec4(0.55, 0.35, 0.23, 1.0);
uniform float run_hz = 2.8;      // RenderLook.RUN_STRIDE_HZ, RUN_LEG_SWING, RUN_ARM_SWING, RUN_LEAN, RUN_BOB
uniform float leg_swing = 0.75;
uniform float arm_swing = 0.9;
uniform float run_lean = 0.28;
uniform float run_bob = 1.1;
uniform float startle_arms = 2.4;   // RenderLook.STARTLE_ARMS, STARTLE_CROUCH, STARTLE_TREMBLE
uniform float startle_crouch = 0.1;
uniform float startle_tremble = 0.3;

varying vec4 v_custom;
varying float v_kind;
varying float v_fade;

// p rotated by a about the z axis through pivot (x, y): a swing in the figure's plane, positive toward -x at the bottom.
vec3 swing(vec3 p, vec2 pivot, float a) {
	vec2 q = p.xy - pivot;
	return vec3(pivot + vec2(q.x * cos(a) - q.y * sin(a), q.x * sin(a) + q.y * cos(a)), p.z);
}

void vertex() {
	v_kind = UV.x;
	v_custom = INSTANCE_CUSTOM;
	v_fade = COLOR.a;
	float run = 1.0 - COLOR.g;
	vec3 v = VERTEX;
	vec3 nrm = NORMAL;
	float ph = fract(float(INSTANCE_ID) * 0.618034);
	if (run > 0.0) {
		// Parts by place (crowd_mesh.gd): the legs below the hip (7.2), the arms beyond the torso's sides (2.4).
		float s = sin(TIME * run_hz * 6.2831853 + ph * 40.0);
		float side = v.x < 0.0 ? 1.0 : -1.0;
		float a = 0.0;
		vec2 pivot = vec2(0.0);
		if (v.y < 7.25 && abs(v.x) < 2.0) {
			a = side * s * leg_swing * run;
			pivot = vec2(-side * 1.05, 7.2);
		} else if (abs(v.x) > 2.5) {
			a = -side * s * arm_swing * run;
			pivot = vec2(-side * 3.25, 12.6);
		}
		v = swing(v, pivot, a);
		nrm = swing(nrm, vec2(0.0), a);
		v.y += abs(s) * run_bob * run;
		v = swing(v, vec2(0.0), -run_lean * run);
		nrm = swing(nrm, vec2(0.0), -run_lean * run);
	}
	float st = (1.0 - COLOR.r) * (1.0 - run);
	if (st > 0.0) {
		if (abs(v.x) > 2.5) {
			float side = v.x < 0.0 ? 1.0 : -1.0;
			v = swing(v, vec2(-side * 3.25, 12.6), side * startle_arms * st);
			nrm = swing(nrm, vec2(0.0), side * startle_arms * st);
		}
		v.y *= 1.0 - startle_crouch * st;
		v.x += sin(TIME * 37.0 + ph * 50.0) * startle_tremble * st;
	}
	if (UV.x < 0.25) {
		v += nrm * outline / boost;
	}
	// A small idle hop on about half of them, out of step.
	v.y += max(0.0, sin(TIME * 4.0 + ph * 40.0)) * 0.9 * step(0.5, ph) * (1.0 - run) * (1.0 - st);
	VERTEX = v * boost;
	NORMAL = nrm;
}

void fragment() {
	if (v_fade < 0.999 && fract(dot(FRAGCOORD.xy, vec2(0.7548777, 0.5698403))) >= v_fade) {
		discard;
	}
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
