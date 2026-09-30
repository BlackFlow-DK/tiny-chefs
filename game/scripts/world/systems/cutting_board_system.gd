class_name CuttingBoardSystem
extends RefCounted
## Owns the result of a finished chop: the whole food is replaced by CHOP_SLICES slices.
## Host only. Chop progress, worker count and the knife animation live in stations/cutting_board.gd.
## Reads Item.def["chops_to"]. Calls world.remove_item, world.spawn_item, Net.event.

var world: World


func _init(w: World) -> void:
	world = w


func chop(tom: Item) -> void:
	var pos := tom.global_position
	var k := str(tom.def["chops_to"])
	world.remove_item(tom)
	for i in Tuning.CHOP_SLICES:
		world.spawn_item(k, Vector3(pos.x + (i - 1) * 2.3, 0.6, pos.z))
	Net.event("", "pop")
