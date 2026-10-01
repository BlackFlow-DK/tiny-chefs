shader_type spatial;
render_mode cull_disabled;
// Picnic cloth: soft rose gingham (checks where both stripe sets overlap, lighter where one does,
// cream elsewhere), a fine weave that fades with distance, faint fold creases and fabric mottling.
// Pattern coordinates come from UV2 = fabric metres (EnvPicnic builds the cloth with SurfaceTool), so
// the checks run on over the edge and down the drape like real cloth. Low contrast: food must pop.

#include "res://assets/shaders/env_common.gdshaderinc"

uniform float check = 4.2;                                  // m per stripe period (squares are half)
uniform vec4 cream : source_color = vec4(0.93, 0.89, 0.8, 1.0);
uniform vec4 red : source_color = vec4(0.84, 0.55, 0.51, 1.0);
uniform float single_mix = 0.45;                            // one stripe set: this far from cream to red
uniform float crease = 0.06;
uniform float relief = 0.22;                                // m: soft wrinkles (bump-mapped)

varying vec2 fab;

void vertex() {
	fab = UV2;
}

float stripe(float x, float aa) {
	float f = fract(x / check);
	float half_w = 0.25;
	float d = abs(f - 0.5) - half_w;   // < 0 inside the stripe
	return 1.0 - smoothstep(-aa, aa, d);
}

void fragment() {
	vec2 p = fab;
	float aa = max(fwidth(p.x), fwidth(p.y)) / check * 0.75 + 0.002;
	float sx = stripe(p.x, aa);
	float sy = stripe(p.y, aa);
	float both = sx * sy;
	float one = max(sx, sy) - both;
	vec3 col = cream.rgb;
	col = mix(col, mix(cream.rgb, red.rgb, single_mix), one);
	col = mix(col, red.rgb, both);
	// Weave: tiny cross threads, gone before they can shimmer.
	float fine = 1.0 - smoothstep(0.02, 0.06, aa * check);
	float weave = (sin(p.x * 38.0) * sin(p.y * 38.0)) * 0.5 + 0.5;
	col *= 1.0 - weave * 0.05 * fine;
	// Mottling + faint creases where the cloth was folded (every 10.5 m).
	float mott = env_fbm(p * 0.12) - 0.5;
	col *= 1.0 + mott * 0.07;
	vec2 cr = abs(fract(p / 10.5 + 0.5) - 0.5) * 10.5;
	float c = (1.0 - smoothstep(0.0, 0.35, cr.x)) + (1.0 - smoothstep(0.0, 0.35, cr.y));
	col *= 1.0 - c * crease * (0.6 + 0.4 * env_vnoise(p * 0.4));
	ALBEDO = col;
	// Soft fabric relief (height in metres -> bumped normal from screen derivatives).
	float hgt = (env_fbm(p * 0.16 + 4.0) + env_vnoise(p * 0.8) * 0.12) * relief - c * 0.04;
	vec3 dpdx = dFdx(VERTEX);
	vec3 dpdy = dFdy(VERTEX);
	vec3 r1 = cross(dpdy, NORMAL);
	vec3 r2 = cross(NORMAL, dpdx);
	float det = dot(dpdx, r1);
	vec3 grad = sign(det) * (dFdx(hgt) * r1 + dFdy(hgt) * r2);
	NORMAL = normalize(abs(det) * NORMAL - grad);
	ROUGHNESS = 0.92;
	SPECULAR = 0.25;
}
