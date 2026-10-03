extends Node
## Agent test scenes for food physics (FoodPhysicsSystem adds this to the World when an arg asks for it).
##   --physics-test=<a,b,...> (host): scripted scenes once play starts, one after another (see SCENES):
##     pile    12 mixed items dropped one by one on one spot; logs the max speed 3 s after the last one
##     toss    the host chef grabs a tomato and lets go while "walking" at 7 m/s (CarrySystem.release with the
##             carrier velocity set, the same path as a real walk); logs it rolling
##     egg     an egg tossed the same way (splats) and one dropped standing (does not)
##     griddle a raw patty tossed at duo-carry speed onto the griddle; logs when it starts cooking
##     cheese  a cheese slice tossed at 7 m/s: slides and settles flat; logs its up vector
##     sway    a bun bottom then a patty dropped onto the plate (stack sway)
##     long    a sausage tossed sideways (spins)
##     punch   the host chef punches an egg (needs --upgrades=gloves): launched, lands, splats
##   --physics-shots=<dir> (host): the scenes save PNGs at their key moments (needs a window).
##   --physics-shot=<shift seconds>@<png> (any peer, repeatable): save the view when the shift clock passes
##     that many seconds (host and client screenshots of the same moment).

const SCENES := ["pile", "toss", "egg", "griddle", "cheese", "sway", "long", "punch"]

var world: World
var _queue: Array = []
var _scene := ""
var _t := 0.0
var _state := {}
var _shots_dir := ""
var _clock_shots: Array = []   # [seconds, png, done]
var _warm := 0.0               # play time before the first scene (the shift banner fades first)


func setup(w: World) -> void:
	world = w
	name = "FoodPhysicsTest"
	if world.is_host and Net.has_arg("physics-test"):
		for s in Net.arg_str("physics-test", "").split(","):
			if SCENES.has(s):
				_queue.append(s)
	_shots_dir = Net.arg_str("physics-shots", "")
	if _shots_dir != "":
		DirAccess.make_dir_recursive_absolute(_shots_dir)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--physics-shot="):
			var p := a.trim_prefix("--physics-shot=").split("@")
			if p.size() == 2:
				_clock_shots.append([p[0].to_float(), p[1], false])


func _process(_dt: float) -> void:
	if _clock_shots.is_empty() or not world.shift.running:
		return
	var el := float(world.shift.def.get("duration", 0.0)) - world.shift.time_left
	for s in _clock_shots:
		if not s[2] and el >= float(s[0]):
			s[2] = true
			_save(str(s[1]), "%s at shift %.2f s" % ["host" if world.is_host else "client", el])


func _physics_process(dt: float) -> void:
	if not world.is_host or Net.phase != Net.Phase.PLAYING:
		return
	_warm += dt
	if _scene == "":
		if _queue.is_empty() or _warm < 4.0:
			return
		_scene = _queue.pop_front()
		_t = 0.0
		_state = {}
		print("physics-test: scene %s starts" % _scene)
	_t += dt
	var done: bool = call("_scene_" + _scene, dt)
	if done:
		print("physics-test: scene %s done" % _scene)
		for it in world.items.values().duplicate():
			world.remove_item(it)
		_scene = ""


# ---------------------------------------------------------------- scenes (return true when finished)

func _scene_pile(_dt: float) -> bool:
	var kinds := ["cheese_slice", "patty_raw", "tomato", "bun_bottom", "lettuce_leaf", "onion", "tomato_slice",
		"bacon_raw", "pickle_slice", "bun_top", "potato", "fried_egg"]
	var spot := Vector3(-18.0, 0.0, -3.0)
	var n: int = _state.get("n", 0)
	if n < kinds.size() and _t > 0.5 + n * 0.25:
		var j := Vector3(sin(n * 2.3) * 0.9, 3.2, cos(n * 1.7) * 0.9)
		var it := world.spawn_item(kinds[n], spot + j)
		_state.get_or_add("items", []).append(it)
		_state["n"] = n + 1
		if n + 1 == kinds.size():
			_state["last"] = _t
		return false
	if not _state.has("last"):
		return false
	var since := _t - float(_state["last"])
	if since > 0.35 and not _state.has("shot0"):
		_state["shot0"] = true
		_shot("pile_falling")
	for k in [1.0, 3.0, 4.0, 5.0, 6.0]:
		if since >= k and not _state.has("log%d" % k):
			_state["log%d" % k] = true
			_log_pile(k)
	if since > 3.0 and not _state.has("shot1"):
		_state["shot1"] = true
		_shot("pile_settled")
	return since > 6.1


func _log_pile(k: float) -> void:
	var mx := 0.0
	var mxa := 0.0
	var top := 0.0
	var who := ""
	var items: Array = _state["items"]
	for o in items:
		var it := o as Item if is_instance_valid(o) else null
		if it != null and not it.removed:
			if it.linear_velocity.length() > mx:
				who = "%s at %s" % [it.kind, it.global_position.snapped(Vector3.ONE * 0.01)]
			mx = maxf(mx, it.linear_velocity.length())
			mxa = maxf(mxa, absf(it.angular_velocity.y))
			top = maxf(top, it.global_position.y)
	print("physics-test: pile %.0f s after the last drop: max speed %.3f m/s, max spin %.3f rad/s, top item at y %.2f, %d items (fastest: %s)" % [
		k, mx, mxa, top, items.size(), who])


func _scene_toss(_dt: float) -> bool:
	return _toss_scene("tomato", Vector3(-8.0, 0.0, 12.5), Vector3(1, 0, 0), 7.0, [0.15, 0.55, 1.1, 2.6])


func _scene_cheese(_dt: float) -> bool:
	if _t > 3.5 and not _state.has("flat"):
		_state["flat"] = true
		var it: Item = _state.get("item")
		if it != null and is_instance_valid(it):
			print("physics-test: cheese settled at %s up %s speed %.3f" % [it.global_position.snapped(Vector3.ONE * 0.01),
				it.global_transform.basis.y.snapped(Vector3.ONE * 0.001), it.linear_velocity.length()])
	return _toss_scene("cheese_slice", Vector3(-8.0, 0.0, 12.5), Vector3(1, 0, 0), 7.0, [0.3, 3.4])


func _scene_long(_dt: float) -> bool:
	return _toss_scene("sausage_raw", Vector3(-8.0, 0.0, 12.5), Vector3(1, 0, 0), 7.0, [0.4, 1.0], true)


func _scene_griddle(_dt: float) -> bool:
	var it: Item = _state.get("item")
	if it != null and is_instance_valid(it) and it.cooking and _state.has("tossed") and not _state.has("cook"):
		_state["cook"] = true
		print("physics-test: tossed %s started cooking at %s (%.2f s after the toss)" % [it.kind,
			it.global_position.snapped(Vector3.ONE * 0.01), _t - float(_state.get("tossed", 0.0))])
		_shot("griddle_cooking")
	# A duo carry of a weight-3 patty walks at 7 * 2/3 m/s.
	return _toss_scene("patty_raw", Vector3(-17.1, 0.0, 0.0), Vector3(1, 0, 0), 7.0 * 2.0 / 3.0, [0.5, 2.0]) and _t > 4.0


func _scene_egg(_dt: float) -> bool:
	if _state.get("phase", 0) == 0:
		if _toss_scene("egg", Vector3(-8.0, 0.0, 12.5), Vector3(1, 0, 0), 7.0, [0.4, 1.2]):
			print("physics-test: tossed egg is now %s" % _kind_of(_state.get("item")))
			_state = {"phase": 1}
			_t = 0.0
		return false
	if _toss_scene("egg", Vector3(-8.0, 0.0, 12.5), Vector3(1, 0, 0), 0.0, [0.8], false, "egg_dropped"):
		print("physics-test: dropped (standing) egg is now %s" % _kind_of(_state.get("item")))
		return true
	return false


func _scene_punch(_dt: float) -> bool:
	var c: Chef = world.chefs.get(world.my_id)
	if c == null:
		return true
	if not _state.has("item"):
		c.global_position = Vector3(-8.0, 0.0, 12.5)
		c.rotation.y = PI * 0.5
		c.facing = Vector3(1, 0, 0)
		_state["item"] = world.spawn_item("egg", Vector3(-6.4, 0.05, 12.5))
		return false
	if _t > 0.8 and not _state.has("punched"):
		_state["punched"] = true
		c.facing = Vector3(1, 0, 0)
		world._punch_sys.on_punch_pressed(c)
		var it: Item = _state["item"]
		print("physics-test: punched egg, velocity %s" % (it.linear_velocity.snapped(Vector3.ONE * 0.01) if is_instance_valid(it) else "gone"))
	if _t > 0.95 and not _state.has("shot"):
		_state["shot"] = true
		_shot("punch_egg_air")
	if _t > 3.0:
		print("physics-test: punched egg is now %s" % _kind_of(_state.get("item")))
		return true
	return false


func _scene_sway(_dt: float) -> bool:
	var p: Plate = world.plate
	if _t > 0.5 and not _state.has("a"):
		_state["a"] = world.spawn_item("bun_bottom", p.global_position + Vector3(0, 2.0, 0))
	if _t > 2.0 and not _state.has("b"):
		_state["b"] = world.spawn_item("patty_cooked", p.global_position + Vector3(0, 2.4, 0))
		_state["tb"] = _t
	if _state.has("tb"):
		for k in [0.06, 0.2, 1.8]:
			if _t - float(_state["tb"]) > k and not _state.has("shot%s" % k):
				_state["shot%s" % k] = true
				_shot("plate_sway_%dms" % roundi(k * 1000.0))
	if _t > 4.0:
		print("physics-test: plate stack %s" % str(p.stack))
		p.clear_stack()
		return true
	return false


## Put the host chef at `at`, give it a kind just in front (towards dir), grab it, then let go while the
## carrier moves along dir at speed (0 = standing). Screenshots at the given seconds after the release.
func _toss_scene(kind: String, at: Vector3, dir: Vector3, speed: float, shots: Array, sideways := false, tag := "") -> bool:
	var c: Chef = world.chefs.get(world.my_id)
	if c == null:
		return true
	if not _state.has("item"):
		c.global_position = at
		c.velocity = Vector3.ZERO
		c.rotation.y = atan2(dir.x, dir.z)
		c.facing = dir
		var d: Dictionary = GameData.ITEMS[kind]
		var sz: Vector3 = d["size"]
		var half := (minf(sz.x, sz.z) if sideways else maxf(sz.x, sz.z)) * 0.5
		var it := world.spawn_item(kind, at + dir * (0.45 + half + 0.2) + Vector3(0, 0.05, 0))
		if sideways:
			it.rotation.y = atan2(dir.x, dir.z)   # long axis (x) across the throw
		_state["item"] = it
		_state["t0"] = _t
		return false
	var it: Item = _state["item"]
	if not _state.has("grabbed") and _t - float(_state["t0"]) > 0.5:
		_state["grabbed"] = true
		world._carry_sys.on_grab_pressed(c)
		print("physics-test: chef grabbed %s: %s" % [kind, c.holding == it])
		return false
	if _state.has("grabbed") and not _state.has("tossed") and _t - float(_state["t0"]) > 1.3:
		_state["tossed"] = _t
		c.velocity = dir * speed
		world.release(c, true)
		var v := it.linear_velocity if is_instance_valid(it) else Vector3.ZERO
		print("physics-test: %s let go at carrier speed %.1f: item velocity %s (%.2f m/s)" % [kind, speed,
			v.snapped(Vector3.ONE * 0.01), v.length()])
		c.velocity = Vector3.ZERO
		return false
	if not _state.has("tossed"):
		return false
	var since := _t - float(_state["tossed"])
	for i in shots.size():
		if since >= float(shots[i]) and not _state.has("shot%d" % i):
			_state["shot%d" % i] = true
			_shot("%s_%d" % [kind if tag == "" else tag, i])
	var lt := float(_state.get("logt", 0.0))
	if since - lt >= 0.25 and is_instance_valid(it) and not it.removed:
		_state["logt"] = since
		var tq := it.tumble
		print("physics-test: %s t+%.2f pos %s v %.2f yaw %.0f tumble %.0f deg" % [it.kind, since,
			it.global_position.snapped(Vector3.ONE * 0.01), it.linear_velocity.length(),
			rad_to_deg(it.global_transform.basis.get_euler().y), rad_to_deg(tq.get_angle())])
	return since > maxf(3.0, float(shots.back()) + 0.2)


func _kind_of(it: Variant) -> String:
	return (it as Item).kind if it != null and is_instance_valid(it) else "(gone)"


func _shot(tag: String) -> void:
	if _shots_dir != "":
		_save(_shots_dir.path_join(tag + ".png"), tag)


func _save(path: String, tag: String) -> void:
	var tex := get_viewport().get_texture()
	var img := tex.get_image() if tex != null else null
	if img == null or img.is_empty():
		print("physics-test: no image for %s (headless?)" % tag)
		return
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	if img.save_png(path) == OK:
		print("physics-test: saved %s (%s)" % [path, tag])
