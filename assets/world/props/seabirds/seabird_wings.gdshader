shader_type spatial;
render_mode cull_disabled;
void vertex() {
    VERTEX.y += sin(TIME * 5.0 + INSTANCE_CUSTOM.x * 6.28318) * abs(VERTEX.x) * 0.28 * INSTANCE_CUSTOM.y;
}
void fragment() {
    ALBEDO = mix(vec3(0.91, 0.91, 0.83), vec3(0.18, 0.22, 0.24), smoothstep(0.76, 1.0, UV.x));
    ROUGHNESS = 0.9;
}
