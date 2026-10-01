shader_type spatial;
// Lawn far below the picnic table, in world XZ: broad sunny/shady patches, darker clover clumps,
// faint mowing stripes, blade speckle close up and tiny white/yellow flower dots that fade out
// before they can shimmer. Soft rather than busy: it sits 29 m under the play area.

#include "res://assets/shaders/env_common.gdshaderinc"

uniform vec4 grass_a : source_color = vec4(0.42, 0.62, 0.25, 1.0);
uniform vec4 grass_b : source_color = vec4(0.30, 0.50, 0.20, 1.0);
uniform vec4 grass_dry : source_color = vec4(0.62, 0.66, 0.34, 1.0);
uniform vec4 clover : source_color = vec4(0.22, 0.42, 0.18, 1.0);
uniform float stripe_period = 26.0;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = wpos.xz;
	float aa = length(fwidth(p));
	float big = env_fbm(p * 0.008);
	float mid = env_fbm(p * 0.045 + 7.0);
	vec3 col = mix(grass_b.rgb, grass_a.rgb, smoothstep(0.3, 0.7, big));
	col = mix(col, grass_dry.rgb, smoothstep(0.62, 0.85, mid) * 0.45);
	float cl = env_fbm(p * 0.11 + 31.0);
	col = mix(col, clover.rgb, smoothstep(0.58, 0.72, cl) * 0.55);
	// Mowing stripes (along Z), fading with distance so they read as a soft pattern.
	float st = sin(p.x / stripe_period * 3.14159) * 0.5 + 0.5;
	col *= 0.95 + st * 0.08;
	// Blade speckle close up.
	float fine = 1.0 - smoothstep(0.05, 0.5, aa);
	float sp = env_vnoise(p * vec2(2.2, 3.1)) - 0.5;
	col *= 1.0 + sp * 0.22 * fine;
	// Flower dots (daisies white, buttercups yellow).
	vec2 cell = floor(p / 2.6);
	vec2 cc = (cell + 0.2 + 0.6 * env_hash22(cell)) * 2.6;
	float d = length(p - cc);
	float has = step(0.9, env_hash12(cell + 17.0)) * step(0.45, env_fbm(p * 0.02 + 3.0));
	float fl = (1.0 - smoothstep(0.28, 0.28 + aa, d)) * has * (1.0 - smoothstep(0.15, 0.6, aa));
	vec3 fc = env_hash12(cell + 5.0) < 0.7 ? vec3(0.97, 0.96, 0.9) : vec3(1.0, 0.85, 0.2);
	col = mix(col, fc, fl);
	ALBEDO = col;
	ROUGHNESS = 0.95;
	SPECULAR = 0.2;
}
