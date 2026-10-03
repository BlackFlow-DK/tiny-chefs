class_name ObjectiveSystem
extends RefCounted
## Campaign objectives (host). Objective 1 is always the shift target (1 star); then up to two bonus
## objectives from the mission (ShiftDef "objectives": no_burnt, no_expired, serve_n {recipe, n}, earn {n}),
## each +1 star when the target is met. Live state is world.shift.objectives (replicated in the shift meta):
## one entry per objective, [type, recipe, n, have, state] with state PENDING / MET / FAILED.
## Only campaign shifts have objectives (other modes: []). At the end: stars, Progress.set_stars (host).
## Reads world.shift, world.items. Hook: world.note_served(recipe_id) from PlateSystem.

const PENDING := 0
const MET := 1
const FAILED := 2
const MAX_BONUS := 2

var world: World
var _served: Dictionary = {}   # recipe id -> orders served this shift


func _init(w: World) -> void:
	world = w


## Objective entries for a ShiftDef ([] unless campaign). "earn n" scales like the shift target does
## (ShiftPlan.build: difficulty preset "target" multiplier, then x Tuning.target_players_scale(players)),
## so it stays above the target instead of being a free star.
static func build(def: Dictionary, players := 1) -> Array:
	if str(def.get("mode", "")) != "campaign":
		return []
	var out: Array = [["target", "", int(def.get("target", 0)), 0, PENDING]]
	for o in def.get("objectives", []):
		if out.size() > MAX_BONUS:
			break
		var d: Dictionary = o
		var n := int(d.get("n", 0))
		if str(d.get("type", "")) == "earn":
			n = int(round(float(n) * float(Difficulty.preset(str(def.get("difficulty", "normal")))["target"])))
			n = int(round(float(n) * Tuning.target_players_scale(players)))
		out.append([str(d.get("type", "")), str(d.get("recipe", "")), n, 0, PENDING])
	return out


## Every peer: one line for the HUD / intro / results, e.g. "Serve 3x Double Beef Cheeseburger".
static func label(e: Array) -> String:
	var n := int(e[2])
	match str(e[0]):
		"target":
			return "Target: %d coins" % n
		"earn":
			return "Earn %d coins" % n
		"serve_n":
			var i := GameData.recipe_index(str(e[1]))
			var rn: String = str(GameData.RECIPES[i]["name"]) if i >= 0 else str(e[1]).capitalize()
			return "Serve %dx %s" % [n, rn]
		"no_burnt":
			return "Burn nothing"
		"no_expired":
			return "No expired orders"
	return str(e[0]).capitalize()


## Every peer: the live progress part ("1/3"), or "" for pass/fail objectives.
static func progress_text(e: Array) -> String:
	match str(e[0]):
		"target", "earn", "serve_n":
			return "%d/%d" % [mini(int(e[3]), int(e[2])), int(e[2])]
	return ""


## Stars for final entries: 0 when the target (entry 0) is missed, else 1 + bonus objectives met.
static func stars_for(entries: Array) -> int:
	if entries.is_empty() or int(entries[0][4]) != MET:
		return 0
	var s := 0
	for e in entries:
		if int(e[4]) == MET:
			s += 1
	return mini(s, 3)


## Host, after ShiftManager.begin.
func start() -> void:
	_served.clear()
	world.shift.objectives = build(world.shift.def, maxi(1, world.chefs.size()))
	if not world.shift.objectives.is_empty():
		print("objectives: start mission %d %s" % [int(world.shift.def.get("mission_id", -1)), JSON.stringify(world.shift.objectives)])


## Host: an order of recipe_id was served.
func note_served(recipe_id: String) -> void:
	_served[recipe_id] = int(_served.get(recipe_id, 0)) + 1


## Host tick, before the shift clock.
func tick(playing: bool) -> void:
	if playing and world.shift.running and not world.shift.objectives.is_empty():
		_evaluate(false)


## Host, at shift end (before the RESULTS phase): final states, stars, save. Returns extra results info
## (empty unless campaign): mode, mission, objectives, stars, best_stars, stars_before (the host's saved best
## before this shift), next_mission (-1 after the last).
func finish() -> Dictionary:
	var s := world.shift
	if s.objectives.is_empty():
		return {}
	_evaluate(true)
	var stars := stars_for(s.objectives)
	var id := int(s.def.get("mission_id", -1))
	var before := Progress.get_stars(id)
	Progress.set_stars(id, maxi(before, stars))
	var nxt := Net.settings.mission + s.next_index
	var next_id := nxt if nxt < Missions.count() else -1
	for e in s.objectives:
		print("objectives: mission %d %s %s -> %s" % [id, label(e), progress_text(e), ["pending", "met", "failed"][int(e[4])]])
	print("objectives: mission %d stars %d (saved best %d) next mission %d" % [id, stars, Progress.get_stars(id), next_id])
	return {"mode": "campaign", "mission": id, "objectives": s.objectives.duplicate(true), "stars": stars,
		"best_stars": Progress.get_stars(id), "stars_before": before, "next_mission": next_id}


func _evaluate(final: bool) -> void:
	var s := world.shift
	var burnt := -1   # scanned lazily
	for e in s.objectives:
		var n := int(e[2])
		match str(e[0]):
			"target", "earn":
				e[3] = maxi(0, s.earned)
				e[4] = MET if s.earned >= n else (FAILED if final else PENDING)
			"serve_n":
				e[3] = int(_served.get(str(e[1]), 0))
				e[4] = MET if int(e[3]) >= n else (FAILED if final else PENDING)
			"no_expired":
				e[3] = s.failed
				e[4] = FAILED if s.failed > 0 else (MET if final else PENDING)
			"no_burnt":
				if int(e[4]) != FAILED:
					if burnt < 0:
						burnt = _count_burnt()
					if burnt > 0:
						e[3] = burnt
						e[4] = FAILED
					elif final:
						e[4] = MET
			_:
				if final:
					e[4] = FAILED


func _count_burnt() -> int:
	var n := 0
	for it in world.items.values():
		if not it.removed and str(it.kind).ends_with("_burnt"):
			n += 1
	return n
