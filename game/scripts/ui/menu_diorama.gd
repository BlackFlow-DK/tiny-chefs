class_name MenuDiorama
extends SubViewportContainer
## Living backdrop for menu/lobby: the selected map's kitchen (built by Kitchen, read-only) with a few
## chefs, stations and a burger stack, seen by a slowly drifting shallow-focus camera + vignette.
## Rendering pauses while hidden.

const DEFAULT_FOCUS := Vector3(4.4, 1.0, 5.0)

var focus := DEFAULT_FOCUS
var _yaw := 0.0              # map "menu_view" yaw: 180 looks from the far side towards the front edge
var _lift := 0.0             # map "menu_view" lift: look this far above the focus (more sky)
var _vp: SubViewport
var _cam: Camera3D
var _chefs: Array = []
var _t := 0.0
var _seed := 0.0
var _root: Node3D
var _map_id := ""


func _ready() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	UI.full_rect(self)
	_vp = SubViewport.new()
	_vp.own_world_3d = true
	_vp.msaa_3d = Viewport.MSAA_2X
	_vp.handle_input_locally = false
	_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_vp)
	_build_world()
	Net.settings_changed.connect(_on_settings_changed)
	_cam = Camera3D.new()
	_cam.fov = 42.0
	var attr := CameraAttributesPractical.new()
	attr.dof_blur_far_enabled = true
	attr.dof_blur_far_distance = 11.0
	attr.dof_blur_far_transition = 12.0
	attr.dof_blur_amount = 0.12
	_cam.attributes = attr
	_vp.add_child(_cam)
	_cam.current = true
	_place_camera()
	# Vignette + slight dim so cards read.
	var v := ColorRect.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = "shader_type canvas_item;
uniform vec4 tint : source_color = vec4(0.17, 0.13, 0.2, 1.0);
void fragment() {
	vec2 p = UV - vec2(0.5);
	float d = smoothstep(0.25, 0.85, length(p * vec2(1.1, 1.0)));
	COLOR = vec4(tint.rgb, 0.22 + d * 0.5);
}"
	var m := ShaderMaterial.new()
	m.shader = sh
	v.material = m
	v.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(v)
	visibility_changed.connect(_on_vis)
	_on_vis()


## The set for the selected map (Net.settings.map; the menu's own settings before hosting).
func _build_world() -> void:
	_map_id = str(Net.settings.map) if Net.settings != null else "diner"
	var map := GameData.map(_map_id)
	var view: Dictionary = map.get("menu_view", {})
	focus = view.get("focus", DEFAULT_FOCUS)
	_yaw = deg_to_rad(float(view.get("yaw", 0.0)))
	_lift = float(view.get("lift", 0.0))
	_root = Node3D.new()
	_vp.add_child(_root)
	_vp.move_child(_root, 0)
	Kitchen.build(_root, map)
	_build_set(_root)


func _on_settings_changed() -> void:
	if Net.settings == null or str(Net.settings.map) == _map_id or not GameData.MAPS.has(str(Net.settings.map)):
		return
	_chefs.clear()
	_root.queue_free()
	_build_world()


func _on_vis() -> void:
	if _vp != null:
		_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS if is_visible_in_tree() else SubViewport.UPDATE_DISABLED
	set_process(is_visible_in_tree())


func _build_set(root: Node3D) -> void:
	# Stations from the game data (visuals only, no colliders).
	var back := Vector3(0, 0, 1).rotated(Vector3.UP, _yaw)   # from the focus towards the camera
	for s in GameData.map(_map_id)["stations"]:
		var rel: Vector3 = s["pos"] - focus
		if Vector3(rel.x, 0, rel.z).dot(back) > 1.0:
			continue  # would sit between the camera and the chefs
		var n := Models.load_model(str(s["model"]))
		if n == null:
			continue
		n.position = s["pos"]
		n.rotation.y = deg_to_rad(float(s.get("yaw", 0.0)))
		root.add_child(n)
	# Burger stack on the plate.
	var at := _set_pos(Vector3(12.5, 0, 2.5))
	var plate := Models.load_model("plate")
	if plate != null:
		plate.position = at
		root.add_child(plate)
	var y := 0.4
	for item in ["bun_bottom", "patty_cooked", "cheese_slice", "lettuce_leaf", "bun_top"]:
		var it := Models.load_model(item)
		if it == null:
			continue
		it.position = at + Vector3(0, y, 0)
		root.add_child(it)
		y += _height(it)
	# Chefs in the four player colours, mid-shift, each with a random hat and accessory.
	var spots := [Vector3(2.6, 0, 5.0), Vector3(4.4, 0, 3.6), Vector3(6.2, 0, 5.2), Vector3(4.2, 0, 6.6)]
	var yaws := [-0.5, 0.0, 0.45, -0.15]
	for i in 4:
		var c := Models.load_model("chef")
		if c == null:
			continue
		var hat: Dictionary = GameData.HATS.pick_random()
		var acc: Dictionary = GameData.ACCESSORIES.pick_random()
		Chef.dress(c, GameData.PLAYER_COLORS[i], str(hat["id"]), str(acc["id"]))
		var holder := Node3D.new()
		holder.position = _set_pos(spots[i])
		holder.rotation.y = yaws[i] + _yaw
		holder.add_child(c)
		root.add_child(holder)
		_chefs.append(holder)


## A diner-layout staging position moved to this map's focus and turned by its menu yaw.
func _set_pos(p: Vector3) -> Vector3:
	var d := p - DEFAULT_FOCUS
	d.y = 0.0
	var out := focus + d.rotated(Vector3.UP, _yaw)
	out.y = p.y
	return out


static func _height(n: Node3D) -> float:
	var box := LobbyChefView.aabb_of(n)
	return maxf(box.size.y, 0.02)


func _process(delta: float) -> void:
	_t += delta
	_place_camera()
	for i in _chefs.size():
		var h: Node3D = _chefs[i]
		h.position.y = absf(sin(_t * 2.2 + i * 1.7)) * 0.07
		h.rotation.y += sin(_t * 0.9 + i) * 0.002


func _place_camera() -> void:
	var a := sin(_t * 0.16 + _seed) * 0.32
	var r := 6.8
	var pos := focus + Vector3(sin(a) * r, 2.0 + sin(_t * 0.23) * 0.35, cos(a) * r).rotated(Vector3.UP, _yaw)
	_cam.position = pos
	_cam.look_at(focus + Vector3(0, _lift, 0), Vector3.UP)
	_cam.h_offset = -1.9
