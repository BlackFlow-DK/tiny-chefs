extends Node3D
## Dev scene (scenes/dev/postcard.tscn): a "postcard" render of one map for the lobby map card, with
## two static chefs hauling a raw patty over the plank. No HUD. Args (after --):
##   --pc-out=<png>        where to write the PNG (required; the run quits afterwards)
##   --pc-cam=1..4         camera preset (1 high three-quarter, 2 hero angle through the plank,
##                         3 top-down-ish, 4 low front); --pc-pos= --pc-look= (x,y,z) --pc-fov= override it
##   --pc-size=WxH         render size (default 2560x1024, the card aspect at 4x; downsample after)
##   --map=<id>            map (default twin_islands)
## Run: godot --path game --windowed --resolution 1280x720 res://scenes/dev/postcard.tscn -- --quality=high ...

const CAMS := {
	1: {"pos": Vector3(0, 30, 35), "look": Vector3(0, -2, -1), "fov": 37.0},
	2: {"pos": Vector3(0, 10, 30), "look": Vector3(0, 0, -3), "fov": 52.0},
	3: {"pos": Vector3(0, 48, 12), "look": Vector3(0, 0, -1), "fov": 34.0},
	4: {"pos": Vector3(-21, 27, 37), "look": Vector3(1, -1, 0), "fov": 40.0},
}

var _vp: SubViewport
var _chefs: Array[Chef] = []
var _cs := 1.0   # --pc-chef-scale: chefs and the patty drawn bigger so they read on a postcard


func _ready() -> void:
	var size := Vector2i(2560, 1024)
	var sz := Net.arg_str("pc-size", "").split("x")
	if sz.size() == 2:
		size = Vector2i(int(sz[0]), int(sz[1]))
	_vp = SubViewport.new()
	_vp.size = size
	_vp.own_world_3d = true
	_vp.msaa_3d = Viewport.MSAA_8X
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	var rect := TextureRect.new()   # something on screen so the window shows the render
	rect.texture = _vp.get_texture()
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var layer := CanvasLayer.new()
	layer.add_child(rect)
	add_child(layer)
	add_child(_vp)
	var root := Node3D.new()
	_vp.add_child(root)
	_cs = Net.arg_float("pc-chef-scale", 2.2)
	var map := GameData.map(Net.arg_str("map", "twin_islands"))
	Kitchen.build(root, map)
	for s in map["stations"]:
		var n := Models.load_model(str(s["model"]))
		if n == null:
			continue
		n.position = s["pos"]
		n.rotation.y = deg_to_rad(float(s.get("yaw", 0.0)))
		root.add_child(n)
	if str(map["id"]) == "twin_islands":
		_stage_twin(root)
	var cam := Camera3D.new()
	var c: Dictionary = CAMS.get(Net.arg_int("pc-cam", 1), CAMS[1])
	var pos: Vector3 = c["pos"]
	var look: Vector3 = c["look"]
	var fov: float = c["fov"]
	var p := Net.arg_str("pc-pos", "")
	if p != "":
		var a := p.split(",")
		pos = Vector3(float(a[0]), float(a[1]), float(a[2]))
	var l := Net.arg_str("pc-look", "")
	if l != "":
		var a := l.split(",")
		look = Vector3(float(a[0]), float(a[1]), float(a[2]))
	fov = Net.arg_float("pc-fov", fov)
	cam.fov = fov
	root.add_child(cam)
	cam.position = pos
	cam.look_at(look, Vector3.UP)
	cam.current = true
	var out := Net.arg_str("pc-out", "")
	await _settle()
	if out != "":
		await RenderingServer.frame_post_draw
		var img := _vp.get_texture().get_image()
		DirAccess.make_dir_recursive_absolute(out.get_base_dir())
		img.save_png(out)
		print("postcard: saved %dx%d to %s" % [img.get_width(), img.get_height(), out])
		get_tree().quit(0)


func _settle() -> void:
	for i in 40:
		await get_tree().process_frame


## Two chefs haul a raw patty over the plank, a third works the griddle.
func _stage_twin(root: Node3D) -> void:
	var holders := [
		[Vector3(-2.2, 0.1, 0.0), 90.0, 0], [Vector3(2.2, 0.1, 0.0), -90.0, 1],
	]
	for h in holders:
		_chef(root, h[0], h[1], h[2], true)
	var patty := Models.load_model("patty_raw")
	if patty != null:
		patty.position = Vector3(0, 0.95, 0)
		root.add_child(patty)
	_chef(root, Vector3(11.0, 0, 4.0), 200.0, 2, false)
	_chef(root, Vector3(-9.5, 0, 6.0), 40.0, 3, false)


func _chef(root: Node3D, pos: Vector3, yaw_deg: float, slot: int, carry: bool) -> void:
	var c := Chef.new()
	c.setup(100 + slot, slot, "Chef", true, false)
	root.add_child(c)
	c.position = pos
	c.rotation.y = deg_to_rad(yaw_deg)
	c.scale = Vector3.ONE * _cs
	c.apply_look({"color": slot, "hat": ["toque", "beanie", "paper", "bandana"][slot], "acc": "none"})
	if carry:
		c.held_id = 9999
		c.anim.state.weight = 3
		c.anim.state.carriers = 2
		c.anim.state.hold = Vector3(0, 0.25, 0.5)
	_chefs.append(c)
