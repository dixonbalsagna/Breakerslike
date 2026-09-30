// Water: the sea and crater lakes, one surface from well in front of the camera to the horizon. In the crater rows it
// comes from S.water (the sim's per-column depth): a surface at each wet column's standing level, depth-tested against
// the ground, so a lake shows only inside its bowl; off the sea (base below -30) the ground there must also be dug, so
// low coastal land beside a lake stays dry. Beyond the crater rows the far terrain decides, in the sea's columns (base
// below -30, the sim's sea rule): sea level wherever the far ground is below it, so the sea runs on to the horizon
// with one shoreline, and islands rise where the far sea floor does. In front of the fighter plane the foreground rule
// (fore_fall) lowers the surface and the ground under it together, below the sight line to the fighter plane's water.
// Where it had to fall (the camera near or below the waterline) or is seen from under its own level, the water shows
// its body, so what is under the water reads as under it, as the old front face did.
// The shore (in the crater rows): a vertex whose ground stands at or above the level of the water at or beside it (row
// 20, ground_field.gd) keeps that level, so a triangle from the water to the land stays flat and is cut where the land
// rises through it (v_depth crosses zero): the shoreline and a lake's outline in depth follow the ground's own contour.
// Without it the land vertex took the ground's height, the sheet sloped up the bank and was cut halfway between the
// vertices, a jagged wedge climbing the land at the mesh's stride. Dry land a little below the water beside it (at
// most shore_flood, as World's sea edge leaves a strip of up to 0.25 bh) is drawn flooded at that level, so the
// waterline is where the land rises through it and the drop at the sea's last column stays under water; deeper low
// land beside water stays dry, as the sim has it.
// It fogs into the sky like the ground. UV.x: terrain column. UV2.y: 1 on the fighter-plane row. Same data as the
// terrain (ground.gdshaderinc).
shader_type spatial;
render_mode unshaded, cull_disabled, blend_mix, depth_draw_never;

#include "res://render/shaders/bend.gdshaderinc"
#include "res://render/shaders/ground.gdshaderinc"
#include "res://render/shaders/skycol.gdshaderinc"

uniform vec4 water : source_color;
uniform vec4 surface : source_color;
uniform float fall_body = 4.0;   // RenderLook.WATER_FALL_BODY: a sheet that fell this far shows its body
uniform float fog_near = 700.0;
uniform float fog_far = 12000.0;

varying float v_wet;
varying float v_depth;
varying float v_ok;
varying float v_under;
varying vec3 v_view;
varying float v_wz;

void vertex() {
	int i = int(UV.x + 0.5) % nc;
	float xw = UV.x * col_w;
	float b = gf(i, 0);
	float d0 = gf(i, 1);
	float wd = gf(i, 4);
	float z = VERTEX.z;
	float s = far_weight(z);
	float surf;
	float ground;
	bool shore = false;
	if (s <= 0.0) {
		v_wet = wd >= wet_min ? 1.0 : 0.0;
		surf = b + d0 + wd;
		float lv = gf(i, 20);
		float off = d0;
		if ((v_wet > 0.5 || lv > -1.0e8) && UV2.y < 0.5) {
			off = ground_offset(i, xw, z);
		}
		ground = b + off;
		// The sea is wherever the sim's water stands at sea level (World's edge follows S.water, not the base rule).
		v_ok = (b < sea_base || off < -wet_min || abs(surf) < wet_min) ? 1.0 : 0.0;
		if (lv > -1.0e8 && ground >= lv) {
			shore = true;
			surf = lv;
			v_wet = 1.0;
			v_ok = 1.0;
		} else if (lv > -1.0e8 && v_wet < 0.5 && lv - ground <= shore_flood) {
			surf = lv;
			v_wet = 1.0;
			v_ok = 1.0;
		}
	} else {
		float xs = far_x(xw, z, s);
		ground = mix(b, far_height3(xs, xw, z).x, s);
		surf = 0.0;
		v_wet = (ground < 0.0 && (mix(b, gfx(xs, 0), s) < sea_base || gfx(xs, 4) >= wet_min)) ? 1.0 : 0.0;
		v_ok = 1.0;
	}
	// The foreground rule on the surface and the ground under it, as the terrain shader applies it to that ground.
	float surf0 = surf;
	if (!shore && (v_wet < 0.5 || v_ok < 0.5 || surf <= ground)) {
		surf = ground;
	}
	vec2 gr = vec2(0.0);
	float ox = MODEL_MATRIX[3].x;
	if (shore) {
		// The land falls as dry land does; the sheet falls with the water beside it, to the sight line's cap for tops.
		float top = ground;
		fore_fall(ground, gr, top, xw + ox, z, ox);
		if (z > 0.0) {
			surf = min(surf, fore_cap3(xw + ox, z, ox, true).x);
		}
		surf = min(surf, ground);   // never over land the rule pushed below it
	} else {
		fore_fall(ground, gr, surf, xw + ox, z, ox);
	}
	v_under = max(clamp((surf0 - fore_cam.y) / fall_body, 0.0, 1.0), smoothstep(0.0, fall_body, surf0 - surf));
	VERTEX.y = surf;
	v_depth = surf - ground;
	vec4 bw = bent_world(MODEL_MATRIX, VERTEX);
	v_view = (VIEW_MATRIX * bw).xyz;
	v_wz = bw.z;
	POSITION = PROJECTION_MATRIX * vec4(v_view, 1.0);
}

void fragment() {
	if (v_wet < 0.5 || v_depth <= 0.0 || v_ok < 0.5) {
		discard;
	}
	vec3 c;
	float a;
	c = mix(surface.rgb, water.rgb, v_under);
	a = mix(surface.a, 0.5 + 0.25 * clamp(v_depth / 340.0, 0.0, 1.0), v_under);
	float fog = ground_fog(elevation(v_view), -v_wz, fog_near, fog_far);
	ALBEDO = mix(c, sky_color(elevation(v_view)), fog);
	ALPHA = mix(a, 1.0, fog);
}
