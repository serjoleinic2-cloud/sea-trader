shader_type sky;

// Optional lightweight procedural sky clouds; disabled by default for performance.
uniform bool clouds_enabled = false;
uniform float night_amount : hint_range(0.0, 1.0) = 0.0;
uniform float twilight_amount : hint_range(0.0, 1.0) = 0.0;
uniform vec3 jupiter_direction = vec3(0.0, 0.06, -1.0);
uniform vec3 sun_direction = vec3(-0.4, 0.08, -1.0);
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

float cloud_hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float cloud_noise(vec2 p) {
	vec2 cell = floor(p);
	vec2 local = fract(p);
	local = local * local * (3.0 - 2.0 * local);
	float a = cloud_hash(cell);
	float b = cloud_hash(cell + vec2(1.0, 0.0));
	float c = cloud_hash(cell + vec2(0.0, 1.0));
	float d = cloud_hash(cell + vec2(1.0, 1.0));
	return mix(mix(a, b, local.x), mix(c, d, local.x), local.y);
}

vec3 sky_clouds(vec3 direction, vec3 background) {
	if (!clouds_enabled || direction.y < -0.01) {
		return background;
	}
	vec2 cloud_uv = direction.xz / max(direction.y + 0.20, 0.16) * 2.2;
	float density = cloud_noise(cloud_uv) * 0.58
		+ cloud_noise(cloud_uv * 2.03 + vec2(8.3, 2.1)) * 0.29
		+ cloud_noise(cloud_uv * 4.07 + vec2(3.7, 9.2)) * 0.13;
	float cover = smoothstep(0.49, 0.67, density) * smoothstep(-0.01, 0.10, direction.y);
	float daylight = (1.0 - night_amount * 0.96) * (1.0 - twilight_amount * 0.30);
	vec3 cloud_color = mix(vec3(0.42, 0.52, 0.62), vec3(0.96, 0.98, 1.0), smoothstep(0.53, 0.70, density));
	return mix(background, cloud_color, cover * daylight * 0.76);
}

float ring_dust(vec2 p) {
	float radius = length(p);
	float band = smoothstep(1.20, 1.24, radius) * (1.0 - smoothstep(1.78, 1.83, radius));
	float strands = 0.36 + 0.24 * sin(radius * 230.0);
	float gap = smoothstep(0.006, 0.014, abs(radius - 1.48));
	return band * strands * gap * 0.42;
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
	float dust = ring_dust(rings);
	float rocks_back = dust * step(rings.y, 0.0) * visible_sky;
	vec3 stone_color = mix(background + vec3(0.12, 0.13, 0.14), vec3(0.43, 0.50, 0.58), night_amount);
	vec3 result = mix(background, stone_color, rocks_back);
	float planet_hit = step(radius_squared, 1.0) * step(0.0, dot(direction, center)) * visible_sky;
	vec3 planet_normal = vec3(screen, sqrt(max(0.0, 1.0 - radius_squared)));
	vec3 key_light = normalize(vec3(-0.80, 0.28, -0.60));
	float illumination = smoothstep(-0.015, 0.16, dot(planet_normal, key_light));
	vec3 lit_color = mix(vec3(0.76, 0.86, 0.89), vec3(1.0, 0.77, 0.49), twilight_amount * 0.65);
	vec3 dark_color = background * mix(0.88, 0.45, max(night_amount, twilight_amount));
	vec3 planet_color = mix(dark_color, lit_color, illumination);
	float limb = pow(1.0 - sqrt(max(0.0, 1.0 - radius_squared)), 7.0) * illumination;
	planet_color += vec3(0.24, 0.48, 0.65) * limb * 0.3;
	result = mix(result, planet_color, planet_hit * 0.82);
	float rocks_front = dust * step(0.0, rings.y) * visible_sky;
	result = mix(result, stone_color, rocks_front * 0.94);
	float haze_shape = exp(-pow((direction.y - 0.025) * 9.0, 2.0)) * exp(-radius_squared * 0.10) * visible_sky;
	vec3 haze_color = mix(vec3(0.82, 0.89, 0.91), vec3(0.20, 0.27, 0.37), night_amount);
	result = mix(result, haze_color, haze_shape * 0.18);
	return result;
}

vec3 small_moon(vec3 direction, vec3 center, float radius, vec3 background) {
	center = normalize(center);
	vec3 right = normalize(cross(center, vec3(0.0, 1.0, 0.0)));
	vec3 up = cross(right, center);
	vec2 p = vec2(dot(direction, right), dot(direction, up)) / max(dot(direction, center), 0.001) / tan(radius);
	float r2 = dot(p, p);
	if (r2 > 1.0 || dot(direction, center) < 0.0 || direction.y < 0.0) { return background; }
	vec3 normal = vec3(p, sqrt(max(0.0, 1.0 - r2)));
	float light = smoothstep(0.0, 0.18, dot(normal, normalize(vec3(-0.8, 0.25, -0.25))));
	return mix(background, mix(background * 0.65, vec3(0.68, 0.83, 0.93), light), 0.75);
}

void sky() {
	vec3 direction = normalize(EYEDIR);
	float altitude = max(0.0, direction.y);
	float horizon = pow(clamp(altitude, 0.0, 1.0), 0.55);
	vec3 day = mix(vec3(0.67, 0.82, 0.87), vec3(0.16, 0.40, 0.65), horizon);
	vec3 night = mix(vec3(0.055, 0.085, 0.14), vec3(0.012, 0.026, 0.075), horizon);
	vec3 sun = normalize(sun_direction);
	float facing_sunset = pow(max(0.0, dot(normalize(vec3(direction.x, 0.001, direction.z)), normalize(vec3(sun.x, 0.001, sun.z)))), 3.0);
	float sunset_band = exp(-altitude * 5.0);
	vec3 dusk = mix(vec3(0.018, 0.042, 0.090), vec3(0.90, 0.19, 0.035), sunset_band);
	dusk = mix(dusk, vec3(1.0, 0.47, 0.11), exp(-altitude * 23.0) * facing_sunset * 0.8);
	vec3 background = mix(mix(day, night, night_amount), dusk, twilight_amount * (1.0 - night_amount * 0.55));
	background = sky_clouds(direction, background);
	float sun_alignment = dot(direction, sun);
	float solar_disc = smoothstep(cos(0.010), cos(0.007), sun_alignment) * smoothstep(-0.01, 0.012, direction.y);
	float glow = pow(max(0.0, sun_alignment), 190.0) * twilight_amount;
	background += vec3(1.0, 0.48, 0.13) * glow * 0.6;
	// A restrained camera glare appears only when the view faces the sun.
	// Keep it out of the radiance cubemap so it cannot create moving patches
	// on the ocean or brighten reflections when the sun is behind the camera.
	if (!AT_CUBEMAP_PASS) {
		float daylight = (1.0 - night_amount) * smoothstep(-0.015, 0.03, direction.y);
		float sun_beam = pow(max(0.0, sun_alignment), 42.0) * daylight;
		background += vec3(1.0, 0.86, 0.65) * sun_beam * 0.12;
	}
	background = mix(background, vec3(1.0, 0.91, 0.65) * 2.0, solar_disc);
	// Celestial artwork is a sky background, not blobs in the radiance cubemap.
	if (AT_CUBEMAP_PASS) {
		COLOR = background;
	} else {
		vec3 celestial = background + sky_stars(direction);
		celestial = small_moon(direction, vec3(0.45, 0.40, -1.0), 0.072, celestial);
		COLOR = distant_jupiter(direction, celestial);
	}
}
