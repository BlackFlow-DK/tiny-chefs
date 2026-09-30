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


func begin(i: int, players: int, duration_override: float) -> void:
	index = i
	def = GameData.shift_def(i, players)
	if duration_override > 0.0:
		def["duration"] = duration_override
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
	return [index, shift_name(), time_left, coins, earned, target(), served, failed, upgrades, running, next_index]


func from_meta(a: Array) -> void:
	index = a[0]
	def = {"name": a[1], "target": a[5]}
	time_left = a[2]
	coins = a[3]
	earned = a[4]
	served = a[6]
	failed = a[7]
	upgrades = a[8]
	running = a[9]
	next_index = a[10]
