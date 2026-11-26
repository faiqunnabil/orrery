shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, fog_disabled;

uniform float size_scale = 1.0;
uniform float brightness = 1.0;

varying float intensity;

void vertex() {
	POINT_SIZE = max(UV.x * size_scale, 1.0);
	intensity = UV.y * brightness;
}

void fragment() {
	vec2 offset = POINT_COORD * 2.0 - 1.0;
	float falloff = exp(-dot(offset, offset) * 3.5);
	ALBEDO = COLOR.rgb * intensity;
	ALPHA = falloff;
}
