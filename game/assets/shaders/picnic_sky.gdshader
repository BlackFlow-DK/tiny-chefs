shader_type sky;
// Summer afternoon sky for the picnic: deep blue zenith to a warm pale horizon, soft cumulus puffs
// (static, so the radiance map is baked once), a warm sun disc + glow from the first directional
// light, and a hazy green-blue below the horizon (seen only past the far plane).

#include "res://assets/shaders/env_common.gdshaderinc"

uniform vec4 zenith : source_color = vec4(0.30, 0.55, 0.92, 1.0);
uniform vec4 horizon : source_color = vec4(0.70, 0.83, 0.95, 1.0);
uniform vec4 haze : source_color = vec4(0.98, 0.90, 0.76, 1.0);
uniform vec4 ground : source_color = vec4(0.52, 0.64, 0.50, 1.0);
uniform vec4 cloud_lit : source_color = vec4(1.0, 0.98, 0.94, 1.0);
uniform vec4 cloud_shade : source_color = vec4(0.72, 0.78, 0.88, 1.0);
uniform float cloud_cover = 0.5;

void sky() {
	vec3 d = EYEDIR;
	float h = d.y;
	vec3 col;
	if (h >= 0.0) {
		col = mix(horizon.rgb, zenith.rgb, pow(clamp(h, 0.0, 1.0), 0.4));
		// Warm haze towards the sun near the horizon.
		vec3 sd = normalize(LIGHT0_DIRECTION);   // points towards the sun
		float sun_side = max(dot(normalize(vec2(d.x, d.z) + 1e-4), normalize(vec2(sd.x, sd.z) + 1e-4)), 0.0);
		col = mix(col, haze.rgb, pow(1.0 - h, 14.0) * (0.25 + 0.4 * sun_side));
		// Clouds on a flat layer: puffy fbm with a lit top and shaded underside.
		vec2 uv = d.xz / (h + 0.08) * 0.9;
		float n = env_fbm(uv * 1.1 + vec2(3.0, 1.0));
		float n2 = env_fbm(uv * 2.7 + 9.0);
		float c = smoothstep(1.0 - cloud_cover, 1.0 - cloud_cover + 0.28, n * 0.8 + n2 * 0.3);
		float shade = smoothstep(0.3, 0.9, env_fbm(uv * 1.1 + vec2(3.25, 1.2)) * 0.8 + n2 * 0.3);
		vec3 cc = mix(cloud_shade.rgb, cloud_lit.rgb, clamp(shade * 1.2 - 0.1, 0.0, 1.0));
		float fade = smoothstep(0.02, 0.2, h);
		col = mix(col, cc, c * fade * 0.92);
		// Sun disc + glow.
		float sdot = max(dot(d, sd), 0.0);
		col += LIGHT0_COLOR * (pow(sdot, 900.0) * 6.0 + pow(sdot, 12.0) * 0.18) * (1.0 - c * 0.7);
	} else {
		col = mix(horizon.rgb * 0.95, ground.rgb, smoothstep(0.0, 0.08, -h));
	}
	COLOR = col;
}
