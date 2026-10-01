class_name PunchSystem
extends RefCounted
## Owns the punch (Boxing Gloves upgrade): cooldown gate, target pick, launching food, shoving chefs.
## Host only. Reads world.chefs, world.items, world.shift upgrades.
## Calls world.release, world.detach_all, Net.event/metrics; sets Chef.knock and Item velocities.

var world: World


func _init(w: World) -> void:
	world = w


## A fresh punch press.
func on_punch_pressed(c: Chef) -> void:
	if world.shift.has_upgrade("gloves") and c.punch_cd <= 0.0 and c.respawn_timer < 0.0 and c.holding == null:
		_punch(c)


func _punch(c: Chef) -> void:
	c.punch_cd = Tuning.PUNCH_COOLDOWN
	c.punch_anim = 0.25
	world.stats.on_punch(c)
	Net.event("", "punch")
	Net.metrics["punches"] = int(Net.metrics.get("punches", 0)) + 1
	var fwd := c.facing
	var best: Node3D = null
	var bd := Tuning.PUNCH_RANGE
	for o in world.chefs.values():
		if o == c or o.respawn_timer >= 0.0:
			continue
		var to: Vector3 = o.global_position - c.global_position
		to.y = 0.0
		var d := maxf(to.length() - 0.4, 0.0)
		if d <= bd and to.normalized().dot(fwd) > 0.3:
			best = o
			bd = d
	for it in world.items.values():
		if it.removed:
			continue
		var to: Vector3 = it.global_position - c.global_position
		to.y = 0.0
		var d: float = it.footprint_distance(c.global_position)
		if d <= bd and (to.length() < 0.5 or to.normalized().dot(fwd) > 0.3):
			best = it
			bd = d
	if best is Chef:
		var o := best as Chef
		Net.metrics["punch_hits"] = int(Net.metrics.get("punch_hits", 0)) + 1
		world.release(o)
		o.knock = fwd * Tuning.PUNCH_PLAYER_SPEED
	elif best is Item:
		var it := best as Item
		Net.metrics["punch_hits"] = int(Net.metrics.get("punch_hits", 0)) + 1
		var held := it.carriers.size()
		world.detach_all(it)
		world.item_launched(it)   # slippery: no "keeps its carry velocity" on top of the punch
		var w := sqrt(float(it.weight()))
		it.linear_velocity = fwd * (Tuning.PUNCH_ITEM_SPEED / w) + Vector3.UP * (Tuning.PUNCH_ITEM_UP / w)
		it.angular_velocity = Vector3(0, 8.0, 0)
		it.refuse_cooldown = 0.3
		if Net.has_arg("carry-log"):
			print("punch: chef %d launched %s %d (held by %d) at %.2f m/s" % [c.peer_id, it.kind, it.item_id, held,
				it.linear_velocity.length()])
