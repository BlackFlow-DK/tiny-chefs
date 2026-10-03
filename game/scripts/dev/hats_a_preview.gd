extends Node3D
## Dev preview of hat set A on the chef. Env vars:
##   HATA_HATS   = comma list of hat ids (default: all nine)
##   HATA_VIEW   = front | back | three | game | top (default front); game = camera ~17 m away, pitched 40 deg
##   HATA_BODIES = comma list of body shapes, one row each (default standard)
##   HATA_CLOSE  = 1 frames the heads (front / back / three)
##   HATA_FOV   = game view only: lens angle (50 = the real camera; use ~14 to magnify the same shot)
##   HATA_SPIN   = 1 rotates every `Spin` node a quarter turn (propeller check)

const ALL := ["cowboy", "crown", "viking", "top_hat", "propeller", "sombrero", "pirate", "wizard", "pot"]
const COLORS := [Color(0.24, 0.48, 1.0), Color(1.0, 0.29, 0.29), Color(0.24, 0.81, 0.35), Color(1.0, 0.82, 0.23)]


func _env(k: String, d: String) -> String:
	return OS.get_environment(k) if OS.has_environment(k) else d


func _ready() -> void:
	var hats := _env("HATA_HATS", ",".join(ALL)).split(",")
	var bodies := _env("HATA_BODIES", "standard").split(",")
	var view := _env("HATA_VIEW", "front")
	var spacing := 1.5
	for r in bodies.size():
		for i in hats.size():
			var chef := Models.load_model("chef")
			Chef.dress(chef, COLORS[i % 4], {"hat": hats[i], "acc": "none", "beard": "moustache", "back": "none",
				"outfit": "classic", "body": bodies[r]})
			add_child(chef)
			chef.position = Vector3((i - (hats.size() - 1) / 2.0) * spacing, 0, -r * 1.8)
			chef.rotation.y = {"back": PI, "three": deg_to_rad(35)}.get(view, 0.0)
			if _env("HATA_SPIN", "0") == "1":
				var s := chef.find_child("Spin", true, false) as Node3D
				if s != null:
					s.rotate_y(0.7)
	_stage(view, hats.size(), spacing, bodies.size())


func _stage(view: String, n: int, spacing: float, rows: int) -> void:
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
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(80, 80)
	ground.mesh = plane
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.74, 0.66, 0.55)
	ground.material_override = gm
	add_child(ground)
	var cam := Camera3D.new()
	add_child(cam)
	var width := n * spacing + 0.4
	var fov := 34.0
	var target := Vector3(0, 1.0, -(rows - 1) * 0.9)
	var pos := Vector3.ZERO
	var close := _env("HATA_CLOSE", "0") == "1"
	match view:
		"game":
			fov = _env("HATA_FOV", "50").to_float()
			target = Vector3(0, 0.7, -(rows - 1) * 0.9)
			pos = target + Vector3(0, sin(deg_to_rad(40.0)), cos(deg_to_rad(40.0))) * 17.0
		"top":
			target = Vector3(0, 0.9, -(rows - 1) * 0.9)
			pos = target + Vector3(0, 6.0, 3.0)
		_:
			var dist := width * 0.5 / tan(deg_to_rad(fov * 0.5)) * (0.62 if close else 1.0)
			pos = target + Vector3(0, 0.15, dist) if view != "back" else target + Vector3(0, 0.15, dist)
			if close:
				target.y = 1.15
				pos.y = 1.3
	cam.fov = fov
	cam.far = 500.0
	cam.position = pos
	cam.look_at(target, Vector3.UP)
	cam.current = true
