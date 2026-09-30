shader_type spatial;
// Kitchen worktop: warm speckled terrazzo in world space (triplanar by dominant axis), low contrast
// so food and chefs pop. Chips are anti-aliased with fwidth and the fine layer fades with distance.

#include "res://assets/shaders/env_common.gdshaderinc"

uniform vec4 base_color : source_color = vec4(0.79, 0.73, 0.64, 1.0);
uniform vec4 chip_a : source_color = vec4(0.80, 0.56, 0.46, 1.0);  // terracotta
uniform vec4 chip_b : source_color = vec4(0.63, 0.69, 0.60, 1.0);  // sage
uniform vec4 chip_c : source_color = vec4(0.60, 0.57, 0.54, 1.0);  // warm grey
uniform vec4 chip_d : source_color = vec4(0.93, 0.91, 0.86, 1.0);  // cream
uniform vec4 chip_e : source_color = vec4(0.40, 0.38, 0.38, 1.0);  // charcoal (rare)
uniform float chip_strength = 0.42;
uniform float cloud_strength = 0.07;
uniform float roughness_base = 0.6;

varying vec3 wpos;
varying vec3 wnrm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

vec3 palette(float h) {
	if (h < 0.26) return chip_a.rgb;
	if (h < 0.47) return chip_b.rgb;
	if (h < 0.76) return chip_c.rgb;
	if (h < 0.95) return chip_d.rgb;
	return chip_e.rgb;
}

// rgb = chip colour, a = coverage
vec4 chips(vec2 p, float cell, float rmin, float rmax, float density, float aa, float salt) {
	vec2 q = p / cell;
	vec2 g = floor(q);
	vec2 f = q - g;
	vec4 outc = vec4(0.0);
	for (int j = -1; j <= 1; j++) {
		for (int i = -1; i <= 1; i++) {
			vec2 o = vec2(float(i), float(j));
			vec2 id = g + o + salt;
			if (env_hash12(id * 1.37 + 11.0) > density) {
				continue;
			}
			vec2 d = (f - o - env_hash22(id)) * cell;
			float ang = env_hash12(id + 5.1) * 6.2831;
			float cs = cos(ang);
			float sn = sin(ang);
			d = vec2(cs * d.x - sn * d.y, sn * d.x + cs * d.y);
			d.x *= 1.0 + env_hash12(id + 9.7) * 0.7;
			float r = mix(rmin, rmax, env_hash12(id + 3.3));
			float dist = mix(length(d), max(abs(d.x), abs(d.y)) * 1.12, 0.45);
			float m = 1.0 - smoothstep(r - aa, r + aa, dist);
			if (m > outc.a) {
				outc = vec4(palette(env_hash12(id + 7.7)), m);
			}
		}
	}
	return outc;
}

void fragment() {
	vec3 an = abs(wnrm);
	vec2 p;
	if (an.y >= an.x && an.y >= an.z) {
		p = wpos.xz;
	} else if (an.x >= an.z) {
		p = wpos.zy + vec2(31.0, 0.0);
	} else {
		p = wpos.xy + vec2(0.0, 57.0);
	}
	float aa = length(fwidth(p)) * 0.7 + 0.004;
	float cloud = env_fbm(p * 0.09) - 0.5;
	float mottling = env_vnoise(p * 1.7) - 0.5;
	vec3 col = base_color.rgb * (1.0 + cloud * cloud_strength * 2.0 + mottling * 0.025);
	vec4 big = chips(p, 1.2, 0.08, 0.24, 0.45, aa, 0.0);
	float fine_fade = 1.0 - smoothstep(0.03, 0.09, aa);
	vec4 small = chips(p, 0.45, 0.035, 0.085, 0.62, aa, 41.0);
	col = mix(col, big.rgb, big.a * chip_strength);
	col = mix(col, small.rgb, small.a * chip_strength * 0.85 * fine_fade);
	// Fine sparkle speckle (quartz-like), fades out before it can shimmer.
	float sp = env_hash12(floor(p * 14.0));
	float speck = step(0.93, sp) * fine_fade * (1.0 - smoothstep(0.01, 0.03, aa));
	col = mix(col, col * 0.82, speck * 0.6);
	ALBEDO = col;
	ROUGHNESS = roughness_base - big.a * 0.12 + cloud * 0.08;
	SPECULAR = 0.38;
}
