class_name EnvUtil
extends RefCounted
## Mesh + material helpers for the kitchen environment builders (env_*.gd). Everything is built
## from code and deterministic, so host and clients get the identical kitchen.

const SHADER_DIR := "res://assets/shaders/"

static var _std: Dictionary = {}
static var _shaders: Dictionary = {}


## Plain PBR material, cached by its parameters.
static func mat(color: Color, rough := 0.7, metal := 0.0) -> StandardMaterial3D:
	var key := "%s|%.2f|%.2f" % [color.to_html(), rough, metal]
	if _std.has(key):
		return _std[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.roughness = rough
	m.metallic = metal
	if color.a < 0.999:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	_std[key] = m
	return m


static func emissive(color: Color, energy: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = energy
	return m


## New ShaderMaterial for res://assets/shaders/<name>.gdshader with the given uniforms.
static func shader_mat(name: String, params := {}) -> ShaderMaterial:
	if not _shaders.has(name):
		_shaders[name] = load(SHADER_DIR + name + ".gdshader")
	var m := ShaderMaterial.new()
	m.shader = _shaders[name]
	for k in params:
		m.set_shader_parameter(k, params[k])
	return m


static func node(parent: Node3D, name: String, pos := Vector3.ZERO) -> Node3D:
	var n := Node3D.new()
	n.name = name
	n.position = pos
	parent.add_child(n)
	return n


static func mesh(parent: Node3D, m: Mesh, material: Material, pos: Vector3, shadows := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = m
	mi.material_override = material
	mi.position = pos
	if not shadows:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	return mi


## Box by centre.
static func box(parent: Node3D, size: Vector3, center: Vector3, material: Material, shadows := true) -> MeshInstance3D:
	var b := BoxMesh.new()
	b.size = size
	return mesh(parent, b, material, center, shadows)


## Box by min/max corners.
static func box_mm(parent: Node3D, lo: Vector3, hi: Vector3, material: Material, shadows := true) -> MeshInstance3D:
	return box(parent, hi - lo, (lo + hi) * 0.5, material, shadows)


## Vertical cylinder standing on base (y up), optional axis "x"/"z" to lay it down (centre at base then).
static func cyl(parent: Node3D, r_top: float, r_bot: float, h: float, base: Vector3, material: Material,
		axis := "y", segments := 24, shadows := true) -> MeshInstance3D:
	var c := CylinderMesh.new()
	c.top_radius = r_top
	c.bottom_radius = r_bot
	c.height = h
	c.radial_segments = segments
	c.rings = 1
	var mi: MeshInstance3D
	match axis:
		"x":
			mi = mesh(parent, c, material, base, shadows)
			mi.rotation = Vector3(0, 0, PI * 0.5)
		"z":
			mi = mesh(parent, c, material, base, shadows)
			mi.rotation = Vector3(PI * 0.5, 0, 0)
		_:
			mi = mesh(parent, c, material, base + Vector3(0, h * 0.5, 0), shadows)
	return mi


static func sphere(parent: Node3D, r: float, center: Vector3, material: Material, scale := Vector3.ONE,
		shadows := true, segments := 20) -> MeshInstance3D:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0
	s.radial_segments = segments
	s.rings = maxi(4, segments / 2)
	var mi := mesh(parent, s, material, center, shadows)
	mi.scale = scale
	return mi


## Flat quad facing +Z (or any basis), centred.
static func quad(parent: Node3D, size: Vector2, center: Vector3, material: Material, shadows := false) -> MeshInstance3D:
	var q := QuadMesh.new()
	q.size = size
	return mesh(parent, q, material, center, shadows)


## Horizontal plane (+Y normal), centred.
static func plane(parent: Node3D, size: Vector2, center: Vector3, material: Material, shadows := false) -> MeshInstance3D:
	var p := PlaneMesh.new()
	p.size = size
	return mesh(parent, p, material, center, shadows)


## Rect2 minus hole -> up to 4 rects that tile the remainder (hole clipped to rect).
static func rect_minus(r: Rect2, hole: Rect2) -> Array:
	var h := r.intersection(hole)
	if h.size.x <= 0.0 or h.size.y <= 0.0:
		return [r]
	var out: Array = []
	var x0 := r.position.x
	var x1 := r.end.x
	var y0 := r.position.y
	var y1 := r.end.y
	if h.position.y > y0:
		out.append(Rect2(x0, y0, x1 - x0, h.position.y - y0))
	if h.end.y < y1:
		out.append(Rect2(x0, h.end.y, x1 - x0, y1 - h.end.y))
	if h.position.x > x0:
		out.append(Rect2(x0, h.position.y, h.position.x - x0, h.size.y))
	if h.end.x < x1:
		out.append(Rect2(h.end.x, h.position.y, x1 - h.end.x, h.size.y))
	return out


static func rects_minus(rects: Array, hole: Rect2) -> Array:
	var out: Array = []
	for r in rects:
		out.append_array(rect_minus(r, hole))
	return out
