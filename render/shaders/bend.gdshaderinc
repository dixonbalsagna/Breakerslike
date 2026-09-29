// Planet curvature: world geometry sags by bend * x^2, where x is the distance from the camera across (the camera
// sits at x = 0), weighted by depth so the fighter plane (z = 0) and everything near it stays exactly flat and only
// the world behind curves away. bend is set every frame from the zoom and the camera height (main.gd).
uniform float bend = 0.0;

vec4 bent_clip(mat4 model, mat4 view, mat4 proj, vec3 v) {
	vec4 w = model * vec4(v, 1.0);
	float k = clamp((-w.z - 60.0) / 1200.0, 0.0, 1.0);
	w.y -= bend * w.x * w.x * k;
	return proj * (view * w);
}
