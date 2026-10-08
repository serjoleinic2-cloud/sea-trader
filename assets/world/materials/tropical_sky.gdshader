shader_type sky;

// Clear sky only. Procedural clouds are removed while gameplay is developed.
uniform float night_amount : hint_range(0.0, 1.0) = 0.0;
uniform float twilight_amount : hint_range(0.0, 1.0) = 0.0;

void sky() {
	float elevation = clamp(EYEDIR.y * 0.5 + 0.5, 0.0, 1.0);
	float horizon = smoothstep(0.36, 0.94, elevation);
	vec3 day = mix(vec3(0.67, 0.82, 0.87), vec3(0.20, 0.48, 0.70), horizon);
	vec3 night = mix(vec3(0.055, 0.085, 0.14), vec3(0.012, 0.026, 0.075), horizon);
	vec3 color = mix(day, night, night_amount);
	vec3 dusk = mix(vec3(0.88, 0.40, 0.22), vec3(0.35, 0.43, 0.57), smoothstep(0.18, 0.85, elevation));
	COLOR = mix(color, dusk, twilight_amount * (1.0 - night_amount));
}
