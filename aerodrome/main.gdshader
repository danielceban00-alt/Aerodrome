shader_type sky;

float hash(vec3 p) {
	p = fract(p * 0.3183099 + 0.1);
	p *= 17.0;
	return fract(p.x * p.y * p.z * (p.x + p.y + p.z));
}

void sky() {
	vec3 dir = normalize(EYEDIR);
	vec3 col = vec3(0.01, 0.02, 0.05);
	vec3 p = dir * 180.0;
	vec3 id = floor(p);
	vec3 f = fract(p) - 0.5;
	if (hash(id) > 0.985) {
		float s = smoothstep(0.25, 0.0, length(f));
		col += vec3(s * (0.4 + 0.6 * hash(id + 7.0)));
	}
	COLOR = col;
}