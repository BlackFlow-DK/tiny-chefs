class_name WindHazard
extends Hazard
## Hazard "wind" (picnic): every 20 to 40 s a gust from a random compass direction. 2 s telegraph
## (leaves stream across the view from that side, a whoosh, an arrow toast "Gust from the west!"),
## then for 2 s every loose weight-1 food is pushed 3 to 5 m downwind: its horizontal velocity is
## steered along a sine speed profile (impulses every tick, not a teleport), so food near an edge
## blows off and falls as usual. Carried food and heavier food are safe.
## Host decides and pushes; every peer gets Net.event("", "gust:<dir>") (reliable) for the effects.
## Compass: north = -Z (the far edge), east = +X. The camera never yaws, so screen right = east.
## Debug (host): --wind-at=<s> first gust s seconds into play, --wind-every=<s> fixed interval,
## --wind-dir=<0..7> fixed direction (0 north, clockwise), --wind-log per-gust displacement stats.

const INTERVAL := Vector2(20.0, 40.0)
const TELEGRAPH := 2.0
const PUSH := 2.0
const DIST := Vector2(3.5, 4.3)      # x the per-item 0.85..1.15 spread = 3..5 m
const SLIP := 1.12                   # speed factor that makes up for table friction (measured with --wind-log)
const DIR_NAMES := ["north", "north-east", "east", "south-east", "south", "south-west", "west", "north-west"]
const LEAVES := 54
const STREAKS := 18
const FX_TIME := TELEGRAPH + PUSH + 0.6
const EVENT := "gust:"

var _rng := RandomNumberGenerator.new()
var _next := 0.0              # host: seconds until the next gust
var _t := -1.0                # host: seconds since the gust began, < 0 when calm
var _dir := 0
var _dist := 4.0
var _start_pos: Dictionary = {}   # --wind-log: item id -> position when the push began
var _log := false

var _fx_root: Node3D           # every peer: pooled gust leaves
var _fx: Array = []            # [{node, t0, life, from, vel, flutter, spin, axis, scale, streak}]
var _fx_t := -1.0
var _fx_blow := Vector3.RIGHT
var _ui: CanvasLayer


func setup(w: World) -> void:
	super.setup(w)
	_rng.randomize()
	_log = Net.has_arg("wind-log")
	_next = Net.arg_float("wind-at", _rng.randf_range(INTERVAL.x, INTERVAL.y))
	Net.event_received.connect(_on_event)


# ================================================================ host

func host_tick(dt: float) -> void:
	if _t < 0.0:
		_next -= dt
		if _next <= 0.0:
			_begin()
		return
	var was := _t
	_t += dt
	if _t > TELEGRAPH and _t <= TELEGRAPH + PUSH:
		if was <= TELEGRAPH:
			_start_pos.clear()
			for it in world.items.values():
				if _loose(it):
					_start_pos[it.item_id] = it.global_position
		_push((_t - TELEGRAPH) / PUSH)
	elif _t > TELEGRAPH + PUSH:
		if _log:
			_log_result()
		_t = -1.0
		_next = Net.arg_float("wind-every", _rng.randf_range(INTERVAL.x, INTERVAL.y))


func _begin() -> void:
	_dir = Net.arg_int("wind-dir", _rng.randi_range(0, 7)) % 8
	_dist = _rng.randf_range(DIST.x, DIST.y)
	_t = 0.0
	if _log:
		print("wind: gust from the %s, %.1f m" % [DIR_NAMES[_dir], _dist])
	Net.event("", EVENT + str(_dir))


## Unit vector the wind blows along (from the named side towards the other).
static func blow_dir(dir: int) -> Vector3:
	var a := dir * PI * 0.25
	return -Vector3(sin(a), 0.0, -cos(a))


func _loose(it: Item) -> bool:
	return not it.removed and not it.is_carried() and not it.freeze and it.weight() == 1 \
		and it.global_position.y > -1.5


## s: 0..1 through the push. Speed profile peak * sin(pi s) covers dist over PUSH seconds.
func _push(s: float) -> void:
	var blow := blow_dir(_dir)
	var peak := _dist * PI / (2.0 * PUSH) * SLIP
	var prof := sin(PI * clampf(s, 0.0, 1.0))
	for it: Item in world.items.values():
		if not _loose(it):
			continue
		var spread := 0.85 + 0.3 * fposmod(sin(float(it.item_id) * 12.9898) * 43758.5453, 1.0)
		var want := blow * peak * spread * prof
		var v := it.linear_velocity
		var dv := Vector3(want.x - v.x, 0.0, want.z - v.z)
		it.sleeping = false
		it.apply_central_impulse(dv * it.mass)
		# A lazy spin so light food looks blown, not conveyed.
		it.angular_velocity.y = (1.6 if it.item_id % 2 == 0 else -1.6) * prof


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
		print("wind: gust over, no loose light food on the table (%d fell)" % fell)
	else:
		print("wind: gust over, moved %d items avg %.2f m (min %.2f, max %.2f), %d gone" % [n, total / n, lo, hi, fell])


# ================================================================ every peer (presentation)

func _on_event(_text: String, sfx: String) -> void:
	if not sfx.begins_with(EVENT) or not is_instance_valid(world):
		return
	var d := int(sfx.trim_prefix(EVENT)) % 8
	_fx_blow = blow_dir(d)
	_fx_t = 0.0
	Sfx.play("gust")
	_spawn_leaves()
	_show_toast("Gust from the %s!" % DIR_NAMES[d], _fx_blow)


func client_tick(dt: float) -> void:
	if _fx_t < 0.0:
		return
	_fx_t += dt
	var done := _fx_t > FX_TIME + 2.5
	for f in _fx:
		var n: Node3D = f["node"]
		var lt: float = _fx_t - float(f["t0"])
		if lt < 0.0 or lt > float(f["life"]) or done:
			n.visible = false
			continue
		n.visible = true
		var from: Vector3 = f["from"]
		var vel: Vector3 = f["vel"]
		var side := Vector3(-vel.z, 0.0, vel.x).normalized()
		var fl: float = f["flutter"]
		if f["streak"]:
			# A thin gust line: flat, along the wind, fading in and out over its life.
			n.position = from + vel * lt + side * sin(lt * 2.0 + fl) * 0.6
			(n as MeshInstance3D).set_instance_shader_parameter("fade", sin(PI * lt / float(f["life"])))
			continue
		var p := from + vel * lt + side * sin(lt * 5.0 + fl) * 1.3 + Vector3(0, sin(lt * 3.3 + fl * 2.0) * 0.9 - lt * 0.8, 0)
		n.position = p
		n.basis = Basis(f["axis"], lt * float(f["spin"]) + fl).scaled(Vector3.ONE * float(f["scale"]))
	if done:
		_fx_t = -1.0


func _spawn_leaves() -> void:
	if _fx_root == null:
		_fx_root = Node3D.new()
		_fx_root.name = "GustLeaves"
		world.add_child(_fx_root)
		for i in LEAVES:
			var leaf := Models.load_model("leaf")
			if leaf == null:
				leaf = Models.primitive("box", Vector3(1.5, 0.2, 2.5), Color(0.45, 0.62, 0.22))
			_no_shadow(leaf)
			leaf.visible = false
			_fx_root.add_child(leaf)
			_fx.append({"node": leaf, "streak": false})
		var q := QuadMesh.new()
		q.size = Vector2(1.0, 1.0)
		q.orientation = PlaneMesh.FACE_Y
		var sm := ShaderMaterial.new()
		sm.shader = Shader.new()
		sm.shader.code = STREAK_SHADER
		for i in STREAKS:
			var mi := MeshInstance3D.new()
			mi.mesh = q
			mi.material_override = sm
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			mi.visible = false
			_fx_root.add_child(mi)
			_fx.append({"node": mi, "streak": true})
	# Stream across what the camera sees: start upwind of the view centre, fly through it.
	var centre := _view_centre()
	var side := Vector3(-_fx_blow.z, 0.0, _fx_blow.x)
	var r := RandomNumberGenerator.new()
	r.seed = hash(Time.get_ticks_msec())
	for i in _fx.size():
		var f: Dictionary = _fx[i]
		var streak: bool = f["streak"]
		var speed := r.randf_range(30.0, 40.0) if streak else r.randf_range(17.0, 25.0)
		f["t0"] = r.randf_range(0.0, TELEGRAPH + PUSH - 0.6)
		f["life"] = 1.8 if streak else 3.2
		f["from"] = centre - _fx_blow * r.randf_range(30.0, 38.0) + side * r.randf_range(-20.0, 20.0) \
			+ Vector3(0, r.randf_range(0.6, 5.5), 0)
		f["vel"] = _fx_blow * speed
		if streak:
			var sn: Node3D = f["node"]
			sn.basis = Basis(Vector3.UP, atan2(-_fx_blow.z, _fx_blow.x)).scaled(Vector3(r.randf_range(7.0, 12.0), 1.0, r.randf_range(0.12, 0.22)))
			f["flutter"] = r.randf_range(0.0, TAU)
			continue
		f["flutter"] = r.randf_range(0.0, TAU)
		f["spin"] = r.randf_range(4.0, 9.0) * (1.0 if r.randf() < 0.5 else -1.0)
		f["axis"] = Vector3(r.randf_range(-1, 1), r.randf_range(-0.4, 1), r.randf_range(-1, 1)).normalized()
		f["scale"] = r.randf_range(0.9, 1.5)


func _view_centre() -> Vector3:
	var cam := world.camera
	if cam == null:
		return Vector3.ZERO
	var f := -cam.global_transform.basis.z
	if f.y > -0.05:
		return Vector3(cam.global_position.x, 0.0, cam.global_position.z - 20.0)
	return cam.global_position + f * (-cam.global_position.y / f.y)


const STREAK_SHADER := """shader_type spatial;
render_mode unshaded, blend_add, depth_draw_never, cull_disabled, shadows_disabled;
instance uniform float fade = 0.0;
void fragment() {
	float along = sin(UV.x * 3.14159);
	float across = 1.0 - abs(UV.y * 2.0 - 1.0);
	ALBEDO = vec3(1.0, 0.99, 0.95);
	ALPHA = along * along * across * fade * 0.9;
}
"""


static func _no_shadow(n: Node) -> void:
	if n is GeometryInstance3D:
		(n as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for c in n.get_children():
		_no_shadow(c)


## Arrow toast (a dark chip like the HUD's toasts, with an arrow pointing downwind instead of the dot).
func _show_toast(text: String, blow: Vector3) -> void:
	if _ui == null:
		_ui = CanvasLayer.new()
		_ui.name = "GustToast"
		_ui.layer = 2
		world.add_child(_ui)
		var holder := Control.new()
		holder.name = "Holder"
		holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
		holder.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		holder.theme = UI.theme()
		_ui.add_child(holder)
	var host: Control = _ui.get_node("Holder")
	for c in host.get_children():
		c.queue_free()
	var p := PanelContainer.new()
	p.theme_type_variation = "DarkChipPanel"
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	var arrow := GustArrow.new()
	arrow.angle = atan2(blow.z, blow.x)
	h.add_child(arrow)
	h.add_child(UIKit.body(text, "dark"))
	p.add_child(h)
	host.add_child(p)
	p.anchor_left = 0.5
	p.anchor_right = 0.5
	p.anchor_top = 0.3
	p.anchor_bottom = 0.3
	p.grow_horizontal = Control.GROW_DIRECTION_BOTH
	UIKit.pop_in(p)
	var tw := p.create_tween()
	tw.tween_interval(TELEGRAPH + PUSH - 0.4)
	tw.tween_property(p, "modulate:a", 0.0, 0.3)
	tw.tween_callback(p.queue_free)


## Mustard disc with an ink arrow pointing along angle (screen radians, 0 = right, y down); it sways.
class GustArrow extends Control:
	var angle := 0.0
	var _t := 0.0

	func _init() -> void:
		custom_minimum_size = Vector2(30, 30)
		size_flags_vertical = Control.SIZE_SHRINK_CENTER
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _process(delta: float) -> void:
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var c := size * 0.5
		var r := minf(size.x, size.y) * 0.5
		draw_circle(c, r, UITheme.INK)
		draw_circle(c, r - 3.0, UITheme.MUSTARD)
		draw_set_transform(c + Vector2(cos(angle), sin(angle)) * sin(_t * 9.0) * 1.5, angle + sin(_t * 6.0) * 0.08)
		var ink := UITheme.INK
		draw_line(Vector2(-r * 0.55, 0), Vector2(r * 0.25, 0), ink, 4.0, true)
		draw_colored_polygon(PackedVector2Array([Vector2(r * 0.62, 0), Vector2(r * 0.05, -r * 0.42), Vector2(r * 0.05, r * 0.42)]), ink)
		draw_set_transform(Vector2.ZERO)
