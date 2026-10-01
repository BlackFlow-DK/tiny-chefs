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
var upgrades: Array = []  # upgrade ids owned
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


func has_upgrade(id: String) -> bool:
	return upgrades.has(id)


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
	upgrades = a[8]
	running = a[9]
	next_index = a[10]
	objectives = a[11] if a.size() > 11 else []
