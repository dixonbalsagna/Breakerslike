shader_type canvas_item;
// The panel cut-in's strip (docs/camera/rule-of-cool-shots.md): the inset pane's texture clipped to a slanted
// parallelogram, a border in the fighter's colour, a vignette toward the edges, and a wipe that opens it along the slant.
uniform vec2 box;                 // the quad's size in px (the parallelogram plus the slant's overhang)
uniform float slant;              // px, signed: the top edge is shifted right by this much (negative: left)
uniform float open : hint_range(0.0, 1.0) = 1.0;
uniform float wipe_dir = 1.0;     // +1 opens from the left, -1 from the right
uniform vec4 edge_col : source_color = vec4(0.95, 0.55, 0.2, 1.0);
uniform float border = 4.0;

void fragment() {
	vec2 p = UV * box;
	float w = box.x - abs(slant);
	float t = p.y / box.y;
	float xl = slant >= 0.0 ? slant * (1.0 - t) : -slant * t;
	float x = p.x - xl;
	float dy = min(p.y, box.y - p.y);
	float inside = smoothstep(0.0, 1.5, x) * smoothstep(0.0, 1.5, w - x) * smoothstep(0.0, 1.5, dy);
	float u = wipe_dir > 0.0 ? x / w : 1.0 - x / w;
	float reveal = smoothstep(0.0, 0.05, open * 1.08 - u);
	float d = min(min(x, w - x), dy);
	vec3 col = texture(TEXTURE, UV).rgb;
	col *= mix(1.0, 0.72, smoothstep(border + 26.0, border, d));
	col = mix(col, edge_col.rgb, step(d, border));
	COLOR = vec4(col, inside * reveal);
}
