shader_type spatial;
// Weathered honey-pine boards for the picnic table (planks, legs, benches). Grain runs along each
// board's LOCAL X (EnvPicnic builds every board as a box whose long side is local X); end faces show
// growth rings. Colour varies per board (seeded by its world origin); edges wear a little lighter.

#include "res://assets/shaders/env_common.gdshaderinc"

uniform vec4 wood_light : source_color = vec4(0.80, 0.60, 0.40, 1.0);
uniform vec4 wood_dark : source_color = vec4(0.60, 0.41, 0.25, 1.0);
uniform vec4 knot_color : source_color = vec4(0.40, 0.26, 0.16, 1.0);
uniform vec3 half_size = vec3(1.0);   // box half extents (local), for the worn edges

varying vec3 lpos;
varying vec3 lnrm;
varying float seed;

void vertex() {
	lpos = VERTEX;
	lnrm = NORMAL;
	vec3 o = MODEL_MATRIX[3].xyz;
	seed = env_hash12(o.xz * 0.37 + o.y * 0.11);
}

void fragment() {
	vec3 an = abs(lnrm);
	vec3 p = lpos + seed * 91.0;
	vec3 col;
	float rough = 0.78;
	if (an.x > an.y && an.x > an.z) {
		// End grain: rings around an off-centre pith.
		vec2 q = lpos.yz + vec2(seed * 3.0 - 1.5, -half_size.z * 1.6);
		float r = length(q) * 3.2 + env_fbm(q * 1.2) * 1.5;
		float ring = sin(r * 6.2831) * 0.5 + 0.5;
		col = mix(wood_dark.rgb * 0.9, wood_light.rgb * 0.95, ring * 0.6 + 0.2);
		rough = 0.9;
	} else {
		vec2 g = vec2(p.x * 0.05, (an.y > an.z ? p.z : p.y) * 1.3);
		float grain = env_fbm(g + vec2(0.0, seed * 7.0));
		float streak = env_fbm(vec2(p.x * 0.012, (an.y > an.z ? p.z : p.y) * 3.1) + 5.0);
		float lines = sin(((an.y > an.z ? p.z : p.y) * 5.0 + grain * 7.0) * 3.14159) * 0.5 + 0.5;
		float t = clamp(0.25 + seed * 0.45 + (grain - 0.5) * 0.6 + (streak - 0.5) * 0.5, 0.0, 1.0);
		col = mix(wood_dark.rgb, wood_light.rgb, t);
		col *= 0.93 + lines * 0.08;
		// A few knots.
		vec2 kq = vec2(p.x * 0.09, (an.y > an.z ? p.z : p.y) * 0.5);
		vec2 kc = floor(kq);
		vec2 kf = fract(kq) - (0.3 + 0.4 * env_hash22(kc + 3.0));
		float kd = length(kf * vec2(1.0, 1.6));
		float knot = (1.0 - smoothstep(0.03, 0.09, kd)) * step(0.72, env_hash12(kc + seed * 13.0));
		col = mix(col, knot_color.rgb, knot * 0.8);
		// Weathering: a soft grey wash in patches.
		float wx = env_fbm(p.xz * 0.06 + 11.0);
		col = mix(col, vec3(dot(col, vec3(0.33))) * 1.05, smoothstep(0.55, 0.8, wx) * 0.35);
	}
	// Worn, sun-bleached edges.
	vec3 e = half_size - abs(lpos);
	float edge = min(min(an.x > 0.5 ? 9.0 : e.x, an.y > 0.5 ? 9.0 : e.y), an.z > 0.5 ? 9.0 : e.z);
	col = mix(col * 1.12, col, smoothstep(0.02, 0.22, edge));
	ALBEDO = col;
	ROUGHNESS = rough;
	SPECULAR = 0.35;
}
