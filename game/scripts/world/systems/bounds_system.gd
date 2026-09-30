class_name BoundsSystem
extends RefCounted
## Owns the counter edge for food: carried food pushed past the edge is let go (it falls), and food
## that fell below the counter is removed. Host only. Chefs falling/respawning lives in Chef.host_move.
## Reads world.items, GameData.COUNTER_SIZE. Calls world.detach_all, world.remove_item.

var world: World


func _init(w: World) -> void:
	world = w


## Right after carry movement: over the edge, everybody lets go and it falls.
func drop_over_edge() -> void:
	var hx := GameData.COUNTER_SIZE.x * 0.5
	var hz := GameData.COUNTER_SIZE.y * 0.5
	for it in world.items.values():
		if it.removed or it.carriers.is_empty():
			continue
		var ip: Vector3 = it.global_position
		if absf(ip.x) > hx or absf(ip.z) > hz:
			world.detach_all(it)


## After the stations: food that fell off the counter is gone.
func remove_fallen() -> void:
	for it in world.items.values():
		if not it.removed and it.global_position.y < -3.0:
			world.remove_item(it)
