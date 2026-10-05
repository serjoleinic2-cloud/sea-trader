shader_type spatial;
render_mode cull_disabled, depth_draw_always;

uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_linear;
uniform vec3 deep_water : source_color = vec3(0.018, 0.17, 0.22);
uniform vec3 shallow_water : source_color = vec3(0.25, 0.68, 0.55);
uniform vec3 sky_reflection : source_color = vec3(0.48, 0.73, 0.78);
uniform vec3 twilight_reflection : source_color = vec3(0.95, 0.41, 0.18);
uniform float twilight_amount = 0.0;
// Four long, crossing swells keep the sea readable without becoming stormy.
uniform float wave_strength = 1.0;
uniform float crest_foam_strength = 0.42;
uniform float shore_foam_strength = 1.0;
uniform float wave_speed = 1.0;
uniform float ocean_time = 0.0;

varying vec3 ocean_at;

float grain(vec2 p) {
	return fract(sin(dot(p, vec2(127.1,311.7))) * 43758.5453);
}
float foam_noise(vec2 p) {
	// Warped, continuous bands avoid the checkerboard from interpolated cell noise.
	vec2 q = p + vec2(
		sin(p.y * 1.17 + cos(p.x * 0.63)) * 0.38,
		cos(p.x * 0.91 - sin(p.y * 0.72)) * 0.34
	);
	return 0.5
		+ 0.22 * sin(dot(q, vec2(1.17, 0.73)))
		+ 0.16 * cos(dot(q, vec2(-0.61, 1.43)) + sin(q.x * 0.31))
		+ 0.09 * sin(dot(q, vec2(1.91, -1.27)));
}

float wave_height(vec2 p, float t) {
	float a = dot(p, vec2(0.32, 0.11)) + t * 0.83;
	float b = dot(p, vec2(-0.19, 0.36)) + t * 0.67;
	float c = dot(p, vec2(0.57, -0.28)) + t * 1.02;
	float d = dot(p, vec2(-0.13, -0.43)) - t * 0.51;
	return (sin(a) * 0.14 + sin(b) * 0.075 + sin(c) * 0.035 + sin(d) * 0.025) * wave_strength;
}

void vertex() {
	// Concentrate existing vertices around the ship, rather than 4.7m-wide cells.
	VERTEX.xz = sign(VERTEX.xz) * pow(abs(VERTEX.xz) / 1200.0, vec2(2.0)) * 1200.0;
	vec3 world_pos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	VERTEX.y += wave_height(world_pos.xz, ocean_time * wave_speed);
	ocean_at = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float scene_depth = texture(depth_texture, SCREEN_UV).r;
	#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	vec3 ndc = vec3(SCREEN_UV, scene_depth) * 2.0 - 1.0;
	#else
	vec3 ndc = vec3(SCREEN_UV * 2.0 - 1.0, scene_depth);
	#endif
	vec4 scene_position = INV_PROJECTION_MATRIX * vec4(ndc, 1.0);
	scene_position.xyz /= scene_position.w;
	float raw_thickness = VERTEX.z - scene_position.z;
	// Depth reconstruction also rejects any ocean fragment behind an opaque deck.
	if (raw_thickness < -0.015) { discard; }
	float thickness = max(0.0, raw_thickness);
	float shallow = exp(-thickness * 0.21);
	vec2 p = ocean_at.xz;
	float t = ocean_time * wave_speed;
	float a = dot(p, vec2(0.32, 0.11)) + t * 0.83;
	float b = dot(p, vec2(-0.19, 0.36)) + t * 0.67;
	float c = dot(p, vec2(0.57, -0.28)) + t * 1.02;
	float d = dot(p, vec2(-0.13, -0.43)) - t * 0.51;
	vec2 slope = cos(a) * 0.14 * vec2(0.32, 0.11);
	slope += cos(b) * 0.075 * vec2(-0.19, 0.36);
	slope += cos(c) * 0.035 * vec2(0.57, -0.28);
	slope += cos(d) * 0.025 * vec2(-0.13, -0.43);
	slope *= wave_strength;
	// Fine, independently scrolling chop gives highlights texture without grid-like bands.
	slope += cos(dot(p, vec2(1.4, 0.8)) + t * 0.9) * vec2(0.035, 0.020);
	slope += cos(dot(p, vec2(-0.6, 1.7)) - t * 0.65) * vec2(-0.015, 0.043);
	float ripple = foam_noise(p*2.1+vec2(t*.17,-t*.08));
	slope += cos(dot(p, vec2(1.16, 0.77)) + t * 0.81) * vec2(0.018, 0.012);
	slope += cos(dot(p, vec2(-0.53, 1.45)) - t * 0.63) * vec2(-0.010, 0.021);
	NORMAL = normalize((VIEW_MATRIX * vec4(normalize(vec3(-slope.x, 1.0, -slope.y)), 0.0)).xyz);

	// World-space foam breakup avoids repeating square/diamond patterns.
	float noise = sin(dot(p, vec2(0.73, 1.19)) + t * 0.37) * 0.5;
	noise += sin(dot(p, vec2(-1.31, 0.47)) - t * 0.29) * 0.3;
	noise += cos(dot(p, vec2(1.87, -0.91)) + t * 0.19) * 0.2;
	float shoreline = 1.0 - smoothstep(0.18, 2.35, thickness);
	float shore_breakup = smoothstep(-0.68, 0.35, noise + sin(a) * 0.22 + sin(b * 1.3) * 0.12);
	float shore_foam = shoreline * shore_breakup * shore_foam_strength;
	float crest = sin(a) * 0.48 + sin(b) * 0.29 + sin(c) * 0.15 + sin(d) * 0.08;
	float crest_breakup = clamp(0.86 + noise * 0.12 + sin(b * 1.7) * 0.025 + cos(c * 1.9) * 0.025, 0.68, 1.0);
	float crest_width = max(fwidth(crest), 0.025);
	// Thin wind-torn streaks follow individual crests, not broad summed sine blobs.
	float streak = smoothstep(0.90-crest_width,0.99,sin(a));
	streak *= smoothstep(.40,.68,foam_noise(p*.85+vec2(-t*.15,t*.07)));
	streak += smoothstep(.94,.999,sin(b))*smoothstep(.58,.78,foam_noise(p*1.15-vec2(t*.12,0.0)))*.6;
	float crest_foam = streak * crest_foam_strength * smoothstep(.15,.65,ripple);
	float foam = clamp(max(shore_foam, crest_foam), 0.0, 0.86);

	vec3 color = mix(deep_water, shallow_water, shallow * 0.9);
	float fresnel = pow(1.0 - clamp(dot(normalize(NORMAL), normalize(VIEW)), 0.0, 1.0), 4.0);
	color = mix(color, sky_reflection, fresnel * 0.42);
	color = mix(color, vec3(0.92, 0.99, 0.96), foam);
	ALBEDO = mix(color, twilight_reflection, twilight_amount * 0.14);
	ROUGHNESS = mix(0.36, 0.70, foam);
	SPECULAR = 0.38;
	METALLIC = 0.0;
	ALPHA = mix(0.90, 1.0, 1.0 - shallow);
}
