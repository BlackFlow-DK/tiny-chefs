class_name Dispenser
extends Station
## Hold work next to it for Tuning.DISPENSE_HOLD seconds to spawn its food in front of it.
## One batch per hold: release work and hold again for the next.

var gives: Array = []
var _timers: Dictionary = {}  # peer id -> held seconds, or -1 once spent until released


func build() -> void:
	gives = def["gives"]
	var v := Models.load_model(str(def["model"]))
	if v == null:
		v = Node3D.new()
		var first: Dictionary = GameData.ITEMS[gives[0]]
		var col: Color = first["color"]
		v.add_child(box(Vector3(size.x, 2.2, size.z), col.lerp(Color(0.9, 0.88, 0.84), 0.4), Vector3.ZERO))
		v.add_child(box(Vector3(size.x - 0.6, 0.3, size.z - 0.6), col.lerp(Color(0.2, 0.2, 0.2), 0.25), Vector3(0, 2.2, 0)))
		for k in gives:
			var d: Dictionary = GameData.ITEMS[k]
			var sample := Models.make(k, d["size"], d["color"], d["shape"])
			sample.position = Vector3(0, 2.5 + (0.0 if k == gives[0] else 0.8), 0)
			v.add_child(sample)
	add_child(v)
	add_solid_collider(Vector3(size.x, 3.0, size.z))
	add_label(str(def["label"]), Vector3(0, size.y + 1.6, 0))


## Where spawned food appears (world space): in front of the dispenser, towards the counter centre.
func output_spots() -> Array:
	var out: Array = []
	var n := gives.size()
	for i in n:
		var x := (float(i) - float(n - 1) * 0.5) * 3.6
		out.append(global_position + Vector3(x, 1.2, half.y + 2.2))
	return out


## Where a chef should stand to work it without being hit by the food (bots use this).
func stand_spot() -> Vector3:
	return global_position + Vector3(-half.x + 0.3, 0, half.y + 0.55)


func host_update(dt: float) -> void:
	var active := {}
	for c in workers():
		active[c.peer_id] = true
		var t: float = _timers.get(c.peer_id, 0.0)
		if t < 0.0:
			continue
		t += dt
		if t >= Tuning.DISPENSE_HOLD:
			t = -1.0
			world.dispense(self)
		_timers[c.peer_id] = t
	for id in _timers.keys():
		if not active.has(id):
			_timers.erase(id)


func work_hint() -> String:
	return "hold F: %s" % str(def["label"])
