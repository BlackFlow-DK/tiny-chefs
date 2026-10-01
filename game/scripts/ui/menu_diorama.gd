class_name MenuDiorama
extends SubViewportContainer
## Living backdrop for menu/lobby: the selected map's kitchen (Net.settings.map, built by Kitchen,
## read-only; rebuilt when the setting changes) with a few chefs, stations and a burger stack, seen by
## a slowly drifting shallow-focus camera + vignette. A MapDef may frame it with an optional
## "menu": {"focus": Vector3, "plate": Vector3, "height": float (camera above the focus)}; the diner
## framing is the default.
## Rendering pauses while hidden.

const DEFAULT_FOCUS := Vector3(4.4, 1.0, 5.0)
const DEFAULT_PLATE := Vector3(12.5, 0, 2.5)

var focus := DEFAULT_FOCUS
var height := 2.0
var _vp: SubViewport
var _cam: Camera3D
var _root: Node3D
var _map_id := ""
var _chefs: Array = []
var _t := 0.0
var _seed := 0.0


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
	_rebuild()
	Net.settings_changed.connect(_rebuild)
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


func _on_vis() -> void:
	if _vp != null:
		_vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS if is_visible_in_tree() else SubViewport.UPDATE_DISABLED
	set_process(is_visible_in_tree())


## (Re)builds the kitchen set for the selected map; a no-op while the map is unchanged.
func _rebuild() -> void:
	var id := str(Net.settings.map) if Net.settings != null else "diner"
	if id == _map_id and _root != null:
		return
	_map_id = id
	if _root != null:
		_root.queue_free()
	_chefs.clear()
	var map := GameData.map(id)
	var menu: Dictionary = map.get("menu", {})
	focus = menu.get("focus", DEFAULT_FOCUS)
	height = float(menu.get("height", 2.0))
	_root = Node3D.new()
	_vp.add_child(_root)
	Kitchen.build(_root, map)
	_build_set(_root, map, menu.get("plate", DEFAULT_PLATE))


func _build_set(root: Node3D, map: Dictionary, plate_pos: Vector3) -> void:
	# Stations from the game data (visuals only, no colliders).
	for s in map["stations"]:
		if float(s["pos"].z) > focus.z + 1.0:
			continue  # would sit between the camera and the chefs
		var n := Models.load_model(str(s["model"]))
		if n == null:
			continue
		n.position = s["pos"]
		n.rotation.y = deg_to_rad(float(s.get("yaw", 0.0)))
		root.add_child(n)
	# Burger stack on the plate.
	var plate := Models.load_model("plate")
	if plate != null:
		plate.position = plate_pos
		root.add_child(plate)
	var y := 0.4
	for item in ["bun_bottom", "patty_cooked", "cheese_slice", "lettuce_leaf", "bun_top"]:
		var it := Models.load_model(item)
		if it == null:
			continue
		it.position = plate_pos + Vector3(0, y, 0)
		root.add_child(it)
		y += _height(it)
	# Chefs in the four player colours, mid-shift, around the focus.
	var spots := [Vector3(-1.8, 0, 0.0), Vector3(0.0, 0, -1.4), Vector3(1.8, 0, 0.2), Vector3(-0.2, 0, 1.6)]
	var yaws := [-0.5, 0.0, 0.45, -0.15]
	for i in 4:
		var c := Models.load_model("chef")
		if c == null:
			continue
		LobbyChefView.tint(c, GameData.PLAYER_COLORS[i])
		var holder := Node3D.new()
		holder.position = Vector3(focus.x, 0, focus.z) + spots[i]
		holder.rotation.y = yaws[i]
		holder.add_child(c)
		root.add_child(holder)
		_chefs.append(holder)


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
	var pos := focus + Vector3(sin(a) * r, height + sin(_t * 0.23) * 0.35, cos(a) * r)
	_cam.position = pos
	_cam.look_at(focus, Vector3.UP)
	_cam.h_offset = -1.9
