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
// 4. Windows. Every wall carries a row of windows a floor and a column every win_pitch along it, each lit or dark by
//    a hash of the building and its cell. They come from win_tex, two float texels a building: a bit per floor whose
//    windows are out (packed as the floor cut's mask), the height of a floor (0: none), the wall's base and the floors
//    standing. A floor's windows go out with VFX's blow-outs (planet_view.gd blow_windows) and show as dark holes, so
//    the facade matches the glass VFX throws. Thin windows fade into the wall before they alias.
// An instance with nothing to cut keeps back-face culling (its back faces are thrown away in the vertex stage), so
// only the cut towers pay for their insides. tools/cull_check.gd compares that with the rasterizer's own culling.
shader_type spatial;
render_mode unshaded, cull_disabled;

#include "res://render/shaders/color.gdshaderinc"
#include "res://render/shaders/bend.gdshaderinc"

uniform sampler2D stub_tex : filter_nearest, repeat_disable;
uniform sampler2D cut_tex : filter_nearest, repeat_disable;
uniform sampler2D win_tex : filter_nearest, repeat_disable;
uniform float windows = 1.0;         // 0: blank walls
uniform float win_pitch = 62.0;      // RenderLook.WINDOW_PITCH
uniform float win_lit_share = 0.3;   // RenderLook.WINDOW_LIT_SHARE
uniform vec4 win_lit : source_color = vec4(0.95, 0.81, 0.53, 1.0);
uniform vec4 win_glass : source_color = vec4(0.17, 0.21, 0.31, 1.0);
uniform vec4 hole[2];          // xyz: a hidden fighter's chest (world, as drawn); w: the hole's radius in pixels (0: none)
uniform vec4 hole_to[2];       // xyz: the hole's other end (the chest again for a round hole); w: the radius there
uniform vec2 hole_near[2];     // cut what is nearer the camera than this (view distance): at the chest, at the other end
uniform vec4 inside : source_color = vec4(0.07, 0.07, 0.09, 1.0);   // RenderLook.BUILDING_INSIDE
uniform float ref_cull = 0.0;        // 1: leave the back faces to the rasterizer (tools/cull_check.gd's reference picture)

varying flat vec4 v_cut;      // x, y, z: the mask's three parts; w: floor height
varying flat vec2 v_base;     // x: the base's world y; y: the top standing floor
varying flat float v_back;    // 1 on the back wall (model normal toward -z)
varying flat vec4 v_win;      // x, y, z: the mask of floors whose windows are out; w: floor height (0: no windows)
varying flat vec3 v_winb;     // x: the wall's base (world y); y: floors standing; z: the building, for the windows' hash
varying vec3 v_face;          // x: along the wall, from its middle; y: the wall's length; z: 1 on a wall (not a top, not a roof)
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
	int id = min(INSTANCE_ID, textureSize(win_tex, 0).x - 1);
	v_win = texelFetch(win_tex, ivec2(id, 0), 0);
	vec4 wb = texelFetch(win_tex, ivec2(id, 1), 0);
	bool zface = abs(NORMAL.z) > 0.5;
	float sx = length(MODEL_MATRIX[0].xyz);
	float sz = length(MODEL_MATRIX[2].xyz);
	v_winb = vec3(wb.x, wb.y, float(INSTANCE_ID) + (zface ? 0.0 : 0.5));
	v_face = vec3(zface ? VERTEX.x * sx : VERTEX.z * sz, zface ? sx : sz, (abs(NORMAL.y) < 0.5 && COLOR.a > 0.5) ? 1.0 : 0.0);
	POSITION = PROJECTION_MATRIX * (VIEW_MATRIX * bent_world(mat4(1.0), w.xyz));
	if (c.w <= 0.0 && ref_cull < 0.5) {
		// Nothing to cut: cull this face if it looks away from the camera, as cull_back would. Every corner of a face
		// must decide the same, or a face thrown away at some corners only is drawn stretched to the screen's corner
		// (a dark stripe from a roof). So the test uses the face's plane and nothing of the corner itself: the true
		// normal (an instance is scaled unevenly, so the normal takes the inverse scale; a roof's slopes need it) and
		// one point of the plane, the same from every corner (the foot of the model's origin on it, rounded so the
		// corners agree to the bit; lowered with the stub).
		vec3 s2 = max(vec3(dot(MODEL_MATRIX[0].xyz, MODEL_MATRIX[0].xyz), dot(MODEL_MATRIX[1].xyz, MODEL_MATRIX[1].xyz), dot(MODEL_MATRIX[2].xyz, MODEL_MATRIX[2].xyz)), vec3(1e-12));
		vec3 n = (VIEW_MATRIX * (MODEL_MATRIX * vec4(NORMAL / s2, 0.0))).xyz;
		float pd = floor(dot(NORMAL, VERTEX) * 4096.0 + 0.5) / 4096.0;
		vec4 fp = MODEL_MATRIX * vec4(NORMAL * pd, 1.0);
		fp.y = min(fp.y, COLOR.a < 0.5 ? stub - 1.0 : stub);
		if (dot(n, (VIEW_MATRIX * fp).xyz) > 0.0) {
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

// Whether floor k's bit is set in a mask packed as 24, 24 and 14 bits.
bool bit_on(float k, vec3 m) {
	float part = k < 24.0 ? m.x : (k < 48.0 ? m.y : m.z);
	float bit = k < 24.0 ? k : (k < 48.0 ? k - 24.0 : k - 48.0);
	return mod(floor(part / exp2(bit)), 2.0) > 0.5;
}

// Whether floor k is cleared (its bit is 0).
bool cleared(float k, vec3 m) {
	return !bit_on(k, m);
}

float win_hash(vec3 p) {
	p = fract(p * vec3(0.1031, 0.1030, 0.0973));
	p += dot(p, p.yxz + 33.33);
	return fract((p.x + p.y) * p.z);
}

void fragment() {
	if (ref_cull > 0.5 && v_cut.w <= 0.0 && !FRONT_FACING) {
		discard;
	}
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
	if (windows > 0.5 && FRONT_FACING && v_face.z > 0.5 && v_win.w > 0.0) {
		float fy = (v_wy - v_winb.x) / v_win.w;
		float cx = (v_face.x / v_face.y + 0.5) * max(1.0, floor(v_face.y / win_pitch));
		vec2 r = vec2(fract(cx), fract(fy));
		float kf = floor(fy);
		if (kf >= 0.0 && kf < v_winb.y && r.x > 0.24 && r.x < 0.76 && r.y > 0.3 && r.y < 0.78) {
			float fine = 1.0 - smoothstep(0.3, 0.75, max(fwidth(cx), fwidth(fy)));
			vec3 wc = inside.rgb;
			if (!bit_on(kf, v_win.xyz)) {
				wc = win_hash(vec3(v_winb.z, floor(cx), kf)) < win_lit_share ? win_lit.rgb : flat_shade(win_glass.rgb, NORMAL, 0.35);
			}
			col = mix(col, wc, fine);
		}
	}
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
