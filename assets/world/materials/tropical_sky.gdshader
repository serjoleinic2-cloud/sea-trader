shader_type sky;

// Clear sky only. Procedural clouds are removed while gameplay is developed.
uniform float night_amount : hint_range(0.0, 1.0) = 0.0;
uniform float twilight_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec3 jupiter_direction = vec3(0.0, -0.10, -1.0);
uniform float jupiter_radius : hint_range(0.05, 0.5) = 0.14;

float star_hash(vec2 cell) {
	vec3 hash = fract(vec3(cell.xyx) * 0.1031);
	hash += dot(hash, hash.yzx + 33.33);
	return fract((hash.x + hash.y) * hash.z);
}

vec3 sky_stars(vec3 direction) {
	// Background only: no point meshes around/under an overhead camera.
	if (night_amount < 0.08 || direction.y < 0.025 ||
		dot(direction, normalize(jupiter_direction)) > cos(jupiter_radius)) {
		return vec3(0.0);
	}
	vec2 sky_uv = vec2(atan(direction.z, direction.x) / 6.2831853 + 0.5,
		asin(clamp(direction.y, -1.0, 1.0)) / 3.14159265 + 0.5);
	vec2 grid = sky_uv * vec2(1024.0, 512.0);
	vec2 cell = floor(grid);
	float seed = star_hash(cell);
	if (seed < 0.988) {
		return vec3(0.0);
	}
	vec2 point = vec2(star_hash(cell + 17.3), star_hash(cell + 83.7)) * 0.5 + 0.25;
	float radius = mix(0.07, 0.20, star_hash(cell + 47.1));
	float antialias = max(0.02, length(fwidth(grid)) * 0.35);
	float dot_light = 1.0 - smoothstep(radius, radius + antialias, distance(fract(grid), point));
	return mix(vec3(0.57, 0.72, 1.0), vec3(1.0, 0.90, 0.72), star_hash(cell + 11.9))
		* dot_light * night_amount * smoothstep(0.025, 0.10, direction.y);
}

float ring_line(vec2 p, float major_radius, float minor_scale) {
	float ellipse_radius = length(vec2(p.x / major_radius, p.y / (major_radius * minor_scale)));
	float edge = abs(ellipse_radius - 1.0);
	return 1.0 - smoothstep(0.014, 0.014 + max(fwidth(ellipse_radius), 0.0025), edge);
}

vec3 stylized_jupiter(vec2 surface, float radius_squared) {
	float latitude = surface.y;
	float longitude = surface.x;
	float ripple = sin(longitude * 3.2 + sin(latitude * 7.0) * 0.42) * 0.035;
	float bands = sin((latitude + ripple) * 38.0);
	vec3 deep_teal = vec3(0.16, 0.39, 0.46);
	vec3 pale_sand = vec3(0.80, 0.70, 0.53);
	vec3 warm_coral = vec3(0.64, 0.34, 0.27);
	vec3 base = mix(deep_teal, pale_sand, smoothstep(-0.28, 0.26, bands));
	base = mix(base, warm_coral, smoothstep(0.82, 0.98, sin(latitude * 15.0 + ripple * 20.0)) * 0.48);
	float contour = 1.0 - smoothstep(0.0, 0.075 + fwidth(latitude) * 2.0, abs(fract((latitude + ripple) * 15.0) - 0.5));
	base = mix(base, vec3(0.07, 0.16, 0.22), contour * 0.72);
	float radial = sqrt(radius_squared);
	float outline = smoothstep(0.925, 0.966, radial) * (1.0 - smoothstep(0.982, 1.0, radial));
	base = mix(base, vec3(0.045, 0.10, 0.15), outline);
	float storm_distance = length(vec2((longitude - 0.43) * 0.70, latitude + 0.31));
	float storm_outer = 1.0 - smoothstep(0.058, 0.073, storm_distance);
	float storm_inner = 1.0 - smoothstep(0.032, 0.047, storm_distance);
	base = mix(base, vec3(0.16, 0.10, 0.12), storm_outer);
	base = mix(base, vec3(0.83, 0.43, 0.30), storm_inner);
	return base;
}

vec3 distant_jupiter(vec3 direction, vec3 background) {
	vec3 center = normalize(jupiter_direction);
	vec3 right = normalize(cross(center, vec3(0.0, 1.0, 0.0)));
	vec3 up = cross(right, center);
	float center_depth = max(dot(direction, center), 0.0001);
	vec2 screen = vec2(dot(direction, right), dot(direction, up)) / center_depth / tan(jupiter_radius);
	float ring_angle = -0.24;
	vec2 rings = vec2(cos(ring_angle) * screen.x - sin(ring_angle) * screen.y,
		sin(ring_angle) * screen.x + cos(ring_angle) * screen.y);
	float ring_mask = 0.0;
	vec3 ring_color = vec3(0.35, 0.23, 0.19);
	float ring_1 = ring_line(rings, 1.28, 0.16);
	float ring_2 = ring_line(rings, 1.52, 0.17);
	float ring_3 = ring_line(rings, 1.90, 0.175);
	float ring_4 = ring_line(rings, 2.30, 0.18);
	float ring_5 = ring_line(rings, 2.80, 0.18);
	ring_mask = max(max(ring_1, ring_2), max(max(ring_3, ring_4), ring_5));
	float radius_squared = dot(screen, screen);
	float visible_sky = smoothstep(-0.035, 0.075, direction.y);
	float visible_rings = ring_mask * (1.0 - smoothstep(0.94, 1.03, radius_squared)) * visible_sky;
	vec3 ring_ink = mix(ring_color, vec3(0.72, 0.61, 0.49), night_amount * 0.72);
	vec3 result = mix(background, ring_ink, visible_rings * 0.96);
	if (dot(direction, center) > 0.0 && radius_squared < 1.0) {
		vec3 normal = vec3(screen, sqrt(max(0.0, 1.0 - radius_squared)));
		vec2 surface = vec2(atan(normal.x, normal.z), normal.y);
		vec3 planet = stylized_jupiter(surface, radius_squared);
		float horizon_haze = smoothstep(-0.025, 0.11, direction.y);
		float limb = smoothstep(0.0, 0.016, 1.0 - radius_squared);
		float visibility = mix(0.70, 0.95, night_amount) * limb * horizon_haze * visible_sky;
		result = mix(result, planet, visibility);
	}
	float haze_shape = exp(-dot(screen, screen) * 0.14) * visible_sky;
	vec3 haze_color = mix(vec3(0.91, 0.69, 0.51), vec3(0.38, 0.49, 0.64), night_amount);
	result = mix(result, haze_color, haze_shape * 0.10);
	return result;
}

void sky() {
	float elevation = clamp(EYEDIR.y * 0.5 + 0.5, 0.0, 1.0);
	float horizon = smoothstep(0.36, 0.94, elevation);
	vec3 day = mix(vec3(0.67, 0.82, 0.87), vec3(0.20, 0.48, 0.70), horizon);
	vec3 night = mix(vec3(0.055, 0.085, 0.14), vec3(0.012, 0.026, 0.075), horizon);
	vec3 color = mix(day, night, night_amount);
	vec3 dusk = mix(vec3(0.88, 0.40, 0.22), vec3(0.35, 0.43, 0.57), smoothstep(0.18, 0.85, elevation));
	vec3 background = mix(color, dusk, twilight_amount * (1.0 - night_amount));
	vec3 direction = normalize(EYEDIR);
	COLOR = distant_jupiter(direction, background + sky_stars(direction));
}
