class_name Kitchen
extends RefCounted
## Static scenery: light, sky, the giant counter island, the floor far below, the wall behind,
## and the big props from the contract (solid obstacles). Identical on every peer.


static func build(root: Node3D) -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.62, 0.74, 0.86)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.85, 0.88, 0.95)
	env.ambient_light_energy = 0.4
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.fog_enabled = true
	env.fog_light_color = Color(0.62, 0.74, 0.86)
	env.fog_density = 0.002
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)

	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-58), deg_to_rad(28), 0)
	sun.light_energy = 0.95
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 90.0
	root.add_child(sun)

	var cw := GameData.COUNTER_SIZE.x
	var cd := GameData.COUNTER_SIZE.y
	var ch := GameData.COUNTER_HEIGHT
	# Counter: one solid block, top at y = 0.
	_solid(root, Vector3(cw, ch, cd), Vector3(0, -ch, 0))
	var top_mat := _checker(Color(0.62, 0.52, 0.42), Color(0.58, 0.48, 0.38), 12.0)
	var slab := _box(root, Vector3(cw, 1.0, cd), Color.WHITE, Vector3(0, -1.0, 0))
	slab.material_override = top_mat
	_box(root, Vector3(cw + 0.6, 0.5, cd + 0.6), Color(0.3, 0.26, 0.24), Vector3(0, -1.5, 0))
	_box(root, Vector3(cw - 1.0, ch - 1.5, cd - 1.0), Color(0.55, 0.38, 0.25), Vector3(0, -ch, 0))
	# Drawer fronts and handles on the camera side of the island.
	for i in 4:
		var x := -22.5 + i * 15.0
		_box(root, Vector3(13.5, 11.0, 0.4), Color(0.62, 0.44, 0.3), Vector3(x, -14.0, cd * 0.5 - 0.4))
		_box(root, Vector3(4.0, 0.8, 0.8), Color(0.8, 0.8, 0.82), Vector3(x, -5.5, cd * 0.5 - 0.2))
		_box(root, Vector3(13.5, 11.0, 0.4), Color(0.62, 0.44, 0.3), Vector3(x, -27.0, cd * 0.5 - 0.4))
	# Floor far below, wall behind.
	var floor_mi := _box(root, Vector3(260, 1.0, 200), Color.WHITE, Vector3(0, -ch - 1.0, 20))
	floor_mi.material_override = _checker(Color(0.42, 0.45, 0.5), Color(0.34, 0.37, 0.42), 26.0)
	var wall := _box(root, Vector3(260, 90, 1.0), Color.WHITE, Vector3(0, -ch, -cd * 0.5 - 1.0))
	wall.material_override = _checker(Color(0.9, 0.92, 0.9), Color(0.84, 0.88, 0.86), 36.0)
	_solid(root, Vector3(260, 90, 1.0), Vector3(0, -ch, -cd * 0.5 - 1.0))

	for s in GameData.SCENERY:
		var n := Node3D.new()
		n.name = str(s["model"]).to_pascal_case()
		n.position = s["pos"]
		root.add_child(n)
		var v := Models.load_model(str(s["model"]))
		if v == null:
			v = _prop(str(s["model"]), s["size"], s["color"])
		n.add_child(v)
		var csz: Vector3 = s.get("collider", s["size"])
		var coff: Vector3 = s.get("collider_offset", Vector3.ZERO)
		_solid(n, csz, coff)


static func _box(root: Node3D, sz: Vector3, color: Color, base: Vector3) -> MeshInstance3D:
	var b := BoxMesh.new()
	b.size = sz
	var mi := Models.mesh_node(b, color, base + Vector3(0, sz.y * 0.5, 0))
	root.add_child(mi)
	return mi


static func _cyl(root: Node3D, r_top: float, r_bot: float, h: float, color: Color, base: Vector3) -> MeshInstance3D:
	var c := CylinderMesh.new()
	c.top_radius = r_top
	c.bottom_radius = r_bot
	c.height = h
	var mi := Models.mesh_node(c, color, base + Vector3(0, h * 0.5, 0))
	root.add_child(mi)
	return mi


static func _solid(root: Node3D, sz: Vector3, base: Vector3) -> void:
	var sb := StaticBody3D.new()
	sb.collision_layer = Tuning.LAYER_WORLD
	sb.collision_mask = 0
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = sz
	cs.shape = b
	cs.position = base + Vector3(0, sz.y * 0.5, 0)
	sb.add_child(cs)
	root.add_child(sb)


static func _checker(a: Color, b: Color, tiles: float) -> StandardMaterial3D:
	var img := Image.create(2, 2, false, Image.FORMAT_RGB8)
	img.set_pixel(0, 0, a)
	img.set_pixel(1, 1, a)
	img.set_pixel(1, 0, b)
	img.set_pixel(0, 1, b)
	var m := StandardMaterial3D.new()
	m.albedo_texture = ImageTexture.create_from_image(img)
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE / tiles
	m.roughness = 0.6
	return m


## Fallback primitives for the scenery props, roughly the contract shapes.
static func _prop(model: String, sz: Vector3, color: Color) -> Node3D:
	var n := Node3D.new()
	var r := sz.x * 0.5
	match model:
		"sink_tap":
			_cyl(n, 1.2, 1.5, sz.y - 1.0, color, Vector3(0, 0, -2.5))
			_box(n, Vector3(1.4, 1.2, 6.5), color, Vector3(0, sz.y - 1.6, 0.4))
			_cyl(n, 0.5, 0.5, 2.0, color, Vector3(0, sz.y - 3.2, 3.3))
		"ketchup_bottle":
			_cyl(n, r * 0.85, r, sz.y * 0.8, color, Vector3.ZERO)
			_cyl(n, r * 0.35, r * 0.8, sz.y * 0.2, Color(0.95, 0.95, 0.95), Vector3(0, sz.y * 0.8, 0))
		"utensil_pot":
			_cyl(n, r, r * 0.85, sz.y * 0.5, color, Vector3.ZERO)
			_box(n, Vector3(0.5, sz.y * 0.5, 1.2), Color(0.8, 0.8, 0.82), Vector3(-1.0, sz.y * 0.5, 0))
			_box(n, Vector3(0.5, sz.y * 0.45, 1.6), Color(0.35, 0.25, 0.18), Vector3(1.0, sz.y * 0.5, 0.5))
			_box(n, Vector3(1.8, 0.4, 1.4), Color(0.8, 0.8, 0.82), Vector3(-1.0, sz.y - 0.4, 0))
		_:
			_cyl(n, r, r, sz.y * 0.8, color, Vector3.ZERO)
			_cyl(n, r * 0.9, r, sz.y * 0.2, Color(0.72, 0.74, 0.78), Vector3(0, sz.y * 0.8, 0))
	return n
