shader_type spatial;
render_mode cull_disabled, diffuse_lambert_wrap;
uniform sampler2D leaf_texture : source_color, filter_linear_mipmap;
void vertex() {
    vec3 at = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
    float gust = sin(TIME * 1.15 + at.x * 0.6 + at.z * 0.45);
    VERTEX.x += gust * 0.045 * UV.y;
    VERTEX.z += sin(TIME * 0.8 + at.z) * 0.02 * UV.y;
}
void fragment() {
    vec4 leaf = texture(leaf_texture, UV);
    if (leaf.a < 0.38) discard;
    ALBEDO = leaf.rgb;
    ROUGHNESS = 0.72;
    SPECULAR = 0.25;
}
