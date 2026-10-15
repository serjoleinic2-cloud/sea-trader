shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled;

uniform sampler2D atlas : source_color, filter_linear_mipmap, repeat_disable;
varying vec4 particle;
void vertex() {
	particle=INSTANCE_CUSTOM;
	vec3 scale=vec3(length(MODEL_MATRIX[0].xyz),length(MODEL_MATRIX[1].xyz),length(MODEL_MATRIX[2].xyz));
	// Only the little droplets face the viewer; foam stays flat on the sea.
	MODELVIEW_MATRIX=VIEW_MATRIX*mat4(INV_VIEW_MATRIX[0],INV_VIEW_MATRIX[1],INV_VIEW_MATRIX[2],MODEL_MATRIX[3]);
	VERTEX*=scale;
}
void fragment() {
	float frame=min(7.0,floor(particle.r*8.0));
	vec2 uv=vec2((clamp(UV.x,0.004,0.996)+frame)/8.0,UV.y);
	ALBEDO=vec3(0.87,0.96,0.95);
	ROUGHNESS=1.0;
	SPECULAR=0.0;
	ALPHA=texture(atlas,uv).a*particle.g;
	if(ALPHA<0.015){discard;}
}
