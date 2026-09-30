class_name LobbyChefView
extends SubViewportContainer
## Small turntable of the chef model tinted in a player colour (transparent background).

var _vp: SubViewport
var _pivot: Node3D


var _color := Color.WHITE
var _px := Vector2i(150, 150)


func _init(color := Color.WHITE, px := Vector2i(150, 150)) -> void:
	_color = color
	_px = px


func _ready() -> void:
	var color := _color
	var px := _px
	stretch = true
	custom_minimum_size = Vector2(px)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_vp = SubViewport.new()
	_vp.own_world_3d = true
	_vp.transparent_bg = true
	_vp.msaa_3d = Viewport.MSAA_4X
	_vp.size = px
	add_child(_vp)
	var root := Node3D.new()
	_vp.add_child(root)
	var model := Models.load_model("chef")
	if model == null:
		return
	tint(model, color)
	_pivot = Node3D.new()
	_pivot.add_child(model)
	root.add_child(_pivot)
	var box := aabb_of(model)
	var h := maxf(box.size.y, 0.5)
	var mid := Vector3(0, box.position.y + h * 0.5, 0)
	var light := DirectionalLight3D.new()
	light.rotation = Vector3(deg_to_rad(-40), deg_to_rad(30), 0)
	root.add_child(light)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.9, 0.9, 1.0)
	env.ambient_light_energy = 0.55
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var cam := Camera3D.new()
	cam.fov = 30.0
	root.add_child(cam)
	cam.current = true
	cam.position = mid + Vector3(0, h * 0.05, h * 2.5)
	cam.look_at(mid, Vector3.UP)


func _process(delta: float) -> void:
	if _pivot != null:
		_pivot.rotation.y = sin(Time.get_ticks_msec() * 0.0012) * 0.55


## Recolour every ChefBody surface (contract rule for chef.glb; mirrors Chef._tint).
static func tint(n: Node, color: Color) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		if mi.mesh != null:
			for i in mi.mesh.get_surface_count():
				var m := mi.get_active_material(i)
				if m != null and m.resource_name == "ChefBody" and m is BaseMaterial3D:
					var d := m.duplicate() as BaseMaterial3D
					d.albedo_color = color
					mi.set_surface_override_material(i, d)
	for c in n.get_children():
		tint(c, color)


## Local-space bounding box of every mesh under n.
static func aabb_of(n: Node3D) -> AABB:
	var out := AABB()
	var first := true
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var b := m.mesh.get_aabb() if m.mesh != null else AABB()
		var xf := Transform3D.IDENTITY
		var cur: Node = m
		while cur != null and cur != n:
			if cur is Node3D:
				xf = (cur as Node3D).transform * xf
			cur = cur.get_parent()
		b = xf * b
		out = b if first else out.merge(b)
		first = false
	return out
