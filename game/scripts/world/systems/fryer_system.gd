class_name FryerSystem
extends RefCounted
## Owns the fried/burnt transition of food in the fryer: the kind change and its ding / "burnt" announcement.
## Host only. Slots, fry timers, bars and bubbles live in stations/fryer.gd (Fryer, a Griddle subclass).
## Calls Item.set_kind, Net.event.

var world: World


func _init(w: World) -> void:
	world = w


func change_kind(it: Item, k: String) -> void:
	var was := str(it.kind)
	it.set_kind(k)
	print("content: fryer %s -> %s" % [was, k])
	if k.ends_with("_burnt"):
		world.stats.on_burnt(it)
		Net.event("Something burnt in the fryer!", "fail")
	else:
		Net.event("", "ding")
