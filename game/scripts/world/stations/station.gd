class_name Station
extends Node3D
## Base for kitchen stations. Built identically on every peer from GameData.STATIONS.
## Host runs host_update(); clients receive state()/apply_state() through the snapshot.

var def: Dictionary = {}
var type := ""
var size := Vector3.ONE
var half := Vector2.ONE
var world: Node = null
var marker_text := ""    # the floating name marker is drawn by IndicatorLayer from def["label"]


func setup(d: Dictionary, w: Node) -> void:
	def = d
	type = str(d["type"])
	size = d["size"]
	half = Vector2(size.x * 0.5, size.z * 0.5)
	world = w
	name = str(d["model"]).to_pascal_case()
	position = d["pos"]
	# Optional "yaw" (degrees): visuals and collider turn with the node; the XZ footprint helpers stay
	# axis-aligned, so only multiples of 90 are exact (a quarter turn swaps the footprint's X and Z).
	rotation.y = deg_to_rad(float(d.get("yaw", 0.0)))
	if absf(sin(rotation.y)) > 0.7:
		half = Vector2(half.y, half.x)
	build()


## Override to build visuals; call the helpers below.
func build() -> void:
	pass


## Flat stations sit in the counter with the top at y = 0.03 and have no collider.
func add_flat_visual(v: Node3D) -> void:
	v.position.y = 0.03 - size.y
	add_child(v)


func add_solid_collider(sz: Vector3) -> void:
	var sb := StaticBody3D.new()
	sb.collision_layer = Tuning.LAYER_WORLD
	sb.collision_mask = 0
	var cs := CollisionShape3D.new()
	var b := BoxShape3D.new()
	b.size = sz
	cs.shape = b
	cs.position = Vector3(0, sz.y * 0.5, 0)
	sb.add_child(cs)
	add_child(sb)


## Kept for the station subclasses; the old giant Label3D is gone (IndicatorLayer draws a small pill).
func add_label(text: String, _pos: Vector3) -> void:
	marker_text = text


func contains_xz(p: Vector3, margin := 0.0) -> bool:
	var l := p - global_position
	return absf(l.x) <= half.x + margin and absf(l.z) <= half.y + margin


func footprint_distance(p: Vector3) -> float:
	var l := p - global_position
	var dx := maxf(absf(l.x) - half.x, 0.0)
	var dz := maxf(absf(l.z) - half.y, 0.0)
	return sqrt(dx * dx + dz * dz)


func centre_distance(p: Vector3) -> float:
	var l := p - global_position
	l.y = 0.0
	return l.length()


## Chefs (host) standing within reach, empty-handed, holding work.
func workers(margin := 0.0) -> Array:
	var out: Array = []
	for c in world.chefs.values():
		if c.holding == null and c.work_held and c.respawn_timer < 0.0 and footprint_distance(c.global_position) <= Tuning.REACH + margin:
			out.append(c)
	return out


func host_update(_dt: float) -> void:
	pass


func state() -> Variant:
	return null


func apply_state(_s: Variant) -> void:
	pass


## Text for the context hint when the local chef can work here, "" when not.
func work_hint() -> String:
	return ""


func box(sz: Vector3, color: Color, pos: Vector3) -> MeshInstance3D:
	var b := BoxMesh.new()
	b.size = sz
	return Models.mesh_node(b, color, pos + Vector3(0, sz.y * 0.5, 0))


func cyl(radius: float, height: float, color: Color, pos: Vector3) -> MeshInstance3D:
	var c := CylinderMesh.new()
	c.top_radius = radius
	c.bottom_radius = radius
	c.height = height
	c.radial_segments = 32
	return Models.mesh_node(c, color, pos + Vector3(0, height * 0.5, 0))
