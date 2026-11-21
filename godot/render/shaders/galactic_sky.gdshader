shader_type sky;

uniform sampler2D panorama : source_color, filter_linear, repeat_enable;
uniform mat3 render_to_galactic;

void sky() {
	vec3 galactic = render_to_galactic * EYEDIR;
	float longitude = atan(galactic.y, galactic.x);
	float latitude = asin(clamp(galactic.z, -1.0, 1.0));
	vec2 uv = vec2(fract(0.5 - longitude / TAU), 0.5 + latitude / PI);
	COLOR = textureLod(panorama, uv, 0.0).rgb;
}
