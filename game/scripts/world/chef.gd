class_name Chef
extends CharacterBody3D
## A player's chef. Host: a real CharacterBody3D driven by that player's PlayerInput.
## Client: a collision-less puppet easing towards the snapshot. Visual bob/lean/hand poses
## run everywhere from observed motion, so they look the same on every screen.

const FLAG_WORKING := 1
const FLAG_PUNCHING := 2
const FLAG_RESPAWNING := 4
const AIM_TURN_RATE := 14.0   # rad/s, turning to face PlayerInput.aim_point
const AIM_MIN_DIST := 0.4     # cursor on the chef itself: keep the current facing
const RADIUS := 0.4           # body capsule radius

var peer_id := 0
var slot := 0
var player_name := "Chef"
var puppet := false
var is_local := false
var holding: Item = null      # host
var held_id := -1             # host + replicated
# Solo carry (host, CarrySystem): the item is held out along hold_yaw, hold_dist from the chef's centre
# (easing to hold_goal after a grab), turned hold_rel_yaw relative to that direction.
var hold_yaw := 0.0
var hold_dist := 0.0
var hold_goal := 0.0
var hold_rel_yaw := 0.0
var facing := Vector3(0, 0, 1)
var walk_vel := Vector3.ZERO
var knock := Vector3.ZERO
var vy := 0.0
var respawn_timer := -1.0
var punch_cd := 0.0
var punch_anim := 0.0
var work_held := false
var flags := 0                # replicated animation flags
var spawn_point := Vector3.ZERO
var seq_ready := false
var last_grab_seq := 0
var last_punch_seq := 0
var last_work_seq := 0

var _anim_root: Node3D
var _visual: Node3D
var _hands: Array[Node3D] = []
var _hand_rest: Array[Vector3] = []
var _gloves: Array[Node3D] = []
var _label: Label3D
var _last_pos := Vector3.ZERO
var _anim_t := 0.0
var _speed01 := 0.0
var _target_pos := Vector3.ZERO
var _target_yaw := 0.0
var _has_target := false


func setup(id: int, player_slot: int, pname: String, is_puppet: bool, local: bool) -> void:
	peer_id = id
	slot = player_slot
	player_name = pname
	puppet = is_puppet
	is_local = local
	name = "Chef%d" % id
	if puppet:
		collision_layer = 0
		collision_mask = 0
	else:
		collision_layer = Tuning.LAYER_PLAYERS
		collision_mask = Tuning.LAYER_WORLD | Tuning.LAYER_PLAYERS | Tuning.LAYER_ITEMS
	floor_snap_length = 0.3
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = RADIUS
	cap.height = 1.4
	cs.shape = cap
	cs.position = Vector3(0, 0.7, 0)
	add_child(cs)
	_anim_root = Node3D.new()
	add_child(_anim_root)
	var color: Color = GameData.PLAYER_COLORS[slot % GameData.PLAYER_COLORS.size()]
	# Player-colour disc on the counter so you can spot your chef in the chaos.
	var disc := CylinderMesh.new()
	disc.top_radius = 0.8
	disc.bottom_radius = 0.8
	disc.height = 0.02
	var dm := StandardMaterial3D.new()
	dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dm.albedo_color = Color(color, 0.55)
	var dmi := MeshInstance3D.new()
	dmi.mesh = disc
	dmi.material_override = dm
	dmi.position = Vector3(0, 0.05, 0)
	dmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(dmi)
	_visual = Models.load_model("chef")
	if _visual == null:
		_visual = _primitive_chef(color)
	else:
		_tint(_visual, color)
	_anim_root.add_child(_visual)
	for hn in ["HandL", "HandR"]:
		var h := _visual.find_child(hn, true, false) as Node3D
		if h != null:
			_hands.append(h)
			_hand_rest.append(h.position)
			# The hand's origin may sit at the model origin (transforms applied), so use its mesh centre.
			var centre := Vector3.ZERO
			if h is MeshInstance3D and (h as MeshInstance3D).mesh != null:
				centre = (h as MeshInstance3D).get_aabb().get_center()
			var g := Models.load_model("boxing_glove")
			if g == null:
				g = Node3D.new()
				var s := SphereMesh.new()
				s.radius = 0.24
				s.height = 0.48
				g.add_child(Models.mesh_node(s, Color(0.85, 0.08, 0.08), Vector3.ZERO))
				g.position = centre
			else:
				g.position = centre + Vector3(0, -0.25, 0)
			g.visible = false
			h.add_child(g)
			_gloves.append(g)
	if not local:
		_label = Models.label(pname, 2.3, color.lightened(0.35), 40)
		add_child(_label)


func set_player_name(pname: String) -> void:
	player_name = pname
	if _label != null:
		_label.text = pname


func set_gloves(on: bool) -> void:
	for g in _gloves:
		g.visible = on


func _primitive_chef(color: Color) -> Node3D:
	var root := Node3D.new()
	var body := CapsuleMesh.new()
	body.radius = 0.4
	body.height = 1.0
	var bm := StandardMaterial3D.new()
	bm.albedo_color = color
	bm.resource_name = "ChefBody"
	var bmi := MeshInstance3D.new()
	bmi.mesh = body
	bmi.material_override = bm
	bmi.position = Vector3(0, 0.5, 0)
	root.add_child(bmi)
	var hat := CylinderMesh.new()
	hat.top_radius = 0.3
	hat.bottom_radius = 0.26
	hat.height = 0.3
	root.add_child(Models.mesh_node(hat, Color.WHITE, Vector3(0, 1.12, 0)))
	var puff := SphereMesh.new()
	puff.radius = 0.34
	puff.height = 0.4
	root.add_child(Models.mesh_node(puff, Color.WHITE, Vector3(0, 1.3, 0)))
	var eye := SphereMesh.new()
	eye.radius = 0.07
	eye.height = 0.14
	root.add_child(Models.mesh_node(eye, Color(0.05, 0.05, 0.08), Vector3(0.14, 0.72, 0.36)))
	root.add_child(Models.mesh_node(eye, Color(0.05, 0.05, 0.08), Vector3(-0.14, 0.72, 0.36)))
	var hand := SphereMesh.new()
	hand.radius = 0.14
	hand.height = 0.28
	var hl := Models.mesh_node(hand, Color(1.0, 0.86, 0.72), Vector3(0.48, 0.45, 0.05))
	hl.name = "HandL"
	root.add_child(hl)
	var hr := Models.mesh_node(hand, Color(1.0, 0.86, 0.72), Vector3(-0.48, 0.45, 0.05))
	hr.name = "HandR"
	root.add_child(hr)
	return root


## Recolour every surface whose material is named ChefBody (contract rule for chef.glb).
func _tint(n: Node, color: Color) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		if mi.mesh != null:
			for i in mi.mesh.get_surface_count():
				var m := mi.get_active_material(i)
				if m != null and m.resource_name == "ChefBody" and m is BaseMaterial3D:
					var d := m.duplicate() as BaseMaterial3D
					d.albedo_color = color
					mi.set_surface_override_material(i, d)
	for c in n.get_children():
		_tint(c, color)


# ---------------------------------------------------------------- host simulation

## Walk (when not carrying). Returns true on the tick the chef falls off the counter.
func host_move(dt: float, inp: PlayerInput, speed_mult: float) -> bool:
	punch_cd = maxf(0.0, punch_cd - dt)
	punch_anim = maxf(0.0, punch_anim - dt)
	if respawn_timer >= 0.0:
		respawn_timer -= dt
		if respawn_timer < 0.0:
			respawn()
		else:
			vy -= Tuning.GRAVITY * dt
			velocity = Vector3(0, vy, 0)
			move_and_slide()
		return false
	if holding != null:
		return false
	var dir := inp.move3()
	walk_vel = walk_vel.move_toward(dir * Tuning.PLAYER_SPEED * speed_mult, Tuning.PLAYER_ACCEL * dt)
	knock = knock.move_toward(Vector3.ZERO, Tuning.KNOCK_DECAY * dt)
	if is_on_floor():
		vy = 0.0
	else:
		vy -= Tuning.GRAVITY * dt
	velocity = walk_vel + knock + Vector3(0, vy, 0)
	move_and_slide()
	_push_items(dir)
	if inp.has_aim:
		aim_at(inp.aim3(), dt)
	elif dir.length() > 0.1:
		face(dir, dt)
	if global_position.y < Tuning.FALL_Y:
		respawn_timer = Tuning.RESPAWN_DELAY
		return true
	return false


func _push_items(dir: Vector3) -> void:
	if dir.length() < 0.1:
		return
	for i in get_slide_collision_count():
		var col := get_slide_collision(i)
		var it := col.get_collider() as Item
		if it == null or it.is_carried() or it.freeze:
			continue
		var n := -col.get_normal()
		n.y = 0.0
		if n.length_squared() < 0.01 or n.normalized().dot(dir) < 0.2:
			continue
		n = n.normalized()
		var target := Tuning.PUSH_SPEED / float(it.weight())
		var along := it.linear_velocity.dot(n)
		if along < target:
			it.apply_central_impulse(n * (target - along) * it.mass)


func face(dir: Vector3, dt: float) -> void:
	dir.y = 0.0
	if dir.length() < 0.05:
		return
	facing = dir.normalized()
	rotation.y = lerp_angle(rotation.y, atan2(facing.x, facing.z), minf(1.0, 14.0 * dt))


## Not carrying + has_aim: turn towards a point on the counter at up to AIM_TURN_RATE rad/s.
## facing (used by punch) points at the target at once; the body catches up.
func aim_at(point: Vector3, dt: float) -> void:
	var to := point - global_position
	to.y = 0.0
	if to.length() < AIM_MIN_DIST:
		return
	facing = to.normalized()
	rotation.y = rotate_toward(rotation.y, atan2(facing.x, facing.z), AIM_TURN_RATE * dt)


func respawn() -> void:
	respawn_timer = -1.0
	global_position = spawn_point + Vector3(0, 0.5, 0)
	walk_vel = Vector3.ZERO
	knock = Vector3.ZERO
	vy = 0.0
	velocity = Vector3.ZERO


func host_flags() -> int:
	var f := 0
	if work_held and holding == null:
		f |= FLAG_WORKING
	if punch_anim > 0.0:
		f |= FLAG_PUNCHING
	if respawn_timer >= 0.0:
		f |= FLAG_RESPAWNING
	return f


# ---------------------------------------------------------------- client puppet + visuals

func set_target(pos: Vector3, yaw: float) -> void:
	if not _has_target:
		global_position = pos
		rotation.y = yaw
		_last_pos = pos
		_has_target = true
	_target_pos = pos
	_target_yaw = yaw


func _process(delta: float) -> void:
	if puppet and _has_target:
		var t := 1.0 - exp(-Tuning.PUPPET_SMOOTH * delta)
		global_position = global_position.lerp(_target_pos, t)
		rotation.y = lerp_angle(rotation.y, _target_yaw, t)
	elif not puppet:
		flags = host_flags()
	_animate(delta)


func _animate(delta: float) -> void:
	var p := global_position
	var hv := p - _last_pos
	hv.y = 0.0
	_last_pos = p
	var spd := hv.length() / maxf(delta, 0.0001)
	_speed01 = lerpf(_speed01, clampf(spd / Tuning.PLAYER_SPEED, 0.0, 1.0), 1.0 - exp(-10.0 * delta))
	var held := _held_item()
	# Carrying: heavier food = slower, smaller bob; short-handed on heavy food = lean back and pull.
	var heavy := 1.0
	var lean := 0.22 * _speed01
	if held != null:
		heavy = 1.0 + 0.35 * float(held.weight() - 1)
		var short := clampf(float(held.weight() - held.carrier_count) / 2.0, 0.0, 1.0)
		lean = -(0.05 + 0.13 * short) * (0.5 + 0.5 * _speed01) if held.weight() > 1 else 0.05 * _speed01
	_anim_t += delta * (5.0 + 11.0 * _speed01) / heavy
	_anim_root.position.y = absf(sin(_anim_t)) * 0.16 * _speed01 / heavy
	_anim_root.rotation.x = lerpf(_anim_root.rotation.x, lean, 1.0 - exp(-8.0 * delta))
	_anim_root.rotation.z = sin(_anim_t) * 0.07 * _speed01 / heavy
	var carry_off := Vector3(0, 0.3, 0.3)
	if held != null:
		# Hands reach forward to the near edge of the held food, at its middle height.
		var reach := clampf(held.footprint_distance(global_position) - 0.1, 0.2, 0.7)
		var up := clampf(held.global_position.y + held.size.y * 0.5 - global_position.y - 0.45, 0.0, 0.5)
		carry_off = Vector3(0, up, reach)
	var carrying := held_id >= 0
	var working := (flags & FLAG_WORKING) != 0
	var punching := (flags & FLAG_PUNCHING) != 0
	for i in _hands.size():
		var off := Vector3.ZERO
		if carrying:
			off = carry_off
		elif working:
			off = Vector3(0, 0.15 + sin(Time.get_ticks_msec() * 0.03 + i * PI) * 0.18, 0.3)
		if punching and i == 1:
			off = Vector3(0.2, 0.25, 0.75)
		_hands[i].position = _hands[i].position.lerp(_hand_rest[i] + off, minf(1.0, 20.0 * delta))


## The food this chef holds, on any peer (held_id is replicated; items live in the World).
func _held_item() -> Item:
	if held_id < 0:
		return null
	var w := get_parent() as World
	if w == null:
		return null
	var it: Item = w.items.get(held_id)
	return it if it != null and is_instance_valid(it) and not it.removed else null
