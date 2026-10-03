extends Node3D
## Dev preview of outfit_<id>.glb / back_<id>.glb on the chef. Env vars:
##   PV_KIND  = outfit | back (default outfit)
##   PV_IDS   = csv of ids (default: every id of the kind)
##   PV_VIEW  = front | back | side | game | top (default front); game = the game camera pitch, closer
##   PV_VARY  = tint | body (rows; default tint). front/back/side use the first row only unless PV_ROWS=all
##   PV_TINTS = player colour indices, e.g. "0123" (default "0")
##   PV_BODIES = csv of body shapes (default "standard"; with PV_VARY=body)
##   PV_ROWS  = all to stack every variant as rows in depth (best with game/top)
## Materials named OutfitTint are tinted here like ChefBody (Chef.tint only knows ChefBody/HatTint).

const COLORS := [Color(0.24, 0.48, 1.0), Color(1.0, 0.29, 0.29), Color(0.24, 0.81, 0.35), Color(1.0, 0.82, 0.23)]
const OUTFITS := ["stripes", "tuxedo", "overalls", "hero", "bbq", "knight", "scarf", "hawaiian", "sash"]
const BACKS := ["cape", "backpack", "wings", "jetpack", "guitar", "shell", "pan", "balloon", "sword"]


func _env(k: String, d: String) -> String:
	return OS.get_environment(k) if OS.has_environment(k) else d


func _ready() -> void:
	var kind := _env("PV_KIND", "outfit")
	var ids: PackedStringArray = _env("PV_IDS", ",".join(OUTFITS if kind == "outfit" else BACKS)).split(",")
	var view := _env("PV_VIEW", "front")
	var vary := _env("PV_VARY", "tint")
	var tints := _env("PV_TINTS", "0")
	var bodies: PackedStringArray = _env("PV_BODIES", "standard").split(",")
	var variants: Array = []
	if vary == "tint":
		for c in tints:
			variants.append([c.to_int(), bodies[0]])
	else:
		for b in bodies:
			variants.append([tints[0].to_int(), b])
	if _env("PV_ROWS", "") != "all" and view in ["front", "back", "side"]:
		variants = variants.slice(0, 1)
	var spacing := 1.25
	var rows := variants.size()
	for r in rows:
		for i in ids.size():
			var look := {"hat": "toque", "acc": "none", "beard": "moustache", "back": "none", "outfit": "classic", "body": variants[r][1]}
			look["outfit" if kind == "outfit" else "back"] = ids[i]
			var chef := Models.load_model("chef")
			Chef.dress(chef, COLORS[variants[r][0]], look)
			_tint_outfit(chef, COLORS[variants[r][0]])
			add_child(chef)
			chef.position = Vector3((i - (ids.size() - 1) / 2.0) * spacing, 0, -r * 1.6)
			chef.rotation.y = {"back": PI, "side": PI / 2}.get(view, 0.0)
			var tag := Label3D.new()
			tag.text = ids[i]
			tag.font_size = 36
			tag.pixel_size = 0.004
			tag.modulate = Color(0.1, 0.1, 0.12)
			tag.outline_size = 0
			tag.rotation.x = -PI / 2 + 0.7
			tag.position = chef.position + Vector3(0, 0.0, 0.62)
			add_child(tag)
	_stage(view, ids.size(), spacing, rows)


func _tint_outfit(n: Node, c: Color) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		if mi.mesh != null:
			for i in mi.mesh.get_surface_count():
				var m := mi.mesh.surface_get_material(i)
				if m != null and m.resource_name == "OutfitTint" and m is BaseMaterial3D:
					var d := m.duplicate() as BaseMaterial3D
					d.albedo_color = c
					mi.set_surface_override_material(i, d)
	for k in n.get_children():
		_tint_outfit(k, c)


func _stage(view: String, cols: int, spacing: float, rows: int) -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.55, 0.62, 0.72)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.85, 0.85, 0.9)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-50), deg_to_rad(-25), 0)
	sun.shadow_enabled = true
	add_child(sun)
	var fill := DirectionalLight3D.new()
	fill.rotation = Vector3(deg_to_rad(-30), deg_to_rad(160), 0)
	fill.light_energy = 0.5
	add_child(fill)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(80, 80)
	ground.mesh = plane
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.74, 0.66, 0.55)
	gm.roughness = 0.9
	ground.material_override = gm
	add_child(ground)
	var cam := Camera3D.new()
	add_child(cam)
	var width := cols * spacing * 0.95
	var fov := 30.0
	cam.fov = fov
	var fit := width * 0.5 / tan(deg_to_rad(fov * 0.5)) / (float(get_viewport().size.x) / float(get_viewport().size.y)) + 0.2
	match view:
		"front", "back", "side":
			cam.position = Vector3(0, 0.85, maxf(fit, 3.2))
			cam.look_at(Vector3(0, 0.75, 0))
		"game", "top":
			var pitch := 50.0 if view == "game" else 80.0
			var target := Vector3(0, 0.6, -(rows - 1) * 0.8)
			var dist := maxf(fit * 0.95 + rows * 0.8, 4.0)
			cam.position = target + Vector3(0, sin(deg_to_rad(pitch)), cos(deg_to_rad(pitch))) * dist
			cam.look_at(target)
