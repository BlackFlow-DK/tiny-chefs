extends Node3D
## Dev scene (scenes/dev/itch_cover.tscn): renders the itch.io cover candidates at 2x (1260x1000) from a staged map
## with dressed chefs carrying one giant ingredient, plus the title in the game's UI style. tools: docs/itch.
##   godot --path game --windowed --resolution 1280x720 res://scenes/dev/itch_cover.tscn -- --quality=high \
##     --ic-comp=a --ic-out=<abs png> [--ic-pos=x,y,z --ic-look=x,y,z --ic-fov=f]
## COMPS: map, camera, chefs (as postcard.gd + full look dict), item {name, p, s, yaw}, title {pos, size, rot}.

const COMPS := {
	"a": {
		"map": "diner", "pos": Vector3(0, 9, 22), "look": Vector3(0, 1.6, 3), "fov": 44.0, "cs": 2.4,
		"chefs": [
			{"p": Vector3(-3.1, 0, 3.0), "yaw": 90, "look": {"color": 1, "hat": "crown", "acc": "sunglasses", "beard": "handlebar"}, "carry": true},
			{"p": Vector3(3.1, 0, 3.0), "yaw": -90, "look": {"color": 0, "hat": "propeller", "acc": "glasses", "outfit": "stripes", "body": "stout"}, "carry": true},
			{"p": Vector3(-7.4, 0, 7.5), "yaw": 160, "look": {"color": 2, "hat": "pirate", "acc": "eyepatch", "beard": "full"}},
			{"p": Vector3(7.4, 0, 7.5), "yaw": -160, "look": {"color": 3, "hat": "wizard", "outfit": "hawaiian", "beard": "wizard"}}],
		"item": {"name": "tomato", "p": Vector3(0, 2.1, 3.0), "s": 1.8},
		"title": {"pos": Vector2(0.5, 0.13), "size": 150},
	},
	"b": {
		"map": "picnic", "pos": Vector3(-2, 5.0, 17), "look": Vector3(1.2, 2.2, 5), "fov": 48.0, "cs": 2.4,
		"chefs": [
			{"p": Vector3(-3.2, 0, 5.0), "yaw": 90, "look": {"color": 3, "hat": "cowboy", "acc": "sunglasses", "outfit": "bbq", "beard": "mutton"}, "carry": true},
			{"p": Vector3(3.2, 0, 5.0), "yaw": -90, "look": {"color": 2, "hat": "party", "acc": "clown_nose", "outfit": "overalls"}, "carry": true},
			{"p": Vector3(7.5, 0, 6.0), "yaw": -130, "look": {"color": 1, "hat": "top_hat", "acc": "monocle", "outfit": "tuxedo", "beard": "walrus"}}],
		"item": {"name": "cheese_slice", "p": Vector3(0, 2.1, 5.0), "s": 1.4},
		"title": {"pos": Vector2(0.5, 0.84), "size": 150},
	},
}

var _vp: SubViewport
var _root: Node3D


func _ready() -> void:
	var c: Dictionary = COMPS[Net.arg_str("ic-comp", "a")]
	var size := Vector2i(1260, 1000)
	_vp = SubViewport.new()
	_vp.size = size
	_vp.own_world_3d = true
	_vp.msaa_3d = Viewport.MSAA_8X
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var rect := TextureRect.new()
	rect.texture = _vp.get_texture()
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var layer := CanvasLayer.new()
	layer.add_child(rect)
	add_child(layer)
	add_child(_vp)
	_root = Node3D.new()
	_vp.add_child(_root)
	var map := GameData.map(str(c["map"]))
	Kitchen.build(_root, map)
	for s in map["stations"]:
		if s.has("upgrade"):
			continue
		var n := Models.load_model(str(s["model"]))
		if n == null:
			continue
		n.position = s["pos"]
		n.rotation.y = deg_to_rad(float(s.get("yaw", 0.0)))
		_root.add_child(n)
	var cam := Camera3D.new()
	_root.add_child(cam)
	cam.current = true
	cam.fov = Net.arg_float("ic-fov", float(c["fov"]))
	cam.position = _v3(Net.arg_str("ic-pos", ""), c["pos"])
	cam.look_at(_v3(Net.arg_str("ic-look", ""), c["look"]), Vector3.UP)
	var cs := float(c["cs"])
	for spec in c["chefs"]:
		_chef(spec, cs)
	var it: Dictionary = c["item"]
	var item := Models.load_model(str(it["name"]))
	if item != null:
		item.position = it["p"]
		item.scale = Vector3.ONE * float(it["s"])
		_root.add_child(item)
	_title(c["title"])
	for i in 50:
		await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var img := _vp.get_texture().get_image()
	var out := Net.arg_str("ic-out", "")
	if out != "":
		DirAccess.make_dir_recursive_absolute(out.get_base_dir())
		img.save_png(out)
		print("itch_cover: saved %dx%d to %s" % [img.get_width(), img.get_height(), out])
	get_tree().quit(0)


func _v3(s: String, d: Vector3) -> Vector3:
	if s == "":
		return d
	var a := s.split(",")
	return Vector3(float(a[0]), float(a[1]), float(a[2]))


func _title(t: Dictionary) -> void:
	var ctl := Control.new()
	ctl.theme = UI.theme()
	ctl.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var l := UIKit.title("TINY CHEFS", UITheme.S_HERO)
	var sz := int(t["size"])
	l.add_theme_font_size_override("font_size", sz)
	l.add_theme_constant_override("outline_size", int(sz * 0.2))
	l.add_theme_constant_override("shadow_offset_y", int(sz * 0.09))
	l.add_theme_constant_override("shadow_offset_x", int(sz * 0.0))
	l.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	l.anchor_top = float(t["pos"].y) - 0.1
	l.anchor_bottom = float(t["pos"].y) + 0.1
	l.offset_top = 0
	l.offset_bottom = 0
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ctl.add_child(l)
	_vp.add_child(ctl)


func _chef(spec: Dictionary, cs: float) -> void:
	var look: Dictionary = spec["look"]
	var slot := int(look.get("color", 0))
	var c := Chef.new()
	c.setup(100 + slot, slot, "Chef", true, false)
	_root.add_child(c)
	c.position = spec["p"]
	c.rotation.y = deg_to_rad(float(spec.get("yaw", 0.0)))
	c.scale = Vector3.ONE * cs
	c.apply_look(look)
	if spec.get("carry", false):
		c.held_id = 9999
		c.anim.state.weight = 3
		c.anim.state.carriers = 2
		c.anim.state.hold = Vector3(0, 0.25, 0.5)
