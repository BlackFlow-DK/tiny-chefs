shader_type spatial;
render_mode blend_add, unshaded, depth_draw_never, cull_disabled, shadows_disabled, fog_disabled;
// Fake daylight shaft from the window: additive sheets, UV.y runs 0 (window) -> 1 (counter),
// UV.x across the sheet. Faded at the sheet edges, along its length and at grazing angles.

uniform vec4 tint : source_color = vec4(1.0, 0.86, 0.62, 1.0);
uniform float strength = 0.05;

varying float wy;

void vertex() {
	wy = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y;
}

void fragment() {
	float across = smoothstep(0.0, 0.25, UV.x) * smoothstep(1.0, 0.75, UV.x);
	float along = smoothstep(0.0, 0.06, UV.y) * (1.0 - smoothstep(0.1, 0.55, UV.y));
	// Keep the play surface clear: the shaft only shows above the dispensers.
	along *= smoothstep(4.0, 10.0, wy);
	float facing = pow(abs(dot(NORMAL, VIEW)), 0.7);
	ALBEDO = tint.rgb * strength * across * along * facing;
}
