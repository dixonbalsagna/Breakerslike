// Planet curvature: world geometry sags by bend * x^2, where x is the distance from the camera across (the camera
// sits at x = 0), weighted by depth so the fighter plane (z = 0) and everything near it stays exactly flat and only
// the world behind curves away. The weight also divides out perspective (cam_dist / (cam_dist + depth)), so every
// layer from 1,260 units back to the horizon sags the same number of pixels at the screen edge: one clean curve.
// bend and cam_dist are set every frame from the zoom and the camera height (main.gd).
uniform float bend = 0.0;
uniform float cam_dist = 3000.0;

vec4 bent_world(mat4 model, vec3 v) {
	vec4 w = model * vec4(v, 1.0);
	float back = max(-w.z, 0.0);
	float k = clamp((back - 60.0) / 1200.0, 0.0, 1.0) * cam_dist / (cam_dist + back);
	w.y -= bend * w.x * w.x * k;
	return w;
}

vec4 bent_clip(mat4 model, mat4 view, mat4 proj, vec3 v) {
	return proj * (view * bent_world(model, v));
}
