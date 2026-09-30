class_name Models
extends RefCounted
## Visual factory: loads res://assets/models/<name>.glb when it exists, otherwise builds a
## coloured primitive of the contract size. Every result stands on y = 0 (base-centre origin).

const MODEL_DIR := "res://assets/models/"

static var _mats: Dictionary = {}


static func has_model(name: String) -> bool:
	return ResourceLoader.exists(MODEL_DIR + name + ".glb")


static func load_model(name: String) -> Node3D:
	var path := MODEL_DIR + name + ".glb"
	if not ResourceLoader.exists(path):
		return null
	var ps := load(path) as PackedScene
	if ps == null:
		return null
	return ps.instantiate() as Node3D


## Model if present, else primitive(shape, size, color).
static func make(name: String, size: Vector3, color: Color, shape: String) -> Node3D:
	var m := load_model(name)
	if m != null:
		return m
	return primitive(shape, size, color)


static func mat(color: Color, unshaded := false) -> StandardMaterial3D:
	var key := "%s|%s" % [color.to_html(), unshaded]
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = 0.75
	if unshaded:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mats[key] = m
	return m


static func mesh_node(mesh: Mesh, color: Color, pos: Vector3) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat(color)
	mi.position = pos
	return mi


static func primitive(shape: String, size: Vector3, color: Color) -> Node3D:
	var root := Node3D.new()
	match shape:
		"cyl":
			var c := CylinderMesh.new()
			c.top_radius = size.x * 0.5
			c.bottom_radius = size.x * 0.5
			c.height = size.y
			c.radial_segments = 24
			var mi := mesh_node(c, color, Vector3(0, size.y * 0.5, 0))
			mi.scale = Vector3(1, 1, size.z / size.x)
			root.add_child(mi)
		"sphere":
			var s := SphereMesh.new()
			s.radius = size.x * 0.5
			s.height = size.y
			root.add_child(mesh_node(s, color, Vector3(0, size.y * 0.5, 0)))
			var stem := CylinderMesh.new()
			stem.top_radius = size.x * 0.12
			stem.bottom_radius = size.x * 0.2
			stem.height = size.y * 0.12
			root.add_child(mesh_node(stem, Color(0.2, 0.55, 0.15), Vector3(0, size.y * 0.98, 0)))
		"dome":
			var d := SphereMesh.new()
			d.radius = size.x * 0.5
			d.height = size.x * 0.5
			d.is_hemisphere = true
			var mi2 := mesh_node(d, color, Vector3.ZERO)
			mi2.scale = Vector3(1, size.y / (size.x * 0.5), size.z / size.x)
			root.add_child(mi2)
		"capsule_x":
			var cap := CapsuleMesh.new()
			cap.radius = size.y * 0.5
			cap.height = size.x
			var mi3 := mesh_node(cap, color, Vector3(0, size.y * 0.5, 0))
			mi3.rotation = Vector3(0, 0, PI * 0.5)
			root.add_child(mi3)
		_:
			var b := BoxMesh.new()
			b.size = size
			root.add_child(mesh_node(b, color, Vector3(0, size.y * 0.5, 0)))
	return root


## Collision shape for a contract footprint, positioned so the body origin is the base centre.
static func collider(shape: String, size: Vector3) -> CollisionShape3D:
	var cs := CollisionShape3D.new()
	match shape:
		"cyl", "dome":
			var c := CylinderShape3D.new()
			c.radius = size.x * 0.5
			c.height = size.y
			cs.shape = c
		"sphere":
			var s := SphereShape3D.new()
			s.radius = size.x * 0.5
			cs.shape = s
		_:
			var b := BoxShape3D.new()
			b.size = size
			cs.shape = b
	cs.position = Vector3(0, size.y * 0.5, 0)
	return cs


## Floating billboard label.
static func label(text: String, height: float, color := Color.WHITE, font_size := 48) -> Label3D:
	var l := Label3D.new()
	l.text = text
	l.position = Vector3(0, height, 0)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.pixel_size = 0.018
	l.font_size = font_size
	l.outline_size = 14
	l.modulate = color
	l.outline_modulate = Color(0, 0, 0, 0.85)
	l.no_depth_test = true
	l.render_priority = 5
	l.outline_render_priority = 4
	return l
