extends Node3D
## Dev preview of the set-B hats (cone, party, fez, beret, cap, santa, headphones, frog, halo) on the real chef.
## Env vars:
##   HATB_IDS   = comma list of hat ids (default all nine)
##   HATB_BODY  = body shape: standard | big_head | ... (GameData.BODY_SHAPES)
##   HATB_VIEW  = front | back | three | side | top | game   (default front)
##   HATB_ZOOM  = game view only: camera distance factor (1 = real game distance, 0.5 = twice as close)
##   HATB_TIME  = seconds of animation to advance Float objects (the halo bobs in code)

const ALL := ["cone", "party", "fez", "beret", "cap", "santa", "headphones", "frog", "halo"]
const COLORS := [Color(0.24, 0.48, 1.0), Color(1.0, 0.29, 0.29), Color(0.24, 0.81, 0.35), Color(1.0, 0.82, 0.23)]

var _floats: Array[Node3D] = []


func _env(k: String, d: String) -> String:
	return OS.get_environment(k) if OS.has_environment(k) else d


func _ready() -> void:
	var ids: PackedStringArray = _env("HATB_IDS", ",".join(ALL)).split(",")
	var body := _env("HATB_BODY", "standard")
	var view := _env("HATB_VIEW", "front")
	var spacing := 1.15
	var n := ids.size()
	for i in n:
		var inst := Models.load_model("chef")
		Chef.dress(inst, COLORS[i % 4], {"hat": ids[i], "body": body, "beard": "moustache"})
		add_child(inst)
		inst.position = Vector3((i - (n - 1) / 2.0) * spacing, 0, 0)
		inst.rotation.y = {"back": PI, "side": PI / 2, "three": deg_to_rad(35)}.get(view, 0.0)
		var f := inst.find_child("Float", true, false) as Node3D
		if f != null:
			_floats.append(f)
			f.position.y += 0.02   # a hair of lift, as the game's bob would
		var l := Label3D.new()
		l.text = ids[i]
		l.font_size = 36
		l.pixel_size = 0.004
		l.modulate = Color(0.1, 0.1, 0.1)
		l.rotation.x = -PI / 2 + 0.6
		l.position = inst.position + Vector3(0, -0.1, 0.55)
		add_child(l)
	_stage(view, n, spacing)


func _stage(view: String, n: int, spacing: float) -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.55, 0.62, 0.72)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.85, 0.85, 0.9)
	env.ambient_light_energy = 0.55
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.glow_enabled = true
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
	var width := n * spacing + 0.1
	var fov := 30.0
	var target := Vector3(0, 1.0, 0)
	var dist := width * 0.5 / tan(deg_to_rad(fov * 0.5)) / 1.78 * 1.05 + 0.5
	dist *= _env("HATB_ZOOM", "0.55").to_float()
	var pos := Vector3(0, 1.15, dist)
	match view:
		"top":
			target = Vector3(0, 0.9, 0)
			pos = Vector3(0, dist * 0.9, dist * 0.45)
		"game":
			var z := _env("HATB_GZOOM", "1").to_float()
			fov = 50.0
			target = Vector3(0, 0.6, 0)
			pos = target + Vector3(0, sin(deg_to_rad(40.0)), cos(deg_to_rad(40.0))) * 19.0 * z
		"three", "side", "back":
			pos = Vector3(0, 1.15, dist)
	cam.fov = fov
	cam.far = 500.0
	cam.position = pos
	cam.look_at(target, Vector3.UP)
	cam.current = true
