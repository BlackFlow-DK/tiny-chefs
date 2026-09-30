class_name World
extends Node3D
## The kitchen for a whole run (all shifts). Thin owner: holds the shared state (chefs, items, stations,
## shift, orders, inputs), creates the systems in systems/ and runs them in a fixed order each tick.
## It is the single target Net forwards to (receive_input, apply_snapshot, try_buy) and the world-level
## API stations, bots and systems call; systems never call each other directly. Map: docs/systems.md.

var is_host := false
var my_id := 1
var items: Dictionary = {}   # item id -> Item
var chefs: Dictionary = {}   # peer id -> Chef
var inputs: Dictionary = {}  # host: peer id -> PlayerInput
var stations: Array = []
var dispensers: Array = []
var griddle: Griddle
var board: CuttingBoard
var plate: Plate
var bell: Bell
var trash: Trash
var shift := ShiftManager.new()
var orders := OrderManager.new()
var camera: Camera3D          # created by CameraSystem
var local_input := PlayerInput.new()
var input_blocked := false   # pause menu open
var hint_text := ""          # written by HintSystem
var grab_target: Item = null
var work_target: Station = null

var _idle := PlayerInput.new()
var _next_item_id := 1
var _tick := 0
var _toast_cooldown := 0.0

var _roster_sys: RosterSystem
var _input_sys: InputSystem
var _carry_sys: CarrySystem
var _punch_sys: PunchSystem
var _bounds_sys: BoundsSystem
var _dispenser_sys: DispenserSystem
var _griddle_sys: GriddleSystem
var _board_sys: CuttingBoardSystem
var _plate_sys: PlateSystem
var _shift_sys: ShiftSystem
var _snapshot_sys: SnapshotSystem
var _camera_sys: CameraSystem
var _hint_sys: HintSystem


func _ready() -> void:
	name = "World"
	is_host = Net.is_host
	my_id = Net.my_id()
	Net.world = self
	Kitchen.build(self)
	_build_stations()
	_roster_sys = RosterSystem.new(self)
	_carry_sys = CarrySystem.new(self)
	_punch_sys = PunchSystem.new(self)
	_bounds_sys = BoundsSystem.new(self)
	_dispenser_sys = DispenserSystem.new(self)
	_griddle_sys = GriddleSystem.new(self)
	_board_sys = CuttingBoardSystem.new(self)
	_plate_sys = PlateSystem.new(self)
	_shift_sys = ShiftSystem.new(self)
	_snapshot_sys = SnapshotSystem.new(self)
	_camera_sys = CameraSystem.new(self)   # adds the camera, then the hint rings, as before
	_hint_sys = HintSystem.new(self)
	_input_sys = InputSystem.new(self)
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


func _build_stations() -> void:
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


# ================================================================ Net targets

func _on_players_changed() -> void:
	_roster_sys.sync()


func _on_phase_changed(ph: int) -> void:
	if is_host and ph == Net.Phase.PLAYING:
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
	_input_sys.collect(dt)
	if is_host:
		var mine: PlayerInput = inputs.get(my_id)
		if mine != null:
			mine.copy_from(local_input)
		_simulate(dt)
		_tick += 1
		if _tick % Tuning.SNAPSHOT_EVERY == 0:
			Net.send_snapshot(_snapshot_sys.build())
	else:
		Net.send_input(local_input)
	Net.metric_max("max_chefs_seen", chefs.size())


## Host tick, fixed order: chef actions + walking, carrying, edge, cooldowns, stations, falls, shift.
func _simulate(dt: float) -> void:
	var playing := Net.phase == Net.Phase.PLAYING
	var mult := Tuning.SHOES_MULT if shift.has_upgrade("shoes") else 1.0
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
	_carry_sys.move_carried(dt, mult, playing)
	_bounds_sys.drop_over_edge()
	_plate_sys.tick(dt)
	for s in stations:
		s.host_update(dt)
	_bounds_sys.remove_fallen()
	_toast_cooldown -= dt
	_shift_sys.tick(dt, playing)


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


# ================================================================ world-level API (host unless noted)

## Input for a chef this tick (idle when none).
func input_of(id: int) -> PlayerInput:
	return inputs.get(id, _idle)


func start_shift() -> void:
	_shift_sys.start_shift()


func note_orders_changed() -> void:
	_shift_sys.sync_order_count()


## Every peer: the food chef c would grab with input inp (aim first; see CarrySystem.grab_candidate).
func grab_candidate(c: Chef, inp: PlayerInput) -> Item:
	return _carry_sys.grab_candidate(c, inp)


func release(c: Chef, sound := false) -> void:
	_carry_sys.release(c, sound)


func detach_all(it: Item) -> void:
	_carry_sys.detach_all(it)


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


func chop(tom: Item) -> void:
	_board_sys.chop(tom)


func refuse_from_plate(it: Item, p: Station) -> void:
	_plate_sys.refuse_from_plate(it, p)


## Rate-limited toast + sound for everyone (1.5 s shared cooldown).
func toast(msg: String, sfx: String) -> void:
	if _toast_cooldown > 0.0:
		return
	_toast_cooldown = 1.5
	Net.event(msg, sfx)


# ================================================================ presentation (every peer)

func _process(delta: float) -> void:
	_camera_sys.update(delta)
	_hint_sys.update()
	_shift_sys.process_quit(delta)


func _on_event(_text: String, sfx: String) -> void:
	Sfx.play(sfx)
	if sfx == "serve" or sfx == "buzz":
		bell.ring()


func my_chef() -> Chef:
	return chefs.get(my_id)
