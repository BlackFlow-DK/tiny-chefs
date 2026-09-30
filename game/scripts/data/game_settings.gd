class_name GameSettings
extends RefCounted
## What kind of run the host has set up (docs/design/overnight-1.md section 6). The host owns the one
## live instance, `Net.settings`; clients hold a read-only copy that Net replaces on every host change.
## Change it only through Net (`Net.change_setting` / `Net.set_settings`); never edit Net.settings in place.
## ShiftPlan.build(settings, shift_index, players) turns it into each shift's ShiftDef.
##
## mode: "campaign" plays Missions.LIST from `mission` onwards (the mission sets map, difficulty,
##   modifiers, recipes; this object's map/difficulty/modifiers are ignored).
## "endless": today's shift ramp on `map` with `difficulty` and `modifiers`.
## "custom": every shift uses duration/recipes/target/interval/patience below, plus map/difficulty/modifiers.

const MODES := ["campaign", "endless", "custom"]
## Map ids until GameData.MAPS exists; map_ids() prefers GameData.MAPS once it lands.
const FALLBACK_MAP_IDS := ["diner", "food_truck", "picnic", "twin_islands"]

## Custom-field limits (validate() clamps into these; the UI can use them for sliders).
const DURATION_RANGE := Vector2(60.0, 600.0)
const TARGET_RANGE := Vector2i(0, 5000)
const INTERVAL_RANGE := Vector2(8.0, 120.0)
const PATIENCE_RANGE := Vector2(30.0, 300.0)

var mode := "endless"
var map := "diner"
var difficulty := "normal"
var modifiers: Array[String] = []
var mission := 0                                     # campaign: first mission index
var duration := 210.0                                # custom: seconds per shift
var recipes: Array[String] = ["cheeseburger", "salad"]  # custom: recipe ids offered
var target := 80                                     # custom: coins for one player
var interval := 40.0                                 # custom: seconds between orders (one player)
var patience := 110.0                                # custom: seconds an order waits


func to_dict() -> Dictionary:
	return {"mode": mode, "map": map, "difficulty": difficulty, "modifiers": modifiers.duplicate(),
		"mission": mission, "duration": duration, "recipes": recipes.duplicate(), "target": target,
		"interval": interval, "patience": patience}


## Missing keys keep their defaults. Does not validate; call validate() on untrusted input.
static func from_dict(d: Dictionary) -> GameSettings:
	var s := GameSettings.new()
	s.mode = str(d.get("mode", s.mode))
	s.map = str(d.get("map", s.map))
	s.difficulty = str(d.get("difficulty", s.difficulty))
	s.modifiers.assign(_strings(d.get("modifiers", s.modifiers)))
	s.mission = int(d.get("mission", s.mission))
	s.duration = float(d.get("duration", s.duration))
	s.recipes.assign(_strings(d.get("recipes", s.recipes)))
	s.target = int(d.get("target", s.target))
	s.interval = float(d.get("interval", s.interval))
	s.patience = float(d.get("patience", s.patience))
	return s


func copy() -> GameSettings:
	return GameSettings.from_dict(to_dict())


func equals(o: GameSettings) -> bool:
	return o != null and to_dict() == o.to_dict()


## Clamps every field into range in place. Returns what it fixed (empty = it was already valid).
func validate() -> Array[String]:
	var fixed: Array[String] = []
	if not MODES.has(mode):
		fixed.append("mode %s -> endless" % mode)
		mode = "endless"
	if not map_ids().has(map):
		fixed.append("map %s -> diner" % map)
		map = "diner"
	if not Difficulty.has_preset(difficulty):
		fixed.append("difficulty %s -> normal" % difficulty)
		difficulty = "normal"
	var mods: Array[String] = []
	for m in modifiers:
		if Difficulty.has_modifier(m) and not mods.has(m):
			mods.append(m)
	if mods != modifiers:
		fixed.append("modifiers %s -> %s" % [modifiers, mods])
		modifiers = mods
	var mi := clampi(mission, 0, Missions.count() - 1)
	if mi != mission:
		fixed.append("mission %d -> %d" % [mission, mi])
		mission = mi
	var rs: Array[String] = []
	for r in recipes:
		if GameData.recipe_index(r) >= 0 and not rs.has(r):
			rs.append(r)
	if rs.is_empty():
		rs.append("cheeseburger")
	if rs != recipes:
		fixed.append("recipes %s -> %s" % [recipes, rs])
		recipes = rs
	var du := clampf(duration, DURATION_RANGE.x, DURATION_RANGE.y)
	var ta := clampi(target, TARGET_RANGE.x, TARGET_RANGE.y)
	var iv := clampf(interval, INTERVAL_RANGE.x, INTERVAL_RANGE.y)
	var pa := clampf(patience, PATIENCE_RANGE.x, PATIENCE_RANGE.y)
	if du != duration or ta != target or iv != interval or pa != patience:
		fixed.append("custom numbers clamped")
	duration = du
	target = ta
	interval = iv
	patience = pa
	return fixed


## One line for logs.
func describe() -> String:
	var s := "mode=%s map=%s difficulty=%s modifiers=%s" % [mode, map, difficulty, ",".join(modifiers)]
	if mode == "campaign":
		s += " mission=%d" % mission
	elif mode == "custom":
		s += " duration=%s recipes=%s target=%d interval=%s patience=%s" % [duration, ",".join(recipes), target, interval, patience]
	return s


## Known map ids: GameData.MAPS keys once that table exists, else FALLBACK_MAP_IDS.
static func map_ids() -> Array:
	var maps: Variant = (GameData as Script).get_script_constant_map().get("MAPS")
	if maps is Dictionary and not (maps as Dictionary).is_empty():
		return (maps as Dictionary).keys()
	return FALLBACK_MAP_IDS


static func _strings(v: Variant) -> Array:
	var out: Array = []
	if v is Array or v is PackedStringArray:
		for x in v:
			out.append(str(x))
	return out
