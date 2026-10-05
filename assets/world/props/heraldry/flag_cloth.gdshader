shader_type spatial;
render_mode cull_disabled;
uniform sampler2D emblem : source_color;
uniform vec4 cloth_color : source_color = vec4(0.05, 0.12, 0.2, 1.0);
void vertex() {
    float free_edge = clamp(VERTEX.x / 1.5, 0.0, 1.0);
    VERTEX.z += sin(TIME * 2.2 + VERTEX.x * 3.5) * 0.09 * free_edge;
}
void fragment() {
    vec4 crest = texture(emblem, UV);
    ALBEDO = mix(cloth_color.rgb, crest.rgb, crest.a);
    ROUGHNESS = 0.85;
}
