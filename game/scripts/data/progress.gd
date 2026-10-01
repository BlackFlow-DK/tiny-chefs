class_name Progress
extends RefCounted
## Local progress saved to user://progress.cfg (static, no autoload; lazy-loaded, saved on every change).
##   [best]     "<map>|<difficulty>" = best coins earned in one shift
##   [mission_N] stars (0..3), best_coins     (N = mission id = index in Missions.LIST)
## Written on the host only (best coins at shift end by StatsSystem; stars by the campaign logic).

const PATH := "user://progress.cfg"

static var _cfg: ConfigFile = null


static func _c() -> ConfigFile:
	if _cfg == null:
		_cfg = ConfigFile.new()
		_cfg.load(PATH)   # missing file is fine
	return _cfg


static func _save() -> void:
	_c().save(PATH)


static func _key(map: String, difficulty: String) -> String:
	return "%s|%s" % [map, difficulty]


## Best coins earned in one shift on this map + difficulty (0 if never played).
static func best(map: String, difficulty: String) -> int:
	return int(_c().get_value("best", _key(map, difficulty), 0))


## Keeps the higher value. Returns true when coins is a new best.
static func set_best(map: String, difficulty: String, coins: int) -> bool:
	if coins <= best(map, difficulty):
		return false
	_c().set_value("best", _key(map, difficulty), coins)
	_save()
	return true


static func get_stars(mission_id: int) -> int:
	return int(_c().get_value("mission_%d" % mission_id, "stars", 0))


## Stars only ever go up (a worse replay never removes stars).
static func set_stars(mission_id: int, n: int) -> void:
	n = clampi(n, 0, 3)
	if n <= get_stars(mission_id):
		return
	_c().set_value("mission_%d" % mission_id, "stars", n)
	_save()


static func get_best_coins(mission_id: int) -> int:
	return int(_c().get_value("mission_%d" % mission_id, "best_coins", 0))


## Keeps the higher value. Returns true when coins is a new best.
static func set_best_coins(mission_id: int, coins: int) -> bool:
	if coins <= get_best_coins(mission_id):
		return false
	_c().set_value("mission_%d" % mission_id, "best_coins", coins)
	_save()
	return true


## Mission 0 is always open; mission i opens when mission i-1 has at least one star.
static func is_unlocked(mission_index: int) -> bool:
	return mission_index <= 0 or get_stars(mission_index - 1) >= 1


## Drop the cached file so the next call re-reads it from disk (tests).
static func reload() -> void:
	_cfg = null
