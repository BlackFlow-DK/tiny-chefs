shader_type spatial;
render_mode unshaded, shadows_disabled, fog_disabled;
// The view outside the kitchen window: soft daylight sky gradient, sun glow, two rows of hills
// and a few trees. HDR-bright so glow picks it up. UV (0,0) top-left.

#include "res://assets/shaders/env_common.gdshaderinc"

uniform vec4 sky_top : source_color = vec4(0.49, 0.70, 0.92, 1.0);
uniform vec4 sky_horizon : source_color = vec4(0.98, 0.91, 0.78, 1.0);
uniform vec4 hill_far : source_color = vec4(0.62, 0.76, 0.66, 1.0);
uniform vec4 hill_near : source_color = vec4(0.42, 0.62, 0.38, 1.0);
uniform float energy = 1.35;
uniform float aspect = 1.0;  // width / height

void fragment() {
	vec2 uv = vec2(UV.x * aspect, 1.0 - UV.y);
	float t = clamp((uv.y - 0.25) / 0.75, 0.0, 1.0);
	vec3 col = mix(sky_horizon.rgb, sky_top.rgb, pow(t, 0.8));
	vec2 sun = vec2(0.25 * aspect, 0.78);
	float sd = length(uv - sun);
	col += vec3(1.0, 0.9, 0.7) * (exp(-sd * 9.0) * 0.9 + exp(-sd * 2.5) * 0.18);
	// Soft clouds.
	float cl = env_fbm(vec2(uv.x * 2.2, uv.y * 7.0) + vec2(3.0, 1.0));
	col = mix(col, vec3(1.0, 0.98, 0.95), smoothstep(0.58, 0.78, cl) * smoothstep(0.45, 0.8, uv.y) * 0.6);
	float far_h = 0.33 + 0.06 * sin(uv.x * 3.1 + 1.0) + 0.03 * sin(uv.x * 7.3);
	float fw = fwidth(uv.y) + 1e-4;
	col = mix(col, hill_far.rgb, smoothstep(far_h + fw, far_h - fw, uv.y) * 0.85);
	float near_h = 0.2 + 0.07 * sin(uv.x * 2.2 + 4.0) + 0.02 * sin(uv.x * 11.0);
	// A few round trees on the near hill.
	for (int i = 0; i < 6; i++) {
		float fx = (float(i) + 0.5) / 6.0 * aspect + (env_hash12(vec2(float(i), 2.0)) - 0.5) * 0.3;
		float r = 0.035 + env_hash12(vec2(float(i), 5.0)) * 0.03;
		float hy = 0.2 + 0.07 * sin(fx * 2.2 + 4.0) + r * 0.8;
		float d = length((uv - vec2(fx, hy)) * vec2(1.0, 0.85));
		near_h = max(near_h, uv.y * step(d, r));
	}
	col = mix(col, hill_near.rgb * (0.9 + 0.2 * env_vnoise(uv * 30.0)), smoothstep(near_h + fw, near_h - fw, uv.y));
	ALBEDO = col * energy;
}
