shader_type spatial;
// Food-truck sheet metal in world space (by dominant axis, like counter_terrazzo): brushed grain along
// one axis, optional panel seams with rivet rows, optional diamond tread plate. Used for the counter
// top (brushed stainless, no seams), the cabinet fronts, the painted wall panels (metal = 0) and the
// tread-plate backsplash / floor (kind 1). Deterministic (no TIME).

#include "res://assets/shaders/env_common.gdshaderinc"

uniform int kind = 0;                     // 0 brushed / painted sheet, 1 diamond tread plate
uniform vec4 base_color : source_color = vec4(0.74, 0.76, 0.78, 1.0);
uniform float metal = 0.75;
uniform float rough = 0.36;
uniform float grain = 0.06;               // brushed streak contrast
uniform float grain_axis = 0.0;           // 0 = grain along X (or Z on X-facing faces), 1 = along the vertical
uniform vec2 panel = vec2(0.0, 0.0);      // seam spacing (m) along (horizontal, vertical); 0 = no seams
uniform float rivet_step = 1.6;           // rivet spacing along seams (0 = no rivets)
uniform float smudge = 0.05;              // soft large-scale wear
uniform float tread_scale = 1.2;          // diamond pitch (m)

varying vec3 wpos;
varying vec3 wnrm;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wnrm = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

// Distance (m) to the nearest seam line of spacing s along one coordinate.
float seam_d(float x, float s) {
	if (s <= 0.0) return 1e3;
	float f = fract(x / s + 0.5) - 0.5;
	return abs(f) * s;
}

void fragment() {
	vec3 an = abs(wnrm);
	vec2 p;          // (horizontal, vertical) on walls; (x, z) on tops
	bool top = an.y >= an.x && an.y >= an.z;
	if (top) {
		p = wpos.xz;
	} else if (an.x >= an.z) {
		p = vec2(wpos.z, wpos.y);
	} else {
		p = vec2(wpos.x, wpos.y);
	}
	float aa = length(fwidth(p)) * 0.6 + 0.002;
	vec3 col = base_color.rgb;
	float r = rough;
	float m = metal;
	float h = 0.0;   // pseudo height for the normal tilt

	if (kind == 1) {
		// Diamond tread plate: raised lozenges in alternating directions on a slightly darker plate.
		vec2 q = p / tread_scale;
		vec2 g = floor(q);
		vec2 f = fract(q) - 0.5;
		float alt = mod(g.x + g.y, 2.0);
		vec2 d = alt < 0.5 ? vec2(f.x + f.y, f.x - f.y) : vec2(f.x - f.y, f.x + f.y);
		d *= 0.7071;
		float lz = length(vec2(d.x * 0.26, d.y)) ;
		float bump = 1.0 - smoothstep(0.055 - aa, 0.075 + aa, lz);
		col = mix(col * 0.82, col * 1.12, bump);
		r = mix(rough + 0.12, rough - 0.08, bump);
		h = bump;
		float speck = env_vnoise(p * 3.0) * env_vnoise(p * 11.0);
		col *= 0.93 + speck * 0.14;
	} else {
		// Brushed streaks: noise stretched hard along the grain direction.
		vec2 gp = grain_axis < 0.5 ? vec2(p.x * 0.6, p.y * 70.0) : vec2(p.x * 70.0, p.y * 0.6);
		float s = env_vnoise(gp) * 0.6 + env_vnoise(gp * vec2(3.1, 2.3) + 7.0) * 0.4;
		float fade = 1.0 - smoothstep(0.02, 0.08, aa);   // streaks fade before they can shimmer
		col *= 1.0 + (s - 0.5) * grain * 2.0 * fade;
		r += (s - 0.5) * 0.06 * fade;
		// Panel seams + rivets.
		float dx = seam_d(p.x, panel.x);
		float dy = seam_d(p.y, panel.y);
		float sd = min(dx, dy);
		float seam = 1.0 - smoothstep(0.04, 0.09 + aa, sd);
		float lip = (1.0 - smoothstep(0.09, 0.22 + aa, sd)) - seam;
		col = mix(col, col * 0.45, seam);
		col *= 1.0 + lip * 0.06;
		if (rivet_step > 0.0 && (panel.x > 0.0 || panel.y > 0.0)) {
			float rv = 0.0;
			// rivets along vertical seams (every rivet_step in y), offset 0.35 m off the seam
			if (panel.x > 0.0) {
				float fx = fract(p.x / panel.x + 0.5) - 0.5;
				float ox = (abs(fx) * panel.x - 0.35);
				float oy = (fract(p.y / rivet_step) - 0.5) * rivet_step;
				rv = max(rv, 1.0 - smoothstep(0.07, 0.11 + aa, length(vec2(ox, oy))));
			}
			if (panel.y > 0.0) {
				float fy = fract(p.y / panel.y + 0.5) - 0.5;
				float oy2 = (abs(fy) * panel.y - 0.35);
				float ox2 = (fract(p.x / rivet_step) - 0.5) * rivet_step;
				rv = max(rv, 1.0 - smoothstep(0.07, 0.11 + aa, length(vec2(ox2, oy2))));
			}
			col = mix(col, col * 1.18 + 0.03, rv);
			r = mix(r, r * 0.6, rv);
			h = max(h, rv);
		}
	}
	// Large soft wear / fingerprints.
	float w = env_fbm(p * 0.11 + 3.0) - 0.5;
	col *= 1.0 + w * smudge * 2.0;
	r += w * smudge;
	ALBEDO = clamp(col, vec3(0.0), vec3(1.0));
	METALLIC = m;
	ROUGHNESS = clamp(r, 0.05, 1.0);
	// Cheap bump: tilt the normal by the height gradient.
	vec2 gh = vec2(dFdx(h), dFdy(h));
	NORMAL = normalize(NORMAL + vec3(-gh.x, -gh.y, 0.0) * 0.6);
}
