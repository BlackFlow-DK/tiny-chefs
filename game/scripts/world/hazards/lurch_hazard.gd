class_name LurchHazard
extends Hazard
## Hazard "lurch" (food truck): every 35 to 55 s the truck lurches. 1 s telegraph (a horn, a "Hold on!"
## toast and a faint rumble), then every loose food item slides about 2 m in one random direction: its
## horizontal velocity is steered along a short sine speed profile (impulses every tick, not a
## teleport), so food near the front edge goes over and falls as usual. Carried food is safe, and so
## is anything frozen (stacked on a plate). Every player's camera shakes for 0.5 s and the hanging
## props (EnvTruck.SWING_GROUP: string lights, order sign) swing.
## Host decides and pushes; every peer gets Net.event("Hold on!", "horn") then Net.event("", "lurch:<deg>").
## Debug (host): --lurch-at=<s> first lurch s seconds into play, --lurch-every=<s> fixed interval,
## --lurch-dir=<deg> fixed direction (0 = +X, 90 = +Z towards the camera), --lurch-log displacement stats.

const INTERVAL := Vector2(35.0, 55.0)
const TELEGRAPH := 1.0
const PUSH := 0.45
const DIST := 2.0
const SLIP := 1.15                   # speed factor that makes up for counter friction (measured with --lurch-log)
const SHAKE := 0.5
const SHAKE_AMP := 0.55              # m of camera h/v offset at the start of the shake
const RUMBLE_AMP := 0.07             # m during the telegraph
const SWING_AMP := 0.2               # rad
const SWING_TIME := 3.5
const EVENT := "lurch:"

var _rng := RandomNumberGenerator.new()
var _next := 0.0              # host: seconds until the next lurch
var _t := -1.0                # host: seconds since the warning, < 0 when calm
var _dir := Vector3.RIGHT
var _start_pos: Dictionary = {}
var _log := false

var _warn_t := -1.0           # every peer: seconds since the warning (rumble), < 0 when none
var _shake_t := -1.0          # every peer: seconds since the lurch, < 0 when none
var _fx_dir := Vector3.RIGHT
var _swing: Array = []        # [{node, base}] pivots found at the lurch


func setup(w: World) -> void:
	super.setup(w)
	_rng.randomize()
	_log = Net.has_arg("lurch-log")
	_next = Net.arg_float("lurch-at", _rng.randf_range(INTERVAL.x, INTERVAL.y))
	Net.event_received.connect(_on_event)


# ================================================================ host

func host_tick(dt: float) -> void:
	if _t < 0.0:
		_next -= dt
		if _next <= 0.0:
			_t = 0.0
			Net.event("Hold on!", "horn")
		return
	var was := _t
	_t += dt
	if _t >= TELEGRAPH and was < TELEGRAPH:
		var deg := Net.arg_float("lurch-dir", _rng.randf_range(0.0, 360.0))
		_dir = Vector3(cos(deg_to_rad(deg)), 0.0, sin(deg_to_rad(deg)))
		_start_pos.clear()
		for it: Item in world.items.values():
			if _loose(it):
				_start_pos[it.item_id] = it.global_position
		if _log:
			print("lurch: towards %.0f deg, %d loose items" % [deg, _start_pos.size()])
		Net.event("", EVENT + str(int(round(deg))))
	if _t >= TELEGRAPH and _t <= TELEGRAPH + PUSH:
		_push((_t - TELEGRAPH) / PUSH)
	elif _t > TELEGRAPH + PUSH:
		if _log:
			_log_result()
		_t = -1.0
		_next = Net.arg_float("lurch-every", _rng.randf_range(INTERVAL.x, INTERVAL.y))


func _loose(it: Item) -> bool:
	return not it.removed and not it.is_carried() and not it.freeze and it.global_position.y > -1.5


## s: 0..1 through the push. Speed profile peak * sin(pi s) covers DIST over PUSH seconds.
func _push(s: float) -> void:
	var peak := DIST * PI / (2.0 * PUSH) * SLIP
	var want := _dir * peak * sin(PI * clampf(s, 0.0, 1.0))
	for it: Item in world.items.values():
		if not _loose(it):
			continue
		var v := it.linear_velocity
		var dv := Vector3(want.x - v.x, 0.0, want.z - v.z)
		it.sleeping = false
		it.apply_central_impulse(dv * it.mass)


func _log_result() -> void:
	var n := 0
	var total := 0.0
	var lo := INF
	var hi := 0.0
	var fell := 0
	for id in _start_pos:
		var it: Item = world.items.get(id)
		if it == null or it.removed:
			fell += 1
			continue
		var d := Vector2(it.global_position.x - _start_pos[id].x, it.global_position.z - _start_pos[id].z).length()
		n += 1
		total += d
		lo = minf(lo, d)
		hi = maxf(hi, d)
	if n == 0:
		print("lurch: over, no loose food on the counter (%d fell)" % fell)
	else:
		print("lurch: over, moved %d items avg %.2f m (min %.2f, max %.2f), %d gone" % [n, total / n, lo, hi, fell])


# ================================================================ every peer (presentation)

func _on_event(_text: String, sfx: String) -> void:
	if not is_instance_valid(world):
		return
	if sfx == "horn":
		_warn_t = 0.0
		return
	if not sfx.begins_with(EVENT):
		return
	var deg := float(sfx.trim_prefix(EVENT))
	_fx_dir = Vector3(cos(deg_to_rad(deg)), 0.0, sin(deg_to_rad(deg)))
	_warn_t = -1.0
	_shake_t = 0.0
	Sfx.play("clunk")
	_swing.clear()
	for n in world.get_tree().get_nodes_in_group(EnvTruck.SWING_GROUP):
		if n is Node3D and world.is_ancestor_of(n):
			_swing.append({"node": n, "base": (n as Node3D).rotation})


func client_tick(dt: float) -> void:
	var cam := world.camera
	var off := Vector2.ZERO
	if _warn_t >= 0.0:
		_warn_t += dt
		if _warn_t > TELEGRAPH + 0.2:
			_warn_t = -1.0
		else:
			var k := _warn_t / TELEGRAPH
			off = Vector2(sin(_warn_t * 61.0), sin(_warn_t * 47.0 + 1.3)) * RUMBLE_AMP * k
	if _shake_t >= 0.0:
		_shake_t += dt
		if _shake_t <= SHAKE:
			var k := 1.0 - _shake_t / SHAKE
			# A hard kick against the lurch direction (screen x = world x, screen y ~ world z), then noise.
			var kick := Vector2(-_fx_dir.x, _fx_dir.z * 0.6) * exp(-_shake_t * 14.0) * 1.4
			var jitter := Vector2(sin(_shake_t * 83.0) + 0.5 * sin(_shake_t * 131.0 + 2.0), sin(_shake_t * 71.0 + 0.7) + 0.5 * sin(_shake_t * 149.0))
			off = (kick + jitter * 0.6) * SHAKE_AMP * k * k
		_swing_tick()
		if _shake_t > SWING_TIME:
			_shake_t = -1.0
			for s in _swing:
				if is_instance_valid(s["node"]):
					(s["node"] as Node3D).rotation = s["base"]
			_swing.clear()
	if cam != null:
		cam.h_offset = off.x
		cam.v_offset = off.y


## Hanging props: a damped swing, first away from the lurch (they lag behind the truck).
func _swing_tick() -> void:
	var a := SWING_AMP * exp(-_shake_t * 1.2) * sin(_shake_t * 5.0)
	for s in _swing:
		var n: Node3D = s["node"]
		if not is_instance_valid(n):
			continue
		var base: Vector3 = s["base"]
		# Pivot frames: rotate about world X for a push along Z and about world Z for a push along X.
		n.rotation = base + Vector3(-_fx_dir.z * a, 0.0, _fx_dir.x * a)
