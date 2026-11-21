shader_type spatial;
render_mode unshaded, blend_mix, depth_draw_never, cull_disabled, fog_disabled;

const int MAX_BODIES = 24;

uniform vec4 bodies[MAX_BODIES];
uniform float softening[MAX_BODIES];
uniform int body_count = 0;
uniform float half_width = 1.0;
uniform float edge_potential = 0.0;
uniform float potential_scale = 1.0;
uniform float depth = 0.3;
uniform float line_count = 48.0;
uniform vec4 rim_color : source_color = vec4(0.35, 0.6, 1.0, 0.45);
uniform vec4 deep_color : source_color = vec4(0.75, 0.5, 1.0, 0.8);

varying float well_depth;
varying vec2 plane;

float potential(vec2 point) {
	float total = 0.0;
	for (int index = 0; index < MAX_BODIES; index++) {
		if (index >= body_count) {
			break;
		}
		vec3 offset = vec3(point.x, 0.0, point.y) - bodies[index].xyz;
		total += bodies[index].w / sqrt(dot(offset, offset) + softening[index] * softening[index]);
	}
	return total;
}

void vertex() {
	plane = VERTEX.xz;
	float excess = max(potential(VERTEX.xz * half_width) - edge_potential, 0.0) / potential_scale;
	well_depth = excess / (1.0 + excess);
	VERTEX.y = -well_depth * depth;
}

void fragment() {
	vec2 grid = plane * line_count * 0.5;
	vec2 width = fwidth(grid);
	vec2 distance_to_line = abs(fract(grid - 0.5) - 0.5) / max(width, vec2(1.0e-5));
	float line = 1.0 - min(min(distance_to_line.x, distance_to_line.y), 1.0);
	float rim = 1.0 - smoothstep(0.7, 1.0, length(plane));
	vec4 color = mix(rim_color, deep_color, well_depth);
	ALBEDO = color.rgb;
	ALPHA = line * color.a * rim;
}
