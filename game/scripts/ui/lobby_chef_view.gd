class_name LobbyChefView
extends SubViewportContainer
## Small turntable of the chef model (transparent background). Either a fixed colour
## (LobbyChefView.new(color, px)) or following a player's look (LobbyChefView.new(color, px, peer_id),
## or follow(peer_id) later): colour, hat and accessory from Net.look_of, updated live on Net.looks_changed.

var peer_id := 0  ## > 0: dressed from Net.look_of(peer_id)
var turntable := false  ## set before adding: full slow spin, drag (mouse / touch) to turn, wider framing (Wardrobe)

var _vp: SubViewport
var _pivot: Node3D
var _model: Node3D
var _anim: ChefAnim  # idle life (breathing, blinks, glances)
var _color := Color.WHITE
var _px := Vector2i(150, 150)
var _look_key := ""
var _want: Dictionary = {}  # look (Net.look_of shape) to show once the model exists


func _init(color := Color.WHITE, px := Vector2i(150, 150), follow_peer := 0) -> void:
	_color = color
	_px = px
	peer_id = follow_peer


## Dress the model from this player's look, now and whenever a look changes.
func follow(id: int) -> void:
	peer_id = id
	_refresh_look()


## Show a fixed look (dev scenes / previews; Net.look_of shape, missing keys = defaults); stops following a player.
func show_look(l: Dictionary) -> void:
	peer_id = 0
	_want = l
	_update_look()


func _ready() -> void:
	var color := _color
	var px := _px
	stretch = true
	custom_minimum_size = Vector2(px)
	mouse_filter = Control.MOUSE_FILTER_STOP if turntable else Control.MOUSE_FILTER_IGNORE
	if turntable:
		mouse_default_cursor_shape = Control.CURSOR_DRAG
	_vp = SubViewport.new()
	_vp.own_world_3d = true
	_vp.transparent_bg = true
	_vp.msaa_3d = Viewport.MSAA_4X
	_vp.size = px
	add_child(_vp)
	var root := Node3D.new()
	_vp.add_child(root)
	var model := Models.load_model("chef")
	if model == null:
		return
	_model = model
	_anim = ChefAnim.new(model, peer_id)
	tint(model, color)
	_pivot = Node3D.new()
	_pivot.add_child(model)
	root.add_child(_pivot)
	var box := aabb_of(model)
	var h := maxf(box.size.y, 0.5)
	var mid := Vector3(0, box.position.y + h * 0.5, 0)
	var light := DirectionalLight3D.new()
	light.rotation = Vector3(deg_to_rad(-40), deg_to_rad(30), 0)
	root.add_child(light)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.9, 0.9, 1.0)
	env.ambient_light_energy = 0.55
	var we := WorldEnvironment.new()
	we.environment = env
	root.add_child(we)
	var cam := Camera3D.new()
	cam.fov = 30.0
	root.add_child(cam)
	cam.current = true
	cam.position = mid + Vector3(0, h * 0.05, h * 2.5)
	if turntable:
		# Room for tall bodies, hats and back items; a touch from above.
		mid.y += h * 0.08
		cam.position = mid + Vector3(0, h * 0.35, h * 3.3)
	cam.look_at(mid, Vector3.UP)
	Net.looks_changed.connect(_refresh_look)
	_refresh_look()


func _refresh_look() -> void:
	if peer_id > 0:
		_want = Net.look_of(peer_id)
	_update_look()


func _update_look() -> void:
	if _model == null or _want.is_empty():
		return
	var key := "%d|%s" % [int(_want.get("color", 0)), Chef.look_ids(_want)]
	if key == _look_key:
		return
	_look_key = key
	var n := GameData.PLAYER_COLORS.size()
	Chef.dress(_model, GameData.PLAYER_COLORS[posmod(int(_want.get("color", 0)), n)], _want)
	_anim.refresh_rest()


func _process(delta: float) -> void:
	if _pivot != null:
		if turntable:
			_idle += delta
			if not _dragging and _idle > 1.5:
				_pivot.rotation.y += delta * 0.6 * clampf(_idle - 1.5, 0.0, 1.0)
		else:
			_pivot.rotation.y = sin(Time.get_ticks_msec() * 0.0012) * 0.55
	if _anim != null:
		_anim.update(delta)


var _dragging := false
var _idle := 0.0


## Turntable: drag to spin; the slow auto-spin resumes a moment after letting go.
func _gui_input(event: InputEvent) -> void:
	if not turntable or _pivot == null:
		return
	if event is InputEventMouseButton and (event as InputEventMouseButton).button_index == MOUSE_BUTTON_LEFT:
		_dragging = event.is_pressed()
		_idle = 0.0
		accept_event()
	elif event is InputEventScreenTouch:
		_dragging = event.is_pressed()
		_idle = 0.0
	elif event is InputEventMouseMotion and _dragging:
		_pivot.rotation.y += (event as InputEventMouseMotion).relative.x * 0.012
		_idle = 0.0
		accept_event()
	elif event is InputEventScreenDrag:
		_pivot.rotation.y += (event as InputEventScreenDrag).relative.x * 0.012
		_idle = 0.0


## Turntable: face the camera (front) or show the back (back items).
func face(back := false) -> void:
	if _pivot != null:
		_pivot.rotation.y = PI if back else 0.0
		_idle = 0.0


## Recolour every ChefBody / HatTint surface (same rule as the game chef: Chef.tint).
static func tint(n: Node, color: Color) -> void:
	Chef.tint(n, color)


## Local-space bounding box of every mesh under n.
static func aabb_of(n: Node3D) -> AABB:
	var out := AABB()
	var first := true
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var b := m.mesh.get_aabb() if m.mesh != null else AABB()
		var xf := Transform3D.IDENTITY
		var cur: Node = m
		while cur != null and cur != n:
			if cur is Node3D:
				xf = (cur as Node3D).transform * xf
			cur = cur.get_parent()
		b = xf * b
		out = b if first else out.merge(b)
		first = false
	return out
