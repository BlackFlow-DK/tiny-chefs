class_name World
extends Node3D
## The kitchen for a whole run (all shifts).
## Host: simulates chefs, food, stations, orders and the shift, then broadcasts snapshots.
## Client: builds the same static kitchen and mirrors chefs/food/stations from snapshots.
## Everyone: local input (keyboard/pad or --bot), follow camera, interaction highlight + hint.

var is_host := false
var my_id := 1
var items: Dictionary = {}   # item id -> Item
var chefs: Dictionary = {}   # peer id -> Chef
var stations: Array = []
var dispensers: Array = []
var griddle: Griddle
var board: CuttingBoard
var plate: Plate
var bell: Bell
var trash: Trash
var shift := ShiftManager.new()
var orders := OrderManager.new()
var camera: Camera3D
var local_input := PlayerInput.new()
var bot: Bot = null
var input_blocked := false   # pause menu open
var hint_text := ""
var grab_target: Item = null
var work_target: Station = null

var _inputs: Dictionary = {}  # host: peer id -> PlayerInput
var _idle := PlayerInput.new()
var _next_item_id := 1
var _tick := 0
var _cam_ready := false
var _grab_ring: MeshInstance3D
var _work_ring: MeshInstance3D
var _carry_track: Dictionary = {}
var _toast_cooldown := 0.0
var _quit_timer := -1.0
var _total_served := 0
var _last_order_count := 0


func _ready() -> void:
	name = "World"
	is_host = Net.is_host
	my_id = Net.my_id()
	Net.world = self
	Kitchen.build(self)
	for d in GameData.STATIONS:
		var s: Station
		match str(d["type"]):
			"dispenser":
				s = Dispenser.new()
				dispensers.append(s)
			"griddle":
				griddle = Griddle.new()
				s = griddle
			"board":
				board = CuttingBoard.new()
				s = board
			"plate":
				plate = Plate.new()
				s = plate
			"bell":
				bell = Bell.new()
				s = bell
			"trash":
				trash = Trash.new()
				s = trash
			_:
				continue
		s.setup(d, self)
		add_child(s)
		stations.append(s)
	camera = Camera3D.new()
	camera.fov = Tuning.CAMERA_FOV
	camera.far = 500.0
	add_child(camera)
	camera.current = true
	_grab_ring = _make_ring(Color(1.0, 0.88, 0.2))
	_work_ring = _make_ring(Color(0.3, 0.9, 1.0))
	if Net.has_arg("bot"):
		bot = Bot.new(self)
	Net.players_changed.connect(_on_players_changed)
	Net.phase_changed.connect(_on_phase_changed)
	Net.event_received.connect(_on_event)
	if is_host:
		for u in Net.arg_str("upgrades", "").split(",", false):
			if not GameData.upgrade(u).is_empty() and not shift.has_upgrade(u):
				shift.upgrades.append(u)  # --upgrades=gloves,knife,shoes (testing)
		_on_players_changed()
		if Net.phase == Net.Phase.PLAYING:
			start_shift()
	else:
		Net.world_ready()


func _exit_tree() -> void:
	if Net.world == self:
		Net.world = null


func _make_ring(color: Color) -> MeshInstance3D:
	var t := TorusMesh.new()
	t.inner_radius = 0.9
	t.outer_radius = 1.0
	t.rings = 48
	t.ring_segments = 6
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	m.no_depth_test = true
	m.render_priority = 3
	var mi := MeshInstance3D.new()
	mi.mesh = t
	mi.material_override = m
	mi.visible = false
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mi


# ================================================================ players

func _on_players_changed() -> void:
	if is_host:
		for id in Net.players.keys():
			if not chefs.has(id):
				_add_chef(id)
		for id in chefs.keys():
			if not Net.players.has(id):
				_remove_chef(id)
	else:
		for id in chefs.keys():
			chefs[id].set_player_name(Net.name_of(id))


func _add_chef(id: int) -> void:
	var slot := Net.slot_of(id)
	var c := Chef.new()
	c.setup(id, slot, Net.name_of(id), false, id == my_id)
	c.spawn_point = GameData.SPAWN_POINTS[slot % GameData.SPAWN_POINTS.size()]
	add_child(c)
	c.global_position = c.spawn_point + Vector3(0, 0.5, 0)
	c.set_gloves(shift.has_upgrade("gloves"))
	chefs[id] = c
	_inputs[id] = PlayerInput.new()
	if id != my_id:
		Net.event("%s joined the kitchen!" % Net.name_of(id), "pop")


func _remove_chef(id: int) -> void:
	var c: Chef = chefs[id]
	release(c)
	chefs.erase(id)
	_inputs.erase(id)
	c.queue_free()
	Net.event("%s left the kitchen." % c.player_name, "drop")


## Host: a client's input packet.
func receive_input(id: int, move: Vector2, work: bool, grab_seq: int, punch_seq: int, work_seq: int) -> void:
	var inp: PlayerInput = _inputs.get(id)
	if inp == null:
		return
	inp.move = move.limit_length(1.0)
	inp.work = work
	inp.grab_seq = grab_seq
	inp.punch_seq = punch_seq
	inp.work_seq = work_seq


# ================================================================ shift flow (host)

func _on_phase_changed(ph: int) -> void:
	if is_host and ph == Net.Phase.PLAYING:
		start_shift()


func start_shift() -> void:
	for it in items.values():
		remove_item(it)
	plate.clear_stack()
	board.reset()
	griddle.reset()
	for c in chefs.values():
		release(c)
		c.respawn()
	shift.begin(shift.next_index, maxi(1, chefs.size()), Net.arg_float("shift-seconds", 0.0))
	orders.reset()
	_last_order_count = 0
	if int(Net.metrics["coins_start"]) < 0:
		Net.metrics["coins_start"] = shift.coins
	Net.event("Shift %d: %s. Earn %d coins!" % [shift.index + 1, shift.shift_name(), shift.target()], "start")


func _end_shift() -> void:
	shift.running = false
	var met := shift.earned >= shift.target()
	shift.next_index = shift.index + 1 if met else shift.index
	orders.orders.clear()
	for c in chefs.values():
		release(c)
	var info := {"shift": shift.index, "name": shift.shift_name(), "served": shift.served, "failed": shift.failed,
		"earned": shift.earned, "target": shift.target(), "met": met, "coins": shift.coins}
	Net.metrics["shifts_finished"] = int(Net.metrics["shifts_finished"]) + 1
	Net.set_phase(Net.Phase.RESULTS, info)
	if Net.has_arg("quit-after-shift"):
		_quit_timer = 2.0


func try_buy(id: String) -> void:
	if Net.phase != Net.Phase.SHOP and Net.phase != Net.Phase.RESULTS:
		return
	var u := GameData.upgrade(id)
	if u.is_empty() or shift.has_upgrade(id):
		return
	if shift.coins < int(u["price"]):
		Net.event("Not enough coins for %s." % u["name"], "buzz")
		return
	shift.coins -= int(u["price"])
	shift.upgrades.append(id)
	Net.event("Bought %s!" % u["name"], "buy")
	if id == "gloves":
		for c in chefs.values():
			c.set_gloves(true)


# ================================================================ tick

func _physics_process(dt: float) -> void:
	_collect_local_input(dt)
	if is_host:
		var mine: PlayerInput = _inputs.get(my_id)
		if mine != null:
			mine.copy_from(local_input)
		_simulate(dt)
		_tick += 1
		if _tick % Tuning.SNAPSHOT_EVERY == 0:
			Net.send_snapshot(_build_snapshot())
	else:
		Net.send_input(local_input)
	Net.metric_max("max_chefs_seen", chefs.size())


func _collect_local_input(dt: float) -> void:
	if bot != null:
		bot.update(dt, local_input)
		return
	var active := Net.phase == Net.Phase.PLAYING and not input_blocked and get_window().has_focus()
	if not active:
		local_input.move = Vector2.ZERO
		local_input.work = false
		return
	local_input.move = Input.get_vector("move_left", "move_right", "move_up", "move_down")
	local_input.work = Input.is_action_pressed("work")
	if Input.is_action_just_pressed("grab"):
		local_input.grab_seq += 1
	if Input.is_action_just_pressed("punch"):
		local_input.punch_seq += 1
	if Input.is_action_just_pressed("work"):
		local_input.work_seq += 1


func _simulate(dt: float) -> void:
	var playing := Net.phase == Net.Phase.PLAYING
	var mult := Tuning.SHOES_MULT if shift.has_upgrade("shoes") else 1.0
	for id in chefs.keys():
		var c: Chef = chefs[id]
		var inp: PlayerInput = _inputs.get(id, _idle)
		if not c.seq_ready or not playing:
			c.last_grab_seq = inp.grab_seq
			c.last_punch_seq = inp.punch_seq
			c.last_work_seq = inp.work_seq
			c.seq_ready = true
		else:
			_handle_actions(c, inp)
		c.work_held = playing and inp.work
		c.host_move(dt, inp if playing else _idle, mult)
	_move_carried(dt, mult, playing)
	for it in items.values():
		it.refuse_cooldown = maxf(0.0, it.refuse_cooldown - dt)
	for s in stations:
		s.host_update(dt)
	for it in items.values():
		if not it.removed and it.global_position.y < -3.0:
			remove_item(it)
	_toast_cooldown -= dt
	if playing and shift.running:
		shift.time_left -= dt
		for o in orders.update(dt, shift.def):
			shift.add_coins(-Tuning.EXPIRE_PENALTY)
			shift.failed += 1
			Net.event("%s order expired! -%d" % [GameData.RECIPES[int(o["r"])]["name"], Tuning.EXPIRE_PENALTY], "fail")
		if orders.orders.size() > _last_order_count:
			var newest: Dictionary = orders.orders[orders.orders.size() - 1]
			Net.event("New order: %s" % GameData.RECIPES[int(newest["r"])]["name"], "order")
		_last_order_count = orders.orders.size()
		if shift.time_left <= 0.0:
			shift.time_left = 0.0
			_end_shift()
	Net.metric_max("coins_max", shift.coins)
	Net.metrics["coins_final"] = shift.coins


func _handle_actions(c: Chef, inp: PlayerInput) -> void:
	if inp.grab_seq != c.last_grab_seq:
		c.last_grab_seq = inp.grab_seq
		if c.respawn_timer < 0.0:
			if c.holding != null:
				release(c, true)
			else:
				_try_grab(c)
	if inp.punch_seq != c.last_punch_seq:
		c.last_punch_seq = inp.punch_seq
		if shift.has_upgrade("gloves") and c.punch_cd <= 0.0 and c.respawn_timer < 0.0 and c.holding == null:
			_punch(c)
	if inp.work_seq != c.last_work_seq:
		c.last_work_seq = inp.work_seq
		if c.holding == null and c.respawn_timer < 0.0 and bell.footprint_distance(c.global_position) <= Tuning.REACH:
			_serve(c)


# ================================================================ carrying (host)

## The food a chef at p would grab: in reach, best grab_score. Shared with the hint and bots.
func grab_candidate(p: Vector3) -> Item:
	var best: Item = null
	var bs := INF
	for it in items.values():
		if it.removed or absf(it.global_position.y - p.y) > 3.0:
			continue
		if it.footprint_distance(p) > Tuning.REACH:
			continue
		var s: float = it.grab_score(p)
		if s < bs:
			best = it
			bs = s
	return best


func _try_grab(c: Chef) -> void:
	var best := grab_candidate(c.global_position)
	if best == null:
		return
	best.attach(c)
	c.holding = best
	c.held_id = best.item_id
	c.hold_offset = c.global_position - best.global_position
	c.hold_offset.y = 0.0
	c.walk_vel = Vector3.ZERO
	Net.event("", "grab", c.peer_id)
	Net.metrics["grabs"] = int(Net.metrics.get("grabs", 0)) + 1


func release(c: Chef, sound := false) -> void:
	var it := c.holding
	c.holding = null
	c.held_id = -1
	if it != null and is_instance_valid(it):
		it.detach(c)
		if sound:
			Net.event("", "drop", c.peer_id)


func detach_all(it: Item) -> void:
	for c in it.carriers.duplicate():
		c.holding = null
		c.held_id = -1
		it.detach(c)


## Carried food moves with the AVERAGE of its carriers' inputs (opposite inputs cancel) at
## PLAYER_SPEED * clamp(carriers / weight, CARRY_MIN_FACTOR, 1); carriers keep their offsets.
func _move_carried(dt: float, mult: float, playing: bool) -> void:
	var hx := GameData.COUNTER_SIZE.x * 0.5
	var hz := GameData.COUNTER_SIZE.y * 0.5
	for it in items.values():
		if it.removed or it.carriers.is_empty():
			continue
		var sum := Vector3.ZERO
		for c in it.carriers:
			var inp: PlayerInput = _inputs.get(c.peer_id, _idle)
			var mv := inp.move3() if playing else Vector3.ZERO
			sum += mv
			if mv.length() > 0.1:
				c.face(mv, dt)
		var n: int = it.carriers.size()
		var avg := sum / float(n)
		var factor := clampf(float(n) / float(it.weight()), Tuning.CARRY_MIN_FACTOR, 1.0)
		var before: Vector3 = it.global_position
		it.carry_step(avg * Tuning.PLAYER_SPEED * mult * factor * dt)
		var moved: Vector3 = it.global_position - before
		moved.y = 0.0
		for c in it.carriers:
			var p: Vector3 = it.global_position + c.hold_offset
			p.y = c.global_position.y
			c.global_position = p
			c.velocity = moved / dt
		if str(it.kind).begins_with("patty"):
			_track_carry(it.item_id, n, moved.length(), dt)
		var ip: Vector3 = it.global_position
		if absf(ip.x) > hx or absf(ip.z) > hz:
			detach_all(it)  # over the edge: everybody lets go, it falls


func _track_carry(id: int, n: int, dist: float, dt: float) -> void:
	var tr: Dictionary = _carry_track.get(id, {"n": n, "t": 0.0, "d": 0.0})
	if int(tr["n"]) != n:
		tr = {"n": n, "t": 0.0, "d": 0.0}
	tr["t"] = float(tr["t"]) + dt
	tr["d"] = float(tr["d"]) + dist
	if float(tr["t"]) >= 0.5:
		var spd := float(tr["d"]) / float(tr["t"])
		if n == 1:
			Net.metric_max("patty_solo_speed", spd)
		elif spd > 0.5:
			Net.metric_max("patty_duo_speed", spd)
			Net.metrics["patty_duo_seconds"] = float(Net.metrics["patty_duo_seconds"]) + float(tr["t"])
		tr["t"] = 0.0
		tr["d"] = 0.0
	_carry_track[id] = tr


func _punch(c: Chef) -> void:
	c.punch_cd = Tuning.PUNCH_COOLDOWN
	c.punch_anim = 0.25
	Net.event("", "punch")
	Net.metrics["punches"] = int(Net.metrics.get("punches", 0)) + 1
	var fwd := c.facing
	var best: Node3D = null
	var bd := Tuning.PUNCH_RANGE
	for o in chefs.values():
		if o == c or o.respawn_timer >= 0.0:
			continue
		var to: Vector3 = o.global_position - c.global_position
		to.y = 0.0
		var d := maxf(to.length() - 0.4, 0.0)
		if d <= bd and to.normalized().dot(fwd) > 0.3:
			best = o
			bd = d
	for it in items.values():
		if it.removed:
			continue
		var to: Vector3 = it.global_position - c.global_position
		to.y = 0.0
		var d: float = it.footprint_distance(c.global_position)
		if d <= bd and (to.length() < 0.5 or to.normalized().dot(fwd) > 0.3):
			best = it
			bd = d
	if best is Chef:
		var o := best as Chef
		Net.metrics["punch_hits"] = int(Net.metrics.get("punch_hits", 0)) + 1
		release(o)
		o.knock = fwd * Tuning.PUNCH_PLAYER_SPEED
	elif best is Item:
		var it := best as Item
		Net.metrics["punch_hits"] = int(Net.metrics.get("punch_hits", 0)) + 1
		detach_all(it)
		var w := sqrt(float(it.weight()))
		it.linear_velocity = fwd * (Tuning.PUNCH_ITEM_SPEED / w) + Vector3.UP * (Tuning.PUNCH_ITEM_UP / w)
		it.angular_velocity = Vector3(0, 8.0, 0)
		it.refuse_cooldown = 0.3


# ================================================================ stations (host helpers)

func spawn_item(kind: String, pos: Vector3) -> Item:
	var it := Item.new()
	it.setup(_next_item_id, kind, false)
	_next_item_id += 1
	add_child(it)
	it.global_position = pos
	items[it.item_id] = it
	return it


func remove_item(it: Item) -> void:
	if it.removed:
		return
	it.removed = true
	detach_all(it)
	items.erase(it.item_id)
	_carry_track.erase(it.item_id)
	it.queue_free()


func dispense(d: Dispenser) -> void:
	if items.size() + d.gives.size() > Tuning.MAX_LOOSE_ITEMS:
		_toast("The counter is full! Drag food to the trash.", "buzz")
		return
	var spots := d.output_spots()
	for i in d.gives.size():
		spawn_item(d.gives[i], spots[i])
	Net.metrics["dispensed"] = int(Net.metrics.get("dispensed", 0)) + 1
	Net.event("", "pop")


func change_kind(it: Item, k: String) -> void:
	it.set_kind(k)
	if k.ends_with("_cooked"):
		Net.event("", "ding")
	elif k.ends_with("_burnt"):
		Net.event("Something burnt on the griddle!", "fail")


func chop(tom: Item) -> void:
	var pos := tom.global_position
	var k := str(tom.def["chops_to"])
	remove_item(tom)
	for i in Tuning.CHOP_SLICES:
		spawn_item(k, Vector3(pos.x + (i - 1) * 2.3, 0.6, pos.z))
	Net.event("", "pop")


func refuse_from_plate(it: Item, p: Station) -> void:
	var dir := it.global_position - p.global_position
	dir.y = 0.0
	if dir.length() < 0.1:
		dir = Vector3(0, 0, 1)
	it.linear_velocity = dir.normalized() * 9.0 + Vector3.UP * 5.0
	it.refuse_cooldown = 1.2
	var k := str(it.kind)
	var msg := "Chop it on the cutting board first!"
	if k.ends_with("_raw"):
		msg = "Raw! Cook it on the griddle first."
	elif k.ends_with("_burnt"):
		msg = "Burnt food can't be served. Trash it!"
	_toast(msg, "buzz")


func _serve(c: Chef) -> void:
	if plate.stack.is_empty():
		Net.event("Put food on the plate first!", "buzz", c.peer_id)
		return
	var idx := orders.match_plate(plate.stack)
	if idx >= 0:
		var o: Dictionary = orders.orders[idx]
		var r: Dictionary = GameData.RECIPES[int(o["r"])]
		var frac := clampf(float(o["left"]) / float(o["patience"]), 0.0, 1.0)
		var pay := int(r["price"]) + int(round(float(r["bonus"]) * frac))
		shift.add_coins(pay)
		shift.served += 1
		orders.orders.remove_at(idx)
		_last_order_count = orders.orders.size()
		_total_served += 1
		Net.metrics["orders_served"] = _total_served
		(Net.metrics["served_recipes"] as Array).append(r["name"])
		Net.event("%s served! +%d" % [r["name"], pay], "serve")
	else:
		shift.add_coins(-Tuning.WRONG_SERVE_PENALTY)
		Net.event("That matches no order! -%d" % Tuning.WRONG_SERVE_PENALTY, "buzz")
	plate.clear_stack()


func _toast(msg: String, sfx: String) -> void:
	if _toast_cooldown > 0.0:
		return
	_toast_cooldown = 1.5
	Net.event(msg, sfx)


# ================================================================ replication

func _build_snapshot() -> Dictionary:
	var ci := PackedInt32Array()
	var cf := PackedFloat32Array()
	for id in chefs.keys():
		var c: Chef = chefs[id]
		ci.append(id)
		ci.append(c.held_id)
		ci.append(c.host_flags())
		var p := c.global_position
		cf.append(p.x)
		cf.append(p.y)
		cf.append(p.z)
		cf.append(c.rotation.y)
	var ii := PackedInt32Array()
	var fi := PackedFloat32Array()
	for id in items.keys():
		var it: Item = items[id]
		if it.removed:
			continue
		ii.append(id)
		ii.append(GameData.kind_index(it.kind))
		ii.append(it.carrier_count)
		ii.append(it.bar_kind | (16 if it.cooking else 0))
		var p := it.global_position
		var q := it.global_transform.basis.get_rotation_quaternion()
		fi.append(p.x)
		fi.append(p.y)
		fi.append(p.z)
		fi.append(q.x)
		fi.append(q.y)
		fi.append(q.z)
		fi.append(q.w)
		fi.append(it.bar)
	return {"c": ci, "cf": cf, "i": ii, "if": fi, "m": _meta()}


func _meta() -> Dictionary:
	return {"s": shift.to_meta(), "o": orders.to_meta(), "p": plate.state(), "b": board.state()}


## Client: mirror the host's snapshot.
func apply_snapshot(d: Dictionary) -> void:
	var ci: PackedInt32Array = d["c"]
	var cf: PackedFloat32Array = d["cf"]
	var seen := {}
	for k in range(0, ci.size(), 3):
		var id := ci[k]
		var j := (k / 3) * 4
		seen[id] = true
		var c: Chef = chefs.get(id)
		if c == null:
			c = Chef.new()
			c.setup(id, Net.slot_of(id), Net.name_of(id), true, id == my_id)
			add_child(c)
			chefs[id] = c
		c.held_id = ci[k + 1]
		c.flags = ci[k + 2]
		c.set_target(Vector3(cf[j], cf[j + 1], cf[j + 2]), cf[j + 3])
	for id in chefs.keys():
		if not seen.has(id):
			chefs[id].queue_free()
			chefs.erase(id)
	var ii: PackedInt32Array = d["i"]
	var fi: PackedFloat32Array = d["if"]
	seen = {}
	for k in range(0, ii.size(), 4):
		var id := ii[k]
		var j := (k / 4) * 8
		seen[id] = true
		var kind: String = GameData.ITEM_KINDS[ii[k + 1]]
		var it: Item = items.get(id)
		if it == null:
			it = Item.new()
			it.setup(id, kind, true)
			add_child(it)
			items[id] = it
		else:
			it.set_kind(kind)
		it.carrier_count = ii[k + 2]
		it.bar_kind = ii[k + 3] & 15
		it.set_cooking((ii[k + 3] & 16) != 0)
		it.bar = fi[j + 7]
		it.set_target(Vector3(fi[j], fi[j + 1], fi[j + 2]), Quaternion(fi[j + 3], fi[j + 4], fi[j + 5], fi[j + 6]).normalized())
	for id in items.keys():
		if not seen.has(id):
			items[id].queue_free()
			items.erase(id)
	var m: Dictionary = d["m"]
	shift.from_meta(m["s"])
	orders.from_meta(m["o"])
	plate.apply_state(m["p"])
	board.apply_state(m["b"])
	var gloves := shift.has_upgrade("gloves")
	for c in chefs.values():
		c.set_gloves(gloves)
	if int(Net.metrics["coins_start"]) < 0:
		Net.metrics["coins_start"] = shift.coins
	Net.metric_max("coins_max", shift.coins)
	Net.metrics["coins_final"] = shift.coins
	Net.metrics["orders_served"] = maxi(int(Net.metrics["orders_served"]), shift.served)


# ================================================================ presentation (every peer)

func _process(delta: float) -> void:
	_update_camera(delta)
	_update_targets()
	if _quit_timer > 0.0:
		_quit_timer -= delta
		if _quit_timer <= 0.0:
			Net.finish_test()


func _on_event(_text: String, sfx: String) -> void:
	Sfx.play(sfx)
	if sfx == "serve" or sfx == "buzz":
		bell.ring()


func my_chef() -> Chef:
	return chefs.get(my_id)


func _update_camera(delta: float) -> void:
	var target := Vector3(0, 0, 2)
	var me := my_chef()
	if me != null:
		target = me.global_position
		target.y = clampf(target.y, -1.0, 1.0)
	var pitch := deg_to_rad(Tuning.CAMERA_PITCH_DEG)
	var want := target + Vector3(0, sin(pitch), cos(pitch)) * Tuning.CAMERA_DISTANCE
	if not _cam_ready:
		camera.global_position = want
		_cam_ready = me != null
	else:
		camera.global_position = camera.global_position.lerp(want, 1.0 - exp(-Tuning.CAMERA_SMOOTH * delta))
	camera.rotation = Vector3(-pitch, 0, 0)


func _update_targets() -> void:
	grab_target = null
	work_target = null
	hint_text = ""
	var me := my_chef()
	if me == null or Net.phase != Net.Phase.PLAYING or (me.flags & Chef.FLAG_RESPAWNING) != 0:
		_grab_ring.visible = false
		_work_ring.visible = false
		return
	var parts := PackedStringArray()
	var p := me.global_position
	if me.held_id >= 0:
		var held: Item = items.get(me.held_id)
		var t := "E: drop"
		if held != null and held.carrier_count < held.weight():
			t += "   (heavy: %d/%d chefs for full speed)" % [held.carrier_count, held.weight()]
		parts.append(t)
	else:
		grab_target = grab_candidate(p)
		if grab_target != null:
			var w := grab_target.weight()
			parts.append("E: grab %s%s" % [grab_target.label_text(), (" (%d chefs for full speed)" % w) if w > 1 else ""])
		if bell.footprint_distance(p) <= Tuning.REACH:
			work_target = bell
		else:
			for s in dispensers:
				if s.footprint_distance(p) <= Tuning.REACH:
					work_target = s
			if work_target == null and board.has_tomato and board.footprint_distance(p) <= Tuning.REACH + 0.3:
				work_target = board
		if work_target != null:
			parts.append(work_target.work_hint())
	if shift.has_upgrade("gloves"):
		parts.append("Q: punch")
	hint_text = "     ".join(parts)
	_grab_ring.visible = grab_target != null
	if grab_target != null:
		var r := grab_target.radius() + 0.4
		_grab_ring.global_position = grab_target.global_position + Vector3(0, 0.1, 0)
		_grab_ring.scale = Vector3(r, 1, r)
	_work_ring.visible = work_target != null
	if work_target != null:
		var r2 := maxf(work_target.half.x, work_target.half.y) + 0.5
		_work_ring.global_position = work_target.global_position + Vector3(0, 0.12, 0)
		_work_ring.scale = Vector3(r2, 1, r2)
