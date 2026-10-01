class_name QualityApply
extends RefCounted
## The one place a Quality preset reaches the renderer. Three parts:
##  - display(tree): root viewport (render scale + FSR1, MSAA, FXAA, mesh LOD), the directional shadow
##    atlas and filter, the SSAO quality, and (for real players only) vsync, frame cap and fullscreen.
##  - scene(root): a set Kitchen built (the World, or the menu diorama's root; Kitchen.build calls it and
##    tags the root "quality_scene"): its WorldEnvironment (SSAO/SSIL/glow/DOF), directional light shadows,
##    particles, picnic grass density and PicnicLife. Every value it changes is
##    remembered in node meta first, so switching back to High restores the map's own look exactly.
##  - node_added hook: particles created later (sizzle, fryer bubbles) follow the preset.
## apply_all(tree) re-runs everything live (SettingsView); "quality_listener" nodes get apply_quality().
## Probe: Auto's first-launch frame-time check (Main adds it when Quality.needs_probe()).

const META := &"quality_orig"
const SCENE_GROUP := &"quality_scene"
const LISTENER_GROUP := &"quality_listener"

static var _hooked := false


## Auto, first launch on this GPU: skips the first SETTLE_FRAMES frames (startup pipeline compiles stall
## them), then averages the frame rate over 2 s (the title screen with its live kitchen backdrop, at the
## detected preset). Under Quality.PROBE_MIN_FPS steps down one level. Saved, so it runs once per GPU.
class Probe extends Node:
	const SETTLE_FRAMES := 90
	const SPAN := 2.0
	var _settle := 0
	var _t := 0.0
	var _frames := 0

	func _process(delta: float) -> void:
		if _settle < SETTLE_FRAMES:
			_settle += 1
			return
		_t += delta
		_frames += 1
		if _t >= SPAN:
			var before := Quality.active_preset()
			var lvl := Quality.finish_probe(_frames / _t)
			if lvl != before:
				QualityApply.apply_all(get_tree())
			queue_free()


static func apply_all(tree: SceneTree) -> void:
	display(tree)
	for n in tree.get_nodes_in_group(SCENE_GROUP):
		scene(n)
	for n in tree.get_nodes_in_group(LISTENER_GROUP):
		n.call(&"apply_quality")


# ================================================================ display (global)

static func display(tree: SceneTree) -> void:
	var p := Quality.preset()
	var vp := tree.root
	var s := Quality.render_scale()
	vp.scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR if s < 0.999 and fsr_available() else Viewport.SCALING_3D_MODE_BILINEAR
	vp.scaling_3d_scale = s
	var msaa := int(p["msaa"])
	if msaa < 0:
		msaa = int(ProjectSettings.get_setting("rendering/anti_aliasing/quality/msaa_3d", Viewport.MSAA_2X))
	vp.msaa_3d = msaa as Viewport.MSAA
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if bool(p["fxaa"]) else Viewport.SCREEN_SPACE_AA_DISABLED
	vp.mesh_lod_threshold = float(p["lod_threshold"])
	var size := int(p["shadow_size"])
	if size <= 0:
		size = int(ProjectSettings.get_setting("rendering/lights_and_shadows/directional_shadow/size", 4096))
	RenderingServer.directional_shadow_atlas_set_size(size,
		bool(ProjectSettings.get_setting("rendering/lights_and_shadows/directional_shadow/16_bits", true)))
	var soft_dir := int(ProjectSettings.get_setting("rendering/lights_and_shadows/directional_shadow/soft_shadow_filter_quality", 2))
	var soft_pos := int(ProjectSettings.get_setting("rendering/lights_and_shadows/positional_shadow/soft_shadow_filter_quality", 2))
	var soft := bool(p["shadow_soft"])
	RenderingServer.directional_soft_shadow_filter_set_quality(
		(soft_dir if soft else RenderingServer.SHADOW_QUALITY_HARD) as RenderingServer.ShadowQuality)
	RenderingServer.positional_soft_shadow_filter_set_quality(
		(soft_pos if soft else RenderingServer.SHADOW_QUALITY_HARD) as RenderingServer.ShadowQuality)
	var q := int(p["ssao_quality"])
	if q < 0:
		q = int(ProjectSettings.get_setting("rendering/environment/ssao/quality", 2))
	RenderingServer.environment_set_ssao_quality(q as RenderingServer.EnvironmentSSAOQuality,
		bool(ProjectSettings.get_setting("rendering/environment/ssao/half_size", true)),
		float(ProjectSettings.get_setting("rendering/environment/ssao/adaptive_target", 0.5)),
		int(ProjectSettings.get_setting("rendering/environment/ssao/blur_passes", 2)),
		float(ProjectSettings.get_setting("rendering/environment/ssao/fadeout_from", 50.0)),
		float(ProjectSettings.get_setting("rendering/environment/ssao/fadeout_to", 300.0)))
	if not Quality.is_test_run() and DisplayServer.get_name() != "headless":
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if bool(Quality.get_value("vsync")) else DisplayServer.VSYNC_DISABLED)
		Engine.max_fps = int(Quality.get_value("fps_cap"))
		var want := Window.MODE_FULLSCREEN if bool(Quality.get_value("fullscreen")) else Window.MODE_WINDOWED
		var win := tree.root
		if (win.mode == Window.MODE_FULLSCREEN or win.mode == Window.MODE_EXCLUSIVE_FULLSCREEN) != (want == Window.MODE_FULLSCREEN):
			win.mode = want
	if not _hooked:
		_hooked = true
		tree.node_added.connect(_on_node_added)


## FSR1 upscaling exists only in Forward+ (Mobile warns and falls back).
static func fsr_available() -> bool:
	return RenderingServer.get_current_rendering_method() == "forward_plus"


# ================================================================ a built set

static func scene(root: Node) -> void:
	var p := Quality.preset()
	if not root.is_in_group(SCENE_GROUP):
		root.add_to_group(SCENE_GROUP)
	for we: WorldEnvironment in root.find_children("*", "WorldEnvironment", true, false):
		_environment(we, p)
	for l: DirectionalLight3D in root.find_children("*", "DirectionalLight3D", true, false):
		_sun(l, p)
	for n in root.find_children("*", "CPUParticles3D", true, false):
		_particles(n, p)
	for n in root.find_children("*", "GPUParticles3D", true, false):
		_particles(n, p)
	for mmi: MultiMeshInstance3D in root.find_children("Blades", "MultiMeshInstance3D", true, false):
		var mm := mmi.multimesh
		mm.visible_instance_count = -1 if float(p["grass"]) >= 1.0 else int(mm.instance_count * float(p["grass"]))
	for life in root.find_children("PicnicLife", "", true, false):
		if life.has_method(&"set_cheap"):
			life.call(&"set_cheap", str(p["life"]) == "cheap")


static func _environment(we: WorldEnvironment, p: Dictionary) -> void:
	var env := we.environment
	if env == null:
		return
	if not we.has_meta(META):
		we.set_meta(META, {"ssao": env.ssao_enabled, "ssil": env.ssil_enabled, "glow": env.glow_enabled,
			"attr": we.camera_attributes})
	var o: Dictionary = we.get_meta(META)
	env.ssao_enabled = bool(o["ssao"]) and bool(p["ssao"])
	env.ssil_enabled = bool(o["ssil"]) and bool(p["ssil"])
	env.glow_enabled = bool(o["glow"]) and bool(p["glow"])
	we.camera_attributes = o["attr"] if bool(p["dof"]) else null


static func _sun(l: DirectionalLight3D, p: Dictionary) -> void:
	if not l.has_meta(META):
		l.set_meta(META, {"shadow": l.shadow_enabled, "mode": l.directional_shadow_mode,
			"dist": l.directional_shadow_max_distance, "split1": l.directional_shadow_split_1})
	var o: Dictionary = l.get_meta(META)
	if not bool(o["shadow"]):
		return
	var splits := int(p["shadow_splits"])
	l.shadow_enabled = splits > 0
	match splits:
		1:
			l.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
			l.directional_shadow_max_distance = minf(float(o["dist"]), 50.0)
		2:
			l.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_2_SPLITS
			l.directional_shadow_max_distance = float(o["dist"])
			l.directional_shadow_split_1 = float(o["split1"])
		_:
			l.directional_shadow_mode = o["mode"]
			l.directional_shadow_max_distance = float(o["dist"])
			l.directional_shadow_split_1 = float(o["split1"])


static func _particles(n: Node, p: Dictionary) -> void:
	if not n.has_meta(META):
		n.set_meta(META, int(n.get(&"amount")))
	var want := maxi(1, roundi(int(n.get_meta(META)) * float(p["particles"])))
	if int(n.get(&"amount")) != want:
		n.set(&"amount", want)


static func _on_node_added(n: Node) -> void:
	if n is CPUParticles3D or n is GPUParticles3D:
		_particles(n, Quality.preset())
