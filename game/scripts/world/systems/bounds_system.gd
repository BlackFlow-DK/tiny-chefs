class_name BoundsSystem
extends RefCounted
## Owns the counter edge for food: carried food pushed past the edge is let go (it falls), and food
## that fell below the counter is removed. Host only. Chefs falling/respawning lives in Chef.host_move.
## Reads world.items, world.on_counter (the map's surfaces). Calls world.detach_all, world.remove_item.
## --map-log: prints every food removal after a fall (with where it left the counter).

var world: World
var _log := Net.has_arg("map-log")


func _init(w: World) -> void:
	world = w


## Right after carry movement: over the edge, everybody lets go and it falls.
func drop_over_edge() -> void:
	for it in world.items.values():
		if it.removed or it.carriers.is_empty():
			continue
		var ip: Vector3 = it.global_position
		if not world.on_counter(Vector2(ip.x, ip.z)):
			world.stats.on_dropped(it)
			world.detach_all(it)


## After the stations: food that fell off the counter is gone.
func remove_fallen() -> void:
	for it in world.items.values():
		if not it.removed and it.global_position.y < -3.0:
			if _log:
				var p: Vector3 = it.global_position
				print("map: item %d %s fell off the counter at (%.1f, %.1f), removed" % [it.item_id, it.kind, p.x, p.z])
			world.remove_item(it)
