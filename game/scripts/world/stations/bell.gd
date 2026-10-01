class_name Bell
extends Station
## Press work next to it to serve what is on its plate (the World checks the orders). A map may have
## several bells; each serves its nearest plate (`plate`, set by World). One with an "upgrade" in its def
## wears a cover and refuses to serve until that upgrade is owned.
## The wobble is replicated as a counter (state()/apply_state()), so every peer rings the right bell.

var plate: Plate          # the plate this bell serves (nearest one)
var _ring := 0.0
var _ring_seq := 0
var _visual: Node3D
var _cover: Node3D


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
	if def.has("upgrade"):
		_cover = Node3D.new()
		var c := CylinderMesh.new()
		c.top_radius = 0.55
		c.bottom_radius = 1.15
		c.height = 1.9
		c.radial_segments = 24
		_cover.add_child(Models.mesh_node(c, UITheme.TOMATO, Vector3(0, 0.95, 0)))
		_cover.add_child(cyl(0.6, 0.12, UITheme.CREAM, Vector3(0, 1.9, 0)))
		_cover.visible = false
		add_child(_cover)


## Host: wobble on every peer (the counter rides the snapshot).
func ring() -> void:
	_ring_seq += 1
	_ring = 0.5


func state() -> Variant:
	return _ring_seq


func apply_state(s: Variant) -> void:
	if s is int and s != _ring_seq:
		_ring_seq = s
		_ring = 0.5


func work_hint() -> String:
	return "F: serve the plate"


func _process(delta: float) -> void:
	if _cover != null:
		_cover.visible = is_locked()
		_visual.visible = not _cover.visible
	if _ring > 0.0:
		_ring = maxf(0.0, _ring - delta)
		var s := 1.0 + sin(_ring * 40.0) * 0.12 * (_ring / 0.5)
		_visual.scale = Vector3(s, 1.0 / s, s)
	else:
		_visual.scale = Vector3.ONE
