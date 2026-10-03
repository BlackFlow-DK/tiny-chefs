extends Node3D
## Dev gallery: lays out every generated model in a labelled grid for visual review.
## Env vars (the screenshot tool cannot pass extra args):
##   GALLERY_PAGE  1 ingredients, 2 stations, 3 dispensers, 4 scenery, 5 characters,
##                 6 scenery: appliances and books, 7 scenery: small items, 8 scale scene, 9 new ingredients batch 2 (default 1)
##                 14 truck props, 10 truck menu board + string lights, 11 picnic props, 12/13 scale scenes with the chef (truck / picnic)
##                 15 stations 2 (fryer, soda fountain) + new dispensers
##   GALLERY_VIEW  "top" (steep, like the game camera), "angle" (default "top"),
##                 "close" (low, near, for detail review) or "game" (45 deg down, 25 m away)
##   GALLERY_MODELS comma separated model names: show just those in one row (detail review)
##   GALLERY_PRINT 1 = print every model's AABB size and lowest y (use with --headless --quit-after)

const PAGES: Dictionary = {
	1: {"cols": 5, "names": [
		"bun_bottom", "bun_top", "patty_raw", "patty_cooked", "patty_burnt",
		"cheese_slice", "lettuce_leaf", "tomato", "tomato_slice", "hotdog_bun",
		"sausage_raw", "sausage_cooked", "sausage_burnt"]},
	2: {"cols": 3, "names": [
		"cutting_board", "knife", "griddle", "plate", "service_bell", "trash_drain"]},
	3: {"cols": 4, "names": [
		"dispenser_buns", "dispenser_patties", "dispenser_cheese", "dispenser_lettuce",
		"dispenser_tomatoes", "dispenser_sausages", "dispenser_hotdog_buns"]},
	4: {"cols": 5, "names": [
		"salt_shaker", "pepper_shaker", "ketchup_bottle", "utensil_pot", "sink_tap"]},
	5: {"cols": 2, "names": ["chef", "boxing_glove"]},
	6: {"cols": 3, "names": [
		"toaster", "kettle", "fruit_bowl", "cookbook_stack", "paper_towel_roll", "rolling_pin"]},
	7: {"cols": 4, "names": [
		"coffee_mug", "oil_bottle", "dish_sponge", "spice_jar_a", "spice_jar_b", "spice_jar_c"]},
	8: {"cols": 3, "names": [
		"chef", "toaster", "coffee_mug", "spice_jar_a", "salt_shaker", "oil_bottle"]},
	9: {"cols": 5, "names": [
		"bacon_raw", "bacon_cooked", "bacon_burnt", "egg", "fried_egg",
		"egg_burnt", "onion", "onion_slice", "onion_rings", "onion_rings_burnt",
		"pickle_slice", "potato", "fries_raw", "fries", "fries_burnt",
		"chicken_raw", "chicken_cooked", "chicken_burnt", "soda_cup"]},
	14: {"cols": 5, "names": [
		"truck_napkin_dispenser", "truck_sauce_bottles", "truck_order_bell_sign", "truck_tip_jar", "truck_cash_register"]},
	10: {"cols": 1, "names": ["truck_menu_board", "truck_string_lights"]},
	11: {"cols": 4, "names": [
		"picnic_basket", "lemonade_jug", "watermelon_slice", "daisy_flower",
		"paper_plates_stack", "ant", "bee", "leaf"]},
	12: {"cols": 4, "names": [
		"chef", "truck_cash_register", "truck_napkin_dispenser", "truck_sauce_bottles", "truck_tip_jar", "truck_order_bell_sign"]},
	13: {"cols": 4, "names": [
		"chef", "picnic_basket", "lemonade_jug", "watermelon_slice", "daisy_flower", "paper_plates_stack", "ant", "bee"]},
	15: {"cols": 4, "names": [
		"fryer", "soda_fountain", "dispenser_bacon", "dispenser_eggs",
		"dispenser_onions", "dispenser_pickles", "dispenser_potatoes", "dispenser_chicken"]},
}

var _page: int = 1
var _view: String = "top"


func _ready() -> void:
	_page = clampi(OS.get_environment("GALLERY_PAGE").to_int(), 1, PAGES.size()) if OS.has_environment("GALLERY_PAGE") else 1
	if OS.has_environment("GALLERY_VIEW"):
		_view = OS.get_environment("GALLERY_VIEW")
	var print_mode: bool = OS.get_environment("GALLERY_PRINT") == "1"
	var names: Array = PAGES[_page]["names"]
	var cols: int = PAGES[_page]["cols"]
	if OS.get_environment("GALLERY_MODELS") != "":
		names = Array(OS.get_environment("GALLERY_MODELS").split(","))
		cols = names.size()
	var rows: int = ceili(float(names.size()) / cols)

	var nodes: Array[Node3D] = []
	var boxes: Array[AABB] = []
	var cell: float = 0.0
	var hmax: float = 0.0
	for n in names:
		var scene: PackedScene = load("res://assets/models/%s.glb" % n) as PackedScene
		var inst: Node3D = scene.instantiate() as Node3D
		add_child(inst)
		var box: AABB = _aabb_of(inst)
		nodes.append(inst)
		boxes.append(box)
		cell = maxf(cell, maxf(box.size.x, box.size.z))
		hmax = maxf(hmax, box.size.y)
		if print_mode:
			print("AABB %s size=(%.2f, %.2f, %.2f) min_y=%.3f center_xz=(%.2f, %.2f)" % [
				n, box.size.x, box.size.y, box.size.z, box.position.y,
				box.get_center().x, box.get_center().z])
	cell *= 1.22
	var cell_z: float = cell * (1.0 if _view == "top" else 1.45)
	if _page == 8 or (_page >= 12 and _page <= 14):
		cell_z = cell * 1.1
	var width: float = cell * cols
	var depth: float = cell_z * rows

	for i in names.size():
		var c: int = i % cols
		var r: int = i / cols
		var p := Vector3((c - (cols - 1) / 2.0) * cell, 0.0, (r - (rows - 1) / 2.0) * cell_z)
		nodes[i].position = p
		var label := Label3D.new()
		label.text = names[i]
		label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		label.no_depth_test = true
		label.font_size = 48
		label.outline_size = 12
		label.modulate = Color(1, 1, 1)
		label.outline_modulate = Color(0.05, 0.05, 0.08)
		label.pixel_size = cell * 0.085 / 48.0
		label.position = p + Vector3(0, label.pixel_size * 24.0, boxes[i].size.z * 0.5 + cell * 0.09)
		add_child(label)

	_build_stage(width, depth, hmax)
	if print_mode:
		print("GALLERY page=%d cell=%.2f" % [_page, cell])


func _aabb_of(root: Node3D) -> AABB:
	var out := AABB()
	var first := true
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		for ch in n.get_children():
			stack.append(ch)
		if n is MeshInstance3D:
			var mi: MeshInstance3D = n
			var b: AABB = mi.global_transform * mi.get_aabb()
			out = b if first else out.merge(b)
			first = false
	return out


func _build_stage(width: float, depth: float, hmax: float) -> void:
	if OS.get_environment("GALLERY_ENV") == "game":  # the real game lighting + sky reflections
		EnvLook.build(self)
		_build_ground_and_camera(width, depth, hmax)
		return
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.32, 0.36, 0.42)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.78, 0.85)
	env.ambient_light_energy = 0.5
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-58), deg_to_rad(28), 0)
	sun.shadow_enabled = true
	sun.light_energy = 0.9
	add_child(sun)
	_build_ground_and_camera(width, depth, hmax)


func _build_ground_and_camera(width: float, depth: float, hmax: float) -> void:
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(width * 1.6 + 4.0, depth * 1.6 + 4.0)
	ground.mesh = plane
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.42, 0.45, 0.5)
	gm.roughness = 1.0
	ground.material_override = gm
	ground.position.y = -0.005
	add_child(ground)

	var elev: float = deg_to_rad(66.0 if _view == "top" else 30.0)
	var vfov: float = 40.0
	if _view == "close":
		elev = deg_to_rad(22.0)
	elif _view == "game":
		elev = deg_to_rad(45.0)
		vfov = 50.0
	var aspect: float = 16.0 / 9.0
	var hfov: float = 2.0 * atan(tan(deg_to_rad(vfov) / 2.0) * aspect)
	var need_h: float = (width * 0.5) / tan(hfov / 2.0)
	var need_v: float = ((depth * sin(elev) + hmax * cos(elev)) * 0.5) / tan(deg_to_rad(vfov) / 2.0)
	var dist: float = maxf(need_h * 1.2, need_v) * 1.0 + hmax * 0.4
	if _view == "game":
		dist = 25.0
	elif _view == "close":
		dist *= 0.95
	var target := Vector3(0, hmax * (0.4 if _view == "close" else 0.25), depth * 0.06)
	var cam := Camera3D.new()
	cam.fov = vfov
	cam.far = 2000.0
	add_child(cam)
	cam.position = target + Vector3(0, sin(elev), cos(elev)) * dist
	cam.look_at(target, Vector3.UP)
	cam.current = true
