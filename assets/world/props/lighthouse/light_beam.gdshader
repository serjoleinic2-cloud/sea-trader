shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
uniform float night_strength = 0.0;
void fragment() {
    float fade = pow(clamp(UV.y, 0.0, 1.0), 0.6);
    ALBEDO = vec3(0.95, 0.79, 0.48);
    EMISSION = ALBEDO * 0.5;
    ALPHA = night_strength * fade * 0.045;
}
