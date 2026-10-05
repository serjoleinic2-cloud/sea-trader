shader_type sky;


uniform float night_amount : hint_range(0.0, 1.0) = 0.0;
uniform float twilight_amount : hint_range(0.0, 1.0) = 0.0;

float hash3(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.yxz + 33.33);
	return fract((p.x + p.y) * p.z);
}

float value_noise(vec3 p) {
	vec3 i = floor(p);
	vec3 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	float x00 = mix(hash3(i), hash3(i + vec3(1.0, 0.0, 0.0)), f.x);
	float x10 = mix(hash3(i + vec3(0.0, 1.0, 0.0)), hash3(i + vec3(1.0, 1.0, 0.0)), f.x);
	float x01 = mix(hash3(i + vec3(0.0, 0.0, 1.0)), hash3(i + vec3(1.0, 0.0, 1.0)), f.x);
	float x11 = mix(hash3(i + vec3(0.0, 1.0, 1.0)), hash3(i + vec3(1.0, 1.0, 1.0)), f.x);
	return mix(mix(x00, x10, f.y), mix(x01, x11, f.y), f.z);
}

float cloud_fbm(vec3 p) {
	float sum = 0.0;
	float weight = 0.55;
	for (int octave = 0; octave < 4; octave++) {
		sum += value_noise(p) * weight;
		p = p * 2.03 + vec3(7.1, 3.7, 5.3);
		weight *= 0.5;
	}
	return sum / 0.966;
}

void sky() {
	float elevation = EYEDIR.y;
	vec3 direction = normalize(EYEDIR);
	vec3 cloud_position = direction * 2.15 + vec3(0.0, 1.9, 0.0);
	float broad = cloud_fbm(cloud_position * 2.2);
	float detail = cloud_fbm(cloud_position * 6.1 + vec3(5.7, 1.1, 2.8));
	float shaped = broad * 0.78 + detail * 0.22;
	float horizon_fade = smoothstep(-0.02, 0.16, elevation) * (1.0 - smoothstep(0.75, 0.98, elevation));
	float coverage = smoothstep(0.53, 0.66, shaped) * horizon_fade * (1.0 - smoothstep(0.03, 0.8, night_amount));
	float sunlight = max(dot(direction, normalize(LIGHT0_DIRECTION)), 0.0);
	vec3 cloud_color = mix(vec3(0.60, 0.72, 0.76), vec3(1.0, 0.98, 0.92), smoothstep(0.0, 0.7, sunlight));
	cloud_color = mix(cloud_color, vec3(0.86, 0.55, 0.40), twilight_amount * 0.48);
	cloud_color *= mix(1.0, 0.40, night_amount);
		float sky_elevation = clamp(EYEDIR.y * 0.5 + 0.5, 0.0, 1.0);
		vec3 day_top = vec3(0.20, 0.48, 0.70);
		vec3 day_horizon = vec3(0.67, 0.82, 0.87);
		vec3 night_top = vec3(0.012, 0.026, 0.075);
		vec3 night_horizon = vec3(0.055, 0.085, 0.14);
		vec3 sky_color = mix(day_horizon, day_top, smoothstep(0.36, 0.94, sky_elevation));
		vec3 night_color = mix(night_horizon, night_top, smoothstep(0.36, 0.94, sky_elevation));
		sky_color = mix(sky_color, night_color, night_amount);
		vec3 dusk_color = mix(vec3(0.88, 0.40, 0.22), vec3(0.35, 0.43, 0.57), smoothstep(0.18, 0.85, sky_elevation));
		sky_color = mix(sky_color, dusk_color, twilight_amount * (1.0 - night_amount));
		COLOR = mix(sky_color, cloud_color, coverage * 0.92);
}
