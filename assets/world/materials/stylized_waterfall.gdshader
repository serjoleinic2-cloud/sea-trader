shader_type spatial;
render_mode cull_disabled;
uniform vec4 tint : source_color = vec4(0.34,0.73,0.78,1.0);
void vertex() {
 VERTEX.x += sin(TIME * 1.7 + UV.y * 14.0) * 0.035 * UV.y;
}
void fragment() {
 float flow = UV.y * 27.0 + TIME * 2.5;
 float streak = smoothstep(0.45,0.92,sin(flow + sin(UV.x * 19.0) * 3.0));
 ALBEDO = mix(tint.rgb,vec3(0.90,0.98,0.96),streak * 0.48);
 ROUGHNESS = 0.32;
 EMISSION = ALBEDO * 0.06;
}
