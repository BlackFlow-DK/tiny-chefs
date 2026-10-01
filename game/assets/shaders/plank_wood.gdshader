shader_type spatial;
// Butcher-block cutting board used as the bridge plank: glued strips along X (local), long grain,
// a juice groove around the top, knife scores and wear in the walking lane, end grain on the X ends.
// Works in the plank node's local space (the plank is built axis-aligned around its centre).

#include "res://assets/shaders/env_common.gdshaderinc"

uniform vec2 half_size = vec2(5.2, 2.5);    // local half extents of the top (x along the board, z across)
uniform float strip_w = 0.72;
uniform vec4 wood_light : source_color = vec4(0.86, 0.66, 0.44, 1.0);
uniform vec4 wood_dark : source_color = vec4(0.62, 0.40, 0.23, 1.0);
uniform vec4 groove_color : source_color = vec4(0.40, 0.25, 0.14, 1.0);

varying vec3 lpos;
varying vec3 lnrm;

void vertex() {
	lpos = VERTEX;
	lnrm = NORMAL;
}

float sd_round_box(vec2 p, vec2 b, float r) {
	vec2 q = abs(p) - b + r;
	return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

vec3 strip_wood(vec2 p, out float grain) {
	float sid = floor((p.y + half_size.y) / strip_w);
	float h = env_hash12(vec2(sid, 7.0));
	vec3 wood = mix(wood_dark.rgb, wood_light.rgb, 0.3 + 0.7 * h);
	grain = env_fbm(vec2(p.x * 0.35 + h * 40.0, p.y * 11.0));
	float lines = sin(p.y * 40.0 + grain * 9.0 + h * 30.0) * 0.5 + 0.5;
	wood *= 0.86 + grain * 0.2 + lines * 0.06;
	// Glue seam between strips.
	float f = fract((p.y + half_size.y) / strip_w);
	float seam = min(f, 1.0 - f) * strip_w;
	wood = mix(wood * 0.72, wood, smoothstep(0.0, 0.035, seam));
	return wood;
}

void fragment() {
	vec3 n = normalize(lnrm);
	float grain = 0.0;
	vec3 col;
	float rough = 0.55;
	if (n.y > 0.6) {
		// Top.
		vec2 p = lpos.xz;
		col = strip_wood(p, grain);
		// Juice groove, a rounded rectangle 0.45 m in from the edge.
		float d = sd_round_box(p, half_size - vec2(0.45), 0.5);
		float g = 1.0 - smoothstep(0.05, 0.11, abs(d));
		col = mix(col, groove_color.rgb, g * 0.8);
		// Knife scores: short thin lines in random cells, denser in the middle lane.
		vec2 cell = floor(p * vec2(1.3, 2.2));
		vec2 hh = env_hash22(cell + 11.0);
		vec2 lp = fract(p * vec2(1.3, 2.2)) - 0.5;
		float ang = (hh.x - 0.5) * 2.4;
		vec2 dir = vec2(cos(ang), sin(ang));
		float along = dot(lp, dir);
		float across = abs(dot(lp, vec2(-dir.y, dir.x)));
		float score = (1.0 - smoothstep(0.0, 0.018, across)) * (1.0 - smoothstep(0.25, 0.4, abs(along))) * step(0.55, hh.y);
		score *= 1.0 - smoothstep(half_size.y - 0.9, half_size.y - 0.5, abs(p.y));
		col = mix(col, col * 0.62, score * 0.7);
		// Walked-in lighter lane down the middle, a little oiled sheen at the edges.
		float lane = 1.0 - smoothstep(0.6, 2.0, abs(p.y));
		col *= 1.0 + lane * 0.06 * (0.5 + env_vnoise(p * 1.7));
		rough = mix(0.42, 0.62, lane) + grain * 0.1;
	} else if (abs(n.x) > 0.6) {
		// End grain: growth rings per strip.
		float sid = floor((lpos.z + half_size.y) / strip_w);
		float h = env_hash12(vec2(sid, 7.0));
		vec2 c = vec2((sid + 0.5) * strip_w - half_size.y + (h - 0.5) * 0.3, -2.2 - h * 1.5);
		float r = length(vec2(lpos.z, lpos.y) - c);
		float rings = sin(r * 38.0 + env_vnoise(vec2(lpos.z, lpos.y) * 4.0) * 3.0) * 0.5 + 0.5;
		col = mix(wood_dark.rgb, wood_light.rgb, 0.25 + 0.5 * h) * (0.78 + rings * 0.16);
		float f = fract((lpos.z + half_size.y) / strip_w);
		col = mix(col * 0.7, col, smoothstep(0.0, 0.05, min(f, 1.0 - f) * strip_w));
		rough = 0.7;
	} else {
		// Long sides and bottom: the outer strip's face grain, running along X.
		float h = env_hash12(vec2(sign(lpos.z) + 3.0, 7.0));
		grain = env_fbm(vec2(lpos.x * 0.35 + h * 40.0, lpos.y * 9.0));
		float lines = sin(lpos.y * 30.0 + grain * 8.0 + h * 20.0) * 0.5 + 0.5;
		col = mix(wood_dark.rgb, wood_light.rgb, 0.25 + 0.6 * h) * (0.82 + grain * 0.2 + lines * 0.06);
		if (n.y < -0.6) {
			col *= 0.7;
		}
		rough = 0.6;
	}
	ALBEDO = col;
	ROUGHNESS = rough;
	SPECULAR = 0.4;
}
