shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_back;

uniform sampler2D cloud_texture : filter_linear_mipmap, repeat_enable;
uniform float opacity = 0.9;
uniform bool has_sun = true;
uniform vec3 sun_direction = vec3(1.0, 0.0, 0.0);
uniform float ambient = 0.03;
uniform float terminator_softness = 0.12;
uniform float night_opacity = 0.35;
uniform bool full_detail = true;

#include "res://render/shaders/eclipse.gdshaderinc"

varying vec3 world_normal;
varying vec3 world_position;

void vertex() {
	world_normal = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	float cover = texture(cloud_texture, UV).r;
	float n_dot_l = dot(normalize(world_normal), normalize(sun_direction));
	float day = has_sun ? smoothstep(-terminator_softness, terminator_softness, n_dot_l) : 0.0;
	if (full_detail && has_sun && eclipse_count > 0) {
		vec3 center = MODEL_MATRIX[3].xyz;
		day *= eclipse_light((world_position - center) / length(MODEL_MATRIX[0].xyz), normalize(sun_direction)).x;
	}
	float lambert = clamp(n_dot_l, 0.0, 1.0);
	ALBEDO = vec3(mix(ambient, 0.3 + 0.7 * lambert, day));
	ALPHA = cover * opacity * mix(night_opacity, 1.0, day);
}
