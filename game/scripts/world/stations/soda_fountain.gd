class_name SodaFountain
extends Dispenser
## Soda fountain: a solid dispenser with a longer hold (Tuning.SODA_HOLD) that pours a soda_cup under its
## nozzle, just in front of it. Host logic is the Dispenser hold timer + DispenserSystem (fizz on spawn).
## The pour (stream + filling cup) is drawn on every peer from the replicated FLAG_WORKING of chefs in reach.

const NOZZLE_Y := 3.9
const OUT_Z := 1.35             # m in front of the body's front face where the cup lands

var _stream: MeshInstance3D
var _ghost: Node3D
var _pour_t := 0.0


func build() -> void:
	gives = def["gives"]
	var v := Models.load_model(str(def["model"]))
	if v == null:
		v = Node3D.new()
		var red := Color(0.85, 0.2, 0.22)
		v.add_child(box(Vector3(size.x, 3.4, size.z), red, Vector3.ZERO))
		v.add_child(box(Vector3(size.x, 1.6, size.z), Color(0.95, 0.94, 0.9), Vector3(0, 3.4, 0)))
		v.add_child(box(Vector3(size.x * 0.8, 0.5, 0.2), red.lightened(0.2), Vector3(0, 4.0, size.z * 0.5)))
		# nozzle arm over the cup spot, drip tray under it
		v.add_child(box(Vector3(0.9, 0.5, OUT_Z + 0.3), Color(0.75, 0.78, 0.8), Vector3(0, NOZZLE_Y, size.z * 0.5 + (OUT_Z + 0.3) * 0.5 - 0.3)))
		v.add_child(box(Vector3(2.8, 0.12, 2.6), Color(0.25, 0.25, 0.27), Vector3(0, 0, size.z * 0.5 + OUT_Z)))
	add_child(v)
	add_solid_collider(size)
	add_label(str(def["label"]), Vector3(0, size.y + 1.6, 0))
	var c := CylinderMesh.new()
	c.top_radius = 0.16
	c.bottom_radius = 0.16
	c.height = 1.0
	_stream = Models.mesh_node(c, Color(0.35, 0.16, 0.08), Vector3.ZERO)
	_stream.visible = false
	add_child(_stream)
	var d: Dictionary = GameData.ITEMS["soda_cup"]
	_ghost = Models.make("soda_cup", d["size"], d["color"], d["shape"])
	_ghost.position = Vector3(0, 0.12, size.z * 0.5 + OUT_Z)
	_ghost.visible = false
	add_child(_ghost)


func hold_time() -> float:
	return Tuning.SODA_HOLD


## The cup lands under the nozzle, just in front of the fountain.
func output_spots() -> Array:
	return [global_position + transform.basis * Vector3(0, 0.25, size.z * 0.5 + OUT_Z)]


func work_hint() -> String:
	return "hold F: pour a soda"


func _process(delta: float) -> void:
	if world == null:
		return
	var pouring := false
	for c in world.chefs.values():
		if (c.flags & Chef.FLAG_WORKING) != 0 and (c.flags & Chef.FLAG_RESPAWNING) == 0 and c.held_id < 0 \
				and footprint_distance(c.global_position) <= Tuning.REACH:
			pouring = true
			break
	_pour_t = _pour_t + delta if pouring else 0.0
	var f := _pour_t / hold_time()
	var on := pouring and f < 1.0
	_stream.visible = on
	_ghost.visible = on
	if not on:
		return
	# The stream shoots down in the first 0.2 s, the cup fills (grows) under it, the stream wobbles a bit.
	var cup_h := 3.0 * clampf(0.15 + f, 0.15, 1.0)
	_ghost.scale = Vector3(1, cup_h / 3.0, 1)
	var bottom := 0.12 + cup_h
	var reach := clampf(_pour_t / 0.2, 0.0, 1.0)
	var length := maxf(0.05, (NOZZLE_Y - bottom) * reach)
	_stream.scale = Vector3(1.0 + 0.15 * sin(_pour_t * 40.0), length, 1.0 + 0.15 * cos(_pour_t * 33.0))
	_stream.position = Vector3(0, NOZZLE_Y - length * 0.5, size.z * 0.5 + OUT_Z)
