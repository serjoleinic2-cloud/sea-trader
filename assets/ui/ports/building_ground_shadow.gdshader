shader_type canvas_item;
render_mode unshaded;

// Project the real sprite alpha onto the ground, away from the upper-right sun.
uniform float ground_y = 238.0;
uniform float shadow_opacity = 0.14;

void vertex() {
	float height_above_ground = ground_y - VERTEX.y;
	VERTEX.x -= height_above_ground * 0.65;
	VERTEX.y = ground_y - height_above_ground * 0.24;
}

void fragment() {
	vec2 step_uv = TEXTURE_PIXEL_SIZE * 2.0;
	float alpha = texture(TEXTURE, UV).a * 4.0;
	alpha += texture(TEXTURE, UV + vec2(step_uv.x, 0.0)).a;
	alpha += texture(TEXTURE, UV - vec2(step_uv.x, 0.0)).a;
	alpha += texture(TEXTURE, UV + vec2(0.0, step_uv.y)).a;
	alpha += texture(TEXTURE, UV - vec2(0.0, step_uv.y)).a;
	COLOR = vec4(0.025, 0.055, 0.065, alpha * shadow_opacity / 8.0);
}
