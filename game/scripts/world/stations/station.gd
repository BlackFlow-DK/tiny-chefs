class_name Station
extends Node3D
## Base for kitchen stations. Built identically on every peer from the map's stations (World.map).
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


## Per station type: metres the sunk model is raised so its lowest visible surface clears the counter
## plane (y = 0) and stops z-fighting with the counter mesh. The fryer model's steel body tops out at y = 0
## and its oil sits 0.1 below the rim, so it needs 0.1 (oil at +0.03, rim at +0.13). Items still rest on
## the counter collider at y = 0 (flat stations have no collider): they sink ~3 cm into the oil.
const VISUAL_LIFT := {"fryer": 0.1}


func visual_lift() -> float:
	return float(VISUAL_LIFT.get(type, 0.0))


## Flat stations sit in the counter with the top at y = 0.03 (+ visual_lift()) and have no collider.
func add_flat_visual(v: Node3D) -> void:
	v.position.y = 0.03 - size.y + visual_lift()
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


## Every peer: true while the def's optional "upgrade" is not owned yet (the station is closed).
func is_locked() -> bool:
	return def.has("upgrade") and world != null and not world.shift.has_upgrade(str(def["upgrade"]))


## Name of the upgrade that opens this station ("" when it needs none).
func unlock_name() -> String:
	return str(GameData.upgrade(str(def.get("upgrade", ""))).get("name", ""))


## A little standing "CLOSED" board (w m wide) facing the camera (+Z), for closed stations.
func closed_sign(w: float) -> Node3D:
	var n := Node3D.new()
	var h := w * 0.42
	var board := Node3D.new()
	board.rotation.x = deg_to_rad(-28.0)   # leans back towards the camera's view
	board.add_child(box(Vector3(w + 0.24, h + 0.24, 0.12), UITheme.INK, Vector3(0, -0.12, -0.02)))
	board.add_child(box(Vector3(w, h, 0.16), UITheme.CREAM, Vector3.ZERO))
	var l := Label3D.new()
	l.text = "CLOSED"
	l.font = UITheme.font(true)
	l.font_size = 96
	l.pixel_size = w / 520.0
	l.modulate = UITheme.TOMATO_DARK
	l.outline_size = 0
	l.position = Vector3(0, h * 0.5, 0.09)
	board.add_child(l)
	n.add_child(board)
	return n


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
