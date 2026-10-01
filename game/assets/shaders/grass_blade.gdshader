shader_type spatial;
render_mode cull_disabled;
// Lawn blades (EnvPicnic MultiMesh): dark at the root, sunlit at the tip, per-blade tint from
// INSTANCE_CUSTOM.rgb; normals bent towards up so blades shade like the lawn they stand in.

uniform vec4 root_color : source_color = vec4(0.16, 0.30, 0.11, 1.0);
uniform vec4 tip_color : source_color = vec4(0.55, 0.70, 0.30, 1.0);

varying vec3 tint;
varying float h;

void vertex() {
	tint = INSTANCE_CUSTOM.rgb;
	h = UV.y;
	NORMAL = normalize(mix(NORMAL, vec3(0.0, 1.0, 0.0), 0.75));
}

void fragment() {
	vec3 col = mix(root_color.rgb, tip_color.rgb, smoothstep(0.0, 1.0, h)) * tint * 1.6;
	ALBEDO = col;
	ROUGHNESS = 0.85;
	SPECULAR = 0.25;
	BACKLIGHT = vec3(0.25, 0.3, 0.1);
}
