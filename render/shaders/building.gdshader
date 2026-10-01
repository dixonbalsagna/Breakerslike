// Buildings and their roofs, every depth row (docs/world/buildings-in-depth.md; "Occlusion" and B3 in
// docs/rendering/README.md): flat like every prop, with three things of its own.
// 1. The hole. A fighter behind a building is kept in view: whatever of a building lies nearer the camera than he
//    does is cut away inside a dithered circle around him on this pane's screen (hole: his chest in world space and
//    the radius in pixels; hole_near: the view distance to cut up to, which stops short of the building he is aimed
//    at, so that one stays whole). When two fighters fight behind a block the hole stretches toward the other one
//    (hole_to: its other end and the radius there; hole_near's second number: the view distance to cut up to there),
//    so one opening covers both and the gap between them. pane_world.gd sets these each frame.
// 2. The stub. The other occlusion method: a building in front of a fighter is cut down to a low stub. Every vertex
//    above the height in stub_tex (a float texel a building, this pane's, read by the instance's index) is lowered to
//    it, so the box sinks to a solid stub with its own top, and a roof (instance colour alpha 0) folds flat under it.
// 3. The floor cut. World's skyscrapers lose floors to a brunt (Building.fmask): a cleared floor under a standing one
//    is a tunnel. Its front and side walls open (discard) and the back wall shows its dark inside, so the fighter is
//    seen flying through the building at his own depth. The mask comes from cut_tex, a float texel a building read by
//    the instance's index (planet_view.gd; a MultiMesh's own custom data is half floats here, too coarse for it): r and
//    g hold floors 0 to 47 (24 bits each), b floors 48 to 61 plus 16,384 times the top standing floor, a the height
//    of a floor (0: nothing to cut). The box's top is that floor's ceiling, which gives the base.
// An instance with nothing to cut keeps back-face culling (its back faces are thrown away in the vertex stage), so
// only the cut towers pay for their insides.
shader_type spatial;
render_mode unshaded, cull_disabled;

#include "res://render/shaders/color.gdshaderinc"
#include "res://render/shaders/bend.gdshaderinc"

uniform sampler2D stub_tex : filter_nearest, repeat_disable;
uniform sampler2D cut_tex : filter_nearest, repeat_disable;
uniform vec4 hole[2];          // xyz: a hidden fighter's chest (world, as drawn); w: the hole's radius in pixels (0: none)
uniform vec4 hole_to[2];       // xyz: the hole's other end (the chest again for a round hole); w: the radius there
uniform vec2 hole_near[2];     // cut what is nearer the camera than this (view distance): at the chest, at the other end
uniform vec4 inside : source_color = vec4(0.07, 0.07, 0.09, 1.0);   // RenderLook.BUILDING_INSIDE

varying flat vec4 v_cut;      // x, y, z: the mask's three parts; w: floor height
varying flat vec2 v_base;     // x: the base's world y; y: the top standing floor
varying flat float v_back;    // 1 on the back wall (model normal toward -z)
varying flat vec4 v_hole0;    // each hole's two ends on this pane's screen, in pixels (xy: the chest, zw: the other end)
varying flat vec4 v_hole1;
varying float v_wy;

// A world point on this pane's screen, in FRAGCOORD's pixels.
vec2 screen_px(mat4 view, mat4 proj, vec3 p, vec2 size) {
	vec4 c = proj * (view * vec4(p, 1.0));
	return (c.xy / c.w * 0.5 + 0.5) * size;
}

void vertex() {
	float stub = texelFetch(stub_tex, ivec2(min(INSTANCE_ID, textureSize(stub_tex, 0).x - 1), 0), 0).r;
	vec4 c = texelFetch(cut_tex, ivec2(min(INSTANCE_ID, textureSize(cut_tex, 0).x - 1), 0), 0);
	float top_floor = floor(c.z / 16384.0);
	v_cut = vec4(c.x, c.y, c.z - top_floor * 16384.0, c.w);
	vec4 w = MODEL_MATRIX * vec4(VERTEX, 1.0);
	float top = MODEL_MATRIX[3].y + 0.5 * length(MODEL_MATRIX[1].xyz);
	v_base = vec2(top - (top_floor + 1.0) * c.w, top_floor);
	v_back = NORMAL.z < -0.5 ? 1.0 : 0.0;
	w.y = min(w.y, COLOR.a < 0.5 ? stub - 1.0 : stub);
	v_wy = w.y;
	POSITION = PROJECTION_MATRIX * (VIEW_MATRIX * bent_world(mat4(1.0), w.xyz));
	if (c.w <= 0.0) {
		// Nothing to cut: cull this face if it looks away from the camera, as cull_back would.
		vec3 n = normalize((VIEW_MATRIX * (MODEL_MATRIX * vec4(NORMAL, 0.0))).xyz);
		vec3 p = (VIEW_MATRIX * w).xyz;
		if (dot(n, p) > 0.0) {
			POSITION = vec4(2.0, 2.0, 2.0, 1.0);
		}
	}
	v_hole0 = vec4(0.0);
	v_hole1 = vec4(0.0);
	if (hole[0].w > 0.0) {
		v_hole0 = vec4(screen_px(VIEW_MATRIX, PROJECTION_MATRIX, hole[0].xyz, VIEWPORT_SIZE), screen_px(VIEW_MATRIX, PROJECTION_MATRIX, hole_to[0].xyz, VIEWPORT_SIZE));
	}
	if (hole[1].w > 0.0) {
		v_hole1 = vec4(screen_px(VIEW_MATRIX, PROJECTION_MATRIX, hole[1].xyz, VIEWPORT_SIZE), screen_px(VIEW_MATRIX, PROJECTION_MATRIX, hole_to[1].xyz, VIEWPORT_SIZE));
	}
}

// Whether floor k is cleared (its bit is 0).
bool cleared(float k, vec3 m) {
	float part = k < 24.0 ? m.x : (k < 48.0 ? m.y : m.z);
	float bit = k < 24.0 ? k : (k < 48.0 ? k - 24.0 : k - 48.0);
	return mod(floor(part / exp2(bit)), 2.0) < 0.5;
}

void fragment() {
	float dith = fract(dot(FRAGCOORD.xy, vec2(0.7548777, 0.5698403)));
	for (int i = 0; i < 2; i++) {
		if (hole[i].w > 0.0) {
			// The distance to the hole's axis (a point for a round hole), and how far along it this pixel is.
			vec4 ends = i == 0 ? v_hole0 : v_hole1;
			vec2 ab = ends.zw - ends.xy;
			vec2 ap = FRAGCOORD.xy - ends.xy;
			float t = clamp(dot(ap, ab) / max(dot(ab, ab), 0.0001), 0.0, 1.0);
			if (-VERTEX.z < mix(hole_near[i].x, hole_near[i].y, t) && length(ap - ab * t) < mix(hole[i].w, hole_to[i].w, t) * (0.8 + 0.25 * dith)) {
				discard;
			}
		}
	}
	vec3 col = FRONT_FACING ? flat_shade(COLOR.rgb, NORMAL, 0.35) : inside.rgb;
	if (v_cut.w > 0.0) {
		float k = floor((v_wy - v_base.x) / v_cut.w);
		if (k >= 0.0 && k < v_base.y && cleared(k, v_cut.xyz)) {
			if (FRONT_FACING || v_back < 0.5) {
				discard;
			}
			col = inside.rgb;
		}
	}
	ALBEDO = col;
}
