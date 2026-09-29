// The fighters' hybrid projection. The world keeps its perspective; a fighter's pivot (anchor, world space) is
// projected with it, so the fighter lands exactly where the perspective puts it (the prototype's w2s mapping on the
// fighter plane, unchanged). Every other vertex of the fighter is offset from that point orthographically, at the
// anchor's own scale, so a fighter never warps or leans toward the screen edges: it looks the same at the centre and
// the edges, at any zoom. Depth stays the vertex's true perspective depth, so the ground still hides feet in a
// hollow and the parts still sort among themselves. ortho 0 (the default) is the plain perspective path.
uniform vec3 anchor = vec3(0.0);
uniform float ortho = 0.0;

vec4 ortho_clip(mat4 model, mat4 view, mat4 proj, vec3 v) {
	vec4 w = model * vec4(v, 1.0);
	vec4 cp = proj * (view * w);
	vec4 ca = proj * (view * vec4(anchor, 1.0));
	vec3 d = (view * vec4(w.xyz - anchor, 0.0)).xyz;
	vec4 c = ca + vec4(proj[0][0] * d.x, proj[1][1] * d.y, 0.0, 0.0);
	c.z = cp.z / cp.w * ca.w;
	return c;
}
