extends Node3D
## Dev preview for beards / face accessories (scenes/dev/face_preview.tscn). Env:
##   FACE_ITEMS  comma list, e.g. "beard:full,acc:mask" (default: all 15); a chef is made per entry
##   FACE_VIEW   front (close, default) | three (3/4 close) | side | game (game camera distance)
##   FACE_BODY   body shape id (default standard; try big_head)
##   FACE_HAT    hat id (default toque)
const ALL := "beard:handlebar,beard:full,beard:goatee,beard:mutton,beard:wizard,beard:stubble,beard:soul_patch,beard:walrus,acc:sunglasses,acc:monocle,acc:eyepatch,acc:clown_nose,acc:goggles,acc:mask,acc:3d_glasses"


func _env(k: String, d: String) -> String:
	var v := OS.get_environment(k)
	return d if v == "" else v


func _ready() -> void:
	var items := _env("FACE_ITEMS", ALL).split(",", false)
	var view := _env("FACE_VIEW", "front")
	var body := _env("FACE_BODY", "standard")
	var hat := _env("FACE_HAT", "toque")
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
	sun.rotation = Vector3(deg_to_rad(-40), deg_to_rad(-20), 0)
	sun.shadow_enabled = true
	add_child(sun)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(80, 80)
	ground.mesh = plane
	ground.material_override = Models.mat(UITheme.COUNTER)
	add_child(ground)
	var n := items.size()
	var cols := n if view != "game" else mini(n, 8)
	var gap := 1.0 if view == "game" else 1.25
	if view == "game":
		gap = 1.6
	for i in n:
		var parts := items[i].split(":")
		var look := {"color": i % 4, "hat": hat, "acc": "none", "beard": "none", "body": body}
		look[("beard" if parts[0] == "beard" else "acc")] = parts[1]
		var c := Chef.new()
		c.setup(100 + i, i % 4, "Chef", true, false)
		add_child(c)
		var col := i % cols
		var row := i / cols
		c.position = Vector3((col - (cols - 1) * 0.5) * gap, 0, -row * gap)
		if view == "three":
			c.rotation.y = deg_to_rad(38)
		elif view == "side":
			c.rotation.y = deg_to_rad(85)
		c.apply_look(look)
	var cam := Camera3D.new()
	add_child(cam)
	var span := (cols - 1) * gap
	if view == "game":
		cam.fov = 50.0
		var target := Vector3(0, 0.6, 0)
		cam.position = target + Vector3(0, sin(deg_to_rad(50.0)), cos(deg_to_rad(50.0))) * 19.0
		cam.look_at(target, Vector3.UP)
	else:
		cam.fov = 22.0
		var vs := get_viewport().get_visible_rect().size
		var dist := (span + 1.1) / (2.0 * tan(deg_to_rad(cam.fov * 0.5)) * vs.x / vs.y)
		var target := Vector3(0, 0.82, 0)
		cam.position = Vector3(0, 0.9, dist)
		cam.look_at(target, Vector3.UP)
	cam.current = true
