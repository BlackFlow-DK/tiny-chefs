class_name SnapshotSystem
extends RefCounted
## Owns the replicated state format: build() on the host (30 Hz via Net.send_snapshot), apply() on clients
## (creates/frees puppet chefs and items, mirrors stations + shift + orders). Changing it changes the wire format.
## Reads/writes world.chefs, world.items, world.shift, world.orders, world.plates/bells/board state(). Calls Net.metrics.

## Items: ii = [id, packed state (_pack_item), tumble (pack_quat)] and fi = [x, y, z, yaw] per item.
const ITEM_INTS := 3
const ITEM_FLOATS := 4

var world: World
var _snap_log := Net.has_arg("snap-log")
var _snap_n := 0


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
		ii.append(_pack_item(it))
		ii.append(pack_quat(it.tumble))
		var p := it.global_position
		fi.append(p.x)
		fi.append(p.y)
		fi.append(p.z)
		fi.append(it.global_transform.basis.get_euler().y)   # loose food never tilts (Item locks x/z)
	var d := {"c": ci, "cf": cf, "i": ii, "if": fi, "m": _meta()}
	_log_size(d)
	return d


## --snap-log: every ~2 s print the encoded snapshot size (var_to_bytes, about what the RPC carries).
func _log_size(d: Dictionary) -> void:
	if not _snap_log:
		return
	_snap_n += 1
	if _snap_n % 60 != 0:
		return
	var n := (d["i"] as PackedInt32Array).size()
	print("snapshot: %d bytes (items part %d bytes) with %d chefs, %d items" % [var_to_bytes(d).size(),
		var_to_bytes({"i": d["i"], "if": d["if"]}).size(), world.chefs.size(), n / ITEM_INTS])


## One int per item: kind (8 bits) | carriers << 8 (4) | bar kind << 12 (4) | cooking << 16 | landing
## counter << 17 (3) | landing power << 20 (3) | bar 0..255 << 23 (8).
static func _pack_item(it: Item) -> int:
	var bar := clampi(roundi(clampf(it.bar, 0.0, 1.0) * 255.0), 0, 255)
	return (GameData.kind_index(it.kind) & 255) | ((it.carrier_count & 15) << 8) | ((it.bar_kind & 15) << 12) \
		| ((1 if it.cooking else 0) << 16) | ((it.land_seq & 7) << 17) | ((it.land_power & 7) << 20) | (bar << 23)


## A unit quaternion in one int: 4 x 8 bits (component * 127 + 128).
static func pack_quat(q: Quaternion) -> int:
	if q.w < 0.0:
		q = -q
	var out := 0
	var c := [q.x, q.y, q.z, q.w]
	for i in 4:
		out |= (clampi(roundi(float(c[i]) * 127.0) + 128, 0, 255)) << (8 * i)
	return out


static func unpack_quat(v: int) -> Quaternion:
	var c: Array[float] = []
	for i in 4:
		c.append(float(((v >> (8 * i)) & 255) - 128) / 127.0)
	var q := Quaternion(c[0], c[1], c[2], c[3])
	return q.normalized() if q.length_squared() > 0.0001 else Quaternion.IDENTITY


func _meta() -> Dictionary:
	var ps: Array = []
	for p in world.plates:
		ps.append(p.state())
	var rings := PackedInt32Array()
	for b in world.bells:
		rings.append(b.state())
	return {"s": world.shift.to_meta(), "o": world.orders.to_meta(), "p": ps, "r": rings, "b": world.board.state(),
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
	for k in range(0, ii.size(), ITEM_INTS):
		var id := ii[k]
		var j := (k / ITEM_INTS) * ITEM_FLOATS
		seen[id] = true
		var pk := ii[k + 1]
		var kind: String = GameData.ITEM_KINDS[pk & 255]
		var it: Item = items.get(id)
		if it == null:
			it = Item.new()
			it.setup(id, kind, true)
			world.add_child(it)
			items[id] = it
		else:
			it.set_kind(kind)
		it.carrier_count = (pk >> 8) & 15
		it.bar_kind = (pk >> 12) & 15
		it.set_cooking(((pk >> 16) & 1) != 0)
		it.bar = float((pk >> 23) & 255) / 255.0
		it.apply_land((pk >> 17) & 7, (pk >> 20) & 7)
		it.set_tumble(unpack_quat(ii[k + 2]))
		it.set_target(Vector3(fi[j], fi[j + 1], fi[j + 2]), Quaternion(Vector3.UP, fi[j + 3]))
	for id in items.keys():
		if not seen.has(id):
			items[id].queue_free()
			items.erase(id)
	var m: Dictionary = d["m"]
	var shift := world.shift
	shift.from_meta(m["s"])
	world.orders.from_meta(m["o"])
	var ps: Array = m["p"]
	for i in mini(ps.size(), world.plates.size()):
		world.plates[i].apply_state(ps[i])
	var rings: PackedInt32Array = m["r"]
	for i in mini(rings.size(), world.bells.size()):
		world.bells[i].apply_state(rings[i])
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
