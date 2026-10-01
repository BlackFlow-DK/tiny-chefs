class_name GriddleSystem
extends RefCounted
## Owns the cooked/burnt transition of food: the kind change and its ding / crack / "burnt" announcement.
## Host only. Slots, cook timers and progress bars live in stations/griddle.gd (Griddle.host_update).
## Calls Item.set_kind, Net.event.

var world: World


func _init(w: World) -> void:
	world = w


func change_kind(it: Item, k: String) -> void:
	var was := str(it.kind)
	var crack := bool(it.def.get("crack", false))
	it.set_kind(k)
	print("content: griddle %s -> %s" % [was, k])
	if k.ends_with("_burnt"):
		world.stats.on_burnt(it)
		Net.event("Something burnt on the griddle!", "fail")
	elif crack:
		Net.event("", "crack")
	else:
		Net.event("", "ding")
