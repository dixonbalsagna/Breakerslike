// The sky's colour for a view direction, anchored to the horizon (the far edge of the ground, where the terrain fog
// ends): the horizon colour at the line, then the lower, upper and top colours above it. As the camera climbs
// (space 0 to 1) the band thins to a narrow rim and the sky above turns to space. The sky shader draws it, and the
// terrain and water fog toward it in the same direction, so the far ground dissolves into the sky with no edge.
uniform vec4 sky_top : source_color;
uniform vec4 sky_upper : source_color;
uniform vec4 sky_lower : source_color;
uniform vec4 sky_horizon : source_color;
uniform vec4 space_col : source_color = vec4(0.01, 0.012, 0.035, 1.0);
uniform float space = 0.0;
uniform float horizon = 0.0;       // tan of the horizon's elevation seen from the camera (below eye level: negative)
uniform float sky_tan = 0.268;     // tan(fov / 2): half a screen height in tan units
uniform float sky_lower_at = 0.12;
uniform float sky_upper_at = 0.55;
uniform float sky_top_at = 1.45;
uniform float sky_thin = 2.5;
uniform float fog_band = 0.25;     // haze depth below the horizon line, in half-screen heights (thins with altitude)

// Height above the horizon in half-screen heights, thinned with altitude, for the tan of an elevation q.
float sky_height(float q) {
	return (q - horizon) / sky_tan * (1.0 + sky_thin * space);
}

vec3 sky_color(float q) {
	float d = sky_height(q);
	vec3 c;
	if (d <= 0.0) {
		c = sky_horizon.rgb;
	} else if (d < sky_lower_at) {
		c = mix(sky_horizon.rgb, sky_lower.rgb, d / sky_lower_at);
	} else if (d < sky_upper_at) {
		c = mix(sky_lower.rgb, sky_upper.rgb, (d - sky_lower_at) / (sky_upper_at - sky_lower_at));
	} else {
		c = mix(sky_upper.rgb, sky_top.rgb, clamp((d - sky_upper_at) / (sky_top_at - sky_upper_at), 0.0, 1.0));
	}
	return mix(c, space_col.rgb, space * clamp(d * 1.5, 0.0, 1.0));
}

// The tan of the elevation of a direction from the camera, in world axes.
float elevation(vec3 v) {
	return v.y / max(0.0001, length(v.xz));
}

// Aerial haze for ground seen at elevation q, depth `depth` behind the fighter plane: thickest along grazing views
// near the horizon line and clearing below it (looking down through less air), thinning as the camera climbs like the
// sky's rim; a light overall haze with distance; and the last eighth before the far edge fading out completely, so
// the ground's end never shows, even where the curvature drops it below the horizon line at the screen sides.
float ground_fog(float q, float depth, float near, float far) {
	float band = fog_band / (1.0 + sky_thin * space);
	float fh = 1.0 - smoothstep(0.0, band, (horizon - q) / sky_tan);
	float f = max(fh * smoothstep(near, 3.0 * near, depth), smoothstep(0.88 * far, far, depth));
	return max(f, 0.25 * smoothstep(near, far, depth));
}
