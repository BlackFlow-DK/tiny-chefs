extends Node3D
## Dev scene (scenes/dev/postcard.tscn): renders the lobby's map-card pictures. Builds a map with
## Kitchen.build (+ station models), poses a few static chefs, takes each SHOTS entry of that map from a
## fixed camera at the High preset, no HUD, and saves 2048x1024 PNGs.
##
## Regenerate the shipped pictures (all four maps; needs a real window, not --headless):
##   tools\map-thumbs.ps1            (runs this scene per map, then tools\map_thumbs.py -> assets/ui/maps/<id>_<n>.webp)
## Or one map by hand:
##   godot --path game --windowed --resolution 1280x720 res://scenes/dev/postcard.tscn -- --quality=high \
##     --pc-map=picnic --pc-dir=<abs dir> [--pc-shot=2] [--pc-size=2048x1024]
##   --pc-shot=<n>        only shot n (1-based); --pc-pos= --pc-look= (x,y,z) --pc-fov= override its camera
##   --pc-chefs=0         no chefs (empty set)
## Edit SHOTS below to add or retake a picture. Chef spec: p = position, yaw = degrees (0 faces +z = the
## camera side, 180 faces the far wall, 90 faces +x), slot = player colour 0-3, hat / acc = look ids,
## carry = holds the patty with a partner (put the two on opposite sides of "patty"), work = chops.

const SHOTS := {
	"diner": [
		{"pos": Vector3(0, 38, 41), "look": Vector3(0, -1, -3), "fov": 40.0, "chefs": [
			{"p": Vector3(-10, 0, 4.4), "yaw": 180, "slot": 0, "hat": "toque"},
			{"p": Vector3(-1.9, 0, 3.0), "yaw": 90, "slot": 1, "hat": "beanie", "carry": true},
			{"p": Vector3(2.5, 0, 3.0), "yaw": -90, "slot": 2, "hat": "paper", "carry": true},
			{"p": Vector3(10, 0, 4.2), "yaw": 180, "slot": 3, "hat": "bandana", "work": true}],
			"patty": Vector3(0.3, 0.95, 3.0), "cs": 1.6},
		{"pos": Vector3(-8, 6, 27), "look": Vector3(1, 4.5, -14), "fov": 52.0, "chefs": [
			{"p": Vector3(-9, 0, -4), "yaw": 180, "slot": 2, "hat": "toque"}], "cs": 1.2},
		{"pos": Vector3(-3, 8, 13), "look": Vector3(-4, 0.4, 0.5), "fov": 40.0, "chefs": [
			{"p": Vector3(-10.5, 0, 4.4), "yaw": 180, "slot": 0, "hat": "toque"},
			{"p": Vector3(-5.2, 0, 2.0), "yaw": 90, "slot": 1, "hat": "beanie", "carry": true},
			{"p": Vector3(-1.0, 0, 2.0), "yaw": -90, "slot": 3, "hat": "bandana", "carry": true}],
			"patty": Vector3(-3.1, 0.95, 2.0), "cs": 1.25},
		{"pos": Vector3(-22, 13, 24), "look": Vector3(6, 0.5, -2), "fov": 46.0, "chefs": [
			{"p": Vector3(4.2, 0, 5.2), "yaw": 0, "slot": 2, "hat": "toque"},
			{"p": Vector3(-5.5, 0, 3.5), "yaw": 90, "slot": 3, "hat": "paper", "work": true},
			{"p": Vector3(11.5, 0, 2.2), "yaw": 180, "slot": 1, "hat": "beanie"}], "cs": 1.9},
	],
	"food_truck": [
		{"pos": Vector3(0, 30, 40), "look": Vector3(0, -1, -2), "fov": 46.0, "chefs": [
			{"p": Vector3(-13, 0, 0.6), "yaw": 0, "slot": 0, "hat": "toque"},
			{"p": Vector3(-1.9, 0, -1.2), "yaw": 90, "slot": 1, "hat": "beanie", "carry": true},
			{"p": Vector3(2.5, 0, -1.2), "yaw": -90, "slot": 2, "hat": "paper", "carry": true}],
			"patty": Vector3(0.3, 0.95, -1.2), "cs": 1.6},
		{"pos": Vector3(-12, 8, 15), "look": Vector3(10, 3.2, -8), "fov": 56.0, "chefs": [
			{"p": Vector3(4, 0, -1.4), "yaw": 0, "slot": 2, "hat": "toque"},
			{"p": Vector3(-6, 0, -1.2), "yaw": 0, "slot": 0, "hat": "beanie"}], "cs": 1.4},
		{"pos": Vector3(-14, 11, 20), "look": Vector3(-13, 0.3, 0), "fov": 42.0, "chefs": [
			{"p": Vector3(-13.5, 0, 0.3), "yaw": 0, "slot": 0, "hat": "toque"},
			{"p": Vector3(-22.5, 0, 0.5), "yaw": 0, "slot": 3, "hat": "bandana"},
			{"p": Vector3(-8.0, 0, -1.2), "yaw": 90, "slot": 1, "hat": "beanie", "carry": true},
			{"p": Vector3(-3.6, 0, -1.2), "yaw": -90, "slot": 2, "hat": "paper", "carry": true}],
			"patty": Vector3(-5.8, 0.95, -1.2), "cs": 1.3},
		{"pos": Vector3(35, 9, 9), "look": Vector3(10, 1.5, -2), "fov": 52.0, "chefs": [
			{"p": Vector3(28.5, 0, 2.5), "yaw": 270, "slot": 1, "hat": "beanie"},
			{"p": Vector3(19, 0, 0.5), "yaw": 0, "slot": 3, "hat": "toque"}], "cs": 1.9},
	],
	"picnic": [
		{"pos": Vector3(0, 40, 46), "look": Vector3(0, -3, 0), "fov": 42.0, "chefs": [
			{"p": Vector3(-12, 0, 0.6), "yaw": 180, "slot": 0, "hat": "toque"},
			{"p": Vector3(-2.0, 0, 5.0), "yaw": 90, "slot": 1, "hat": "beanie", "carry": true},
			{"p": Vector3(2.4, 0, 5.0), "yaw": -90, "slot": 2, "hat": "paper", "carry": true}],
			"patty": Vector3(0.2, 0.95, 5.0), "cs": 1.7},
		{"pos": Vector3(-20, 6, 36), "look": Vector3(3, 2.5, 0), "fov": 56.0, "chefs": [
			{"p": Vector3(-8, 0, 6), "yaw": 30, "slot": 3, "hat": "bandana"}], "cs": 1.2},
		{"pos": Vector3(-5, 11, 21), "look": Vector3(-7, 0.3, 2), "fov": 42.0, "chefs": [
			{"p": Vector3(-12, 0, -7.4), "yaw": 0, "slot": 0, "hat": "toque"},
			{"p": Vector3(-8.2, 0, 7.0), "yaw": 90, "slot": 1, "hat": "beanie", "carry": true},
			{"p": Vector3(-3.8, 0, 7.0), "yaw": -90, "slot": 2, "hat": "paper", "carry": true}],
			"patty": Vector3(-6.0, 0.95, 7.0), "cs": 1.3},
		{"pos": Vector3(10, 12, -33), "look": Vector3(0, 0.5, 2), "fov": 52.0, "chefs": [
			{"p": Vector3(6, 0, -9.5), "yaw": 180, "slot": 3, "hat": "toque"},
			{"p": Vector3(-4, 0, -9.5), "yaw": 180, "slot": 2, "hat": "bandana"}], "cs": 1.7},
	],
	"twin_islands": [
		{"pos": Vector3(0, 30, 35), "look": Vector3(0, -2, -1), "fov": 37.0, "chefs": [
			{"p": Vector3(-2.2, 0.1, 0), "yaw": 90, "slot": 0, "hat": "toque", "carry": true},
			{"p": Vector3(2.2, 0.1, 0), "yaw": -90, "slot": 1, "hat": "beanie", "carry": true},
			{"p": Vector3(11, 0, 4.0), "yaw": 200, "slot": 2, "hat": "paper"}],
			"patty": Vector3(0, 1.05, 0), "cs": 1.8},
		{"pos": Vector3(-5, 7.5, 14), "look": Vector3(1, -0.5, 0), "fov": 44.0, "chefs": [
			{"p": Vector3(-2.2, 0.1, 0), "yaw": 90, "slot": 0, "hat": "toque", "carry": true},
			{"p": Vector3(2.2, 0.1, 0), "yaw": -90, "slot": 3, "hat": "bandana", "carry": true}],
			"patty": Vector3(0, 1.05, 0), "cs": 1.15},
		{"pos": Vector3(14, 10, 20), "look": Vector3(14, 0.4, 1), "fov": 42.0, "chefs": [
			{"p": Vector3(11, 0, -5.6), "yaw": 0, "slot": 1, "hat": "beanie"},
			{"p": Vector3(9, 0, 12.6), "yaw": 180, "slot": 3, "hat": "paper", "work": true},
			{"p": Vector3(17, 0, 3.0), "yaw": 90, "slot": 0, "hat": "toque", "carry": true},
			{"p": Vector3(21.4, 0, 3.0), "yaw": -90, "slot": 2, "hat": "bandana", "carry": true}],
			"patty": Vector3(19.2, 0.95, 3.0), "cs": 1.3},
		{"pos": Vector3(-21, 27, 37), "look": Vector3(1, -1, 0), "fov": 40.0, "chefs": [
			{"p": Vector3(-2.2, 0.1, 0), "yaw": 90, "slot": 0, "hat": "toque", "carry": true},
			{"p": Vector3(2.2, 0.1, 0), "yaw": -90, "slot": 1, "hat": "beanie", "carry": true},
			{"p": Vector3(11, 0, 4.0), "yaw": 200, "slot": 2, "hat": "paper"}],
			"patty": Vector3(0, 1.05, 0), "cs": 2.0},
	],
}

var _vp: SubViewport
var _root: Node3D
var _cam: Camera3D
var _dyn: Array[Node] = []


func _ready() -> void:
	var size := Vector2i(2048, 1024)
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
	_root = Node3D.new()
	_vp.add_child(_root)
	var map_id := Net.arg_str("pc-map", "twin_islands")
	var map := GameData.map(map_id)
	Kitchen.build(_root, map)
	for s in map["stations"]:
		if s.has("upgrade"):
			continue   # second plate etc.: only exists after the shop
		var n := Models.load_model(str(s["model"]))
		if n == null:
			continue
		n.position = s["pos"]
		n.rotation.y = deg_to_rad(float(s.get("yaw", 0.0)))
		_root.add_child(n)
	_cam = Camera3D.new()
	_root.add_child(_cam)
	_cam.current = true
	var shots: Array = SHOTS.get(map_id, [])
	var only := Net.arg_int("pc-shot", 0)
	var out_dir := Net.arg_str("pc-dir", "")
	for i in shots.size():
		if only > 0 and only != i + 1:
			continue
		_take(shots[i], i + 1, map_id, out_dir)
		await _settle()
		if out_dir != "":
			await RenderingServer.frame_post_draw
			var img := _vp.get_texture().get_image()
			DirAccess.make_dir_recursive_absolute(out_dir)
			var path := "%s/%s_%d.png" % [out_dir, map_id, i + 1]
			img.save_png(path)
			print("postcard: saved %dx%d to %s" % [img.get_width(), img.get_height(), path])
	get_tree().quit(0)


func _settle() -> void:
	for i in 40:
		await get_tree().process_frame


func _take(shot: Dictionary, _n: int, _map_id: String, _out: String) -> void:
	for n in _dyn:
		n.queue_free()
	_dyn.clear()
	var pos: Vector3 = shot["pos"]
	var look: Vector3 = shot["look"]
	var p := Net.arg_str("pc-pos", "")
	if p != "":
		var a := p.split(",")
		pos = Vector3(float(a[0]), float(a[1]), float(a[2]))
	var l := Net.arg_str("pc-look", "")
	if l != "":
		var a := l.split(",")
		look = Vector3(float(a[0]), float(a[1]), float(a[2]))
	_cam.fov = Net.arg_float("pc-fov", float(shot["fov"]))
	_cam.position = pos
	_cam.look_at(look, Vector3.UP)
	if Net.arg_int("pc-chefs", 1) == 0:
		return
	var cs := float(shot.get("cs", 1.0))
	var carriers := 0
	for c in shot.get("chefs", []):
		_chef(c, cs)
		if c.get("carry", false):
			carriers += 1
	if carriers >= 2 and shot.has("patty"):
		var patty := Models.load_model("patty_raw")
		if patty != null:
			patty.position = shot["patty"]
			patty.scale = Vector3.ONE * clampf(cs * 0.75, 1.0, 1.4)
			_root.add_child(patty)
			_dyn.append(patty)


func _chef(spec: Dictionary, cs: float) -> void:
	var slot := int(spec.get("slot", 0))
	var c := Chef.new()
	c.setup(100 + slot, slot, "Chef", true, false)
	_root.add_child(c)
	_dyn.append(c)
	c.position = spec["p"]
	c.rotation.y = deg_to_rad(float(spec.get("yaw", 0.0)))
	c.scale = Vector3.ONE * cs
	c.apply_look({"color": slot, "hat": str(spec.get("hat", "toque")), "acc": str(spec.get("acc", "none"))})
	if spec.get("carry", false):
		c.held_id = 9999
		c.anim.state.weight = 3
		c.anim.state.carriers = 2
		c.anim.state.hold = Vector3(0, 0.25, 0.5)
	elif spec.get("work", false):
		c.flags = Chef.FLAG_WORKING
		c.anim.state.work_kind = ChefAnim.Work.CHOP
