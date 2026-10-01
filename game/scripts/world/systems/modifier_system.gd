class_name ModifierSystem
extends RefCounted
## The single owner of "is modifier X active" and of the modifier effects (docs/design/overnight-1.md
## section 5). Modifiers come from the replicated shift def (`world.shift.def["modifiers"]`: host builds
## it in ShiftManager.begin, clients rebuild it from Net.settings in ShiftManager.from_meta), so no RPCs.
##
## Static queries (any peer, any caller; read Net.world's current shift def):
##   active_ids() (for the HUD), is_active(id), def_has(def, id), bursts(def), burst_size(rng, room),
##   weight_bonus() (Item.weight), skip_shop() / after_results_phase() (results -> next shift).
## Hook points elsewhere: Item.weight() (+weight_bonus), Chef.traction (walk accel, set here),
##   OrderManager (bursts), ShiftSystem (Rush! toast, no buying with no_shop), HudTicket (mystery chips),
##   ResultsView + main.gd (no_shop), World (creates this, calls update/host_tick).
## Effects owned here: slippery item physics + drop momentum + chef traction + puddles; lights_out
##   room dimming, chef lanterns, station markers. `--slide-test` (host) logs a slide distance.

const SLIP_FRICTION := 0.02        # item PhysicsMaterial friction (normal 0.9)
const SLIP_LINEAR_DAMP := 0.35     # normal 1.2
const SLIP_ANGULAR_DAMP := 1.0     # normal 3.0
const SLIP_TRACTION := 0.5         # chef walk accel multiplier: ~0.15 s longer to stop or turn
const SLIP_DROP_KEEP := 0.8        # dropped food keeps this share of its carry velocity
const BURST_MIN := 2
const BURST_MAX := 3

var world: World
var _applied: Array = []           # modifier ids the effects were last set up for
var _applied_key := ""
var _lights_on := false
var _saved: Dictionary = {}        # lights_out: original values to restore
var _night: Array[Node] = []       # lights_out nodes added to the room / stations
var _puddles: Node3D = null
var _carry_vel: Dictionary = {}    # host, slippery: item id -> velocity while carried
var _carry_pos: Dictionary = {}
var _slide := {}                   # --slide-test state


func _init(w: World) -> void:
	world = w


# ================================================================ static queries

static func current_def() -> Dictionary:
	var w := Net.world as World
	if w == null or not is_instance_valid(w):
		return {}
	return w.shift.def


static func def_has(def: Dictionary, id: String) -> bool:
	return (def.get("modifiers", []) as Array).has(id)


static func is_active(id: String) -> bool:
	return def_has(current_def(), id)


## Known modifier ids active this shift, in Difficulty.MODIFIER_IDS (display) order.
static func active_ids() -> Array[String]:
	var mods: Array = current_def().get("modifiers", [])
	var out: Array[String] = []
	for id in Difficulty.MODIFIER_IDS:
		if mods.has(id):
			out.append(id)
	return out


## Orders arrive in bursts: chaos difficulty or rush_hour.
static func bursts(def: Dictionary) -> bool:
	return bool(def.get("bursts", false)) or def_has(def, "rush_hour")


## Orders in the next burst (2 to 3), never more than room.
static func burst_size(rng: RandomNumberGenerator, room: int) -> int:
	return clampi(rng.randi_range(BURST_MIN, BURST_MAX), 1, maxi(1, room))


## heavy_hands: every item weighs one more (Item.weight(); carry speed, swing, pips, hints follow).
static func weight_bonus() -> int:
	return 1 if is_active("heavy_hands") else 0


static func skip_shop() -> bool:
	return is_active("no_shop")


## The phase the results screen leads to (host): straight into the next shift with no_shop.
static func after_results_phase() -> int:
	return Net.Phase.PLAYING if skip_shop() else Net.Phase.SHOP


# ================================================================ every peer

## Every frame (World._process): (re)build the presentation when the shift's modifiers change.
func update(_delta: float) -> void:
	var mods: Array = world.shift.def.get("modifiers", [])
	var key := ",".join(mods)
	if key != _applied_key:
		_applied_key = key
		_applied = mods.duplicate()
		_on_changed()
	if _lights_on:
		for c in world.chefs.values():
			if (c as Chef).get_node_or_null("ModLamp") == null:
				_add_lamp(c)


func _on_changed() -> void:
	var def := world.shift.def
	print("modifiers: %s active=[%s] bursts=%s" % ["host" if world.is_host else "client", ",".join(_applied),
		bursts(def)])
	if def_has(def, "heavy_hands"):
		var parts: Array = []
		for k in ["patty_raw", "bun_bottom", "cheese_slice", "tomato"]:
			if GameData.ITEMS.has(k):
				parts.append("%s %d->%d" % [k, int(GameData.ITEMS[k]["weight"]), int(GameData.ITEMS[k]["weight"]) + weight_bonus()])
		print("modifiers: heavy_hands weights +%d (%s)" % [weight_bonus(), ", ".join(parts)])
	_set_lights_out(def_has(def, "lights_out"))
	_set_puddles(def_has(def, "slippery"))


# ================================================================ host

## Host tick (World._simulate, after the stations): slippery physics, drop momentum, --slide-test.
func host_tick(dt: float) -> void:
	var slip := def_has(world.shift.def, "slippery")
	for c in world.chefs.values():
		(c as Chef).traction = SLIP_TRACTION if slip else 1.0
	for it: Item in world.items.values():
		if it.removed:
			continue
		if bool(it.get_meta("slip", false)) != slip:
			_set_item_slip(it, slip)
		if not slip:
			continue
		var id := it.item_id
		if it.is_carried():
			if _carry_pos.has(id):
				_carry_vel[id] = (it.global_position - (_carry_pos[id] as Vector3)) / maxf(dt, 0.001)
			_carry_pos[id] = it.global_position
		elif _carry_pos.has(id):
			# Let go this tick: the food keeps sliding the way it was carried.
			var v: Vector3 = _carry_vel.get(id, Vector3.ZERO)
			v.y = 0.0
			it.linear_velocity = v * SLIP_DROP_KEEP
			_carry_pos.erase(id)
			_carry_vel.erase(id)
	if not slip and not _carry_pos.is_empty():
		_carry_pos.clear()
		_carry_vel.clear()
	if Net.has_arg("slide-test"):
		_slide_test(dt)


func _set_item_slip(it: Item, on: bool) -> void:
	var pm := it.physics_material_override
	if pm == null:
		return
	if on:
		it.set_meta("slip_orig", [pm.friction, it.linear_damp, it.angular_damp])
		pm.friction = SLIP_FRICTION
		it.linear_damp = SLIP_LINEAR_DAMP
		it.angular_damp = SLIP_ANGULAR_DAMP
	elif it.has_meta("slip_orig"):
		var o: Array = it.get_meta("slip_orig")
		pm.friction = o[0]
		it.linear_damp = o[1]
		it.angular_damp = o[2]
	it.set_meta("slip", on)


## --slide-test: once play starts, drop a cheese slice in a clear lane, shove it at 8 m/s and log
## how far it slides (compare runs with and without --modifiers=slippery).
func _slide_test(dt: float) -> void:
	if Net.phase != Net.Phase.PLAYING or _slide.get("done", false):
		return
	var t := float(_slide.get("t", 0.0)) + dt
	_slide["t"] = t
	if not _slide.has("item") and t > 1.0:
		_slide["item"] = world.spawn_item("cheese_slice", Vector3(-4.0, 0.3, 13.2))
		_slide["t0"] = t
		return
	var it: Item = _slide.get("item")
	if it == null:
		return
	if not is_instance_valid(it) or it.removed:
		_slide["done"] = true
		print("modifiers: slide-test item removed before it stopped")
		return
	if not _slide.has("start") and t - float(_slide["t0"]) > 0.6:
		_slide["start"] = it.global_position
		_slide["ts"] = t
		it.linear_velocity = Vector3(8.0, 0.0, 0.0)
		return
	if _slide.has("start") and t - float(_slide["ts"]) > 0.1:
		var v := it.linear_velocity
		v.y = 0.0
		if v.length() < 0.05 or t - float(_slide["ts"]) > 8.0:
			var d := it.global_position - (_slide["start"] as Vector3)
			d.y = 0.0
			_slide["done"] = true
			print("modifiers: slide-test slippery=%s distance=%.2f m time=%.2f s (cheese_slice at 8 m/s)" % [
				def_has(world.shift.def, "slippery"), d.length(), t - float(_slide["ts"])])


# ================================================================ slippery: puddles (every peer)

## A few glossy wet patches on the counter tops (deterministic, clear of the stations).
func _set_puddles(on: bool) -> void:
	if _puddles != null:
		_puddles.queue_free()
		_puddles = null
	if not on:
		return
	_puddles = Node3D.new()
	_puddles.name = "ModPuddles"
	world.add_child(_puddles)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.72, 0.86, 1.0, 0.28)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.03
	m.metallic_specular = 1.0
	m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	var rng := RandomNumberGenerator.new()
	rng.seed = 7331
	var placed := 0
	var tries := 0
	var surfaces: Array = world.map["surfaces"]
	while placed < 7 and tries < 200:
		tries += 1
		var r: Rect2 = surfaces[rng.randi_range(0, surfaces.size() - 1)]
		var p := Vector3(rng.randf_range(r.position.x + 3, r.end.x - 3), 0.02, rng.randf_range(r.position.y + 3, r.end.y - 3))
		var clear := true
		for s: Station in world.stations:
			if s.contains_xz(p, 3.0):
				clear = false
				break
		if not clear:
			continue
		var mesh := CylinderMesh.new()
		mesh.top_radius = rng.randf_range(1.6, 3.0)
		mesh.bottom_radius = mesh.top_radius
		mesh.height = 0.02
		mesh.radial_segments = 28
		var mi := MeshInstance3D.new()
		mi.mesh = mesh
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position = p
		mi.scale = Vector3(rng.randf_range(1.0, 1.7), 1.0, 1.0)
		mi.rotation.y = rng.randf() * TAU
		_puddles.add_child(mi)
		placed += 1


# ================================================================ lights_out (every peer)

func _set_lights_out(on: bool) -> void:
	if on == _lights_on:
		return
	_lights_on = on
	var we := world.get_node_or_null("Environment") as WorldEnvironment
	var sun := world.get_node_or_null("KeySun") as DirectionalLight3D
	var fill := world.get_node_or_null("CoolFill") as DirectionalLight3D
	var hide: Array[Node] = []
	for n in ["LightShaft", "SunPatch"]:
		var x := world.find_child(n, true, false)
		if x != null:
			hide.append(x)
	if on:
		if we != null and we.environment != null:
			var e := we.environment
			_saved["env"] = [e.ambient_light_energy, e.ambient_light_color, e.ambient_light_sky_contribution,
				e.tonemap_exposure, e.fog_light_color, e.glow_intensity, e.adjustment_saturation]
			e.ambient_light_sky_contribution = 0.0
			e.ambient_light_color = Color(0.32, 0.4, 0.62)
			e.ambient_light_energy = 0.32
			e.tonemap_exposure = 1.15
			e.fog_light_color = Color(0.08, 0.1, 0.16)
			e.glow_intensity = 0.8
			e.adjustment_saturation = 1.12
		if sun != null:
			_saved["sun"] = [sun.light_energy, sun.light_color]
			sun.light_energy = 0.16      # moonlight through the window
			sun.light_color = Color(0.55, 0.66, 1.0)
		if fill != null:
			_saved["fill"] = [fill.light_energy]
			fill.light_energy = 0.05
		for x in hide:
			(x as Node3D).visible = false
		_add_station_markers()
		for c in world.chefs.values():
			_add_lamp(c)
	else:
		if we != null and we.environment != null and _saved.has("env"):
			var e := we.environment
			var s: Array = _saved["env"]
			e.ambient_light_energy = s[0]
			e.ambient_light_color = s[1]
			e.ambient_light_sky_contribution = s[2]
			e.tonemap_exposure = s[3]
			e.fog_light_color = s[4]
			e.glow_intensity = s[5]
			e.adjustment_saturation = s[6]
		if sun != null and _saved.has("sun"):
			sun.light_energy = _saved["sun"][0]
			sun.light_color = _saved["sun"][1]
		if fill != null and _saved.has("fill"):
			fill.light_energy = _saved["fill"][0]
		for x in hide:
			(x as Node3D).visible = true
		for n in _night:
			if is_instance_valid(n):
				n.queue_free()
		_night.clear()
		for c in world.chefs.values():
			var l := (c as Chef).get_node_or_null("ModLamp")
			if l != null:
				l.queue_free()
		_saved.clear()


## A warm lantern on a little hook in front of the hat, lighting the way ahead (+Z is the chef's front).
func _add_lamp(c: Chef) -> void:
	var root := Node3D.new()
	root.name = "ModLamp"
	c.add_child(root)
	var at := Vector3(0.0, 1.95, 0.42)
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.2, 0.17, 0.14)
	metal.metallic = 0.6
	metal.roughness = 0.4
	var hook := CylinderMesh.new()
	hook.top_radius = 0.025
	hook.bottom_radius = 0.025
	hook.height = 0.45
	var hk := MeshInstance3D.new()
	hk.mesh = hook
	hk.material_override = metal
	hk.position = Vector3(0.0, at.y + 0.28, at.z * 0.5)
	hk.rotation.x = 0.9
	root.add_child(hk)
	var cap := CylinderMesh.new()
	cap.top_radius = 0.05
	cap.bottom_radius = 0.16
	cap.height = 0.1
	var cp := MeshInstance3D.new()
	cp.mesh = cap
	cp.material_override = metal
	cp.position = at + Vector3(0, 0.2, 0)
	root.add_child(cp)
	var glass := CylinderMesh.new()
	glass.top_radius = 0.12
	glass.bottom_radius = 0.12
	glass.height = 0.28
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color(1.0, 0.82, 0.5)
	glow.emission_enabled = true
	glow.emission = Color(1.0, 0.7, 0.35)
	glow.emission_energy_multiplier = 5.0
	var gl := MeshInstance3D.new()
	gl.mesh = glass
	gl.material_override = glow
	gl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	gl.position = at
	root.add_child(gl)
	var base := MeshInstance3D.new()
	base.mesh = cap
	base.material_override = metal
	base.position = at + Vector3(0, -0.18, 0)
	base.rotation.x = PI
	root.add_child(base)
	# Pool of light ahead (SpotLight3D shines along its -Z; aim it forward-down).
	var spot := SpotLight3D.new()
	spot.light_color = Color(1.0, 0.78, 0.5)
	spot.light_energy = 7.0
	spot.spot_range = 16.0
	spot.spot_angle = 48.0
	spot.spot_angle_attenuation = 0.8
	spot.spot_attenuation = 0.6
	spot.shadow_enabled = true
	spot.shadow_bias = 0.05
	spot.position = at + Vector3(0, 0.1, 0.1)
	spot.basis = Basis.looking_at(Vector3(0.0, -0.75, 1.0).normalized(), Vector3.UP)
	root.add_child(spot)
	# Soft halo so the chef and what they hold stay readable.
	var halo := OmniLight3D.new()
	halo.light_color = Color(1.0, 0.72, 0.42)
	halo.light_energy = 1.6
	halo.omni_range = 5.5
	halo.omni_attenuation = 1.2
	halo.position = at
	root.add_child(halo)


## A small self-lit pilot bulb + glow pool over every station so it can be found in the dark.
func _add_station_markers() -> void:
	for s: Station in world.stations:
		var col := _marker_colour(s.type)
		var h := maxf(s.size.y, 0.4) + 1.4
		var n := Node3D.new()
		n.name = "ModMarker"
		n.position = Vector3(0, h, 0)
		s.add_child(n)
		_night.append(n)
		var bulb := SphereMesh.new()
		bulb.radius = 0.28
		bulb.height = 0.56
		bulb.radial_segments = 16
		bulb.rings = 8
		var m := StandardMaterial3D.new()
		m.albedo_color = col
		m.emission_enabled = true
		m.emission = col
		m.emission_energy_multiplier = 4.0
		var mi := MeshInstance3D.new()
		mi.mesh = bulb
		mi.material_override = m
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		n.add_child(mi)
		var o := OmniLight3D.new()
		o.light_color = col
		o.light_energy = 1.4
		o.omni_range = maxf(s.size.x, s.size.z) * 0.9 + 2.0
		o.omni_attenuation = 1.1
		n.add_child(o)


static func _marker_colour(t: String) -> Color:
	match t:
		"griddle", "fryer":
			return Color(1.0, 0.45, 0.15)
		"plate", "bell":
			return Color(0.55, 1.0, 0.5)
		"trash":
			return Color(1.0, 0.3, 0.3)
		_:
			return Color(0.45, 0.8, 1.0)
