shader_type canvas_item;
// The split-screen compositor (docs/camera/split-screen.md section 11): two pane renders, blended by which side of the
// divider each pixel is on. Pane 1 owns the points with dot(p - c, n) > 0. A feather widens the blend for a dissolve;
// with no feather the edge is a hard step. A thin dark gap sits under the divider line UI draws (docs/ui/hud-spec.md).

uniform sampler2D tex0 : filter_linear, repeat_disable;
uniform sampler2D tex1 : filter_linear, repeat_disable;
uniform vec2 res = vec2(1280.0, 720.0);
uniform vec2 c = vec2(640.0, 360.0);
uniform vec2 n = vec2(1.0, 0.0);
uniform float feather = 0.0;
uniform float gap = 0.0;
uniform float gap_alpha = 0.0;
uniform float active0 = 1.0;
uniform float active1 = 1.0;
uniform float dim0 = 0.0;
uniform float dim1 = 0.0;

void fragment() {
	vec2 p = UV * res;
	float s = dot(p - c, n);
	float w1 = feather > 0.5 ? smoothstep(-feather, feather, s) : step(0.0, s);
	if (active1 < 0.5) {
		w1 = 0.0;
	}
	if (active0 < 0.5) {
		w1 = 1.0;
	}
	vec3 a = texture(tex0, UV).rgb * (1.0 - dim0);
	vec3 b = texture(tex1, UV).rgb * (1.0 - dim1);
	vec3 col = mix(a, b, w1);
	float g = (1.0 - smoothstep(gap * 0.5 - 0.5, gap * 0.5 + 0.5, abs(s))) * gap_alpha * active0 * active1;
	col = mix(col, vec3(0.03, 0.04, 0.06), g * 0.85);
	COLOR = vec4(col, 1.0);
}
