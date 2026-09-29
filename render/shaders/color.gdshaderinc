// Shared colour helpers. Shading happens in linear space: uniforms marked source_color are converted by the engine,
// and vertex and MultiMesh instance colours (set as ordinary sRGB Colors) already reach COLOR in linear space
// (checked by sampling rendered pixels in 4.7.2 Compatibility), so shaders use COLOR as it is.

// The greybox's one fake light: a fixed direction in view space (the camera never rotates), so every renderer and
// every platform shades identically and no light costs a pass.
const vec3 FLAT_LIGHT = vec3(-0.38, 0.78, 0.5);

vec3 flat_shade(vec3 base, vec3 n, float shade) {
	float lam = clamp(dot(normalize(n), normalize(FLAT_LIGHT)), 0.0, 1.0);
	return base * (1.0 - shade + shade * lam);
}
