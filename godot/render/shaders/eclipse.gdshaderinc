// Eclipse shadows cast by up to four spheres. Occluder centers and radii are given in units of
// the receiver's radius, relative to its center. The Sun is treated as a disk of angular radius
// sun_angular_radius, so the shadow has a physically sized umbra and penumbra.
uniform int eclipse_count = 0;
uniform vec4 eclipse_occluders[4];
uniform float eclipse_glow[4];
uniform float sun_angular_radius = 0.00465;

// Fraction of a unit disk covered by a disk of radius r at center distance d.
float covered_fraction(float r, float d) {
	if (d >= 1.0 + r) {
		return 0.0;
	}
	if (d <= abs(1.0 - r)) {
		return r >= 1.0 ? 1.0 : r * r;
	}
	float r_sq = r * r;
	float a1 = acos(clamp((d * d + 1.0 - r_sq) / (2.0 * d), -1.0, 1.0));
	float a2 = acos(clamp((d * d + r_sq - 1.0) / (2.0 * d * r), -1.0, 1.0));
	float kite = sqrt(max((-d + 1.0 + r) * (d + 1.0 - r) * (d - 1.0 + r) * (d + 1.0 + r), 0.0));
	return clamp((a1 + r_sq * a2 - 0.5 * kite) / PI, 0.0, 1.0);
}

// x: fraction of sunlight that reaches the point, y: light refracted by an occluder's atmosphere.
vec2 eclipse_light(vec3 point, vec3 light) {
	float transmitted = 1.0;
	float glow = 0.0;
	for (int index = 0; index < 4; index++) {
		if (index >= eclipse_count) {
			break;
		}
		vec4 occluder = eclipse_occluders[index];
		vec3 to_occluder = occluder.xyz - point;
		float distance_to = length(to_occluder);
		if (distance_to <= occluder.w || dot(to_occluder, light) <= 0.0) {
			continue;
		}
		vec3 direction = to_occluder / distance_to;
		float separation = atan(length(cross(direction, light)), dot(direction, light));
		float occluder_angle = asin(clamp(occluder.w / distance_to, 0.0, 1.0));
		float covered = covered_fraction(occluder_angle / sun_angular_radius, separation / sun_angular_radius);
		transmitted *= 1.0 - covered;
		glow = max(glow, covered * eclipse_glow[index]);
	}
	return vec2(transmitted, glow);
}
