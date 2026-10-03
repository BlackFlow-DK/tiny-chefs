class_name Item
extends RigidBody3D
## A piece of food. Host: a real rigid body (frozen + kinematic while carried), turning only about y.
## Client: a frozen, collision-less puppet that eases towards the latest snapshot.
## Origin is the base centre; the collider comes from the contract size in GameData (round food: a sphere,
## or a capsule along x, resting on its base). Feel (bounce, roll, grip, splat): FoodPhysicsSystem.

enum Bar { NONE, COOK, BURN, CHOP, FRY }  # replicated in 4 bits (SnapshotSystem)

var item_id := 0
var kind := ""
var def: Dictionary = {}
var size := Vector3.ONE
var puppet := false
var carriers: Array = []      # host: Chef nodes holding it
var carrier_count := 0        # host + replicated
var cook_time := 0.0          # host: seconds in the current cook stage
var cooking := false          # replicated: on the griddle/fryer and still changing
var bar := 0.0                # replicated progress 0..1
var bar_kind := 0             # replicated Bar value
var refuse_cooldown := 0.0    # host: plate will not look at it again until this runs out
var removed := false
# Food physics (FoodPhysicsSystem on the host; visuals every peer). The body never tilts (x/z rotation
# locked): flat food lies flat, long food spins about y, round food "rolls" on a visual tumble.
var round_kind := false       # tomato, onion, potato, egg: low friction, rolling resistance, tumble
var long_kind := false        # sausage, bacon, hot dog bun: spins on the counter
var tumble := Quaternion.IDENTITY   # replicated: visual roll of round food about its collider centre
var land_seq := 0             # replicated (3 bits): bumped on every landing, clients squash on change
var land_power := 0           # replicated (3 bits): how hard (0..7)
var bounce_armed := false     # host: the next landing bounces once (set by a drop, toss or launch)
var launched := false         # host: thrown/punched/swept; an egg landing hard from this splats
var prev_vel := Vector3.ZERO  # host: velocity last tick (landing detection)

var _squash: Node3D           # scaled for squash-stretch (about the base)
var _tumble_node: Node3D      # rotated by tumble (about the collider centre)
var _visual: Node3D
var _shape: CollisionShape3D
var _sizzle: CPUParticles3D
var _target_pos := Vector3.ZERO
var _target_rot := Quaternion.IDENTITY
var _target_tumble := Quaternion.IDENTITY
var _has_target := false
var _squash_t := 99.0
var _squash_a := 0.0


func setup(id: int, k: String, is_puppet: bool) -> void:
	item_id = id
	puppet = is_puppet
	name = "Item%d" % id
	var pm := PhysicsMaterial.new()
	pm.friction = Tuning.FOOD_FRICTION
	pm.bounce = 0.0   # the one small bounce is scripted (FoodPhysicsSystem), so piles never jitter
	physics_material_override = pm
	linear_damp = Tuning.FOOD_LINEAR_DAMP
	angular_damp = Tuning.FLAT_ANGULAR_DAMP
	continuous_cd = true
	axis_lock_angular_x = true
	axis_lock_angular_z = true
	center_of_mass_mode = RigidBody3D.CENTER_OF_MASS_MODE_CUSTOM
	_squash = Node3D.new()
	_squash.name = "Squash"
	add_child(_squash)
	_tumble_node = Node3D.new()
	_tumble_node.name = "Tumble"
	_squash.add_child(_tumble_node)
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
	var shape := str(def["shape"])
	round_kind = shape == "sphere"
	long_kind = not round_kind and maxf(size.x, size.z) >= 2.5 * minf(size.x, size.z)
	var pivot := roll_radius() if round_kind else 0.0
	center_of_mass = Vector3(0, pivot if round_kind else size.y * 0.5, 0)
	if not round_kind:
		tumble = Quaternion.IDENTITY
		_target_tumble = tumble
	_tumble_node.position = Vector3(0, pivot, 0)
	_tumble_node.quaternion = tumble
	if _visual != null:
		_visual.queue_free()
	_visual = Models.make(k, size, def["color"], def["shape"])
	_visual.position = Vector3(0, -pivot, 0)
	if k == "egg_splat" and not Models.has_model(k):
		# Primitive splat: the white disc plus a flattened yolk.
		var yolk := SphereMesh.new()
		yolk.radius = size.x * 0.2
		yolk.height = size.x * 0.4
		var y := Models.mesh_node(yolk, Color(1.0, 0.72, 0.12), Vector3(size.x * 0.06, size.y, -size.x * 0.04))
		y.scale = Vector3(1.0, 0.35, 1.0)
		_visual.add_child(y)
	_tumble_node.add_child(_visual)
	if _shape != null:
		_shape.queue_free()
	_shape = _round_collider() if round_kind else Models.collider(shape, size)
	add_child(_shape)
	_apply_physics()


## Radius of a round item's collider (it rests on the counter, centre this high): sphere-ish, never wider
## than the item is tall, so an egg does not float and a potato does not sink.
func roll_radius() -> float:
	return minf(size.x, size.y) * 0.5 if size.x <= size.y * 1.15 else minf(size.y, size.z) * 0.5


## Round food: a sphere, or a capsule along x for elongated food (potato).
func _round_collider() -> CollisionShape3D:
	var cs := CollisionShape3D.new()
	var r := roll_radius()
	if size.x > size.y * 1.15:
		var cap := CapsuleShape3D.new()
		cap.radius = r
		cap.height = size.x
		cs.shape = cap
		cs.rotation = Vector3(0, 0, PI * 0.5)
	else:
		var s := SphereShape3D.new()
		s.radius = r
		cs.shape = s
	cs.position = Vector3(0, r, 0)
	return cs


## Friction and damping by food class (round / long / flat). Under slippery the ModifierSystem values stay
## on and these become the ones it restores.
func _apply_physics() -> void:
	var pm := physics_material_override
	if pm == null:
		return
	var fr := Tuning.ROUND_FRICTION if round_kind else Tuning.FOOD_FRICTION
	var ld := Tuning.ROUND_LINEAR_DAMP if round_kind else Tuning.FOOD_LINEAR_DAMP
	var ad := Tuning.LONG_ANGULAR_DAMP if long_kind else Tuning.FLAT_ANGULAR_DAMP
	if bool(get_meta("slip", false)):
		set_meta("slip_orig", [fr, ld, ad])
		return
	pm.friction = fr
	linear_damp = ld
	angular_damp = ad


## Carriers needed for full speed: the data weight, +1 under heavy_hands (ModifierSystem).
func weight() -> int:
	return int(def["weight"]) + ModifierSystem.weight_bonus()


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
	prev_vel = Vector3.ZERO
	bounce_armed = true   # let go: it drops and bounces once
	launched = false


## Host: a system threw it (toss, punch, cat paw, plate refusal). splat: an egg landing hard from this cracks.
func launch(v: Vector3, splat := true) -> void:
	sleeping = false
	linear_velocity = v
	bounce_armed = true
	launched = splat


# ---------------------------------------------------------------- landing + tumble (every peer)

## Host: FoodPhysicsSystem saw it land (power 0..1): bump the replicated landing counter and squash here.
func on_landed(power: float) -> void:
	land_seq = (land_seq + 1) & 7
	land_power = clampi(roundi(power * 7.0), 0, 7)
	squash(power)


## Client: the snapshot's landing counter; a change squashes the puppet like the host.
func apply_land(seq: int, power: int) -> void:
	if seq != land_seq and _has_target:
		squash(power / 7.0)
	land_seq = seq
	land_power = power


## Visual only: a damped squash-then-stretch about the base.
func squash(power: float) -> void:
	if power <= 0.02:
		return
	_squash_a = maxf(_squash_a * exp(-Tuning.SQUASH_RATE * _squash_t), Tuning.SQUASH_AMOUNT * clampf(power, 0.0, 1.0))
	_squash_t = 0.0


## Client: the replicated tumble (eased like the transform).
func set_tumble(q: Quaternion) -> void:
	if not _has_target:
		tumble = q
		_tumble_node.quaternion = q
	_target_tumble = q


## Host: roll the visual tumble by the horizontal motion this tick, or ease it upright (carried).
func host_tumble(v: Vector3, dt: float, righting: bool) -> void:
	if not round_kind:
		return
	if righting:
		tumble = tumble.slerp(Quaternion.IDENTITY, 1.0 - exp(-Tuning.TUMBLE_RIGHTING * dt))
	else:
		var h := Vector3(v.x, 0.0, v.z)
		var sp := h.length()
		if sp < 0.02:
			return
		var r := roll_radius()
		var inv := global_transform.basis.get_rotation_quaternion().inverse()
		var axis := inv * Vector3.UP.cross(h / sp)   # body-local roll axis
		var ang := sp * dt / r
		if size.x > size.y * 1.15:
			# Elongated (potato): rolls only about its long axis.
			var lv: Vector3 = inv * h
			axis = Vector3.RIGHT
			ang = lv.z * dt / r
		tumble = (Quaternion(axis.normalized(), ang) * tumble).normalized()
	_tumble_node.quaternion = tumble


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
	var t := Prof.t0()
	_frame(delta)
	Prof.add(&"item.process", t)


func _frame(delta: float) -> void:
	if puppet and _has_target:
		var t := 1.0 - exp(-Tuning.PUPPET_SMOOTH * delta)
		global_position = global_position.lerp(_target_pos, t)
		quaternion = quaternion.slerp(_target_rot, t)
		if round_kind:
			tumble = tumble.slerp(_target_tumble, t)
			_tumble_node.quaternion = tumble
	if _squash_a > 0.0:
		_squash_t += delta
		var a := _squash_a * exp(-Tuning.SQUASH_RATE * _squash_t)
		if a < 0.004:
			_squash_a = 0.0
			_squash.scale = Vector3.ONE
		else:
			var s := a * cos(Tuning.SQUASH_FREQ * _squash_t)   # + squash, - stretch
			_squash.scale = Vector3(1.0 + s * 0.5, 1.0 - s, 1.0 + s * 0.5)
