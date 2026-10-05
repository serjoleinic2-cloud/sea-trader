shader_type canvas_item;

uniform float fade_start : hint_range(0.0, 1.0) = 0.04;
uniform float fade_end : hint_range(0.0, 1.0) = 0.48;

void fragment() {
	vec4 art = texture(TEXTURE, UV) * COLOR;
	art.a *= smoothstep(fade_start, fade_end, UV.x);
	COLOR = art;
}
