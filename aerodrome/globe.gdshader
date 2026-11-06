shader_type spatial;

uniform sampler2D land_tex : source_color, filter_linear;
uniform vec3 ocean_color : source_color = vec3(0.04, 0.2, 0.45);

varying vec3 local_pos;

void vertex() {
	local_pos = VERTEX;
}

void fragment() {
	vec3 p = normalize(local_pos);
	float lon = atan(p.x, p.z);
	float lat = asin(clamp(p.y, -1.0, 1.0));
	vec2 uv = vec2(lon / TAU + 0.5, 0.5 - lat / PI);
	vec4 land = textureLod(land_tex, uv, 0.0);
	ALBEDO = mix(ocean_color, land.rgb, land.a);
	ROUGHNESS = 0.85;
}