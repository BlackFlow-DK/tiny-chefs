class_name ShiftPlan
extends RefCounted
## Builds the ShiftDef for a shift from the run's GameSettings. The ShiftDef is a plain Dictionary
## (it lives in `world.shift.def` on the host, and is rebuilt from `Net.settings` on clients):
##   name: String, index: int (0-based shift of the run), mode: String, mission_id: int (-1 unless campaign),
##   map: String (map id), difficulty: String (preset id), modifiers: Array[String], events: Array[String],
##   objectives: Array[Dictionary] (campaign bonus objectives, see missions.gd; [] otherwise), blurb: String,
##   recipes: Array[String] (only ids present in GameData.RECIPES), duration: float (s), interval: float
##   (s between orders), patience: float (s), target: int (coins), burn_scale: float (multiplies the burn
##   window, Tuning.BURN_TIME), bursts: bool (orders in bursts; chaos preset).
## Order: base values (mission / endless ramp / custom fields) -> Difficulty.apply -> player-count scaling.

## Campaign: mission (settings.mission + shift_index), clamped to the last one.
## Endless: GameData.SHIFTS, then "Overtime k" keeps getting harder. Custom: the settings' custom fields.
static func build(settings: GameSettings, shift_index: int, players: int) -> Dictionary:
	if settings == null:
		settings = GameSettings.new()
	var d: Dictionary
	var preset := settings.difficulty
	match settings.mode:
		"campaign":
			var m := Missions.get_mission(settings.mission + shift_index)
			d = {"name": m["name"], "recipes": m["recipes"], "interval": float(m["interval"]),
				"patience": float(m["patience"]), "duration": float(m["duration"]), "target": int(m["target"]),
				"mission_id": int(m["id"]), "map": str(m["map"]), "modifiers": _strings(m["modifiers"]),
				"events": _strings(m["events"]), "objectives": (m["objectives"] as Array).duplicate(true),
				"blurb": str(m["blurb"])}
			preset = str(m["difficulty"])
		"custom":
			d = {"name": "Custom Shift", "recipes": settings.recipes.duplicate(), "interval": settings.interval,
				"patience": settings.patience, "duration": settings.duration, "target": settings.target}
		_:
			d = _endless_base(shift_index)
	if not d.has("mission_id"):
		d["mission_id"] = -1
		d["map"] = settings.map
		d["modifiers"] = settings.modifiers.duplicate()
		d["events"] = []
		d["objectives"] = []
		d["blurb"] = ""
	d["mode"] = settings.mode if GameSettings.MODES.has(settings.mode) else "endless"
	d["recipes"] = _known_recipes(d["recipes"])
	d = Difficulty.apply(d, preset)
	var extra := maxi(0, players - 1)
	d["interval"] = float(d["interval"]) / (1.0 + Tuning.SCALE_ORDER_RATE_PER_PLAYER * extra)
	d["target"] = int(round(float(d["target"]) * (1.0 + Tuning.SCALE_TARGET_PER_PLAYER * extra)))
	d["index"] = shift_index
	return d


## The map a shift will be played on (campaign missions name their own map).
static func map_for(settings: GameSettings, shift_index: int) -> String:
	if settings != null and settings.mode == "campaign":
		return str(Missions.get_mission(settings.mission + shift_index)["map"])
	return settings.map if settings != null else "diner"


## One line for logs.
static func describe(d: Dictionary) -> String:
	return "#%d \"%s\" mode=%s mission=%d map=%s difficulty=%s modifiers=%s events=%s recipes=%s interval=%.3f patience=%.3f duration=%.1f target=%d burn_scale=%.2f bursts=%s objectives=%s" % [
		int(d.get("index", 0)), d.get("name", ""), d.get("mode", ""), int(d.get("mission_id", -1)), d.get("map", ""),
		d.get("difficulty", ""), ",".join(d.get("modifiers", [])), ",".join(d.get("events", [])),
		",".join(d.get("recipes", [])), float(d.get("interval", 0)), float(d.get("patience", 0)),
		float(d.get("duration", 0)), int(d.get("target", 0)), float(d.get("burn_scale", 1.0)),
		d.get("bursts", false), JSON.stringify(d.get("objectives", []))]


## Today's ramp (one player, normal): the SHIFTS table, then Overtime k.
static func _endless_base(i: int) -> Dictionary:
	var shifts := GameData.SHIFTS
	var d: Dictionary
	if i < shifts.size():
		d = shifts[i].duplicate(true)
	else:
		var k := i - shifts.size() + 1
		d = shifts[shifts.size() - 1].duplicate(true)
		d["name"] = "Overtime %d" % k
		d["interval"] = maxf(Tuning.MIN_ORDER_INTERVAL, float(d["interval"]) * pow(0.88, k))
		d["patience"] = maxf(Tuning.MIN_PATIENCE, float(d["patience"]) * pow(0.94, k))
		d["target"] = int(d["target"]) + 50 * k
	return d


## Drops recipe ids that are not in GameData.RECIPES (content may land later); never empty.
static func _known_recipes(ids: Array) -> Array:
	var out: Array = []
	for r in ids:
		if GameData.recipe_index(str(r)) >= 0 and not out.has(str(r)):
			out.append(str(r))
	if out.is_empty():
		out.append("cheeseburger")
	return out


static func _strings(a: Array) -> Array:
	var out: Array = []
	for x in a:
		out.append(str(x))
	return out
