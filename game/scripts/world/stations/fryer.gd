class_name Fryer
extends Griddle
## Deep fryer: the griddle's slots/timers/bars (see Griddle) along "fries_to": raw -> fried after FRY_TIME,
## fried -> burnt after FRY_BURN_TIME, FRYER_SLOTS (+ big_fryer) at once. Flat and sunk like the griddle (no collider).
## Oil bubbles rise while anything on it is frying (every peer, from the replicated Item.cooking).

var _bubbles: CPUParticles3D
var _oil_mat: StandardMaterial3D


func build() -> void:
	var v := Models.load_model(str(def["model"]))
	if v == null:
		v = Node3D.new()
		v.add_child(box(size, Color(0.62, 0.64, 0.68), Vector3.ZERO))
		_oil_mat = StandardMaterial3D.new()
		_oil_mat.albedo_color = Color(0.93, 0.68, 0.18)
		_oil_mat.roughness = 0.15
		_oil_mat.emission_enabled = true
		_oil_mat.emission = Color(0.55, 0.3, 0.02)
		_oil_mat.emission_energy_multiplier = 0.4
		var oil := box(Vector3(size.x - 0.8, 0.02, size.z - 0.8), Color.WHITE, Vector3(0, size.y, 0))
		oil.material_override = _oil_mat
		v.add_child(oil)
		for i in 4:  # basket wires
			v.add_child(box(Vector3(size.x - 1.2, 0.05, 0.08), Color(0.3, 0.3, 0.32), Vector3(0, size.y + 0.02, -1.8 + i * 1.2)))
	add_flat_visual(v)
	_bubbles = CPUParticles3D.new()
	_bubbles.amount = 40
	_bubbles.lifetime = 0.6
	_bubbles.emitting = false
	_bubbles.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_bubbles.emission_box_extents = Vector3(half.x - 0.6, 0.02, half.y - 0.6)
	_bubbles.position = Vector3(0, 0.08 + visual_lift(), 0)
	_bubbles.direction = Vector3.UP
	_bubbles.spread = 12.0
	_bubbles.initial_velocity_min = 0.4
	_bubbles.initial_velocity_max = 1.1
	_bubbles.gravity = Vector3.ZERO
	_bubbles.scale_amount_min = 0.5
	_bubbles.scale_amount_max = 1.3
	var pm := SphereMesh.new()
	pm.radius = 0.12
	pm.height = 0.24
	pm.material = Models.mat(Color(1.0, 0.9, 0.6), true)
	_bubbles.mesh = pm
	add_child(_bubbles)
	add_label(str(def["label"]), Vector3(0, 1.5, -half.y - 0.8))


func key() -> String:
	return "fries_to"


func base_slots() -> int:
	return Tuning.FRYER_SLOTS


func slots_upgrade() -> String:
	return "big_fryer"


func _stage_time(_d: Dictionary, cook_stage: bool) -> float:
	return Tuning.FRY_TIME if cook_stage else Tuning.FRY_BURN_TIME * _burn_scale()


func _cook_bar() -> int:
	return Item.Bar.FRY


func _transform(it: Item, k: String) -> void:
	world.fry(it, k)


func _started(_it: Item) -> void:
	Net.event("", "fry")


func _process(_delta: float) -> void:
	if world == null:
		return
	var frying := false
	for it in world.items.values():
		if is_instance_valid(it) and not it.removed and it.cooking and contains_xz(it.global_position):
			frying = true
			break
	if _bubbles.emitting != frying:
		_bubbles.emitting = frying
