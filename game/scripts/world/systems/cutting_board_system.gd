class_name CuttingBoardSystem
extends RefCounted
## Owns the result of a finished chop: the whole food is replaced by its "chop_count" pieces
## (default Tuning.CHOP_SLICES; a potato gives one cut potato). Host only. Chop progress, worker count and
## the knife animation live in stations/cutting_board.gd.
## Reads Item.def["chops_to"/"chop_count"]. Calls world.remove_item, world.spawn_item, Net.event.

var world: World


func _init(w: World) -> void:
	world = w


func chop(food: Item) -> void:
	var pos := food.global_position
	var k := str(food.def["chops_to"])
	var n := int(food.def.get("chop_count", Tuning.CHOP_SLICES))
	print("content: board %s -> %d x %s" % [food.kind, n, k])
	world.remove_item(food)
	for i in n:
		world.spawn_item(k, Vector3(pos.x + (float(i) - float(n - 1) * 0.5) * 2.3, 0.6, pos.z))
	Net.event("", "pop")