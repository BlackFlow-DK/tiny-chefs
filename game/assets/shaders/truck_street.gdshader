shader_type spatial;
// The street outside the food truck's hatch (world space): kind 0 asphalt with a painted edge line and
// a gutter strip along the curb, kind 1 a concrete pavement of big slabs with seams, stains and a few
// darker replaced slabs. Soft cloud shadows drift across both (the only TIME use: a slow scroll).

#include "res://assets/shaders/env_common.gdshaderinc"

uniform int kind = 0;
uniform vec4 asphalt : source_color = vec4(0.30, 0.31, 0.33, 1.0);
uniform vec4 concrete : source_color = vec4(0.72, 0.70, 0.66, 1.0);
uniform vec4 line_col : source_color = vec4(0.95, 0.86, 0.45, 1.0);
uniform float curb_z = -22.0;      // the road ends here (towards -Z the pavement starts)
uniform float slab = 46.0;         // pavement slab size (m)
uniform float cloud_speed = 6.0;   // m/s the cloud shadows drift (+X)

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = wpos.xz;
	float aa = length(fwidth(p)) * 0.6 + 0.01;
	vec3 col;
	float r;
	if (kind == 0) {
		float n = env_fbm(p * 0.05);
		float g = env_vnoise(p * 1.7);
		col = asphalt.rgb * (0.88 + n * 0.22 + (g - 0.5) * 0.08);
		// Aggregate speckle (fades with distance).
		float sp = step(0.86, env_hash12(floor(p * 2.3)));
		col = mix(col, col * 1.35, sp * (1.0 - smoothstep(0.1, 0.4, aa)) * 0.5);
		// Gutter: a lighter concrete strip along the curb, then the yellow no-parking edge line.
		float gz = p.y - curb_z;          // > 0 on the road side
		float gutter = 1.0 - smoothstep(9.0, 9.0 + aa, gz);
		col = mix(col, concrete.rgb * 0.82, gutter);
		float ln = smoothstep(13.0 - aa, 13.0, gz) * (1.0 - smoothstep(16.0, 16.0 + aa, gz));
		float worn = smoothstep(0.35, 0.6, env_fbm(p * 0.12 + 4.0));
		col = mix(col, line_col.rgb, ln * (0.55 + 0.45 * worn));
		// Old patches and a damp darker stain.
		float patch_m = smoothstep(0.62, 0.64, env_fbm(p * 0.018 + 11.0));
		col *= 1.0 - patch_m * 0.12;
		r = 0.88 - patch_m * 0.1;
	} else {
		vec2 cell = floor(p / slab);
		vec2 f = (fract(p / slab) - 0.5) * slab;
		float edge = min(slab * 0.5 - abs(f.x), slab * 0.5 - abs(f.y));
		float seam = 1.0 - smoothstep(0.5, 0.9 + aa, edge);
		float h = env_hash12(cell);
		col = concrete.rgb * (0.94 + h * 0.1);
		if (h > 0.86) {
			col *= 0.86;   // a replaced, darker slab
		}
		col *= 0.92 + env_fbm(p * 0.09 + h * 13.0) * 0.16;
		// Stains (gum spots, a coffee splash) and fine grit.
		float stain = smoothstep(0.66, 0.7, env_fbm(p * 0.04 + 21.0));
		col *= 1.0 - stain * 0.1;
		float gum = step(0.993, env_hash12(floor(p * 0.6)));
		col = mix(col, col * 0.6, gum * 0.6);
		col *= 0.97 + env_vnoise(p * 2.1) * 0.06 * (1.0 - smoothstep(0.1, 0.4, aa));
		col = mix(col, col * 0.62, seam);
		r = 0.9;
	}
	// Drifting cloud shadows.
	vec2 cp = (p + vec2(TIME * cloud_speed, TIME * cloud_speed * 0.3)) * 0.0045;
	float cloud = smoothstep(0.48, 0.66, env_fbm(cp));
	col *= 1.0 - cloud * 0.32;
	ALBEDO = col;
	ROUGHNESS = r;
	SPECULAR = 0.3;
}
