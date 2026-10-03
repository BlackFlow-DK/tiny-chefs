class_name World
extends Node3D
## The kitchen for a whole run (all shifts). Thin owner: holds the shared state (chefs, items, stations,
## shift, orders, inputs), creates the systems in systems/ and runs them in a fixed order each tick.
## It is the single target Net forwards to (receive_input, apply_snapshot, try_buy) and the world-level
## API stations, bots and systems call; systems never call each other directly. Map: docs/systems.md.

var map: Dictionary = {}      # MapDef (GameData.MAPS entry) this World was built from
var is_host := false
var my_id := 1
var items: Dictionary = {}   # item id -> Item
var chefs: Dictionary = {}   # peer id -> Chef
var inputs: Dictionary = {}  # host: peer id -> PlayerInput
var stations: Array = []
var dispensers: Array = []
var griddle: Griddle
var fryer: Fryer            # null on maps without one
var soda: SodaFountain       # null on maps without one; also listed in dispensers
var board: CuttingBoard
var plate: Plate              # first plate / bell of the map (bots and the HUD use these)
var bell: Bell
var plates: Array[Plate] = []  # every plate / bell; each bell serves its nearest plate (Bell.plate)
var bells: Array[Bell] = []
var trash: Trash
var shift := ShiftManager.new()
var stats: StatsSystem       # host: per-player counters (StatsSystem); hooks call world.stats.on_*
var orders := OrderManager.new()
var events: EventSystem      # shift events (vip, inspector, cat_paw): host schedules, every peer shows
var camera: Camera3D          # created by CameraSystem
var local_input := PlayerInput.new()
var input_blocked := false   # pause menu open
var hint_text := ""          # written by HintSystem
var grab_target: Item = null
var grab_plate: Plate = null  # written by HintSystem: a grab press takes this plate's top item
var work_target: Station = null

var _idle := PlayerInput.new()
var _next_item_id := 1
var _tick := 0
var _toast_cooldown := 0.0
var _ping_at: Dictionary = {}   # host: peer id -> time of the last ping (s)

var _roster_sys: RosterSystem
var _input_sys: InputSystem
var _carry_sys: CarrySystem
var _punch_sys: PunchSystem
var _bounds_sys: BoundsSystem
var _dispenser_sys: DispenserSystem
var _griddle_sys: GriddleSystem
var _fryer_sys: FryerSystem
var _board_sys: CuttingBoardSystem
var _plate_sys: PlateSystem
var _shift_sys: ShiftSystem
var _snapshot_sys: SnapshotSystem
var _camera_sys: CameraSystem
var _hint_sys: HintSystem
var _hazard_sys: HazardSystem
var _mod_sys: ModifierSystem
var _objective_sys: ObjectiveSystem


func _ready() -> void:
	name = "World"
	is_host = Net.is_host
	my_id = Net.my_id()
	Net.world = self
	# The host stamps the map id into every phase change (Net.set_phase), so clients build the same map.
	map = GameData.map(str(Net.phase_info.get("map", map_id_for_session())))
	if Net.has_arg("map-log"):
		print("map: %s builds map '%s' (%d surfaces)" % ["host" if is_host else "client", map["id"], map["surfaces"].size()])
	Kitchen.build(self, map)
	_build_stations()
	_roster_sys = RosterSystem.new(self)
	_carry_sys = CarrySystem.new(self)
	_punch_sys = PunchSystem.new(self)
	_bounds_sys = BoundsSystem.new(self)
	_dispenser_sys = DispenserSystem.new(self)
	_griddle_sys = GriddleSystem.new(self)
	_fryer_sys = FryerSystem.new(self)
	_board_sys = CuttingBoardSystem.new(self)
	_plate_sys = PlateSystem.new(self)
	_shift_sys = ShiftSystem.new(self)
	_mod_sys = ModifierSystem.new(self)
	_objective_sys = ObjectiveSystem.new(self)
	stats = StatsSystem.new(self)
	events = EventSystem.new(self)
	_snapshot_sys = SnapshotSystem.new(self)
	_camera_sys = CameraSystem.new(self)   # adds the camera, then the hint rings, as before
	_hint_sys = HintSystem.new(self)
	_input_sys = InputSystem.new(self)
	_hazard_sys = HazardSystem.new(self)   # map hazards (world.map.hazards)
	Net.players_changed.connect(_on_players_changed)
	Net.phase_changed.connect(_on_phase_changed)
	Net.event_received.connect(_on_event)
	if is_host:
		_shift_sys.apply_test_upgrades()
		_on_players_changed()
		if Net.phase == Net.Phase.PLAYING:
			start_shift()
	else:
		Net.world_ready()


func _exit_tree() -> void:
	if Net.world == self:
		Net.world = null
	# Main swaps the World on a map change mid-run: the old one must stop reacting at once.
	if Net.phase_changed.is_connected(_on_phase_changed):
		Net.players_changed.disconnect(_on_players_changed)
		Net.phase_changed.disconnect(_on_phase_changed)
		Net.event_received.disconnect(_on_event)


func _build_stations() -> void:
	for d in map["stations"]:
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
			"fryer":
				fryer = Fryer.new()
				s = fryer
			"soda":
				soda = SodaFountain.new()
				dispensers.append(soda)
				s = soda
			"plate":
				s = Plate.new()
				plates.append(s)
			"bell":
				s = Bell.new()
				bells.append(s)
			"trash":
				trash = Trash.new()
				s = trash
			_:
				continue
		s.setup(d, self)
		add_child(s)
		stations.append(s)
	plate = plates[0] if not plates.is_empty() else null
	bell = bells[0] if not bells.is_empty() else null
	for b in bells:
		for p in plates:
			if b.plate == null or b.centre_distance(p.global_position) < b.centre_distance(b.plate.global_position):
				b.plate = p


# ================================================================ Net targets

func _on_players_changed() -> void:
	_roster_sys.sync()


func _on_phase_changed(ph: int) -> void:
	if is_host and ph == Net.Phase.PLAYING and is_inside_tree():
		start_shift()


## Host: a client's input packet.
func receive_input(id: int, move: Vector2, work: bool, grab_seq: int, punch_seq: int, work_seq: int,
		aim_point := Vector2.ZERO, has_aim := false) -> void:
	var inp: PlayerInput = inputs.get(id)
	if inp == null:
		return
	inp.move = move.limit_length(1.0)
	inp.work = work
	inp.grab_seq = grab_seq
	inp.punch_seq = punch_seq
	inp.work_seq = work_seq
	inp.has_aim = has_aim and aim_point.is_finite()
	if inp.has_aim:
		inp.aim_point = aim_point


## Client: mirror the host's snapshot.
func apply_snapshot(d: Dictionary) -> void:
	_snapshot_sys.apply(d)


## Host: a shop purchase (from Net.buy / Net._buy).
func try_buy(id: String) -> void:
	_shift_sys.try_buy(id)


# ================================================================ tick

func _physics_process(dt: float) -> void:
	var t := Prof.t0()
	_input_sys.collect(dt)
	Prof.add(&"tick.input+bot", t)
	if is_host:
		var mine: PlayerInput = inputs.get(my_id)
		if mine != null:
			mine.copy_from(local_input)
		_simulate(dt)
		_tick += 1
		if _tick % Tuning.SNAPSHOT_EVERY == 0:
			t = Prof.t0()
			var snap := _snapshot_sys.build()
			Prof.add(&"snapshot.build", t)
			t = Prof.t0()
			Net.send_snapshot(snap)
			Prof.add(&"snapshot.send", t)
	else:
		Net.send_input(local_input)
	Net.metric_max("max_chefs_seen", chefs.size())


## Host tick, fixed order: chef actions + walking, carrying, edge, cooldowns, stations, hazards, falls, shift.
func _simulate(dt: float) -> void:
	var playing := Net.phase == Net.Phase.PLAYING
	var mult := move_mult()
	var t := Prof.t0()
	for id in chefs.keys():
		var c: Chef = chefs[id]
		var inp: PlayerInput = inputs.get(id, _idle)
		if not c.seq_ready or not playing:
			c.last_grab_seq = inp.grab_seq
			c.last_punch_seq = inp.punch_seq
			c.last_work_seq = inp.work_seq
			c.seq_ready = true
		else:
			_handle_actions(c, inp)
		c.work_held = playing and inp.work
		c.host_move(dt, inp if playing else _idle, mult)
	Prof.add(&"tick.chefs", t)
	t = Prof.t0()
	_carry_sys.move_carried(dt, mult, playing)
	Prof.add(&"tick.carry", t)
	t = Prof.t0()
	_bounds_sys.drop_over_edge()
	_plate_sys.tick(dt)
	Prof.add(&"tick.bounds+plates", t)
	t = Prof.t0()
	for s in stations:
		if not playing and s is Griddle:
			continue   # griddle + fryer freeze between shifts: nothing burns during results/shop
		s.host_update(dt)
	Prof.add(&"tick.stations", t)
	t = Prof.t0()
	events.tick(dt, playing)
	_hazard_sys.host_tick(dt, playing)
	_bounds_sys.remove_fallen()
	_mod_sys.host_tick(dt)
	stats.tick()
	_toast_cooldown -= dt
	_objective_sys.tick(playing)
	_shift_sys.tick(dt, playing)
	Prof.add(&"tick.events+mods+shift", t)


## Edge-triggered presses (sequence numbers survive packet loss) routed to their system.
func _handle_actions(c: Chef, inp: PlayerInput) -> void:
	if inp.grab_seq != c.last_grab_seq:
		c.last_grab_seq = inp.grab_seq
		_carry_sys.on_grab_pressed(c)
	if inp.punch_seq != c.last_punch_seq:
		c.last_punch_seq = inp.punch_seq
		_punch_sys.on_punch_pressed(c)
	if inp.work_seq != c.last_work_seq:
		c.last_work_seq = inp.work_seq
		_plate_sys.on_work_pressed(c)


# ================================================================ map (every peer)

## Host: the map id this session plays (--map=<id>, else the settings; a campaign mission names its own).
## During a run it is the map of the running shift, or of the next one between shifts (RESULTS/SHOP), so
## the PLAYING phase carries the next mission's map and Main rebuilds the World when it differs.
## Net.set_phase sends it to clients with every phase change.
static func map_id_for_session() -> String:
	if Net.has_arg("map"):
		return Net.arg_str("map", "diner")
	var i := 0
	var w := Net.world as World
	if w != null and is_instance_valid(w):
		i = w.shift.index if w.shift.running else w.shift.next_index
	return ShiftPlan.map_for(Net.settings, i)


## True when xz (world X, Z) is on any counter surface of the map.
func on_counter(xz: Vector2) -> bool:
	return GameData.surfaces_contain(map["surfaces"], xz)


## Bounding rect (x, z, w, h) of all counter surfaces.
func surface_bounds() -> Rect2:
	return GameData.surfaces_bounds(map["surfaces"])


# ================================================================ world-level API (host unless noted)

## Input for a chef this tick (idle when none).
func input_of(id: int) -> PlayerInput:
	return inputs.get(id, _idle)


func start_shift() -> void:
	_shift_sys.start_shift()
	_objective_sys.start()
	events.start_shift()


func note_orders_changed() -> void:
	_shift_sys.sync_order_count()


## An order was served for pay coins (PlateSystem) / expired (ShiftSystem): event hooks (VIP).
func order_served(o: Dictionary, pay: int) -> void:
	_objective_sys.note_served(str(GameData.RECIPES[int(o["r"])]["id"]))
	events.on_order_served(o, pay)


func order_expired(o: Dictionary) -> void:
	events.on_order_expired(o)


## Host, at shift end: campaign objective results (stars saved) merged into the RESULTS info; {} otherwise.
func finish_objectives() -> Dictionary:
	return _objective_sys.finish()


## Every peer: the food chef c would grab with input inp (aim first; see CarrySystem.grab_candidate).
func grab_candidate(c: Chef, inp: PlayerInput) -> Item:
	return _carry_sys.grab_candidate(c, inp)


## Every peer: what a grab press takes: Item, Plate (its top item) or null (CarrySystem.grab_choice).
func grab_choice(c: Chef, inp: PlayerInput) -> Object:
	return _carry_sys.grab_choice(c, inp)


## Every peer: grab reach in m (tongs upgrade), see CarrySystem.grab_reach.
func grab_reach() -> float:
	return _carry_sys.grab_reach()


## Every peer: walk and carry speed multiplier, 1 + shoes value (nothing else about movement changes).
func move_mult() -> float:
	return 1.0 + shift.upgrade_value("shoes", 0.0)


## Every peer, the plate hook of grab selection: [Plate, aim score] whose top item chef c could take
## with input inp, or [] (PlateSystem.take_candidate).
func plate_take_candidate(c: Chef, inp: PlayerInput) -> Array:
	return _plate_sys.take_candidate(c, inp, _carry_sys.grab_reach())


## Host: chef c takes the top item off plate p; returns it as loose food (CarrySystem attaches it).
func take_from_plate(c: Chef, p: Plate) -> Item:
	return _plate_sys.take_top(c, p)


## Every peer: the plate a chef standing at p would scrape by holding work, or null.
func scrape_target(p: Vector3) -> Plate:
	return _plate_sys.scrape_target(p)


func release(c: Chef, sound := false) -> void:
	_carry_sys.release(c, sound)


func detach_all(it: Item) -> void:
	_carry_sys.detach_all(it)


## A system just launched it (punch): drop-momentum effects (slippery) must not overwrite its velocity.
func item_launched(it: Item) -> void:
	_mod_sys.forget_item(it.item_id)


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
	_carry_sys.forget_item(it.item_id)
	it.queue_free()


func dispense(d: Dispenser) -> void:
	_dispenser_sys.dispense(d)


func change_kind(it: Item, k: String) -> void:
	_griddle_sys.change_kind(it, k)


## Host: the fryer finished a stage (FryerSystem).
func fry(it: Item, k: String) -> void:
	_fryer_sys.change_kind(it, k)


func chop(tom: Item) -> void:
	_board_sys.chop(tom)


func refuse_from_plate(it: Item, p: Station, msg := "") -> void:
	_plate_sys.refuse_from_plate(it, p, msg)


## Every peer: the bell within reach of p (nearest), or null.
func bell_near(p: Vector3) -> Bell:
	return _plate_sys.bell_near(p)


## Every peer: this player pings world point xz (x, z). The host checks the cooldown and tells everyone.
func request_ping(xz: Vector2) -> void:
	if xz.is_finite():
		Net.ping(xz)


## Host: peer id pinged xz. One ping per Tuning.PING_COOLDOWN per player; everyone gets a "ping" event
## whose text is "<peer>:<x>:<z>" (IndicatorLayer draws it, the HUD skips it).
func host_ping(id: int, xz: Vector2) -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if not chefs.has(id) or not xz.is_finite() or now - float(_ping_at.get(id, -99.0)) < Tuning.PING_COOLDOWN:
		return
	_ping_at[id] = now
	Net.event("%d:%.2f:%.2f" % [id, xz.x, xz.y], "ping")


## Rate-limited toast + sound for everyone (1.5 s shared cooldown).
func toast(msg: String, sfx: String) -> void:
	if _toast_cooldown > 0.0:
		return
	_toast_cooldown = 1.5
	Net.event(msg, sfx)


# ================================================================ presentation (every peer)

func _process(delta: float) -> void:
	var t := Prof.t0()
	_camera_sys.update(delta)
	_mod_sys.update(delta)
	_hint_sys.update()
	events.process(delta)
	_hazard_sys.client_tick(delta)
	Prof.add(&"world.process(hints,mods,events)", t)


func _on_event(_text: String, sfx: String) -> void:
	Sfx.play(sfx)   # the serving bell rings itself (Bell.ring, replicated); pings are drawn by IndicatorLayer


func my_chef() -> Chef:
	return chefs.get(my_id)
