class_name Item
extends RigidBody3D
## A piece of food. Host: a real rigid body (frozen + kinematic while carried).
## Client: a frozen, collision-less puppet that eases towards the latest snapshot.
## Origin is the base centre; the collider comes from the contract size in GameData.

enum Bar { NONE, COOK, BURN, CHOP }

var item_id := 0
var kind := ""
var def: Dictionary = {}
var size := Vector3.ONE
var puppet := false
var carriers: Array = []      # host: Chef nodes holding it
var carrier_count := 0        # host + replicated
var cook_time := 0.0          # host: seconds in the current cook stage
var cooking := false          # replicated: on the griddle and still changing
var bar := 0.0                # replicated progress 0..1
var bar_kind := 0             # replicated Bar value
var refuse_cooldown := 0.0    # host: plate will not look at it again until this runs out
var removed := false

var _visual: Node3D
var _shape: CollisionShape3D
var _sizzle: CPUParticles3D
var _target_pos := Vector3.ZERO
var _target_rot := Quaternion.IDENTITY
var _has_target := false


func setup(id: int, k: String, is_puppet: bool) -> void:
	item_id = id
	puppet = is_puppet
	name = "Item%d" % id
	var pm := PhysicsMaterial.new()
	pm.friction = 0.9
	pm.bounce = 0.05
	physics_material_override = pm
	linear_damp = 1.2
	angular_damp = 3.0
	continuous_cd = true
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	if puppet:
		freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
		freeze = true
		collision_layer = 0
		collision_mask = 0
	else:
		collision_layer = Tuning.LAYER_ITEMS
		collision_mask = Tuning.LAYER_WORLD | Tuning.LAYER_ITEMS | Tuning.LAYER_PLAYERS
	set_kind(k)
	_sizzle = CPUParticles3D.new()
	_sizzle.amount = 16
	_sizzle.lifetime = 0.7
	_sizzle.emitting = false
	_sizzle.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_sizzle.emission_box_extents = Vector3(size.x * 0.4, 0.05, size.z * 0.4)
	_sizzle.position = Vector3(0, size.y + 0.1, 0)
	_sizzle.direction = Vector3.UP
	_sizzle.spread = 25.0
	_sizzle.initial_velocity_min = 1.5
	_sizzle.initial_velocity_max = 3.0
	_sizzle.gravity = Vector3(0, -1.0, 0)
	_sizzle.scale_amount_min = 0.6
	_sizzle.scale_amount_max = 1.2
	var pmesh := SphereMesh.new()
	pmesh.radius = 0.09
	pmesh.height = 0.18
	pmesh.material = Models.mat(Color(1, 0.95, 0.8), true)
	_sizzle.mesh = pmesh
	add_child(_sizzle)


func set_kind(k: String) -> void:
	if k == kind:
		return
	kind = k
	def = GameData.ITEMS[k]
	size = def["size"]
	mass = float(def["weight"])
	center_of_mass = Vector3(0, size.y * 0.5, 0)
	var roll := str(def["shape"]) == "sphere"
	axis_lock_angular_x = not roll
	axis_lock_angular_z = not roll
	if _visual != null:
		_visual.queue_free()
	_visual = Models.make(k, size, def["color"], def["shape"])
	add_child(_visual)
	if _shape != null:
		_shape.queue_free()
	_shape = Models.collider(def["shape"], size)
	add_child(_shape)


func weight() -> int:
	return int(def["weight"])


func radius() -> float:
	return maxf(size.x, size.z) * 0.5


func label_text() -> String:
	return str(def["label"])


func is_carried() -> bool:
	return carrier_count > 0


## Horizontal distance from p to the edge of this item's footprint (0 when inside).
func footprint_distance(p: Vector3) -> float:
	var d := p - global_position
	d.y = 0.0
	var shape := str(def["shape"])
	if shape == "box" or shape == "capsule_x":
		var yaw := global_transform.basis.get_euler().y
		var l := d.rotated(Vector3.UP, -yaw)
		var dx := maxf(absf(l.x) - size.x * 0.5, 0.0)
		var dz := maxf(absf(l.z) - size.z * 0.5, 0.0)
		return sqrt(dx * dx + dz * dz)
	return maxf(d.length() - size.x * 0.5, 0.0)


## Grab priority from position p (lower wins): footprint edge distance, ties broken by centre distance.
func grab_score(p: Vector3) -> float:
	var c := p - global_position
	c.y = 0.0
	return footprint_distance(p) + 0.05 * c.length()


# ---------------------------------------------------------------- host carrying

func attach(c: Node) -> void:
	if carriers.is_empty():
		freeze_mode = RigidBody3D.FREEZE_MODE_KINEMATIC
		freeze = true
		# Swept against scenery and other chefs by CarrySystem (its carriers are excluded there).
		collision_mask = Tuning.LAYER_WORLD | Tuning.LAYER_PLAYERS
		var yaw := global_transform.basis.get_euler().y
		var p := global_position
		p.y = Tuning.CARRY_LIFT
		global_transform = Transform3D(Basis(Vector3.UP, yaw), p)
	if not carriers.has(c):
		carriers.append(c)
	carrier_count = carriers.size()


func detach(c: Node) -> void:
	carriers.erase(c)
	carrier_count = carriers.size()
	if carriers.is_empty():
		_unfreeze()


func _unfreeze() -> void:
	freeze = false
	collision_mask = Tuning.LAYER_WORLD | Tuning.LAYER_ITEMS | Tuning.LAYER_PLAYERS
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO


# ---------------------------------------------------------------- client puppet

func set_target(pos: Vector3, rot: Quaternion) -> void:
	if not _has_target:
		global_position = pos
		quaternion = rot
		_has_target = true
	_target_pos = pos
	_target_rot = rot


func set_cooking(on: bool) -> void:
	cooking = on
	if _sizzle != null and _sizzle.emitting != on:
		_sizzle.emitting = on


func _process(delta: float) -> void:
	if puppet and _has_target:
		var t := 1.0 - exp(-Tuning.PUPPET_SMOOTH * delta)
		global_position = global_position.lerp(_target_pos, t)
		quaternion = quaternion.slerp(_target_rot, t)
