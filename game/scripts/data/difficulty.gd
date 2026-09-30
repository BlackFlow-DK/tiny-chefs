class_name Difficulty
extends RefCounted
## Difficulty presets and modifier ids (docs/design/overnight-1.md section 5). Pure data + maths:
## a preset scales a ShiftDef; modifiers are independent toggles whose effects live in their own systems
## (they read `world.shift.def["modifiers"]`). Labels and one-line descriptions here are for the lobby UI.

## Multipliers on a ShiftDef. interval/patience/target scale the order flow; burn scales the burn window
## (cooked -> burnt time, read as ShiftDef "burn_scale"). bursts: orders arrive in bursts (chaos).
const PRESETS := {
	"easy": {"label": "Easy", "desc": "Slower orders, patient customers, lower targets, forgiving griddle.",
		"interval": 1.3, "patience": 1.3, "target": 0.7, "burn": 1.5, "bursts": false},
	"normal": {"label": "Normal", "desc": "The kitchen as intended.",
		"interval": 1.0, "patience": 1.0, "target": 1.0, "burn": 1.0, "bursts": false},
	"hard": {"label": "Hard", "desc": "Faster orders, impatient customers, higher targets, food burns sooner.",
		"interval": 0.8, "patience": 0.85, "target": 1.3, "burn": 0.8, "bursts": false},
	"chaos": {"label": "Chaos", "desc": "Orders pour in bursts, nobody waits, food burns in a blink.",
		"interval": 0.65, "patience": 0.7, "target": 1.6, "burn": 0.6, "bursts": true},
}

## Display order for the UI.
const PRESET_IDS := ["easy", "normal", "hard", "chaos"]

const MODIFIERS := {
	"rush_hour": {"label": "Rush Hour", "desc": "Orders arrive in bursts of 2 to 3."},
	"heavy_hands": {"label": "Heavy Hands", "desc": "Every ingredient weighs one more: carry together."},
	"slippery": {"label": "Slippery Floor", "desc": "Loose food slides far and chefs skid."},
	"mystery_orders": {"label": "Mystery Orders", "desc": "Tickets show only the dish name, not the ingredients."},
	"no_shop": {"label": "No Shop", "desc": "No upgrades between shifts."},
	"lights_out": {"label": "Lights Out", "desc": "The room is dim; each chef carries a lamp."},
}

## Display order for the UI.
const MODIFIER_IDS := ["rush_hour", "heavy_hands", "slippery", "mystery_orders", "no_shop", "lights_out"]


static func has_preset(id: String) -> bool:
	return PRESETS.has(id)


static func has_modifier(id: String) -> bool:
	return MODIFIERS.has(id)


static func preset(id: String) -> Dictionary:
	return PRESETS.get(id, PRESETS["normal"])


static func label(id: String) -> String:
	if PRESETS.has(id):
		return str(PRESETS[id]["label"])
	if MODIFIERS.has(id):
		return str(MODIFIERS[id]["label"])
	return id


static func desc(id: String) -> String:
	if PRESETS.has(id):
		return str(PRESETS[id]["desc"])
	if MODIFIERS.has(id):
		return str(MODIFIERS[id]["desc"])
	return ""


## Returns a copy of shift_def scaled by the preset (unknown id = normal). Sets "difficulty",
## "burn_scale" (multiplies any existing one) and "bursts". Normal leaves every number unchanged.
static func apply(shift_def: Dictionary, preset_id: String) -> Dictionary:
	var p := preset(preset_id)
	var d := shift_def.duplicate(true)
	d["interval"] = float(d.get("interval", 30.0)) * float(p["interval"])
	d["patience"] = float(d.get("patience", 100.0)) * float(p["patience"])
	d["target"] = int(round(float(d.get("target", 0)) * float(p["target"])))
	d["burn_scale"] = float(d.get("burn_scale", 1.0)) * float(p["burn"])
	d["bursts"] = bool(d.get("bursts", false)) or bool(p["bursts"])
	d["difficulty"] = preset_id if PRESETS.has(preset_id) else "normal"
	return d
