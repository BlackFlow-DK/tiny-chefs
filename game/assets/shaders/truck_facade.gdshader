shader_type spatial;
// Building fronts across the pavement (seen through the food truck's hatch). Drawn on a quad facing
// +Z, patterned in world metres: a shopfront ground floor (shop window, door, sign band) and upper
// floors of windows in bays (frame, sill, sky-tinted glass, the odd blind or curtain) on brick or
// plaster. Deterministic (no TIME).

#include "res://assets/shaders/env_common.gdshaderinc"

uniform int kind = 0;                                  // 0 brick, 1 plaster
uniform vec4 wall : source_color = vec4(0.70, 0.38, 0.30, 1.0);
uniform vec4 trim : source_color = vec4(0.93, 0.90, 0.84, 1.0);
uniform vec4 sign_col : source_color = vec4(0.18, 0.36, 0.40, 1.0);
uniform vec4 frame_col : source_color = vec4(0.20, 0.22, 0.24, 1.0);
uniform float x0 = 0.0;            // building left edge (world x)
uniform float y0 = -40.0;          // street level (world y)
uniform float width = 200.0;
uniform float ground_h = 130.0;    // shopfront storey
uniform float floor_h = 100.0;     // upper storeys
uniform float bay_w = 50.0;
uniform float seed = 0.0;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float box_mask(vec2 p, vec2 lo, vec2 hi, float aa) {
	vec2 a = smoothstep(lo - aa, lo + aa, p) * (1.0 - smoothstep(hi - aa, hi + aa, p));
	return a.x * a.y;
}

void fragment() {
	vec2 p = vec2(wpos.x - x0, wpos.y - y0);
	float aa = length(fwidth(p)) * 0.7 + 0.05;
	vec3 col = wall.rgb;
	float r = 0.85;
	float spec = 0.3;
	if (kind == 0) {
		// Brick courses (2.4 m x 7.4 m at this scale) with mortar lines and per-brick tint.
		vec2 bq = vec2(p.x / 7.4 + 0.5 * mod(floor(p.y / 2.4), 2.0), p.y / 2.4);
		vec2 bc = floor(bq);
		vec2 bf = fract(bq);
		float mortar = 1.0 - smoothstep(0.0, 0.08 + aa * 0.1, min(min(bf.x, 1.0 - bf.x) * 7.4, min(bf.y, 1.0 - bf.y) * 2.4) - 0.25);
		col *= 0.86 + env_hash12(bc + seed) * 0.24;
		col = mix(col, vec3(0.78, 0.75, 0.7), mortar * (1.0 - smoothstep(0.3, 1.2, aa)) * 0.7);
	} else {
		col *= 0.93 + env_fbm(p * 0.03 + seed) * 0.12;
	}
	// Soot / weathering towards the bottom and under sills.
	col *= 0.9 + 0.1 * smoothstep(0.0, 300.0, p.y);

	if (p.y < ground_h) {
		// Shopfront: plinth, big window, door at one side, sign band on top.
		col = trim.rgb * 0.92;
		float band = smoothstep(ground_h - 26.0 - aa, ground_h - 26.0 + aa, p.y);
		col = mix(col, sign_col.rgb, band);
		// Lettering hint on the sign band: a row of pale dashes.
		float lx = fract(p.x / 14.0);
		float letters = band * step(ground_h - 19.0, p.y) * step(p.y, ground_h - 8.0) * step(0.25, lx) * step(lx, 0.8)
			* step(width * 0.22, p.x) * step(p.x, width * 0.78) * step(0.3, env_hash12(vec2(floor(p.x / 14.0), seed)));
		col = mix(col, trim.rgb, letters * 0.9);
		float door_x = mod(seed * 37.0, 1.0) < 0.5 ? 18.0 : width - 58.0;
		float win = box_mask(p, vec2(12.0, 14.0), vec2(width - 12.0, ground_h - 32.0), aa);
		float door = box_mask(p, vec2(door_x, 2.0), vec2(door_x + 40.0, ground_h - 32.0), aa);
		win *= 1.0 - door;
		float frame = box_mask(p, vec2(9.0, 11.0), vec2(width - 9.0, ground_h - 29.0), aa) - win;
		col = mix(col, frame_col.rgb, clamp(frame, 0.0, 1.0) * (1.0 - door));
		// Glass: dark inside with a sky reflection gradient and a diagonal sheen.
		vec3 glass = mix(vec3(0.08, 0.1, 0.12), vec3(0.42, 0.55, 0.65), smoothstep(14.0, ground_h - 32.0, p.y) * 0.7);
		glass += 0.12 * smoothstep(0.9, 1.0, sin((p.x + p.y) * 0.05 + seed));
		// Shop interior hints: shelves / warm light low in the window.
		glass += vec3(0.25, 0.17, 0.08) * (1.0 - smoothstep(14.0, 60.0, p.y)) * env_vnoise(vec2(p.x * 0.08, seed));
		col = mix(col, glass, win);
		vec3 door_col = mix(frame_col.rgb * 1.4, vec3(0.12, 0.14, 0.16), box_mask(p, vec2(door_x + 6.0, 8.0), vec2(door_x + 34.0, ground_h - 40.0), aa));
		col = mix(col, door_col, door);
		r = mix(r, 0.15, win);
		spec = mix(spec, 0.6, win);
	} else {
		// Upper storeys: one window per bay.
		float fy = p.y - ground_h;
		float storey = floor(fy / floor_h);
		vec2 lp = vec2(mod(p.x, bay_w), mod(fy, floor_h));
		float bays = floor(width / bay_w);
		float margin = (width - bays * bay_w) * 0.5;
		lp.x = mod(p.x - margin, bay_w);
		float inside_x = step(margin, p.x) * step(p.x, width - margin);
		vec2 wlo = vec2(bay_w * 0.24, floor_h * 0.2);
		vec2 whi = vec2(bay_w * 0.76, floor_h * 0.8);
		float win = box_mask(lp, wlo, whi, aa) * inside_x;
		float surround = box_mask(lp, wlo - 3.0, whi + vec2(3.0, 3.0), aa) * inside_x - win;
		float sill = box_mask(lp, vec2(wlo.x - 5.0, wlo.y - 5.0), vec2(whi.x + 5.0, wlo.y - 1.0), aa) * inside_x;
		col = mix(col, trim.rgb, clamp(surround + sill, 0.0, 1.0));
		float id = env_hash12(vec2(floor((p.x - margin) / bay_w), storey) + seed);
		vec3 glass = mix(vec3(0.12, 0.15, 0.19), vec3(0.5, 0.62, 0.72), smoothstep(wlo.y, whi.y, lp.y) * 0.8);
		// Glazing bars, a drawn blind or curtains in some windows.
		float bar = 1.0 - smoothstep(0.8, 1.6, abs(lp.x - bay_w * 0.5));
		bar = max(bar, 1.0 - smoothstep(0.8, 1.6, abs(lp.y - mix(wlo.y, whi.y, 0.62))));
		float blind = step(0.7, id) * step(mix(whi.y, wlo.y, fract(id * 7.3) * 0.7), lp.y);
		glass = mix(glass, vec3(0.88, 0.84, 0.74), blind);
		float curtain = step(0.45, id) * step(id, 0.6) * (1.0 - smoothstep(4.0, 7.0, min(lp.x - wlo.x, whi.x - lp.x)));
		glass = mix(glass, vec3(0.72, 0.3, 0.26), curtain);
		glass = mix(glass, frame_col.rgb * 1.6, bar);
		col = mix(col, glass, win);
		r = mix(r, 0.18, win * (1.0 - blind));
		spec = mix(spec, 0.55, win);
		// Cornice line between storeys.
		float cl = box_mask(vec2(0.0, mod(fy, floor_h)), vec2(-1.0, 0.0), vec2(1.0, 3.0), aa);
		col = mix(col, trim.rgb * 0.9, cl * 0.6);
	}
	ALBEDO = col;
	ROUGHNESS = r;
	SPECULAR = spec;
}
