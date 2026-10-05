extends Node3D
## Dev scene (scenes/dev/icon_shot.tscn): renders the app-icon subjects (transparent background, 1024x1024)
## from the real chef and food models; scripts/dev/make_icons.py composites them onto tiles (docs/itch/icon/).
##   godot --path game --windowed --resolution 1024x1024 res://scenes/dev/icon_shot.tscn -- --ic-dir=<abs dir> [--ic-shot=a]
## Shots: a = chef head close-up, b = chef holding a giant tomato, c = two chefs carrying a giant patty.

const SHOTS := {
	"a": {"pos": Vector3(0.0, 1.0, 3.6), "look": Vector3(0, 0.95, 0), "fov": 22.0, "chefs": [
		{"p": Vector3(0, 0, 0), "yaw": 0, "slot": 1, "hat": "toque"}]},
	"b": {"pos": Vector3(0.0, 2.9, 13.5), "look": Vector3(-0.1, 1.4, 0), "fov": 30.0, "chefs": [
		{"p": Vector3(-1.7, 0, 3.2), "yaw": 20, "sc": 1.9, "slot": 1, "hat": "toque", "carry": true}],
		"props": [
			{"m": "bun_bottom", "p": Vector3(0.9, 0.0, 0), "s": 1.0},
			{"m": "patty_cooked", "p": Vector3(0.9, 0.7, 0), "s": 1.0},
			{"m": "cheese_slice", "p": Vector3(0.9, 1.3, 0), "s": 1.0},
			{"m": "lettuce_leaf", "p": Vector3(0.9, 1.45, 0), "s": 1.0},
			{"m": "tomato_slice", "p": Vector3(0.9, 1.72, 0), "s": 1.0},
			{"m": "bun_top", "p": Vector3(0.9, 1.92, 0), "s": 1.0}]},
	"c": {"pos": Vector3(0.0, 6.5, 12.0), "look": Vector3(0, 0.9, 0), "fov": 30.0, "chefs": [
		{"p": Vector3(-2.7, 0, 0.6), "sc": 2.3, "yaw": 65, "slot": 0, "hat": "toque", "carry": true},
		{"p": Vector3(2.7, 0, 0.6), "sc": 2.3, "yaw": -65, "slot": 3, "hat": "toque", "carry": true}],
		"props": [{"m": "patty_cooked", "p": Vector3(0, 0.9, 0.0), "s": 1.25, "rot": Vector3(8, 0, 0)}]},
}


func _ready() -> void:
	var out_dir := Net.arg_str("ic-dir", "")
	var only := Net.arg_str("ic-shot", "")
	for k in SHOTS.keys():
		if only != "" and only != k:
			continue
		await _render(k, SHOTS[k], out_dir)
	get_tree().quit(0)


func _render(key: String, shot: Dictionary, out_dir: String) -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(2048, 2048)
	vp.own_world_3d = true
	vp.transparent_bg = true
	vp.msaa_3d = Viewport.MSAA_8X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var rect := TextureRect.new()
	rect.texture = vp.get_texture()
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var layer := CanvasLayer.new()
	layer.add_child(rect)
	add_child(layer)
	add_child(vp)
	var root := Node3D.new()
	vp.add_child(root)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(1, 0.96, 0.9)
	env.ambient_light_energy = 0.75
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 25, 0)
	sun.light_energy = 1.1
	sun.shadow_enabled = false
	root.add_child(sun)
	var cam := Camera3D.new()
	root.add_child(cam)
	cam.current = true
	cam.fov = float(shot["fov"])
	cam.position = shot["pos"]
	cam.look_at(shot["look"], Vector3.UP)
	for spec in shot["chefs"]:
		var slot := int(spec["slot"])
		var c := Chef.new()
		c.setup(100 + slot, slot, "Chef", true, false)
		root.add_child(c)
		c.position = spec["p"]
		c.scale = Vector3.ONE * float(spec.get("sc", 1.0))
		c.rotation.y = deg_to_rad(float(spec.get("yaw", 0.0)))
		c._ring.visible = false
		c.apply_look({"color": slot, "hat": str(spec.get("hat", "toque")), "acc": "none"})
		if spec.get("carry", false):
			c.held_id = 9999
			c.anim.state.weight = 3
			c.anim.state.carriers = 2
			c.anim.state.hold = Vector3(0, 0.25, 0.5)
	for pr in shot.get("props", []):
		var n := Models.load_model(str(pr["m"]))
		if n != null:
			n.position = pr["p"]
			n.scale = Vector3.ONE * float(pr["s"])
			n.rotation_degrees = pr.get("rot", Vector3.ZERO)
			root.add_child(n)
	for i in 40:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(out_dir)
	img.save_png("%s/subject_%s.png" % [out_dir, key])
	print("icon_shot: saved %s" % key)
	vp.queue_free()
	layer.queue_free()
