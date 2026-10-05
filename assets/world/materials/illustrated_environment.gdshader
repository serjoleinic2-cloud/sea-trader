shader_type spatial;
render_mode cull_disabled;
uniform vec4 tint : source_color = vec4(0.2, 0.35, 0.25, 1.0);
uniform float rock_surface = 0.0;
varying vec3 world_at;
void vertex() {
    world_at = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}
void fragment() {
    float broad = sin(world_at.x * 0.42 + sin(world_at.z * 0.31)) * sin(world_at.z * 0.27);
    float grain = sin(world_at.x * 9.0 + world_at.z * 5.0) * sin(world_at.y * 13.0 + world_at.z * 11.0);
    float layer = sin(world_at.y * 2.1 + sin(world_at.x * 0.21) * 0.8);
    ALBEDO = tint.rgb * (0.94 + broad * 0.085 + grain * 0.025 + rock_surface * layer * 0.075);
    ROUGHNESS = 0.92;
    SPECULAR = 0.15;
}
