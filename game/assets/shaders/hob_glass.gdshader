shader_type spatial;
// Glass-ceramic hob panel (decoration, flat, walkable): black glossy glass with printed burner rings
// and one faintly warm ring. UV over the top face; ring centres in UV space.

uniform vec4 glass : source_color = vec4(0.05, 0.05, 0.06, 1.0);
uniform vec4 print_col : source_color = vec4(0.55, 0.55, 0.58, 1.0);
uniform vec2 size = vec2(8.0, 6.0);
uniform vec4 ring_a = vec4(-1.9, 0.9, 1.9, 0.0);   // x, z (metres from centre), radius, warm
uniform vec4 ring_b = vec4(2.0, -0.9, 1.5, 1.0);
uniform vec4 ring_c = vec4(-1.9, -1.9, 0.0, 0.0);

float ring(vec2 p, vec4 r, float aa) {
	if (r.z <= 0.0) return 0.0;
	float d = abs(length(p - r.xy) - r.z);
	float d2 = abs(length(p - r.xy) - r.z * 0.62);
	return max(1.0 - smoothstep(0.03, 0.03 + aa, d), (1.0 - smoothstep(0.02, 0.02 + aa, d2)) * 0.6);
}

float heat(vec2 p, vec4 r) {
	if (r.w <= 0.0) return 0.0;
	float d = length(p - r.xy) / r.z;
	float coil = 0.5 + 0.5 * sin(d * 30.0);
	return (1.0 - smoothstep(0.8, 1.0, d)) * smoothstep(0.1, 0.3, d) * (0.55 + 0.45 * coil) * r.w;
}

void fragment() {
	vec2 p = (UV - 0.5) * size;
	float aa = fwidth(p.x) * 1.5 + 1e-4;
	float pr = max(ring(p, ring_a, aa), max(ring(p, ring_b, aa), ring(p, ring_c, aa)));
	// Control marks along the front edge.
	vec2 m = vec2(mod(p.x + 0.3, 0.6) - 0.3, p.y - size.y * 0.5 + 0.45);
	pr = max(pr, (1.0 - smoothstep(0.07, 0.07 + aa, length(m))) * step(abs(p.x), 1.3));
	float h = heat(p, ring_b);
	ALBEDO = mix(glass.rgb, print_col.rgb, pr * 0.8);
	ROUGHNESS = mix(0.22, 0.45, pr);
	SPECULAR = 0.45;
	EMISSION = vec3(1.0, 0.25, 0.06) * h * 0.9;
}
