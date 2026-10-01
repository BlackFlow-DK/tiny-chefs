class_name Kitchen
extends RefCounted
## Static scenery for one map (a GameData.MAPS entry): lighting/atmosphere, one counter slab per
## surface, the room around them (by theme: "diner" = EnvLook/EnvCounter/EnvRoom, "picnic" =
## EnvPicnic, "truck" = EnvTruck), and the map's scenery props (solid obstacles unless "flat"). Identical on every peer (no unseeded randomness). The visuals live in world/env/
## (EnvLook, EnvCounter, EnvRoom, EnvProps); this file owns the colliders: one box per surface,
## the back wall, one box per solid scenery prop.

const SINK_MODEL := "sink_basin"
const HOB_MODEL := "hob"
const THEMES := ["diner", "picnic", "truck"]   # looks Kitchen can build; anything else falls back to the first


static func build(root: Node3D, map: Dictionary) -> void:
	var ch := GameData.COUNTER_HEIGHT
	var surfaces: Array = map["surfaces"]
	var scenery: Array = map["scenery"]
	var bounds := GameData.surfaces_bounds(surfaces)
	var theme := str(map.get("theme", THEMES[0]))
	if not THEMES.has(theme):
		theme = THEMES[0]

	if theme == "picnic":
		EnvPicnic.build(root, map)   # sky, table + cloth, lawn, trees, bee/ants/leaves, clutter
	elif theme == "truck":
		EnvTruck.build(root, map)    # steel counter + walls, hatch onto the street, lights, floor + end-wall colliders
	else:
		EnvLook.build(root)
		var holes := _sink_holes(scenery)
		for r: Rect2 in surfaces:
			EnvCounter.build(root, r, holes)
		EnvRoom.build(root, surfaces)
	if (map.get("decor", []) as Array).has("diner_clutter"):
		EnvProps.clutter(root, bounds)

	# Colliders: each surface is one solid block, top at y = 0; indoors, the wall behind the back-most
	# edge (outdoors nothing stops food blowing off the far edge).
	for r: Rect2 in surfaces:
		_solid(root, Vector3(r.size.x, ch, r.size.y), Vector3(r.get_center().x, -ch, r.get_center().y))
	if theme != "picnic":
		_solid(root, Vector3(260, 90, 1.0), Vector3(0, -ch, bounds.position.y - 1.0))

	for s in scenery:
		if str(s["model"]) == HOB_MODEL:
			var hs: Vector3 = s["size"]
			EnvProps.hob(root, s["pos"], Vector2(hs.x, hs.z))
			continue
		var n := Node3D.new()
		n.name = str(s["model"]).to_pascal_case()
		n.position = s["pos"]
		n.rotation.y = deg_to_rad(float(s.get("yaw", 0.0)))
		root.add_child(n)
		var v := Models.load_model(str(s["model"]))
		if v == null:
			v = EnvProps.fallback(str(s["model"]), s["size"], s.get("color", Color.WHITE))
		n.add_child(v)
		if bool(s.get("flat", false)):
			continue
		var csz: Vector3 = s.get("collider", s["size"])
		var coff: Vector3 = s.get("collider_offset", Vector3.ZERO)
		_solid(n, csz, coff)

	if root is World and EnvDebug.wanted():
		root.add_child(EnvDebug.new())


## XZ rects of the sink basin footprints (the counter slabs get holes there).
static func _sink_holes(scenery: Array) -> Array:
	var out: Array = []
	for s in scenery:
		if str(s["model"]) == SINK_MODEL:
			var p: Vector3 = s["pos"]
			var sz: Vector3 = s["size"]
			out.append(Rect2(p.x - sz.x * 0.5, p.z - sz.z * 0.5, sz.x, sz.z))
	return out


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
