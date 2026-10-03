extends Node3D
## Dev scene: stacks food by contract heights to check how it reads on a plate.
## Env BURGER_VIEW  "game" (default, 40 deg pitch from afar) or "close".

const H := {
	"bun_bottom": 0.7, "patty_raw": 0.6, "patty_cooked": 0.6, "patty_burnt": 0.6,
	"cheese_slice": 0.15, "bun_top": 1.1, "hotdog_bun": 1.0, "sausage_cooked": 0.8}
const STACKS := [
	["bun_bottom", "patty_cooked", "cheese_slice", "bun_top"],
	["bun_bottom", "patty_raw", "bun_top"],
	["bun_bottom", "patty_burnt", "cheese_slice", "bun_top"],
	["bun_bottom", "patty_cooked", "bun_top"],
]


func _ready() -> void:
	var view := OS.get_environment("BURGER_VIEW")
	var xs := [-8.0, -2.7, 2.7, 8.0]
	for i in STACKS.size():
		var y := 0.0
		for n in STACKS[i]:
			var inst := (load("res://assets/models/%s.glb" % n) as PackedScene).instantiate() as Node3D
			add_child(inst)
			inst.position = Vector3(xs[i] * 0.7, y, 0)
			y += H[n]
	# hot dog: bun with the cooked sausage laid in the split
	var bun := (load("res://assets/models/hotdog_bun.glb") as PackedScene).instantiate() as Node3D
	add_child(bun)
	bun.position = Vector3(0, 0, 5.2)
	var sau := (load("res://assets/models/sausage_cooked.glb") as PackedScene).instantiate() as Node3D
	add_child(sau)
	sau.position = Vector3(0, 0.45, 5.2)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.32, 0.36, 0.42)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.75, 0.78, 0.85)
	env.ambient_light_energy = 0.5
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(deg_to_rad(-58), deg_to_rad(28), 0)
	sun.shadow_enabled = true
	sun.light_energy = 0.9
	add_child(sun)
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(60, 40)
	ground.mesh = plane
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.42, 0.45, 0.5)
	ground.material_override = gm
	ground.position.y = -0.005
	add_child(ground)
	var cam := Camera3D.new()
	add_child(cam)
	var pitch := deg_to_rad(40.0)
	var dist := 17.0
	var target := Vector3(0, 1.0, 2.0)
	if view == "close":
		pitch = deg_to_rad(25.0)
		dist = 13.0
	cam.fov = 40.0 if view != "close" else 45.0
	cam.far = 500.0
	cam.position = target + Vector3(0, sin(pitch), cos(pitch)) * dist
	cam.look_at(target, Vector3.UP)
	cam.current = true
