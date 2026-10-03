class_name Progress
extends RefCounted
## Local progress saved to user://progress.cfg (static, no autoload; lazy-loaded, saved on every change).
##   [best]     "<map>|<difficulty>" = best coins earned in one shift
##   [mission_N] stars (0..3), best_coins     (N = mission id = index in Missions.LIST)
##   [wardrobe] tokens (int), owned (Array of "<category>:<id>", paid items only)
##   [equipped] color (-1 = my slot's colour), hat, acc, beard, outfit, back, body  (my look; Net.local_look)
## Best coins / stars are written on the host (StatsSystem, campaign logic). Tokens are earned by EVERY peer
## for itself at shift end (award_shift, from the replicated results info) and spent in the Wardrobe.
## Wardrobe trust model: tokens and ownership are local and unchecked (a friends game); the host accepts any
## catalogue id in a look (Net._store_look).
##
## Automated runs never write the file (same rule as user://settings.cfg: Quality.is_test_run(), plus
## --tokens= / --look=, which set test values in memory). Test args: --tokens=<n> sets the wallet in memory;
## --progress-file=<abs path> uses (and writes) that file instead, for throwaway purchase tests.
## First load without an [equipped] section migrates the old look from user://menu.cfg [chef] (the retired
## acc "moustache" becomes beard "handlebar"; paid items worn then are granted).

const PATH := "user://progress.cfg"
const OLD_LOOK_CFG := "user://menu.cfg"
const LOOK_KEYS := ["color", "hat", "acc", "beard", "outfit", "back", "body"]

static var _cfg: ConfigFile = null
static var last_award := 0   ## tokens added by the latest award_shift (the results screen shows it)


static func _c() -> ConfigFile:
	if _cfg == null:
		_cfg = ConfigFile.new()
		_cfg.load(_path())   # missing file is fine
		_migrate()
		var t := _arg("tokens")
		if t != "":
			_cfg.set_value("wardrobe", "tokens", maxi(0, int(t)))   # memory only (can_save() is false)
	return _cfg


static func _save() -> void:
	if can_save():
		_c().save(_path())


static func _path() -> String:
	var p := _arg("progress-file")
	return p if p != "" else PATH


## False for bot / agent / bench runs and test wallets: they keep the player's file untouched.
static func can_save() -> bool:
	if _arg("progress-file") != "":
		return true
	if _arg("tokens") != "" or _arg("look") != "":
		return false
	return not Quality.is_test_run()


static func _arg(key: String) -> String:
	for a in OS.get_cmdline_user_args():
		if a == "--" + key:
			return "true"
		if a.begins_with("--" + key + "="):
			return a.trim_prefix("--" + key + "=")
	return ""


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


# ---------------------------------------------------------------- wardrobe: tokens

static func tokens() -> int:
	return int(_c().get_value("wardrobe", "tokens", 0))


static func add_tokens(n: int) -> void:
	if n == 0:
		return
	_c().set_value("wardrobe", "tokens", maxi(0, tokens() + n))
	_save()


## Tokens a shift's results earn every player: floor(team coins earned / 60) + 4 x campaign stars
## (info = the RESULTS phase info every peer receives: "earned", and "stars" on campaign missions).
static func shift_award(info: Dictionary) -> int:
	var coins := maxi(0, int(info.get("earned", 0)))
	var stars := clampi(int(info.get("stars", 0)), 0, 3) if info.has("stars") else 0
	return coins / 60 + 4 * stars


## Every peer at shift end: add this shift's award to my wallet. Returns it (also kept in last_award).
static func award_shift(info: Dictionary) -> int:
	var n := shift_award(info)
	last_award = n
	add_tokens(n)
	return n


# ---------------------------------------------------------------- wardrobe: ownership

static func _owned() -> Array:
	return Array(_c().get_value("wardrobe", "owned", []))


## Free items are always owned; unknown items never.
static func owns(cat: String, id: String) -> bool:
	if not Cosmetics.has_item(cat, id):
		return false
	return Cosmetics.is_free(cat, id) or _owned().has("%s:%s" % [cat, id])


## Spend the price and own the item. True when owned afterwards (already owned costs nothing);
## false for an unknown item or too few tokens.
static func buy(cat: String, id: String) -> bool:
	if not Cosmetics.has_item(cat, id):
		return false
	if owns(cat, id):
		return true
	var p := Cosmetics.price(cat, id)
	if tokens() < p:
		return false
	_grant(cat, id)
	_c().set_value("wardrobe", "tokens", tokens() - p)
	_save()
	return true


static func _grant(cat: String, id: String) -> void:
	var o := _owned()
	var key := "%s:%s" % [cat, id]
	if not o.has(key):
		o.append(key)
		_c().set_value("wardrobe", "owned", o)


# ---------------------------------------------------------------- wardrobe: equipped look

## My saved look (Net.local_look shape): color (-1 = slot colour) and one id per category (catalogue
## default when missing). Ids are not validated here; Net.resolve_look does that.
static func equipped() -> Dictionary:
	var out := {"color": int(_c().get_value("equipped", "color", -1))}
	for cat: String in Cosmetics.CATEGORIES:
		out[cat] = str(_c().get_value("equipped", cat, Cosmetics.default_id(cat)))
	return out


## Save the look keys present in look (partial looks are fine).
static func set_equipped(look: Dictionary) -> void:
	var changed := false
	for k: String in LOOK_KEYS:
		if not look.has(k):
			continue
		var v: Variant = int(look[k]) if k == "color" else str(look[k])
		if not _c().has_section_key("equipped", k) or _c().get_value("equipped", k) != v:
			_c().set_value("equipped", k, v)
			changed = true
	if changed:
		_save()


## Old saves kept the look in menu.cfg [chef]; move it here once (and own any paid item worn back then).
static func _migrate() -> void:
	if _cfg.has_section("equipped"):
		return
	var old := ConfigFile.new()
	if old.load(OLD_LOOK_CFG) != OK or not old.has_section("chef"):
		return
	var look := {}
	for k: String in LOOK_KEYS:
		if old.has_section_key("chef", k):
			look[k] = old.get_value("chef", k)
	for key: String in Cosmetics.RETIRED:
		var parts := key.split(":")
		if str(look.get(parts[0], "")) == parts[1]:
			look.merge(Cosmetics.RETIRED[key], true)
	for k: String in look:
		if k == "color":
			_cfg.set_value("equipped", k, int(look[k]))
		elif Cosmetics.has_item(k, str(look[k])):
			_cfg.set_value("equipped", k, str(look[k]))
			if not Cosmetics.is_free(k, str(look[k])):
				_grant(k, str(look[k]))
	print("progress: migrated the chef look from %s [chef]: %s" % [OLD_LOOK_CFG, look])
	_save()
