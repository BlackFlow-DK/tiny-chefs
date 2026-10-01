shader_type spatial;
// Deep soapy water filling the double sink between the twin islands. Opaque (whatever falls in is
// gone), glossy blue-grey with drifting foam, a slow wind ripple, and drip rings under the tap
// (drip_pos / drip_t are driven from EnvIslands so they match the falling droplet).

#include "res://assets/shaders/env_common.gdshaderinc"

uniform vec4 water_deep : source_color = vec4(0.20, 0.34, 0.40, 1.0);
uniform vec4 water_shallow : source_color = vec4(0.40, 0.55, 0.60, 1.0);
uniform vec4 foam : source_color = vec4(0.96, 0.97, 0.97, 1.0);
uniform vec2 drip_pos = vec2(0.0, -9.0);   // world XZ under the spout
uniform float drip_t = 0.0;                // 0..1 since the last droplet landed
uniform vec4 bowl = vec4(-4.2, -15.0, 4.2, 14.6); // world x0, z0, x1, z1 (walls, for edge foam)

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

// fbm with a rotation per octave (no grid-aligned contours at sharp thresholds).
float rfbm(vec2 p) {
	float s = 0.0;
	float a = 0.5;
	mat2 r = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8));
	for (int i = 0; i < 5; i++) {
		s += a * env_vnoise(p);
		p = r * p * 2.07 + vec2(17.1, 9.2);
		a *= 0.5;
	}
	return s;
}

void fragment() {
	vec2 p = wpos.xz;
	// Distance to the nearest wall (and the divider at z = 0).
	float wall = min(min(p.x - bowl.x, bowl.z - p.x), min(p.y - bowl.y, bowl.w - p.y));
	wall = min(wall, abs(p.y));
	vec2 drift = vec2(TIME * 0.05, TIME * 0.03);
	float f = rfbm(p * 0.28 + drift + 4.0);
	float lace = rfbm(p * 2.4 - drift * 2.0);
	// A few drifting foam islands, a lacy fringe along the walls, bubbly holes inside the foam.
	float islands = smoothstep(0.62, 0.68, f + (lace - 0.5) * 0.14);
	float fringe = (1.0 - smoothstep(0.08, 0.5 + f * 0.9, wall)) * smoothstep(0.42, 0.55, lace);
	float fm = max(islands, fringe);
	fm *= 0.7 + 0.3 * smoothstep(0.3, 0.6, rfbm(p * 6.0 + drift * 5.0));
	// Ripples: two slow wave trains plus the drip rings.
	vec2 rip = vec2(sin(p.x * 2.1 + p.y * 0.7 + TIME * 1.4), cos(p.y * 2.6 - p.x * 0.5 + TIME * 1.1)) * 0.05;
	float dr = length(p - drip_pos);
	float ring_r = drip_t * 3.2;
	float ring = exp(-pow((dr - ring_r) * 5.0, 2.0)) * (1.0 - drip_t) * step(0.001, drip_t);
	float ring2 = exp(-pow((dr - ring_r * 0.55) * 6.0, 2.0)) * (1.0 - drip_t) * 0.6 * step(0.001, drip_t);
	vec2 rdir = dr > 0.001 ? (p - drip_pos) / dr : vec2(0.0);
	rip += rdir * (ring + ring2) * 0.35 * sin(dr * 14.0 - drip_t * 18.0);
	vec3 nrm = normalize(vec3(rip.x, 1.0, rip.y));
	float depth_tint = smoothstep(0.0, 3.0, wall);
	vec3 water = mix(water_shallow.rgb, water_deep.rgb, depth_tint * (0.7 + f * 0.3));
	ALBEDO = mix(water, foam.rgb, fm);
	ROUGHNESS = mix(0.03, 0.75, fm);
	SPECULAR = 0.75;
	NORMAL = normalize((VIEW_MATRIX * vec4(mix(nrm, vec3(0.0, 1.0, 0.0), fm), 0.0)).xyz);
}
