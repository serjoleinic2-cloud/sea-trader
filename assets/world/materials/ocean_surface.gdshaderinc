
// Gerstner waves adapted from UnionBytes / Achim Menzel (2019), MIT.
// Godot 4 port and calm-ocean tuning: Sea Trader. See WATER_LICENSE.md.
// Wave parameters are supplied by OceanSurface on CPU.
uniform vec4 wave_a;
uniform vec4 wave_b;
uniform vec4 wave_c;
uniform float ocean_time = 0.0;
uniform float wave_time_scale = 0.42;
uniform sampler2D normal_a : hint_normal, repeat_enable, filter_linear_mipmap;
uniform sampler2D normal_b : hint_normal, repeat_enable, filter_linear_mipmap;
#ifdef WATER_REFRACTION
uniform sampler2D screen_texture : hint_screen_texture, repeat_disable, filter_linear;
#endif
uniform sampler2D depth_texture : hint_depth_texture, repeat_disable, filter_nearest;
uniform vec3 deep_water : source_color = vec3(0.025, 0.19, 0.25);
uniform vec3 shallow_water : source_color = vec3(0.22, 0.64, 0.51);
uniform float normal_strength = 0.24;
uniform float refraction_strength = 0.012;
varying vec3 ocean_world;
varying vec3 swell_normal;
varying float swell_height;

vec3 gerstner(vec4 wave, vec2 p, float t, inout vec3 tangent, inout vec3 binormal) {
	float k = 6.28318530718 / wave.w;
	vec2 d = normalize(wave.xy);
	float phase = k * (dot(d, p) - sqrt(9.8 / k) * t);
	float s = wave.z * sin(phase);
	float c = wave.z * cos(phase);
	tangent += vec3(-d.x * d.x * s, d.x * c, -d.x * d.y * s);
	binormal += vec3(-d.x * d.y * s, d.y * c, -d.y * d.y * s);
	float a = wave.z / k;
	return vec3(d.x * a * cos(phase), a * sin(phase), d.y * a * cos(phase));
}
vec3 surface_offset(vec2 p, float t, inout vec3 tangent, inout vec3 binormal) {
	vec3 offset = gerstner(wave_a, p, t, tangent, binormal);
	offset += gerstner(wave_b, p, t, tangent, binormal);
	offset += gerstner(wave_c, p, t, tangent, binormal);
	return offset;
}
float foam_noise(vec2 p) {
	p += vec2(sin(p.y * 0.71), cos(p.x * 0.63)) * 0.7;
	return 0.5 + 0.22 * sin(dot(p, vec2(1.17, 0.73)))
		+ 0.16 * cos(dot(p, vec2(-0.61, 1.43)) + sin(p.x * 0.31))
		+ 0.09 * sin(dot(p, vec2(1.91, -1.27)));
}
vec3 view_position(vec2 uv, mat4 inverse_projection) {
	float depth = textureLod(depth_texture, uv, 0.0).r;
	#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	vec3 ndc = vec3(uv, depth) * 2.0 - 1.0;
	#else
	vec3 ndc = vec3(uv * 2.0 - 1.0, depth);
	#endif
	vec4 position = inverse_projection * vec4(ndc, 1.0);
	return position.xyz / position.w;
}
void vertex() {
	// Dense near the ship, coarse towards the horizon, using a single grid.
	VERTEX.xz = sign(VERTEX.xz) * pow(abs(VERTEX.xz) / 1200.0, vec2(2.0)) * 1200.0;
	vec3 at = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec3 tangent = vec3(1.0, 0.0, 0.0);
	vec3 binormal = vec3(0.0, 0.0, 1.0);
	vec3 offset = surface_offset(at.xz, ocean_time * wave_time_scale, tangent, binormal);
	VERTEX += offset;
	NORMAL = normalize(cross(binormal, tangent));
	swell_normal = NORMAL;
	swell_height = offset.y;
	ocean_world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
	float t = ocean_time * wave_time_scale;
	vec3 world_normal = normalize(swell_normal);
	vec2 uv = ocean_world.xz * 0.075;
	vec3 a = texture(normal_a, uv + vec2(t * 0.019, -t * 0.013)).xyz * 2.0 - 1.0;
	vec3 b = texture(normal_b, uv * 1.83 + vec2(-t * 0.014, t * 0.021)).xyz * 2.0 - 1.0;
	vec2 detail = (a.xy * 0.68 + b.xy * 0.32) * normal_strength;
	world_normal = normalize(world_normal + vec3(detail.x, 0.0, detail.y));
	NORMAL = normalize((VIEW_MATRIX * vec4(world_normal, 0.0)).xyz);

	vec3 behind = view_position(SCREEN_UV, INV_PROJECTION_MATRIX);
	float thickness = VERTEX.z - behind.z;
	// Above-water hulls/decks occlude water, including at refraction edges.
	if (thickness < -0.015) { discard; }
	vec3 ground_world = (INV_VIEW_MATRIX * vec4(behind, 1.0)).xyz;
	float depth = max(0.0, ocean_world.y - ground_world.y);
	float shallow = exp(-depth * 0.38);
	vec3 tint = mix(deep_water, shallow_water, shallow);
	vec3 water_color = tint;
	// At depth transmission is negligible: avoid refraction lookups over the
	// open ocean, where they cannot contribute to the image.
	#ifdef WATER_REFRACTION
	if (thickness < 12.0) {
		vec2 refracted_uv = clamp(SCREEN_UV + NORMAL.xy * refraction_strength * smoothstep(0.0, 1.5, thickness), vec2(0.001), vec2(0.999));
		vec3 refracted_position = view_position(refracted_uv, INV_PROJECTION_MATRIX);
		if (refracted_position.z > VERTEX.z) { refracted_uv = SCREEN_UV; }
		vec3 ground_color = texture(screen_texture, refracted_uv).rgb;
		float transmission = exp(-max(thickness, 0.0) * 0.36) * 0.62;
		water_color = mix(tint, ground_color * vec3(0.65, 0.94, 0.87), transmission);
	}

	#endif
	float foam = 0.0;
	// Foam belongs to the shoreline only. Open-sea crest speckles produced
	// periodic blurry white patches, especially with the high/refraction shader.
	if (depth < 0.65) {
		float noise = foam_noise(ocean_world.xz * 1.2 + vec2(t * 0.12, -t * 0.09));
		float shore = 1.0 - smoothstep(0.06, 0.65, depth);
		float wash = smoothstep(0.32, 0.68, noise + sin(depth * 11.0 - t * 2.2) * 0.16);
		foam = clamp(shore * wash * 0.78, 0.0, 0.85);
	}
	ALBEDO = mix(water_color, vec3(0.88, 0.96, 0.93), foam);
	#ifdef WATER_REFRACTION
	ROUGHNESS = mix(0.16, 0.62, foam);
	#else
	ROUGHNESS = mix(0.26, 0.66, foam);
	#endif
	// Sky cubemap omits planet/moon/rings, retaining clean sky reflections.
	SPECULAR = 0.5;
	METALLIC = 0.0;
}
