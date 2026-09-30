class_name DispenserSystem
extends RefCounted
## Owns what happens when a dispenser finishes a hold: the loose-food cap and spawning its batch.
## Host only. The hold timer itself lives in stations/dispenser.gd (Dispenser.host_update).
## Reads world.items, Dispenser.gives/output_spots(). Calls world.spawn_item, world.toast, Net.event.

var world: World


func _init(w: World) -> void:
	world = w


func dispense(d: Dispenser) -> void:
	if world.items.size() + d.gives.size() > Tuning.MAX_LOOSE_ITEMS:
		world.toast("The counter is full! Drag food to the trash.", "buzz")
		return
	var spots := d.output_spots()
	for i in d.gives.size():
		world.spawn_item(d.gives[i], spots[i])
	Net.metrics["dispensed"] = int(Net.metrics.get("dispensed", 0)) + 1
	Net.event("", "pop")
