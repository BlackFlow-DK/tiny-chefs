class_name ShiftManager
extends RefCounted
## Shift clock, team wallet, results and owned upgrades (host-authoritative, replicated as meta).

var index := 0
var next_index := 0
var def: Dictionary = {}
var time_left := 0.0
var running := false
var coins := 0            # team wallet, persists for the run
var earned := 0           # this shift: payments minus penalties
var served := 0
var failed := 0
var upgrades: Dictionary = {}  # upgrade id -> owned level (> 0; only owned ids), replicated as is
var objectives: Array = []  # campaign: [type, recipe, n, have, state] per objective (ObjectiveSystem)


## Host: start shift i. The ShiftDef comes from the session settings (ShiftPlan, see shift_plan.gd).
func begin(i: int, players: int, duration_override: float) -> void:
	index = i
	def = ShiftPlan.build(Net.settings, i, players)
	if duration_override > 0.0:
		def["duration"] = duration_override
	if Net.has_arg("target"):   # test helper: --target=<coins> (e.g. walk a campaign run across missions)
		def["target"] = Net.arg_int("target", target())
	print("shift: host def %s" % ShiftPlan.describe(def))
	time_left = float(def["duration"])
	earned = 0
	served = 0
	failed = 0
	running = true


func add_coins(n: int) -> void:
	earned += n
	coins = maxi(0, coins + n)


## Owned level of an upgrade line (0 = not owned). Old ids work (GameData.UPGRADE_ALIASES).
func upgrade_level(id: String) -> int:
	return int(upgrades.get(GameData.upgrade_id(id), 0))


## Cumulative effect at the owned level (GameData.upgrade_total), or `fallback` when not owned.
func upgrade_value(id: String, fallback := 0.0) -> float:
	var lv := upgrade_level(id)
	return GameData.upgrade_total(id, lv) if lv > 0 else fallback


func has_upgrade(id: String) -> bool:
	return upgrade_level(id) > 0


## True when the line's "requires" (another line at some level) is owned.
func requires_met(id: String) -> bool:
	var r := GameData.upgrade_requires(id)
	return r.is_empty() or upgrade_level(str(r[0])) >= int(r[1])


## Price of the next level, or -1 at the max.
func next_price(id: String) -> int:
	return GameData.upgrade_price(id, upgrade_level(id) + 1)


## Host: set a line's level (clamped to 0..max; 0 removes it).
func set_upgrade_level(id: String, level: int) -> void:
	var cid := GameData.upgrade_id(id)
	var lv := clampi(level, 0, GameData.upgrade_max_level(cid))
	if lv <= 0:
		upgrades.erase(cid)
	else:
		upgrades[cid] = lv


## "hot_griddle:5,shoes:2" (sorted; "" when nothing is owned).
func upgrades_text() -> String:
	var keys := upgrades.keys()
	keys.sort()
	var parts := PackedStringArray()
	for k in keys:
		parts.append("%s:%d" % [k, int(upgrades[k])])
	return ",".join(parts)


func target() -> int:
	return int(def.get("target", 0))


func shift_name() -> String:
	return str(def.get("name", ""))


func to_meta() -> Array:
	return [index, shift_name(), time_left, coins, earned, target(), served, failed, upgrades, running, next_index, objectives]


## Client. The full ShiftDef (map, modifiers, events, objectives...) is rebuilt locally from the replicated
## Net.settings when a shift starts; name and target always follow the host.
func from_meta(a: Array) -> void:
	if not def.has("mode") or int(a[0]) != index or (bool(a[9]) and not running):
		def = ShiftPlan.build(Net.settings, int(a[0]), maxi(1, Net.players.size()))
		print("shift: client def %s" % ShiftPlan.describe(def))
	index = a[0]
	def["name"] = a[1]
	def["target"] = a[5]
	time_left = a[2]
	coins = a[3]
	earned = a[4]
	served = a[6]
	failed = a[7]
	upgrades = a[8] if a[8] is Dictionary else {}
	running = a[9]
	next_index = a[10]
	objectives = a[11] if a.size() > 11 else []
