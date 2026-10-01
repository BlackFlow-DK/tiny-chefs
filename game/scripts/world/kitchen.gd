class_name Kitchen
extends RefCounted
## Static scenery for one map (a GameData.MAPS entry): lighting/atmosphere, one counter slab per
## surface, the room around them (by theme), and the map's scenery props (solid obstacles unless
## "flat"). Identical on every peer (no unseeded randomness). The visuals live in world/env/
## (EnvLook, EnvCounter, EnvRoom, EnvProps); this file owns the colliders: one box per surface,
## the back wall, one box per solid scenery prop.

const SINK_MODEL := "sink_basin"
const HOB_MODEL := "hob"
const THEMES := ["diner"]   # room looks EnvRoom can build; anything else falls back to the first
const STYLE_COUNTER := "counter"
const STYLE_PLANK := "plank"


static func build(root: Node3D, map: Dictionary) -> void:
	var ch := GameData.COUNTER_HEIGHT
	var surfaces: Array = map["surfaces"]
	var scenery: Array = map["scenery"]
	var bounds := GameData.surfaces_bounds(surfaces)
	var theme := str(map.get("theme", THEMES[0]))
	if not THEMES.has(theme):
		theme = THEMES[0]

	EnvLook.build(root)
	var holes := _sink_holes(scenery)
	for i in surfaces.size():
		if surface_style(map, i) == STYLE_PLANK:
			EnvIslands.plank(root, surfaces[i], _plank_gap(map, i))
		else:
			EnvCounter.build(root, surfaces[i], holes)
	if theme == "diner":   # new themes: add their room builder here and the id to THEMES
		EnvRoom.build(root, surfaces)
	var decor: Array = map.get("decor", [])
	if decor.has("diner_clutter"):
		EnvProps.clutter(root, bounds)
	if decor.has("island_sink"):
		# The double sink fills the gap under every plank, over the whole counter depth.
		for i in surfaces.size():
			if surface_style(map, i) == STYLE_PLANK:
				var g := _plank_gap(map, i)
				EnvIslands.double_sink(root, Rect2(g.x, bounds.position.y, g.y - g.x, bounds.size.y), bounds.position.y - 0.5)
	if decor.has("islands_clutter"):
		EnvIslands.clutter(root)

	# Colliders: each counter surface is one solid block, top at y = 0 (a plank only its own
	# thickness, so nothing solid hides under it); the wall behind the back-most edge.
	for i in surfaces.size():
		var r: Rect2 = surfaces[i]
		var h := EnvIslands.PLANK_T if surface_style(map, i) == STYLE_PLANK else ch
		_solid(root, Vector3(r.size.x, h, r.size.y), Vector3(r.get_center().x, -h, r.get_center().y))
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


## Look of surface i: MapDef "surface_styles" (optional, parallel to "surfaces"): "counter" (default:
## terrazzo slab, trim, cabinets, full-height collider) or "plank" (EnvIslands wooden board, collider
## only PLANK_T thick, nothing built under it). Missing or unknown entries are "counter".
static func surface_style(map: Dictionary, i: int) -> String:
	var styles: Array = map.get("surface_styles", [])
	return str(styles[i]) if i < styles.size() else STYLE_COUNTER


## X span (x0, x1) of plank surface i that no counter surface holds up: from the right-most end of
## the counters it overlaps on its left to the left-most start of those on its right.
static func _plank_gap(map: Dictionary, i: int) -> Vector2:
	var surfaces: Array = map["surfaces"]
	var r: Rect2 = surfaces[i]
	var g := Vector2(r.position.x, r.end.x)
	for j in surfaces.size():
		var o: Rect2 = surfaces[j]
		if j == i or surface_style(map, j) == STYLE_PLANK or not o.intersects(r, true):
			continue
		if o.get_center().x < r.get_center().x:
			g.x = maxf(g.x, o.end.x)
		else:
			g.y = minf(g.y, o.position.x)
	return g


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
