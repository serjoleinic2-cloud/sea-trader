shader_type sky;

// Clear sky only. Procedural clouds are removed while gameplay is developed.
uniform float night_amount : hint_range(0.0, 1.0) = 0.0;
uniform float twilight_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec3 jupiter_direction = vec3(0.0, -0.10, -1.0);
uniform float jupiter_radius : hint_range(0.05, 0.5) = 0.30;

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

float ring_stone(vec2 p, float orbit_radius, float count, float seed, float size) {
	float radial = length(p);
	float angle = atan(p.y, p.x);
	float segment = floor(fract(angle / 6.2831853 + 0.5) * count);
	float random_value = star_hash(vec2(segment + seed * 31.0, seed + 7.0));
	float center_angle = ((segment + 0.18 + random_value * 0.64) / count - 0.5) * 6.2831853;
	float angle_delta = atan(sin(angle - center_angle), cos(angle - center_angle));
	float perspective = mix(0.56, 1.42, smoothstep(-0.68, 0.68, sin(angle)));
	float stone_size = size * mix(0.55, 1.3, random_value) * perspective;
	float tangent = angle_delta * orbit_radius;
	float stone_radial = radial - orbit_radius + (random_value - 0.5) * size * 0.5;
	vec2 stone = vec2(tangent, stone_radial) / max(stone_size, 0.001);
	float ax = abs(stone.x);
	float ay = abs(stone.y);
	float faceted_distance = max(max(ax, ay * 0.82), (ax + ay) * mix(0.62, 0.76, random_value));
	return (1.0 - smoothstep(0.66, 1.05, faceted_distance)) * step(random_value, 0.93);
}

vec3 distant_jupiter(vec3 direction, vec3 background) {
	vec3 center = normalize(jupiter_direction);
	vec3 right = normalize(cross(center, vec3(0.0, 1.0, 0.0)));
	vec3 up = cross(right, center);
	float center_depth = max(dot(direction, center), 0.0001);
	vec2 screen = vec2(dot(direction, right), dot(direction, up)) / center_depth / tan(jupiter_radius);
	float radius_squared = dot(screen, screen);
	float visible_sky = smoothstep(-0.025, 0.025, direction.y);
	float ring_angle = 0.785398;
	vec2 rings = vec2(cos(ring_angle) * screen.x + sin(ring_angle) * screen.y,
		(-sin(ring_angle) * screen.x + cos(ring_angle) * screen.y) / 0.70);
	float rocks_a = ring_stone(rings, 1.28, 22.0, 1.0, 0.040);
	float rocks_b = ring_stone(rings, 1.72, 29.0, 2.0, 0.033);
	float rocks_c = ring_stone(rings, 2.20, 36.0, 3.0, 0.026);
	float rocks_back = max(max(rocks_a, rocks_b), rocks_c) * step(rings.y, 0.0) * visible_sky;
	vec3 stone_color = mix(vec3(0.83, 0.89, 0.90), vec3(0.22, 0.27, 0.34), night_amount);
	vec3 result = mix(background, stone_color * 0.86, rocks_back * 0.92);
	float planet_hit = step(radius_squared, 1.0) * step(0.0, dot(direction, center)) * visible_sky;
	vec3 planet_color = mix(vec3(0.73, 0.84, 0.88), vec3(0.15, 0.20, 0.27), night_amount);
	float soft_shade = mix(0.94, 1.04, clamp(screen.x * 0.5 + 0.5, 0.0, 1.0));
	result = mix(result, planet_color * soft_shade, planet_hit);
	float rocks_front = max(max(rocks_a, rocks_b), rocks_c) * step(0.0, rings.y) * visible_sky;
	result = mix(result, stone_color, rocks_front * 0.94);
	float haze_shape = exp(-pow((direction.y - 0.025) * 9.0, 2.0)) * exp(-radius_squared * 0.10) * visible_sky;
	vec3 haze_color = mix(vec3(0.82, 0.89, 0.91), vec3(0.20, 0.27, 0.37), night_amount);
	result = mix(result, haze_color, haze_shape * 0.18);
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
