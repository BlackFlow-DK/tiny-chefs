class_name RosterSystem
extends RefCounted
## Owns which chefs exist: host spawns/removes a Chef (and its PlayerInput slot) as players join/leave;
## clients only refresh name labels (their chefs come from the snapshot).
## Reads Net.players / slot_of / name_of, world.shift upgrades. Writes world.chefs, world.inputs. Calls world.release.

var world: World


func _init(w: World) -> void:
	world = w


## Net.players_changed.
func sync() -> void:
	if world.is_host:
		for id in Net.players.keys():
			if not world.chefs.has(id):
				_add_chef(id)
		for id in world.chefs.keys():
			if not Net.players.has(id):
				_remove_chef(id)
	else:
		for id in world.chefs.keys():
			world.chefs[id].set_player_name(Net.name_of(id))


func _add_chef(id: int) -> void:
	var slot := Net.slot_of(id)
	var c := Chef.new()
	c.setup(id, slot, Net.name_of(id), false, id == world.my_id)
	c.spawn_point = GameData.SPAWN_POINTS[slot % GameData.SPAWN_POINTS.size()]
	world.add_child(c)
	c.global_position = c.spawn_point + Vector3(0, 0.5, 0)
	c.set_gloves(world.shift.has_upgrade("gloves"))
	world.chefs[id] = c
	world.inputs[id] = PlayerInput.new()
	if id != world.my_id:
		Net.event("%s joined the kitchen!" % Net.name_of(id), "pop")


func _remove_chef(id: int) -> void:
	var c: Chef = world.chefs[id]
	world.release(c)
	world.chefs.erase(id)
	world.inputs.erase(id)
	c.queue_free()
	Net.event("%s left the kitchen." % c.player_name, "drop")
