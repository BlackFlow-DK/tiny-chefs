shader_type spatial;
// Honey-oak plank floor (world XZ, planks along X, staggered rows), seen far below the counter.

#include "res://assets/shaders/env_common.gdshaderinc"

uniform float plank_width = 4.2;
uniform float plank_length = 42.0;
uniform vec4 oak_light : source_color = vec4(0.78, 0.60, 0.40, 1.0);
uniform vec4 oak_dark : source_color = vec4(0.60, 0.42, 0.26, 1.0);
uniform vec4 gap_color : source_color = vec4(0.28, 0.19, 0.12, 1.0);

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = wpos.xz;
	float row = floor(p.y / plank_width);
	float x = p.x + env_hash12(vec2(row, 3.0)) * plank_length;
	float col_id = floor(x / plank_length);
	vec2 id = vec2(col_id, row);
	vec2 f = vec2(x - col_id * plank_length, p.y - row * plank_width);
	float edge = min(min(f.x, plank_length - f.x), min(f.y, plank_width - f.y));
	float aa = fwidth(edge) + 1e-4;
	float plank_m = smoothstep(0.06 - aa, 0.06 + aa, edge);
	float h = env_hash12(id + 0.5);
	vec3 wood = mix(oak_dark.rgb, oak_light.rgb, 0.35 + 0.65 * h);
	float grain = env_fbm(vec2(x * 0.06, p.y * 1.8) + id * 13.0);
	float rings = sin((p.y * 2.3 + grain * 6.0 + h * 20.0)) * 0.5 + 0.5;
	wood *= 0.88 + grain * 0.18 + rings * 0.05;
	ALBEDO = mix(gap_color.rgb, wood, plank_m);
	ROUGHNESS = mix(0.9, 0.42 + grain * 0.15, plank_m);
	SPECULAR = 0.45;
}
