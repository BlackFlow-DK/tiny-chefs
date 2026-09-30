shader_type spatial;
// Glossy running-bond subway tiles with recessed grout and rounded (bevelled) tile edges, for a wall
// facing +Z. World-space XY, so any number of wall pieces line up seamlessly.

#include "res://assets/shaders/env_common.gdshaderinc"

uniform vec2 tile_size = vec2(3.6, 1.8);
uniform float grout = 0.13;
uniform float bevel = 0.35;
uniform vec4 tile_color : source_color = vec4(0.80, 0.89, 0.84, 1.0);
uniform vec4 grout_color : source_color = vec4(0.86, 0.85, 0.80, 1.0);

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = wpos.xy;
	float row = floor(p.y / tile_size.y);
	vec2 q = vec2(p.x + mod(row, 2.0) * 0.5 * tile_size.x, p.y);
	vec2 id = floor(q / tile_size);
	vec2 f = q - id * tile_size;
	vec2 e = min(f, tile_size - f);
	float edge = min(e.x, e.y);
	float g = grout * 0.5;
	float aa = fwidth(edge) + 1e-4;
	float tile_m = smoothstep(g - aa, g + aa, edge);
	vec2 dir = vec2(f.x < tile_size.x * 0.5 ? -1.0 : 1.0, f.y < tile_size.y * 0.5 ? -1.0 : 1.0);
	vec2 slope = vec2(
		dir.x * (1.0 - smoothstep(g, g + bevel, e.x)),
		dir.y * (1.0 - smoothstep(g, g + bevel, e.y)));
	float h = env_hash12(id);
	// Handmade waviness per tile so reflections break up a little.
	vec2 wob = vec2(env_vnoise(p * 0.7 + id * 3.1), env_vnoise(p * 0.7 + id * 5.7 + 9.0)) - 0.5;
	vec3 n_world = normalize(vec3((slope * 0.8 + wob * 0.06) * tile_m, 1.0));
	vec3 tc = tile_color.rgb * (0.965 + 0.05 * h);
	ALBEDO = mix(grout_color.rgb, tc, tile_m);
	ROUGHNESS = mix(0.85, 0.07 + 0.05 * h, tile_m);
	SPECULAR = 0.6;
	NORMAL = normalize((VIEW_MATRIX * vec4(n_world, 0.0)).xyz);
}
