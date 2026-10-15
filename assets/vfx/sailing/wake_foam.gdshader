shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, world_vertex_coords;

uniform sampler2D atlas : source_color, filter_linear_mipmap, repeat_disable;
uniform vec4 wave_a;
uniform vec4 wave_b;
uniform vec4 wave_c;
uniform float wave_time_scale = 0.42;
uniform float ocean_time = 0.0;
uniform bool water_waves = true;
varying vec4 particle;

vec3 offset_at(vec4 wave, vec2 p) {
	float k = 6.2831853 / wave.w;
	vec2 d = normalize(wave.xy);
	float phase = k * (dot(d,p) - sqrt(9.8/k) * ocean_time * wave_time_scale);
	return vec3(d.x*cos(phase),sin(phase),d.y*cos(phase)) * (wave.z/k);
}
vec3 surface(vec2 p) { return offset_at(wave_a,p)+offset_at(wave_b,p)+offset_at(wave_c,p); }
void vertex() {
	particle = INSTANCE_CUSTOM;
	if (water_waves) {
		// Match the displaced ocean at the actual world coordinate, including
		// its horizontal Gerstner shift. Four cheap iterations per vertex.
		vec2 base = VERTEX.xz;
		for (int i=0;i<4;i++) { base=VERTEX.xz-surface(base).xz; }
		VERTEX.y = -0.18 + surface(base).y + 0.035;
	} else { VERTEX.y = -0.145; }
}
void fragment() {
	float frame = min(7.0,floor(particle.r*8.0));
	vec2 uv = vec2((clamp(UV.x,0.008,0.992)+frame)/8.0,UV.y);
	float mask = texture(atlas,uv).a;
	ALBEDO = vec3(0.83,0.94,0.91);
	ROUGHNESS = 1.0;
	SPECULAR = 0.0;
	ALPHA = mask*particle.g;
	if (ALPHA<0.015) { discard; }
}
