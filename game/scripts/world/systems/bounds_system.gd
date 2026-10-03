class_name BoundsSystem
extends RefCounted
## Owns the counter edge for food: carried food pushed past the edge is let go (it falls), and food
## that fell below the counter is removed. Host only. Chefs falling/respawning lives in Chef.host_move.
## Reads world.items, world.on_counter (the map's surfaces). Calls world.detach_all, world.remove_item.
## --map-log: prints every food removal after a fall (with where it left the counter).

const HANG_SHARE := 0.6   # carried food hanging over an edge by less than this share of its radius is kept

var world: World
var _log := Net.has_arg("map-log")


func _init(w: World) -> void:
	world = w


## Right after carry movement: over the edge, everybody lets go and it falls.
func drop_over_edge() -> void:
	for it in world.items.values():
		if it.removed or it.carriers.is_empty():
			continue
		if _over_edge(it):
			world.stats.on_dropped(it)
			world.detach_all(it)


## Its centre is off every surface and so is the point HANG_SHARE of its radius back towards its first
## carrier. Food never tilts, so loose food can rest with its centre just past an edge (still on the counter
## by part of its collider); without the margin a grab there let go at once (and bounced it further out)
## every time, so nobody, bot or human, could pull it back.
func _over_edge(it: Item) -> bool:
	var ip := Vector2(it.global_position.x, it.global_position.z)
	if world.on_counter(ip):
		return false
	var c := it.carriers[0] as Node3D
	var to := Vector2(c.global_position.x, c.global_position.z) - ip
	if to.length() < 0.01:
		return true
	return not world.on_counter(ip + to.normalized() * minf(it.radius() * HANG_SHARE, to.length()))


## After the stations: food that fell off the counter is gone.
func remove_fallen() -> void:
	for it in world.items.values():
		if not it.removed and it.global_position.y < -3.0:
			if _log:
				var p: Vector3 = it.global_position
				print("map: item %d %s fell off the counter at (%.1f, %.1f), removed" % [it.item_id, it.kind, p.x, p.z])
			world.remove_item(it)
