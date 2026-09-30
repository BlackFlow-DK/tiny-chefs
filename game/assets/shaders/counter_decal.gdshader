shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_back, shadows_disabled;
// Flat non-colliding clutter on the counter, drawn on a PlaneMesh a hair above the top.
// kind 0 flour dusting, 1 mug/water ring, 2 water puddle, 3 warm sun patch (additive-looking),
// 4 soft contact shadow (dark gradient blob, used on the floor under the counter).

#include "res://assets/shaders/env_common.gdshaderinc"

uniform int kind = 0;
uniform vec4 tint : source_color = vec4(1.0);
uniform float opacity = 0.6;
uniform float seed = 0.0;
uniform vec2 stretch = vec2(1.0, 1.0);

void fragment() {
	vec2 uv = (UV * 2.0 - 1.0);
	float n = env_fbm(uv * 2.6 + seed * 7.13);
	float r = length(uv);
	float a = 0.0;
	ALBEDO = tint.rgb;
	ROUGHNESS = 0.9;
	if (kind == 0) {
		float edge = r + (n - 0.5) * 0.9;
		float mask = 1.0 - smoothstep(0.35, 0.85, edge);
		float grain = env_vnoise(uv * 40.0 + seed);
		a = mask * (0.55 + 0.45 * grain) * (0.6 + 0.4 * env_fbm(uv * 6.0 + seed));
		// A few stray flecks outside the main patch.
		float fl = step(0.965, env_hash12(floor(uv * 26.0) + seed)) * (1.0 - smoothstep(0.7, 1.0, r));
		a = max(a, fl * 0.8);
	} else if (kind == 1) {
		float rr = r + (n - 0.5) * 0.06;
		float ring = 1.0 - smoothstep(0.0, 0.07, abs(rr - 0.82));
		float gap = smoothstep(0.2, 0.5, env_vnoise(vec2(atan(uv.y, uv.x) * 2.0, seed)));
		a = ring * (0.4 + 0.6 * gap) + (1.0 - smoothstep(0.7, 0.85, rr)) * 0.12;
		ROUGHNESS = 0.3;
	} else if (kind == 2) {
		float edge = r + (n - 0.5) * 0.7;
		a = 1.0 - smoothstep(0.55, 0.62, edge);
		// small droplets around the puddle
		vec2 cell = floor(uv * 7.0);
		vec2 c = (cell + 0.2 + 0.6 * env_hash22(cell + seed)) / 7.0;
		float dr = length(uv - c);
		a = max(a, (1.0 - smoothstep(0.018, 0.03, dr)) * step(0.75, env_hash12(cell + seed + 3.0)) * (1.0 - smoothstep(0.8, 1.0, r)));
		ROUGHNESS = 0.03;
		SPECULAR = 0.8;
	} else if (kind == 3) {
		vec2 e = abs(uv);
		float box = (1.0 - smoothstep(0.55, 1.0, e.x)) * (1.0 - smoothstep(0.5, 1.0, e.y));
		a = box;
		EMISSION = tint.rgb * box * opacity * 0.6;
		ALBEDO = tint.rgb;
	} else {
		vec2 e = abs(uv);
		a = (1.0 - smoothstep(0.0, 1.0, e.y)) * (1.0 - smoothstep(0.85, 1.0, e.x));
		a = a * a;
		ALBEDO = vec3(0.0);
	}
	ALPHA = clamp(a * opacity, 0.0, 1.0);
}
