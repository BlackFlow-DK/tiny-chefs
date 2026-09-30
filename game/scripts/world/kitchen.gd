class_name Kitchen
extends RefCounted
## Static scenery: lighting/atmosphere, the giant counter island, the room around it, and the props
## from GameData.SCENERY (solid obstacles). Identical on every peer (no unseeded randomness).
## The visuals live in world/env/ (EnvLook, EnvCounter, EnvRoom, EnvProps); this file owns the
## colliders, which are unchanged gameplay: counter box, back wall, one box per scenery prop.

const SINK_MODEL := "sink_basin"
const HOB_CENTER := Vector3(-25.2, 0, 0.5)
const HOB_SIZE := Vector2(9.0, 7.0)


static func build(root: Node3D) -> void:
	var cw := GameData.COUNTER_SIZE.x
	var cd := GameData.COUNTER_SIZE.y
	var ch := GameData.COUNTER_HEIGHT

	EnvLook.build(root)
	EnvCounter.build(root, _sink_hole())
	EnvRoom.build(root)
	EnvProps.hob(root, HOB_CENTER, HOB_SIZE)
	EnvProps.clutter(root)

	# Colliders: the counter is one solid block, top at y = 0; the wall behind it.
	_solid(root, Vector3(cw, ch, cd), Vector3(0, -ch, 0))
	_solid(root, Vector3(260, 90, 1.0), Vector3(0, -ch, -cd * 0.5 - 1.0))

	for s in GameData.SCENERY:
		var n := Node3D.new()
		n.name = str(s["model"]).to_pascal_case()
		n.position = s["pos"]
		n.rotation.y = deg_to_rad(float(s.get("yaw", 0.0)))
		root.add_child(n)
		var v := Models.load_model(str(s["model"]))
		if v == null:
			v = EnvProps.fallback(str(s["model"]), s["size"], s["color"])
		n.add_child(v)
		var csz: Vector3 = s.get("collider", s["size"])
		var coff: Vector3 = s.get("collider_offset", Vector3.ZERO)
		_solid(n, csz, coff)

	if root is World and EnvDebug.wanted():
		root.add_child(EnvDebug.new())


## XZ rect of the sink basin footprint (the counter slab gets a hole there), or empty.
static func _sink_hole() -> Rect2:
	for s in GameData.SCENERY:
		if str(s["model"]) == SINK_MODEL:
			var p: Vector3 = s["pos"]
			var sz: Vector3 = s["size"]
			return Rect2(p.x - sz.x * 0.5, p.z - sz.z * 0.5, sz.x, sz.z)
	return Rect2()


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
