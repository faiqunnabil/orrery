shader_type spatial;
render_mode unshaded, cull_back;

uniform sampler2D albedo_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D night_texture : source_color, filter_linear_mipmap, repeat_enable;
uniform sampler2D specular_texture : hint_default_black, filter_linear_mipmap, repeat_enable;
uniform sampler2D normal_texture : filter_linear_mipmap, repeat_enable;
uniform bool has_normal_texture = false;
uniform float normal_strength = 1.0;
uniform sampler2D ring_texture : source_color, filter_linear, repeat_disable;
uniform bool has_night_texture = false;
uniform vec4 tint : source_color = vec4(1.0);
uniform bool has_sun = true;
uniform vec3 sun_direction = vec3(1.0, 0.0, 0.0);
uniform float ambient = 0.04;
uniform float terminator_softness = 0.1;
uniform float night_strength = 1.3;
uniform bool full_detail = true;
uniform float relief_strength = 0.0;
uniform float max_relief_footprint = 8.0;
uniform bool has_specular_texture = false;
uniform vec3 specular_color : source_color = vec3(1.0, 0.94, 0.82);
uniform float specular_strength = 0.75;
uniform float shininess = 60.0;
uniform float sheen_strength = 0.12;
uniform float sheen_shininess = 6.0;
uniform bool has_ring_shadow = false;
uniform float ring_inner = 1.2;
uniform float ring_outer = 2.3;
uniform float ring_shadow_strength = 0.9;
uniform vec3 eclipse_glow_color : source_color = vec3(0.55, 0.16, 0.06);

#include "res://render/shaders/eclipse.gdshaderinc"

varying vec3 world_normal;
varying vec3 world_tangent;
varying vec3 world_binormal;
varying vec3 world_position;

void vertex() {
	world_normal = normalize(MODEL_NORMAL_MATRIX * NORMAL);
	world_tangent = normalize((MODEL_MATRIX * vec4(TANGENT, 0.0)).xyz);
	world_binormal = normalize((MODEL_MATRIX * vec4(BINORMAL, 0.0)).xyz);
	world_position = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float height_at(vec2 uv) {
	return dot(texture(albedo_texture, uv).rgb, vec3(0.299, 0.587, 0.114));
}

// Bump mapping with the albedo luminance as a height field. The finite-difference step
// widens with the screen-space texel footprint so distant bodies do not shimmer.
vec3 relief_normal(vec3 normal, vec2 uv) {
	vec2 texel = 1.0 / vec2(textureSize(albedo_texture, 0));
	float footprint = clamp(length(fwidth(uv) / texel), 1.0, max_relief_footprint);
	vec2 step_size = texel * footprint;
	float du = height_at(uv + vec2(step_size.x, 0.0)) - height_at(uv - vec2(step_size.x, 0.0));
	float dv = height_at(uv + vec2(0.0, step_size.y)) - height_at(uv - vec2(0.0, step_size.y));
	vec3 raw_tangent = world_tangent - normal * dot(normal, world_tangent);
	vec3 raw_binormal = world_binormal - normal * dot(normal, world_binormal);
	if (dot(raw_tangent, raw_tangent) < 1e-6 || dot(raw_binormal, raw_binormal) < 1e-6) {
		return normal;
	}
	vec3 tangent = normalize(raw_tangent);
	vec3 binormal = normalize(raw_binormal);
	float scale = relief_strength / footprint;
	return normalize(normal - scale * (du * tangent - dv * binormal));
}

// Tangent-space normal map baked from elevation data: x points east, y points north, z points up.
vec3 mapped_normal(vec3 normal, vec2 uv) {
	vec3 raw_tangent = world_tangent - normal * dot(normal, world_tangent);
	vec3 raw_binormal = world_binormal - normal * dot(normal, world_binormal);
	if (dot(raw_tangent, raw_tangent) < 1e-6 || dot(raw_binormal, raw_binormal) < 1e-6) {
		return normal;
	}
	vec3 local = texture(normal_texture, uv).rgb * 2.0 - 1.0;
	local.xy *= normal_strength;
	return normalize(normalize(raw_tangent) * local.x + normalize(raw_binormal) * local.y + normal * local.z);
}

// Ray from the surface point toward the Sun, intersected with the equatorial ring plane.
float ring_transmittance(vec3 light, mat4 model_matrix) {
	vec3 center = model_matrix[3].xyz;
	float radius = length(model_matrix[0].xyz);
	vec3 ring_normal = normalize(model_matrix[1].xyz);
	float facing = dot(light, ring_normal);
	if (abs(facing) < 1e-4) {
		return 1.0;
	}
	float distance_to_plane = dot(center - world_position, ring_normal) / facing;
	if (distance_to_plane <= 0.0) {
		return 1.0;
	}
	float ring_radius = length(world_position + light * distance_to_plane - center) / radius;
	float u = (ring_radius - ring_inner) / (ring_outer - ring_inner);
	if (u < 0.0 || u > 1.0) {
		return 1.0;
	}
	return 1.0 - texture(ring_texture, vec2(u, 0.5)).a * ring_shadow_strength;
}

void fragment() {
	vec3 albedo = texture(albedo_texture, UV).rgb * tint.rgb;
	vec3 normal = normalize(world_normal);
	vec3 light = normalize(sun_direction);
	vec3 shading_normal = normal;
	if (full_detail && has_normal_texture) {
		shading_normal = mapped_normal(normal, UV);
	} else if (full_detail && relief_strength > 0.0) {
		shading_normal = relief_normal(normal, UV);
	}
	float n_dot_l = dot(normal, light);
	float day = has_sun ? smoothstep(-terminator_softness, terminator_softness, n_dot_l) : 0.0;
	if (full_detail && has_ring_shadow && has_sun) {
		day *= ring_transmittance(light, MODEL_MATRIX);
	}
	vec2 eclipse = vec2(1.0, 0.0);
	if (full_detail && has_sun && eclipse_count > 0) {
		vec3 center = MODEL_MATRIX[3].xyz;
		eclipse = eclipse_light((world_position - center) / length(MODEL_MATRIX[0].xyz), light);
		day *= eclipse.x;
	}
	float lambert = clamp(dot(shading_normal, light), 0.0, 1.0);
	vec3 day_color = albedo * (0.25 + 0.75 * lambert);
	if (full_detail && has_specular_texture && has_sun) {
		vec3 view = normalize(CAMERA_POSITION_WORLD - world_position);
		vec3 half_vector = normalize(light + view);
		float n_dot_h = max(dot(normal, half_vector), 0.0);
		float fresnel = 0.02 + 0.98 * pow(1.0 - max(dot(view, half_vector), 0.0), 5.0);
		float glint = pow(n_dot_h, shininess) * specular_strength;
		float sheen = pow(n_dot_h, sheen_shininess) * sheen_strength;
		float water = texture(specular_texture, UV).r;
		day_color += specular_color * water * (glint + sheen) * mix(0.6, 1.0, fresnel) * clamp(n_dot_l, 0.0, 1.0);
	}
	vec3 night_color = albedo * ambient;
	if (has_night_texture) {
		night_color += texture(night_texture, UV).rgb * night_strength;
	}
	ALBEDO = mix(night_color, day_color, day) + albedo * eclipse_glow_color * eclipse.y * clamp(n_dot_l, 0.0, 1.0);
}
