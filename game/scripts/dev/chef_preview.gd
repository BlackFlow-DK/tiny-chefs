extends Node3D
## Dev preview of chef.glb / boxing_glove.glb with the four player tints.
## Env vars: CHEF_VIEW = front | back | side | three | top | game | glove (default three)
##           CHEF_TINTS = indices into the player colours, e.g. "0123" (default all four; close views use the first)
##           CHEF_GLOVE = 1 shows the boxing gloves on the hands

const COLORS := [Color(0.24, 0.48, 1.0), Color(1.0, 0.29, 0.29), Color(0.24, 0.81, 0.35), Color(1.0, 0.82, 0.23)]


func _ready() -> void:
	var view: String = OS.get_environment("CHEF_VIEW") if OS.has_environment("CHEF_VIEW") else "three"
	var tints: String = OS.get_environment("CHEF_TINTS") if OS.has_environment("CHEF_TINTS") else "0123"
	var gloves: bool = OS.get_environment("CHEF_GLOVE") == "1"
	if view in ["three", "front", "back", "side"] and not OS.has_environment("CHEF_TINTS"):
		tints = "0"
	var n: int = tints.length()
	var spacing: float = 1.5
	for i in n:
		var inst := (load("res://assets/models/chef.glb") as PackedScene).instantiate() as Node3D
		add_child(inst)
		inst.position = Vector3((i - (n - 1) / 2.0) * spacing, 0, 0)
		_tint(inst, COLORS[tints[i].to_int()])
		if view == "back":
			inst.rotation.y = PI
		elif view == "side":
			inst.rotation.y = PI / 2
		elif view == "three":
			inst.rotation.y = deg_to_rad(35)
		if gloves:
			for hn in ["HandL", "HandR"]:
				var h := inst.find_child(hn, true, false) as Node3D
				var g := (load("res://assets/models/boxing_glove.glb") as PackedScene).instantiate() as Node3D
				h.add_child(g)
				g.position = Vector3(0, -0.25, 0)
				(h.get_child(0) as Node3D).visible = false if h.get_child_count() > 1 else true
	if view == "glove":
		for c in get_children():
			c.queue_free()
		var g := (load("res://assets/models/boxing_glove.glb") as PackedScene).instantiate() as Node3D
		add_child(g)
		g.rotation.y = deg_to_rad(OS.get_environment("CHEF_ROT").to_float() if OS.has_environment("CHEF_ROT") else -40.0)
	_stage(view, n)
	if OS.get_environment("CHEF_DUMP") == "1":
		for path in ["chef", "boxing_glove"]:
			var root := (load("res://assets/models/%s.glb" % path) as PackedScene).instantiate() as Node3D
			add_child(root)
			_dump(root, root, 0)
			root.queue_free()


func _tint(node: Node, color: Color) -> void:
	if node is MeshInstance3D:
		var mi := node as MeshInstance3D
		if mi.mesh != null:
			for i in mi.mesh.get_surface_count():
				var m := mi.get_active_material(i)
				if m != null and m.resource_name == "ChefBody" and m is BaseMaterial3D:
					var d := m.duplicate() as BaseMaterial3D
					d.albedo_color = color
					mi.set_surface_override_material(i, d)
	for c in node.get_children():
		_tint(c, color)


func _stage(view: String, n: int) -> void:
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
	sun.light_energy = 1.0
	add_child(sun)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(60, 60)
	ground.mesh = plane
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.74, 0.66, 0.55)
	gm.roughness = 0.9
	ground.material_override = gm
	add_child(ground)
	var cam := Camera3D.new()
	add_child(cam)
	var target := Vector3(0, 0.7, 0)
	var fov := 30.0
	var pos := Vector3(0, 0.9, 3.6)
	match view:
		"front":
			pos = Vector3(0, 0.95, 3.8)
		"back":
			pos = Vector3(0, 0.95, 3.8)
		"side":
			pos = Vector3(0, 0.95, 3.8)
		"three":
			pos = Vector3(0, 1.5, 3.4)
		"top":
			target = Vector3(0, 0.5, 0)
			pos = Vector3(0, 6.0, 3.5)
			fov = 35.0
		"game":
			# Tuning: pitch 50 deg, distance 19, fov 50, looking towards -Z; chefs face +Z (the camera).
			fov = 50.0
			target = Vector3(0, 0.6, 0)
			pos = target + Vector3(0, sin(deg_to_rad(50.0)), cos(deg_to_rad(50.0))) * 19.0
		"glove":
			target = Vector3(0, 0.25, 0)
			pos = Vector3(0.0, 1.1, 1.5)
			fov = 30.0
	if view in ["front", "back", "side", "three"] and n > 1:
		pos.z += 1.0 + n * 0.9
		fov = 34.0
	cam.fov = fov
	cam.far = 500.0
	cam.position = pos
	cam.look_at(target, Vector3.UP)
	cam.current = true


func _dump(n: Node, root: Node3D, depth: int) -> void:
	var line := "%s%s (%s)" % ["  ".repeat(depth), n.name, n.get_class()]
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		var b: AABB = mi.global_transform * mi.get_aabb()
		var mats: Array = []
		var tris := 0
		for i in mi.mesh.get_surface_count():
			var m := mi.get_active_material(i)
			mats.append(m.resource_name if m != null else "-")
			tris += mi.mesh.surface_get_array_index_len(i) / 3
		line += " pos=%s aabb_pos=%s size=%s tris=%d mats=%s" % [mi.position, b.position, b.size, tris, mats]
	print("DUMP ", line)
	for c in n.get_children():
		_dump(c, root, depth + 1)
