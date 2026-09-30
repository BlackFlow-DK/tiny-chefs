class_name Bell
extends Station
## Press work next to it to serve what is on the plate (the World checks the orders).

var _ring := 0.0
var _visual: Node3D


func build() -> void:
	_visual = Models.load_model("service_bell")
	if _visual == null:
		_visual = Node3D.new()
		_visual.add_child(cyl(1.0, 0.35, Color(0.22, 0.14, 0.1), Vector3.ZERO))
		var dome := SphereMesh.new()
		dome.radius = 0.8
		dome.height = 0.8
		dome.is_hemisphere = true
		_visual.add_child(Models.mesh_node(dome, Color(0.9, 0.7, 0.22), Vector3(0, 0.35, 0)))
		_visual.add_child(cyl(0.12, 0.35, Color(0.9, 0.7, 0.22), Vector3(0, 1.1, 0)))
	add_child(_visual)
	add_solid_collider(size)
	add_label("Bell: serve", Vector3(0, size.y + 1.4, 0))


func ring() -> void:
	_ring = 0.5


func work_hint() -> String:
	return "F: serve the plate"


func _process(delta: float) -> void:
	if _ring > 0.0:
		_ring = maxf(0.0, _ring - delta)
		var s := 1.0 + sin(_ring * 40.0) * 0.12 * (_ring / 0.5)
		_visual.scale = Vector3(s, 1.0 / s, s)
	else:
		_visual.scale = Vector3.ONE
