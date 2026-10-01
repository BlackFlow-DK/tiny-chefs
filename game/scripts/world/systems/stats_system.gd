class_name StatsSystem
extends RefCounted
## Owns the per-player counters (host only): per shift and accumulated per run (the World's lifetime).
## Systems call the on_* hooks; nothing here changes gameplay. At shift end ShiftSystem puts
## `results()` into the RESULTS phase info, so clients show the same numbers, and saves best coins.
##
## Attribution:
##   served   the chef who rings the bell on a matching plate
##   carried  each successful grab
##   assists  once per item, each chef who shared carrying it with another chef (co-carrier of any item)
##   burnt    the chef who last held the food before it burnt (the one who put it on the griddle/fryer);
##            never held -> team only
##   dropped  each carrier of food that goes past the counter edge
##   falls    a chef falling off the map
##   punches  each punch thrown
##   coins    a served dish's pay is split evenly between the bell-ringer and the chefs who carried
##            its items onto the plate (remainder to the bell-ringer)

const COUNTERS := ["served", "carried", "assists", "burnt", "dropped", "falls", "punches", "coins"]

var world: World
var shift_stats: Dictionary = {}   # peer id -> {counter: int}
var run_stats: Dictionary = {}
var team_burnt_unowned := 0        # burnt food nobody ever held (this shift)
var run_team_burnt_unowned := 0

var _touched: Dictionary = {}      # item id -> [peer ids who carried it]
var _last_holder: Dictionary = {}  # item id -> peer id of the last chef who held it
var _assisted: Dictionary = {}     # item id -> [peer ids already credited with an assist]
var _plated: Array = []            # peer ids who carried items now on the plate
var _was_down: Dictionary = {}     # peer id -> was respawning last tick


func _init(w: World) -> void:
	world = w


static func _blank() -> Dictionary:
	var d := {}
	for k in COUNTERS:
		d[k] = 0
	return d


func _add(id: int, key: String, n := 1) -> void:
	for table in [shift_stats, run_stats]:
		if not table.has(id):
			table[id] = _blank()
		table[id][key] = int(table[id][key]) + n


## Shift start: per-shift counters and item tracking reset (run totals stay).
func begin_shift() -> void:
	shift_stats.clear()
	team_burnt_unowned = 0
	_touched.clear()
	_last_holder.clear()
	_assisted.clear()
	_plated.clear()


## Every host tick: chef falls.
func tick() -> void:
	for id in world.chefs.keys():
		var down: bool = world.chefs[id].respawn_timer >= 0.0
		if down and not bool(_was_down.get(id, false)):
			_add(id, "falls")
		_was_down[id] = down


func on_grab(c: Chef, it: Item) -> void:
	var id := c.peer_id
	_add(id, "carried")
	_last_holder[it.item_id] = id
	var t: Array = _touched.get(it.item_id, [])
	if not t.has(id):
		t.append(id)
	_touched[it.item_id] = t
	if it.carriers.size() >= 2:
		var done: Array = _assisted.get(it.item_id, [])
		for o in it.carriers:
			if not done.has(o.peer_id):
				done.append(o.peer_id)
				_add(o.peer_id, "assists")
		_assisted[it.item_id] = done


## Carried food went past the counter edge (before everybody lets go).
func on_dropped(it: Item) -> void:
	for c in it.carriers:
		_add(c.peer_id, "dropped")


func on_burnt(it: Item) -> void:
	var id := int(_last_holder.get(it.item_id, -1))
	if id >= 0:
		_add(id, "burnt")
	else:
		team_burnt_unowned += 1
		run_team_burnt_unowned += 1


func on_punch(c: Chef) -> void:
	_add(c.peer_id, "punches")


## Food snapped onto the plate: remember who carried it.
func on_plated(it: Item) -> void:
	for id in _touched.get(it.item_id, []):
		if not _plated.has(id):
			_plated.append(id)


func on_plate_cleared() -> void:
	_plated.clear()


## The bell rang on a matching plate worth `pay` coins.
func on_serve(ringer: Chef, pay: int) -> void:
	var rid := ringer.peer_id
	_add(rid, "served")
	var who: Array = [rid]
	for id in _plated:
		if not who.has(id):
			who.append(id)
	var share := pay / who.size()
	for id in who:
		_add(id, "coins", share)
	_add(rid, "coins", pay - share * who.size())


## Payload for the results screen: {"players": [[id, name, slot, served, ...]], "run": [...], "team": {...}, "run_team": {...}}.
func results() -> Dictionary:
	return {"players": _rows(shift_stats), "run": _rows(run_stats),
		"team": _team(shift_stats, team_burnt_unowned), "run_team": _team(run_stats, run_team_burnt_unowned)}


func _rows(table: Dictionary) -> Array:
	var ids: Array = []
	for id in world.chefs.keys():
		ids.append(id)
	for id in table.keys():
		if not ids.has(id):
			ids.append(id)
	ids.sort()
	var rows: Array = []
	for id in ids:
		var row: Array = [id, Net.name_of(id), Net.slot_of(id)]
		var d: Dictionary = table.get(id, _blank())
		for k in COUNTERS:
			row.append(int(d[k]))
		rows.append(row)
	return rows


func _team(table: Dictionary, unowned: int) -> Dictionary:
	var t := _blank()
	for d in table.values():
		for k in COUNTERS:
			t[k] = int(t[k]) + int(d[k])
	t["burnt"] = int(t["burnt"]) + unowned
	return t
