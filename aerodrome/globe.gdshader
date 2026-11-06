shader_type spatial;

uniform vec3 ocean_color : source_color = vec3(0.05, 0.25, 0.55);
uniform vec3 line_color : source_color = vec3(0.6, 0.8, 1.0);
uniform float meridians = 24.0;  // 24 lines = one every 15 degrees

void fragment() {
	vec2 g = UV * vec2(meridians, meridians * 0.5);
	vec2 d = abs(fract(g - 0.5) - 0.5) / fwidth(g);
	float line = 1.0 - min(min(d.x, d.y), 1.0);
	ALBEDO = mix(ocean_color, line_color, line * 0.4);
	ROUGHNESS = 0.6;
}