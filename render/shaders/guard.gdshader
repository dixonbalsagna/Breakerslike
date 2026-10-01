// The guard arc (fighter_view.gd): a held guard shows as an arc in front of the fighter, on the side he faces. A thin
// line in his lane colour with a faint fill behind it, fading out toward its two ends. It is drawn in a quad that
// stands in the fighter's plane: x runs from the quad's near edge toward the side he faces, y up from its middle, and
// the arc is part of a circle whose centre lies behind the near edge, so it bulges forward.
// A perfect block flashes it (flash 1, falling to 0): the line thickens and goes solid, the fill deepens, and a
// second line runs outward and fades. fill 0 is the reduced version: the line alone.
// The colour is the lane colour at every moment: nothing here is white, gold or red (Legal's rule for the aura,
// docs/design/rule-of-cool.md section 3b), and the blend is a plain mix, so a bright ground does not wash it pale.
shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled;

#include "res://render/shaders/ortho.gdshaderinc"

uniform vec4 albedo : source_color = vec4(1.0);   // rgb: the lane colour; a: the whole arc's opacity
uniform float flash = 0.0;
uniform float fill = 1.0;
uniform vec2 size = vec2(52.0, 88.0);   // the quad, in world units (RenderLook.GUARD_SIZE)
uniform float radius = 46.0;            // the arc's circle (RenderLook.GUARD_RADIUS)
uniform float fill_depth = 20.0;        // how far behind the line the fill reaches
uniform float fill_alpha = 0.16;

void vertex() {
	if (ortho > 0.5) {
		POSITION = ortho_clip(MODEL_MATRIX, VIEW_MATRIX, PROJECTION_MATRIX, VERTEX);
	} else {
		POSITION = PROJECTION_MATRIX * (MODELVIEW_MATRIX * vec4(VERTEX, 1.0));
	}
}

void fragment() {
	vec2 p = vec2(UV.x * size.x, (0.5 - UV.y) * size.y);
	vec2 d = p - vec2(size.x - 6.0 - radius, 0.0);
	float r = length(d);
	float px = max(fwidth(r), 0.0001);   // world units a pixel
	// The arc ends short of the quad's top and bottom, and fades over the last third of its sweep.
	float sweep = asin(min(1.0, (size.y * 0.5 - 4.0) / radius));
	float ends = 1.0 - smoothstep(sweep * 0.66, sweep, abs(atan(d.y, d.x)));
	// The line: never thinner than a pixel and a quarter each side.
	float w = max(1.4, 1.25 * px) * (1.0 + 1.5 * flash);
	float line = (1.0 - smoothstep(w - px, w + px, abs(r - radius))) * (0.8 + 0.2 * flash);
	float inner = fill * fill_alpha * (1.0 + 2.0 * flash) * smoothstep(radius - fill_depth, radius, r) * step(r, radius);
	float w2 = 0.6 * w;
	float line2 = flash * 0.8 * (1.0 - smoothstep(w2 - px, w2 + px, abs(r - radius - (1.0 - flash) * 14.0)));
	ALBEDO = albedo.rgb;
	ALPHA = albedo.a * ends * max(max(line, inner), line2);
}
