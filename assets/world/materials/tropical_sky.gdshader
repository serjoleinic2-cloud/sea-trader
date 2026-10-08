shader_type sky;

// Clear sky only. Procedural clouds are removed while gameplay is developed.
uniform float night_amount : hint_range(0.0, 1.0) = 0.0;
uniform float twilight_amount : hint_range(0.0, 1.0) = 0.0;
uniform sampler2D jupiter_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform vec3 jupiter_direction = vec3(0.0, -0.10, -1.0);
uniform float jupiter_radius : hint_range(0.05, 0.5) = 0.28;
uniform float jupiter_longitude : hint_range(0.0, 1.0) = 0.22;

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

vec3 distant_jupiter(vec3 direction, vec3 background) {
	vec3 center = normalize(jupiter_direction);
	vec3 right = normalize(cross(center, vec3(0.0, 1.0, 0.0)));
	vec3 up = cross(right, center);
	vec2 disc = vec2(dot(direction, right), dot(direction, up)) / sin(jupiter_radius);
	float radius_squared = dot(disc, disc);
	if (dot(direction, center) <= 0.0 || radius_squared >= 1.0 || direction.y <= 0.0) {
		return background;
	}
	vec3 normal = vec3(disc, sqrt(max(0.0, 1.0 - radius_squared)));
	vec2 surface_uv = vec2(
		atan(-normal.x, normal.z) / 6.2831853 + jupiter_longitude,
		0.5 + asin(clamp(normal.y, -1.0, 1.0)) / 3.14159265
	);
	vec3 surface = texture(jupiter_texture, surface_uv).rgb;
	float illumination = 0.30 + 0.70 * max(0.0, dot(normal, normalize(vec3(-0.45, 0.32, 0.92))));
	vec3 planet = surface * illumination * mix(1.0, 0.75, night_amount);
	float limb = smoothstep(0.0, 0.012, 1.0 - radius_squared);
	float horizon_haze = smoothstep(0.0, 0.065, direction.y);
	float visibility = mix(0.64, 0.94, night_amount) * limb * horizon_haze;
	return mix(background, planet, visibility);
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
