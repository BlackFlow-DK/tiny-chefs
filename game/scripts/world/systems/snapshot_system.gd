class_name SnapshotSystem
extends RefCounted
## Owns the replicated state format: build() on the host (30 Hz via Net.send_snapshot), apply() on clients
## (creates/frees puppet chefs and items, mirrors stations + shift + orders). Changing it changes the wire format.
## Reads/writes world.chefs, world.items, world.shift, world.orders, world.plate/board state(). Calls Net.metrics.

var world: World


func _init(w: World) -> void:
	world = w


func build() -> Dictionary:
	var ci := PackedInt32Array()
	var cf := PackedFloat32Array()
	for id in world.chefs.keys():
		var c: Chef = world.chefs[id]
		ci.append(id)
		ci.append(c.held_id)
		ci.append(c.host_flags())
		var p := c.global_position
		cf.append(p.x)
		cf.append(p.y)
		cf.append(p.z)
		cf.append(c.rotation.y)
	var ii := PackedInt32Array()
	var fi := PackedFloat32Array()
	for id in world.items.keys():
		var it: Item = world.items[id]
		if it.removed:
			continue
		ii.append(id)
		ii.append(GameData.kind_index(it.kind))
		ii.append(it.carrier_count)
		ii.append(it.bar_kind | (16 if it.cooking else 0))
		var p := it.global_position
		var q := it.global_transform.basis.get_rotation_quaternion()
		fi.append(p.x)
		fi.append(p.y)
		fi.append(p.z)
		fi.append(q.x)
		fi.append(q.y)
		fi.append(q.z)
		fi.append(q.w)
		fi.append(it.bar)
	return {"c": ci, "cf": cf, "i": ii, "if": fi, "m": _meta()}


func _meta() -> Dictionary:
	return {"s": world.shift.to_meta(), "o": world.orders.to_meta(), "p": world.plate.state(), "b": world.board.state(),
		"e": world.events.state()}


## Client: mirror the host's snapshot.
func apply(d: Dictionary) -> void:
	var chefs := world.chefs
	var items := world.items
	var ci: PackedInt32Array = d["c"]
	var cf: PackedFloat32Array = d["cf"]
	var seen := {}
	for k in range(0, ci.size(), 3):
		var id := ci[k]
		var j := (k / 3) * 4
		seen[id] = true
		var c: Chef = chefs.get(id)
		if c == null:
			c = Chef.new()
			c.setup(id, Net.slot_of(id), Net.name_of(id), true, id == world.my_id)
			world.add_child(c)
			chefs[id] = c
		c.held_id = ci[k + 1]
		c.flags = ci[k + 2]
		c.set_target(Vector3(cf[j], cf[j + 1], cf[j + 2]), cf[j + 3])
	for id in chefs.keys():
		if not seen.has(id):
			chefs[id].queue_free()
			chefs.erase(id)
	var ii: PackedInt32Array = d["i"]
	var fi: PackedFloat32Array = d["if"]
	seen = {}
	for k in range(0, ii.size(), 4):
		var id := ii[k]
		var j := (k / 4) * 8
		seen[id] = true
		var kind: String = GameData.ITEM_KINDS[ii[k + 1]]
		var it: Item = items.get(id)
		if it == null:
			it = Item.new()
			it.setup(id, kind, true)
			world.add_child(it)
			items[id] = it
		else:
			it.set_kind(kind)
		it.carrier_count = ii[k + 2]
		it.bar_kind = ii[k + 3] & 15
		it.set_cooking((ii[k + 3] & 16) != 0)
		it.bar = fi[j + 7]
		it.set_target(Vector3(fi[j], fi[j + 1], fi[j + 2]), Quaternion(fi[j + 3], fi[j + 4], fi[j + 5], fi[j + 6]).normalized())
	for id in items.keys():
		if not seen.has(id):
			items[id].queue_free()
			items.erase(id)
	var m: Dictionary = d["m"]
	var shift := world.shift
	shift.from_meta(m["s"])
	world.orders.from_meta(m["o"])
	world.plate.apply_state(m["p"])
	world.board.apply_state(m["b"])
	if m.has("e"):
		world.events.apply_state(m["e"])
	var gloves := shift.has_upgrade("gloves")
	for c in chefs.values():
		c.set_gloves(gloves)
	if int(Net.metrics["coins_start"]) < 0:
		Net.metrics["coins_start"] = shift.coins
	Net.metric_max("coins_max", shift.coins)
	Net.metrics["coins_final"] = shift.coins
	Net.metrics["orders_served"] = maxi(int(Net.metrics["orders_served"]), shift.served)
