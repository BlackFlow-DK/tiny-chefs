shader_type spatial;
// Flat-woven runner rug on the floor far below: stripes across UV.x, woven texture, border.

#include "res://assets/shaders/env_common.gdshaderinc"

uniform vec4 col_a : source_color = vec4(0.72, 0.36, 0.26, 1.0);
uniform vec4 col_b : source_color = vec4(0.93, 0.86, 0.72, 1.0);
uniform vec4 col_c : source_color = vec4(0.23, 0.36, 0.42, 1.0);
uniform vec2 size = vec2(70.0, 22.0);

void fragment() {
	vec2 p = UV * size;
	vec2 e = min(p, size - p);
	float border = step(min(e.x, e.y), 1.6);
	float band = mod(floor(p.x / 3.0), 5.0);
	vec3 c = band < 2.0 ? col_a.rgb : (band < 4.0 ? col_b.rgb : col_c.rgb);
	float diamond = step(abs(fract(p.x / 6.0) - 0.5) + abs(p.y / size.y - 0.5) * 2.2, 0.35);
	c = mix(c, col_c.rgb, diamond * 0.8 * step(2.0, band) * step(band, 3.5));
	c = mix(c, col_c.rgb, border);
	float weave = 0.9 + 0.1 * sin(p.x * 18.0) * sin(p.y * 18.0) + (env_vnoise(p * 2.0) - 0.5) * 0.08;
	ALBEDO = c * weave;
	ROUGHNESS = 0.95;
	SPECULAR = 0.2;
}
