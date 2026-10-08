shader_type canvas_item;

// The race-specific base illustration remains intact. Each level adds one
// restrained luminous inlay, so all 30 upgrades have a distinct live look
// without shipping hundreds of near-duplicate PNG files.
uniform float building_level : hint_range(1.0, 30.0) = 1.0;
uniform vec4 faction_accent : source_color = vec4(0.30, 0.78, 1.0, 1.0);

void fragment() {
	vec4 art = texture(TEXTURE, UV) * COLOR;
	float level = clamp(building_level, 1.0, 30.0);
	float progress = (level - 1.0) / 29.0;
	float inlay = 0.0;
	float glint = 0.0;
	for (int i = 0; i < 29; i++) {
		float column = float(i % 6);
		float row = floor(float(i) / 6.0);
		vec2 center = vec2(0.235 + column * 0.106, 0.40 + row * 0.072);
		float radius = length((UV - center) * vec2(1.0, 1.28));
		float active = step(float(i) + 1.5, level);
		float gem = 1.0 - smoothstep(0.0045, 0.010, radius);
		float halo = 1.0 - smoothstep(0.010, 0.027, radius);
		inlay = max(inlay, gem * active);
		glint = max(glint, halo * active);
	}
	float seam = 1.0 - smoothstep(0.002, 0.008, abs(UV.y - (0.57 + abs(UV.x - 0.5) * 0.20)));
	float seam_strength = smoothstep(0.12, 0.76, progress) * seam * 0.17;
	vec3 light = faction_accent.rgb * (inlay * 0.55 + glint * 0.10 + seam_strength);
	art.rgb += light * art.a;
	COLOR = art;
}
