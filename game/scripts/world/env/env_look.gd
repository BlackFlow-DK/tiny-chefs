class_name EnvLook
extends RefCounted
## Lighting and atmosphere: warm key "window" sun with soft shadows tuned for 1 m chefs, cool fill,
## sky ambient, SSAO + SSIL, glow, filmic tonemap, depth haze that only starts past the play area,
## and a far-only depth of field. (A ReflectionProbe was tried: no visible gain, and it leaks
## texture RIDs at exit in 4.7.2.)

## Direction the key light travels (from the window side: left, high, a little from behind).
const SUN_DIR := Vector3(0.62, -0.72, 0.31)


static func build(root: Node3D) -> void:
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.68, 0.72, 0.78)
	sky_mat.sky_horizon_color = Color(0.94, 0.88, 0.80)
	sky_mat.ground_horizon_color = Color(0.8, 0.76, 0.7)
	sky_mat.ground_bottom_color = Color(0.5, 0.46, 0.42)
	sky_mat.sun_angle_max = 20.0
	var sky := Sky.new()
	sky.sky_material = sky_mat

	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_sky_contribution = 0.55
	env.ambient_light_color = Color(0.96, 0.88, 0.78)
	env.ambient_light_energy = 0.5
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.tonemap_exposure = 1.0
	env.tonemap_white = 6.0
	env.ssao_radius = 1.4
	env.ssao_intensity = 1.8
	env.ssao_power = 1.5
	env.ssao_detail = 0.7
	env.ssao_light_affect = 0.15
	env.ssil_radius = 6.0
	env.ssil_intensity = 0.8
	env.glow_enabled = true
	env.glow_intensity = 0.45
	env.glow_strength = 0.9
	env.glow_bloom = 0.02
	env.glow_hdr_threshold = 1.05
	env.fog_enabled = true
	env.fog_mode = Environment.FOG_MODE_DEPTH
	env.fog_light_color = Color(0.88, 0.82, 0.74)
	env.fog_density = 0.55
	env.fog_depth_begin = 48.0
	env.fog_depth_end = 240.0
	env.fog_depth_curve = 1.4
	env.fog_sky_affect = 0.0
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.06
	env.adjustment_contrast = 1.03
	var off := _debug_off()
	env.ssil_enabled = not off.has("ssil")
	env.ssao_enabled = not off.has("ssao")
	env.glow_enabled = not off.has("glow")
	env.fog_enabled = not off.has("fog")
	var we := WorldEnvironment.new()
	we.name = "Environment"
	we.environment = env
	# Far-only depth of field: the floor far below and the far room soften; the play area (< 45 m
	# from any gameplay camera) stays sharp. A camera with its own attributes (menu) overrides this.
	var attr := CameraAttributesPractical.new()
	attr.dof_blur_far_enabled = true
	attr.dof_blur_far_distance = 52.0
	attr.dof_blur_far_transition = 30.0
	attr.dof_blur_amount = 0.05
	if not off.has("dof"):
		we.camera_attributes = attr
	root.add_child(we)

	var sun := DirectionalLight3D.new()
	sun.name = "KeySun"
	sun.transform = Transform3D(Basis.looking_at(SUN_DIR.normalized(), Vector3.UP), Vector3.ZERO)
	sun.light_color = Color(1.0, 0.9, 0.76)
	sun.light_energy = 1.3
	sun.light_angular_distance = 0.8
	sun.shadow_enabled = true
	sun.shadow_bias = 0.03
	sun.shadow_normal_bias = 0.7
	sun.shadow_blur = 0.8
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	sun.directional_shadow_max_distance = 65.0
	sun.directional_shadow_split_1 = 0.3
	sun.directional_shadow_split_2 = 0.5
	sun.directional_shadow_split_3 = 0.72
	sun.directional_shadow_blend_splits = true
	root.add_child(sun)

	var fill := DirectionalLight3D.new()
	fill.name = "CoolFill"
	fill.transform = Transform3D(Basis.looking_at(Vector3(-0.35, -0.5, -0.8).normalized(), Vector3.UP), Vector3.ZERO)
	fill.light_color = Color(0.72, 0.82, 1.0)
	fill.light_energy = 0.32
	fill.light_specular = 0.15
	fill.shadow_enabled = false
	root.add_child(fill)


## Effects to leave off: agent A/B switch --env-off=ssil,ssao,glow,fog,dof, plus SSAO and SSIL under the Mobile
## renderer (it has neither; enabling them only prints warnings). The builders set ssao/ssil only from this.
static func _debug_off() -> PackedStringArray:
	var off := PackedStringArray()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--env-off="):
			off = arg.trim_prefix("--env-off=").split(",")
	if Quality.is_mobile_renderer():
		off.append_array(["ssao", "ssil"])
	return off
