shader_type spatial;
render_mode cull_disabled;
uniform vec4 tint : source_color = vec4(0.5, 0.5, 0.5, 1.0);
uniform float surface_kind = 0.0;
uniform float metallic_amount = 0.0;
varying vec3 local_at;
varying vec3 local_normal;
float hash(vec3 p) { return fract(sin(dot(p, vec3(127.1, 311.7, 74.7))) * 43758.5453); }
float noise(vec3 p) {
    vec3 i = floor(p); vec3 f = fract(p); f = f * f * (3.0 - 2.0 * f);
    return mix(mix(mix(hash(i), hash(i+vec3(1,0,0)), f.x), mix(hash(i+vec3(0,1,0)), hash(i+vec3(1,1,0)), f.x), f.y),
               mix(mix(hash(i+vec3(0,0,1)), hash(i+vec3(1,0,1)), f.x), mix(hash(i+vec3(0,1,1)), hash(i+vec3(1,1,1)), f.x), f.y), f.z);
}
void vertex() { local_at = VERTEX; local_normal = NORMAL; }
void fragment() {
    float broad = noise(local_at * 0.7);
    float grain = noise(local_at * 7.0);
    float variation = 0.86 + broad * 0.22 + grain * 0.06;
    if (surface_kind > 0.5 && surface_kind < 1.5) {
        variation += sin(local_at.y * 5.0 + noise(local_at * 0.5) * 5.0) * 0.045;
    } else if (surface_kind > 1.5 && surface_kind < 2.5) {
        variation = 0.75 + broad * 0.38 + grain * 0.10;
    } else if (surface_kind > 2.5 && surface_kind < 3.5) {
        float row = floor(local_at.z / 0.26);
        float edge = min(fract(local_at.z / 0.26), fract(local_at.x / 0.38 + mod(row, 2.0) * 0.5));
        variation *= mix(0.60, 1.0, smoothstep(0.0, 0.065, edge));
    } else if (surface_kind > 3.5 && surface_kind < 4.5) {
        variation += sin(local_at.x * 38.0 + local_at.z * 1.3 + grain * 2.0) * 0.055;
    } else if (surface_kind > 4.5) {
        vec2 wall = abs(local_normal.x) > abs(local_normal.z) ? local_at.zy : local_at.xy;
        float row = floor(wall.y / 0.5);
        float edge = min(fract(wall.y / 0.5), fract(wall.x / 1.0 + mod(row, 2.0) * 0.5));
        variation *= mix(0.78, 1.0, smoothstep(0.0, 0.035, edge));
    }
    ALBEDO = tint.rgb * variation;
    ROUGHNESS = 0.83;
    METALLIC = metallic_amount;
}
