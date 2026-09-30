shader_type spatial;
// Soapy water in the sink basin: glossy blue-grey water with static foam islands and a slow ripple.

#include "res://assets/shaders/env_common.gdshaderinc"

uniform vec4 water : source_color = vec4(0.52, 0.62, 0.66, 1.0);
uniform vec4 foam : source_color = vec4(0.97, 0.97, 0.96, 1.0);

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = wpos.xz;
	float f = env_fbm(p * 0.55 + 4.0);
	float bubbles = env_vnoise(p * 6.0);
	float fm = smoothstep(0.48, 0.56, f + bubbles * 0.08);
	vec2 rip = vec2(sin(p.x * 3.0 + TIME * 1.3), cos(p.y * 3.4 + TIME * 1.1)) * 0.04;
	vec3 n = normalize(vec3(rip.x, 1.0, rip.y));
	ALBEDO = mix(water.rgb, foam.rgb, fm);
	ROUGHNESS = mix(0.04, 0.7, fm);
	SPECULAR = 0.7;
	NORMAL = normalize((VIEW_MATRIX * vec4(mix(n, vec3(0.0, 1.0, 0.0), fm), 0.0)).xyz);
}
