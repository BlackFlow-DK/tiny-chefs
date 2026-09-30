class_name GriddleSystem
extends RefCounted
## Owns the cooked/burnt transition of food: the kind change and its ding / "burnt" announcement.
## Host only. Slots, cook timers and progress bars live in stations/griddle.gd (Griddle.host_update).
## Calls Item.set_kind, Net.event.

var world: World


func _init(w: World) -> void:
	world = w


func change_kind(it: Item, k: String) -> void:
	it.set_kind(k)
	if k.ends_with("_cooked"):
		Net.event("", "ding")
	elif k.ends_with("_burnt"):
		Net.event("Something burnt on the griddle!", "fail")
