class_name LobbyChefView
extends SubViewportContainer
## Small turntable of the chef model (transparent background). Either a fixed colour
## (LobbyChefView.new(color, px)) or following a player's look (LobbyChefView.new(color, px, peer_id),
## or follow(peer_id) later): colour, hat and accessory from Net.look_of, updated live on Net.looks_changed.

var peer_id := 0  ## > 0: dressed from Net.look_of(peer_id)

var _vp: SubViewport
var _pivot: Node3D
var _model: Node3D
var _color := Color.WHITE
var _px := Vector2i(150, 150)
var _look_key := ""
var _want: Array = []  # [color index, hat, acc] to show once the model exists


func _init(color := Color.WHITE, px := Vector2i(150, 150), follow_peer := 0) -> void:
	_color = color
	_px = px
	peer_id = follow_peer


## Dress the model from this player's look, now and whenever a look changes.
func follow(id: int) -> void:
	peer_id = id
	_refresh_look()


## Show a fixed look (dev scenes / previews); stops following a player.
func show_look(color_idx: int, hat: String, acc: String) -> void:
	peer_id = 0
	_want = [color_idx, hat, acc]
	_update_look()


func _ready() -> void:
	var color := _color
	var px := _px
	stretch = true
	custom_minimum_size = Vector2(px)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
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
	cam.look_at(mid, Vector3.UP)
	Net.looks_changed.connect(_refresh_look)
	_refresh_look()


func _refresh_look() -> void:
	if peer_id > 0:
		var look := Net.look_of(peer_id)
		_want = [int(look["color"]), str(look["hat"]), str(look["acc"])]
	_update_look()


func _update_look() -> void:
	if _model == null or _want.is_empty():
		return
	var key := "%d|%s|%s" % _want
	if key == _look_key:
		return
	_look_key = key
	var n := GameData.PLAYER_COLORS.size()
	Chef.dress(_model, GameData.PLAYER_COLORS[posmod(int(_want[0]), n)], str(_want[1]), str(_want[2]))


func _process(delta: float) -> void:
	if _pivot != null:
		_pivot.rotation.y = sin(Time.get_ticks_msec() * 0.0012) * 0.55


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
