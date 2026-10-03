class_name Chef
extends CharacterBody3D
## A player's chef. Host: a real CharacterBody3D driven by that player's PlayerInput.
## Client: a collision-less puppet easing towards the snapshot. The animation (ChefAnim, world/chef_anim.gd)
## runs everywhere from observed motion, replicated flags, the held item and Net events, so it looks the same
## on every screen. chef.glb rig v2 parts: see ChefAnim; attachment anchors: ANCHORS.

const FLAG_WORKING := 1
const FLAG_PUNCHING := 2
const FLAG_RESPAWNING := 4
const AIM_TURN_RATE := 14.0   # rad/s, turning to face PlayerInput.aim_point
const AIM_MIN_DIST := 0.4     # cursor on the chef itself: keep the current facing
const RADIUS := 0.4           # body capsule radius
const HAT_ANCHOR := Vector3(0.0, 0.981, 0.0388)   # chef-local: hat_*.glb origin (centre of the toque base ring)
const FACE_ANCHOR := Vector3(0.0, 0.906, 0.2568)  # chef-local: acc_*.glb origin
## chef.glb anchor nodes (empties) and their rest positions, chef-local, standard body. HatAnchor, FaceAnchor and
## BeardAnchor are children of Head; BackAnchor and NeckAnchor of Body; so attachments follow the animation and
## the body shape. The positions are the fallback for a model without the anchor nodes.
const ANCHORS := {"HatAnchor": HAT_ANCHOR, "FaceAnchor": FACE_ANCHOR, "BeardAnchor": Vector3(0.0, 0.823, 0.2415),
	"BackAnchor": Vector3(0.0, 0.606, -0.1784), "NeckAnchor": Vector3(0.0, 0.776, 0.0388)}
const BODY_PIVOT := Vector3(0.0, 0.246, 0.0388)   # Body's origin (hips) in chef.glb; outfits hang under Body at -this
const LOOK_SLOTS := ["LookHat", "LookAcc", "LookBeard", "LookBack", "LookOutfit"]
const TINTED := ["ChefBody", "HatTint", "OutfitTint"]   # material names that take the player's colour

var peer_id := 0
var slot := 0
var player_name := "Chef"
var color_index := -1         # GameData.PLAYER_COLORS index picked by the player (Net.look_of)
var color := Color.WHITE      # its colour; ground ring, name badge and hints read this
var hat := ""
var acc := ""
var look: Dictionary = {}     # the applied look (Net.look_of shape)
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
var traction := 1.0           # host: walk accel multiplier (ModifierSystem: < 1 on a slippery floor)

var anim: ChefAnim            # procedural animation; VFX hooks: anim.step / anim.skid / anim.sweat
var _anim_root: Node3D
var _visual: Node3D
var _ring: GroundRing
var _gloves: Array[Node3D] = []
var _look_key := ""
var _last_pos := Vector3.ZERO
var _last_yaw := 0.0
var _anim_started := false
var _prev_held := -1
var _was_working := false
var _work_scan := 0.0
var _bell_seen := PackedInt32Array()
var _anim_log := -1.0         # --anim-log: seconds to the next line (< 0 = off)
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
	# Thin player-colour ring on the counter with a facing chevron (own chef's ring is brighter).
	_ring = GroundRing.new()
	add_child(_ring)
	_visual = Models.load_model("chef")
	if _visual == null:
		_visual = _primitive_chef(Color.WHITE)
	_anim_root.add_child(_visual)
	anim = ChefAnim.new(_visual, id)
	for hn in ["HandL", "HandR"]:
		var h := _visual.find_child(hn, true, false) as Node3D
		if h != null:
			# chef.glb hands have their origin at the hand centre; older models may not, so use the mesh centre.
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
	Net.event_received.connect(_on_net_event)
	if Net.has_arg("anim-log"):
		_anim_log = 1.0
	apply_look(Net.look_of(id))


## Player look (Net.look_of shape: color index into GameData.PLAYER_COLORS, hat, acc, beard, outfit, back,
## body ids). Tints the body, recolours the ground ring, swaps the attached models, applies the body shape.
## No-op when unchanged.
func apply_look(new_look: Dictionary) -> void:
	var color_idx := posmod(int(new_look.get("color", 0)), GameData.PLAYER_COLORS.size())
	var key := "%d|%s" % [color_idx, look_ids(new_look)]
	if key == _look_key:
		return
	_look_key = key
	look = new_look.duplicate()
	color_index = color_idx
	color = GameData.PLAYER_COLORS[color_idx]
	hat = str(new_look.get("hat", "toque"))
	acc = str(new_look.get("acc", "none"))
	_ring.setup(color, is_local)
	dress(_visual, color, new_look)
	anim.refresh_rest()


## The model-relevant ids of a look, as one string (change detection).
static func look_ids(l: Dictionary) -> String:
	return "%s|%s|%s|%s|%s|%s" % [l.get("hat", "toque"), l.get("acc", "none"), l.get("beard", "moustache"),
		l.get("outfit", "classic"), l.get("back", "none"), l.get("body", "standard")]


## Dress any chef.glb instance (game chef, lobby turntable, menu diorama, previews) from a look dict
## (missing keys = defaults): body shape (ChefAnim.shape), the built-in Toque unless a hat model is attached,
## hat_<id>.glb at HatAnchor, acc_<id>.glb at FaceAnchor, beard_<id>.glb at BeardAnchor, back_<id>.glb at
## BackAnchor, outfit_<id>.glb under Body (authored in chef space, origin at the feet), replacing earlier
## ones; "none" and missing models (catalogue items not made yet) are skipped. Spin / Float parts get
## CosmeticMotion. Then tints ChefBody / HatTint / OutfitTint surfaces.
static func dress(model: Node3D, tint_color: Color, l: Dictionary) -> void:
	if model == null:
		return
	for n: String in LOOK_SLOTS:
		var old := model.find_child(n, true, false)
		if old != null:
			old.get_parent().remove_child(old)
			old.queue_free()
	ChefAnim.shape(model, str(l.get("body", "standard")))
	var hat_id := str(l.get("hat", "toque"))
	var hat_on := hat_id != "toque" and _attach(model, "hat_" + hat_id, "LookHat", "HatAnchor")
	var toque := model.find_child("Toque", true, false) as Node3D
	if toque != null:
		toque.visible = not hat_on   # also while a hat's model is still being made (never a bald chef)
	var acc_id := str(l.get("acc", "none"))
	if acc_id != "none":
		_attach(model, "acc_" + acc_id, "LookAcc", "FaceAnchor")
	var beard_id := str(l.get("beard", "moustache"))
	if beard_id != "none":
		_attach(model, "beard_" + beard_id, "LookBeard", "BeardAnchor")
	var back_id := str(l.get("back", "none"))
	if back_id != "none":
		_attach(model, "back_" + back_id, "LookBack", "BackAnchor")
	var outfit := Models.load_model("outfit_" + str(l.get("outfit", "classic")))
	if outfit != null:
		outfit.name = "LookOutfit"
		var body := model.find_child("Body", true, false) as Node3D
		if body != null:
			outfit.position = -BODY_PIVOT   # Body-local: the outfit's origin lands on the chef origin at rest
			body.add_child(outfit)
		else:
			model.add_child(outfit)
		CosmeticMotion.attach(outfit)
	tint(model, tint_color)


## Attach model_name.glb at the anchor node (identity transform), or at ANCHORS[anchor] on the model root
## when the model has no such node (primitive chef). Missing model (not made yet): skipped, nothing attached.
## Returns true when something was attached.
static func _attach(model: Node3D, model_name: String, node_name: String, anchor: String) -> bool:
	var m := Models.load_model(model_name)
	if m == null:
		return false
	m.name = node_name
	var a := model.find_child(anchor, true, false) as Node3D
	if a != null:
		a.add_child(m)
	else:
		m.position = ANCHORS.get(anchor, Vector3.ZERO)
		model.add_child(m)
	CosmeticMotion.attach(m)
	return true


## Living cosmetic parts, for any attached cosmetic on any chef (game, lobby, wardrobe, previews): a node
## named `Spin*` turns about its local Y axis (through its mesh centre, so a propeller spins on its hub even
## when its origin is elsewhere); a node named `Float*` bobs up and down with a slight sway (halo, balloon).
## Added by dress() as a child of the cosmetic only when it has such parts; freed with it.
class CosmeticMotion extends Node:
	const SPIN_RATE := 9.0      # rad/s
	const BOB := 0.03           # m, float amplitude
	const BOB_RATE := 2.4       # rad/s
	const SWAY := 0.08          # rad, float tilt

	var _parts: Array = []      # [Node3D, rest Transform3D, pivot Vector3 (local), "spin"|"float", phase]
	var _t := 0.0

	static func attach(cosmetic: Node3D) -> void:
		var parts: Array = []
		var i := 0
		for n in cosmetic.find_children("*", "Node3D", true, false):
			var nm := String(n.name)
			var kind := "spin" if nm.begins_with("Spin") else ("float" if nm.begins_with("Float") else "")
			if kind.is_empty():
				continue
			var nd := n as Node3D
			var pivot := Vector3.ZERO
			if nd is MeshInstance3D and (nd as MeshInstance3D).mesh != null:
				var c := (nd as MeshInstance3D).get_aabb().get_center()
				pivot = Vector3(c.x, 0.0, c.z)
			parts.append([nd, nd.transform, pivot, kind, i * 1.3])
			i += 1
		if parts.is_empty():
			return
		var cm := CosmeticMotion.new()
		cm.name = "CosmeticMotion"
		cm._parts = parts
		cm._t = randf() * 10.0
		cosmetic.add_child(cm)

	func _process(delta: float) -> void:
		_t += delta
		for p: Array in _parts:
			var nd: Node3D = p[0]
			if not is_instance_valid(nd):
				continue
			var rest: Transform3D = p[1]
			var pivot: Vector3 = p[2]
			if p[3] == "spin":
				var r := Transform3D(Basis(Vector3.UP, wrapf(_t * SPIN_RATE, 0.0, TAU)), Vector3.ZERO)
				nd.transform = rest * Transform3D(Basis(), pivot) * r * Transform3D(Basis(), -pivot)
			else:
				var a := _t * BOB_RATE + float(p[4])
				var tilt := Basis(Vector3.FORWARD, sin(a * 0.5) * SWAY)
				nd.transform = Transform3D(tilt * rest.basis, rest.origin + Vector3(0, sin(a) * BOB, 0))


## The name tag is drawn by IndicatorLayer (reads player_name every frame).
func set_player_name(pname: String) -> void:
	player_name = pname


func set_gloves(on: bool) -> void:
	for g in _gloves:
		g.visible = on


func _primitive_chef(body_color: Color) -> Node3D:
	var root := Node3D.new()
	var body := CapsuleMesh.new()
	body.radius = 0.4
	body.height = 1.0
	var bm := StandardMaterial3D.new()
	bm.albedo_color = body_color
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


## Recolour every surface whose material is named ChefBody, HatTint or OutfitTint (contract rule for chef.glb
## and the cosmetics). Starts from the mesh's own material, so tinting again replaces the colour.
static func tint(n: Node, tint_color: Color) -> void:
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		if mi.mesh != null:
			for i in mi.mesh.get_surface_count():
				var m := mi.mesh.surface_get_material(i)
				if m == null:
					m = mi.get_active_material(i)
				if m != null and TINTED.has(m.resource_name) and m is BaseMaterial3D:
					var d := m.duplicate() as BaseMaterial3D
					d.albedo_color = tint_color
					mi.set_surface_override_material(i, d)
	for c in n.get_children():
		tint(c, tint_color)


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
	walk_vel = walk_vel.move_toward(dir * Tuning.PLAYER_SPEED * speed_mult, Tuning.PLAYER_ACCEL * traction * dt)
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
		if Net.has_arg("map-log"):
			print("map: chef %d fell at (%.1f, %.1f), respawns at %s" % [peer_id, global_position.x, global_position.z, spawn_point])
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
	if Net.has_arg("map-log"):
		print("map: chef %d respawned at %s" % [peer_id, spawn_point])
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
	var t := Prof.t0()
	_frame(delta)
	Prof.add(&"chef.process", t)


func _frame(delta: float) -> void:
	if puppet and _has_target:
		var t := 1.0 - exp(-Tuning.PUPPET_SMOOTH * delta)
		global_position = global_position.lerp(_target_pos, t)
		rotation.y = lerp_angle(rotation.y, _target_yaw, t)
	elif not puppet:
		flags = host_flags()
	_animate(delta)


## Fill ChefAnim's state from what every peer knows (observed motion, flags, held item) and run it.
func _animate(delta: float) -> void:
	if anim == null or delta <= 0.0:
		return
	var st := anim.state
	var p := global_position
	if not _anim_started:
		_anim_started = true
		_last_pos = p
		_last_yaw = rotation.y
	var v := (p - _last_pos) / delta
	_last_pos = p
	st.vel = Vector3(v.x, 0.0, v.z)
	st.vy = v.y
	st.turn_rate = lerpf(st.turn_rate, wrapf(rotation.y - _last_yaw, -PI, PI) / delta, 1.0 - exp(-12.0 * delta))
	_last_yaw = rotation.y
	st.yaw = rotation.y
	var held := _held_item()
	st.carrying = held_id >= 0
	if held != null:
		st.weight = held.weight()
		st.carriers = maxi(1, held.carrier_count)
		# Hands reach forward to the near edge of the held food, at its middle height (carry visuals).
		var reach := clampf(held.footprint_distance(global_position) - 0.1, 0.2, 0.7)
		var up := clampf(held.global_position.y + held.size.y * 0.5 - global_position.y - 0.45, 0.0, 0.5)
		st.hold = Vector3(0, up, reach)
	elif not st.carrying:
		st.weight = 1
		st.carriers = 1
	if _prev_held >= 0 and held_id < 0:
		st.toss = true
	_prev_held = held_id
	st.working = (flags & FLAG_WORKING) != 0
	st.punching = (flags & FLAG_PUNCHING) != 0
	st.falling = (flags & FLAG_RESPAWNING) != 0
	var w := get_parent() as World
	if w != null:
		_work_scan -= delta
		if st.working and (not _was_working or _work_scan <= 0.0):
			_work_scan = 0.5
			st.work_kind = _work_kind(w)
		_check_bells(w)
	_was_working = st.working
	anim.update(delta)
	if _anim_log >= 0.0:
		_anim_log -= delta
		if _anim_log < 0.0:
			_anim_log = 1.0
			print("anim: chef %d %s %s" % [peer_id, "puppet" if puppet else "host-sim", anim.debug_line()])


## Which station this chef works at (nearest one within reach): every peer works it out from positions.
func _work_kind(w: World) -> int:
	var best := Tuning.REACH + 0.4
	var kind := ChefAnim.Work.NONE
	for stn: Station in w.stations:
		var k := ChefAnim.Work.NONE
		if stn is SodaFountain:
			k = ChefAnim.Work.SODA
		elif stn is Dispenser:
			k = ChefAnim.Work.DISPENSE
		elif stn is CuttingBoard:
			k = ChefAnim.Work.CHOP
		elif stn is Bell:
			k = ChefAnim.Work.BELL
		else:
			continue
		var d := stn.footprint_distance(global_position)
		if d < best:
			best = d
			kind = k
	return kind


## A bell rang (its replicated ring counter moved): the chef nearest to it slaps it.
func _check_bells(w: World) -> void:
	var n := w.bells.size()
	if _bell_seen.size() != n:
		_bell_seen.resize(n)
		for i in n:
			_bell_seen[i] = int(w.bells[i].state())
		return
	for i in n:
		var b: Bell = w.bells[i]
		var seq := int(b.state())
		if seq == _bell_seen[i]:
			continue
		_bell_seen[i] = seq
		var mine := b.footprint_distance(global_position)
		if mine > Tuning.REACH + 0.5:
			continue
		var nearest := true
		for c: Chef in w.chefs.values():
			if c != self and b.footprint_distance(c.global_position) < mine:
				nearest = false
		if nearest:
			anim.state.slap = true


## Team moments every peer receives: a serve (celebrate), a failure (slump), this chef's ping (point).
func _on_net_event(text: String, sfx: String) -> void:
	if anim == null:
		return
	match sfx:
		"serve":
			anim.state.celebrate = true
		"fail":
			anim.state.fail = true
		"ping":
			var parts := text.split(":")
			if parts.size() == 3 and int(parts[0]) == peer_id:
				var to := Vector3(float(parts[1]), 0.0, float(parts[2])) - global_position
				to.y = 0.0
				anim.state.ping_dir = to.rotated(Vector3.UP, -rotation.y)
				anim.state.ping = true


## The food this chef holds, on any peer (held_id is replicated; items live in the World).
func _held_item() -> Item:
	if held_id < 0:
		return null
	var w := get_parent() as World
	if w == null:
		return null
	var it: Item = w.items.get(held_id)
	return it if it != null and is_instance_valid(it) and not it.removed else null
