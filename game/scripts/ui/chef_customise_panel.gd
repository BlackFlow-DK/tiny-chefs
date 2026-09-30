class_name ChefCustomisePanel
extends VBoxContainer
## Compact look picker for the LOCAL player (lobby card): colour swatches, hat chips, accessory chips.
## setup(peer_id): editable only when peer_id is this machine's player; picks go to Net.set_look (saved
## in menu.cfg, replicated to everyone). Follows Net.looks_changed. A LobbyChefView in the same card
## with no player set is made to follow peer_id, so the card's chef shows the pick live.
## Fits a ~150 px wide card.

const T = preload("res://scripts/ui/ui_theme.gd")
const CHIP := Vector2(34, 32)
const SWATCH := Vector2(30, 30)

var peer_id := 0

var _swatches: Array[Button] = []
var _hat_chips: Array[Button] = []
var _acc_chips: Array[Button] = []
var _label: Label
var _warn: Label
var _look := {"color": 0, "hat": "toque", "acc": "none"}


func setup(id: int) -> void:
	peer_id = id
	if is_inside_tree():
		_refresh()


func _ready() -> void:
	add_theme_constant_override("separation", 6)
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	if peer_id == 0:
		peer_id = Net.my_id()
	_swatches = []
	var row := _row()
	for i in GameData.PLAYER_COLORS.size():
		var b := _chip_button(SWATCH, "%s jacket" % GameData.COLOR_NAMES[i])
		b.pressed.connect(func() -> void: _pick({"color": i}))
		b.draw.connect(_draw_swatch.bind(b, i))
		row.add_child(b)
		_swatches.append(b)
	row = _row()
	for h: Dictionary in GameData.HATS:
		var id := str(h["id"])
		var b := _chip_button(CHIP, str(h["label"]))
		b.pressed.connect(func() -> void: _pick({"hat": id}))
		b.draw.connect(_draw_icon.bind(b, "hat_" + id))
		row.add_child(b)
		_hat_chips.append(b)
	row = _row()
	for a: Dictionary in GameData.ACCESSORIES:
		var id := str(a["id"])
		var b := _chip_button(CHIP, str(a["label"]))
		b.pressed.connect(func() -> void: _pick({"acc": id}))
		b.draw.connect(_draw_icon.bind(b, "acc_" + id))
		row.add_child(b)
		_acc_chips.append(b)
	_label = UIKit.caption("")
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(_label)
	_warn = UIKit.caption("")
	_warn.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_warn.add_theme_color_override("font_color", T.TOMATO_DARK)
	_warn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_warn.custom_minimum_size = Vector2(140, 0)
	add_child(_warn)
	Net.looks_changed.connect(_refresh)
	Net.players_changed.connect(_refresh)
	_refresh()
	_bind_card_view.call_deferred()


func editable() -> bool:
	return peer_id == Net.my_id()


func _row() -> HBoxContainer:
	var r := HBoxContainer.new()
	r.add_theme_constant_override("separation", 6)
	r.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(r)
	return r


func _chip_button(sz: Vector2, tip: String) -> Button:
	var b := Button.new()
	b.custom_minimum_size = sz
	b.tooltip_text = tip
	b.focus_mode = Control.FOCUS_ALL
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	UIKit.attach_press_squash(b)
	return b


## Chip look: cream (mustard when selected), ink outline, small hard shadow.
func _style(b: Button, fill: Color, selected: bool) -> void:
	var bw := 4 if selected else 3
	var sets := {
		"normal": T.box(fill, T.INK, 10, bw, 3),
		"hover": T.box(fill.lightened(0.12), T.INK, 10, bw, 5, 2),
		"pressed": T.box(fill.darkened(0.12), T.INK, 10, bw, 0, -3),
		"hover_pressed": T.box(fill.darkened(0.12), T.INK, 10, bw, 0, -3),
		"disabled": T.box(fill.lerp(T.PAPER_OFF, 0.5), T.PAPER_OFF_INK, 10, bw, 2, 0, T.PAPER_OFF_INK),
	}
	for k: String in sets:
		var sb: StyleBoxFlat = sets[k]
		sb.set_content_margin_all(2)
		b.add_theme_stylebox_override(k, sb)
	var focus := StyleBoxFlat.new()
	focus.draw_center = false
	focus.border_color = T.SKY
	focus.set_border_width_all(3)
	focus.set_corner_radius_all(13)
	focus.set_expand_margin_all(4)
	focus.expand_margin_bottom = 7
	b.add_theme_stylebox_override("focus", focus)


func _pick(d: Dictionary) -> void:
	if not editable():
		return
	Net.set_look(d)
	_refresh()


func _refresh() -> void:
	if _label == null:
		return
	_look = Net.look_of(peer_id)
	var on := editable()
	for i in _swatches.size():
		var b := _swatches[i]
		_style(b, GameData.PLAYER_COLORS[i], i == int(_look["color"]))
		b.disabled = not on
		b.queue_redraw()
	for i in _hat_chips.size():
		var sel: bool = GameData.HATS[i]["id"] == _look["hat"]
		_style(_hat_chips[i], T.MUSTARD if sel else T.CREAM_HI, sel)
		_hat_chips[i].disabled = not on
		_hat_chips[i].queue_redraw()
	for i in _acc_chips.size():
		var sel: bool = GameData.ACCESSORIES[i]["id"] == _look["acc"]
		_style(_acc_chips[i], T.MUSTARD if sel else T.CREAM_HI, sel)
		_acc_chips[i].disabled = not on
		_acc_chips[i].queue_redraw()
	var parts := PackedStringArray([_label_of(GameData.HATS, str(_look["hat"]))])
	if _look["acc"] != "none":
		parts.append(_label_of(GameData.ACCESSORIES, str(_look["acc"])))
	_label.text = "%s · %s" % [GameData.COLOR_NAMES[int(_look["color"])], " + ".join(parts)]
	var same := PackedStringArray()
	for id in Net.players.keys():
		if int(id) != peer_id and Net.color_index_of(int(id)) == int(_look["color"]):
			same.append(Net.name_of(int(id)))
	_warn.text = "Same colour as %s" % ", ".join(same) if not same.is_empty() else ""
	_warn.visible = not same.is_empty()


static func _label_of(table: Array, id: String) -> String:
	for e: Dictionary in table:
		if e["id"] == id:
			return str(e["label"])
	return id


## The card's LobbyChefView (built by the lobby without a player) follows this player.
func _bind_card_view() -> void:
	var n: Node = get_parent()
	for _i in 3:
		if n == null:
			return
		var v := _find_view(n)
		if v != null:
			if v.peer_id == 0:
				v.follow(peer_id)
			return
		n = n.get_parent()


static func _find_view(n: Node) -> LobbyChefView:
	if n is LobbyChefView:
		return n
	for c in n.get_children():
		if c is ChefCustomisePanel:
			continue
		var v := _find_view(c)
		if v != null:
			return v
	return null


# ---------------------------------------------------------------- icons (drawn on the chips)

func _draw_swatch(b: Button, i: int) -> void:
	if i != int(_look["color"]):
		return
	var c := b.size * 0.5 + Vector2(0, _press_dy(b))
	var s := b.size.x * 0.22
	var pts := PackedVector2Array([c + Vector2(-s, 0), c + Vector2(-s * 0.3, s * 0.7), c + Vector2(s, -s * 0.7)])
	b.draw_polyline(pts, T.INK, 5.0, true)
	b.draw_polyline(pts, T.CREAM_HI, 2.5, true)


## Content moves with the chip's pressed/hover lift.
func _press_dy(b: Button) -> float:
	if b.button_pressed or b.get_draw_mode() == BaseButton.DRAW_PRESSED or b.get_draw_mode() == BaseButton.DRAW_HOVER_PRESSED:
		return 3.0
	if b.get_draw_mode() == BaseButton.DRAW_HOVER:
		return -2.0
	return 0.0


func _draw_icon(b: Button, icon: String) -> void:
	var c := b.size * 0.5 + Vector2(0, _press_dy(b))
	var u := minf(b.size.x, b.size.y) / 32.0  # icon unit: drawn on a 32 px grid
	var ink := T.INK if not b.disabled else T.PAPER_OFF_INK
	var tintc: Color = GameData.PLAYER_COLORS[int(_look["color"])]
	var white := Color("#FBF9F3")
	match icon:
		"hat_toque":
			for p: Vector2 in [Vector2(-5, -4), Vector2(5, -4), Vector2(0, -7)]:
				b.draw_circle(c + p * u, 6.5 * u, ink)
			b.draw_rect(Rect2(c + Vector2(-7.5, -3) * u, Vector2(15, 10.5) * u), ink)
			for p: Vector2 in [Vector2(-5, -4), Vector2(5, -4), Vector2(0, -7)]:
				b.draw_circle(c + p * u, 4.8 * u, white)
			b.draw_rect(Rect2(c + Vector2(-5.8, -3) * u, Vector2(11.6, 8.8) * u), white)
		"hat_beanie":
			var dome := _arc(c + Vector2(0, 3) * u, 9.5 * u, PI, TAU, 12)
			_poly(b, dome, tintc, ink, u)
			b.draw_rect(Rect2(c + Vector2(-10.5, 2) * u, Vector2(21, 5) * u), ink)
			b.draw_rect(Rect2(c + Vector2(-9, 3.3) * u, Vector2(18, 2.4) * u), tintc.darkened(0.2))
			b.draw_circle(c + Vector2(0, -8) * u, 3.4 * u, ink)
			b.draw_circle(c + Vector2(0, -8) * u, 2.0 * u, white)
		"hat_paper":
			var boat := PackedVector2Array([c + Vector2(-11, 6) * u, c + Vector2(0, -9) * u, c + Vector2(11, 6) * u])
			_poly(b, boat, white, ink, u)
			b.draw_line(c + Vector2(-9, 3) * u, c + Vector2(9, 3) * u, ink, 1.5 * u, true)
		"hat_bandana":
			var band := PackedVector2Array([c + Vector2(-9, -4) * u, c + Vector2(8, -4) * u, c + Vector2(8, 3) * u, c + Vector2(-9, 3) * u])
			_poly(b, band, tintc, ink, u)
			var tail := PackedVector2Array([c + Vector2(6, 1) * u, c + Vector2(11, 8) * u, c + Vector2(4, 8) * u])
			_poly(b, tail, tintc, ink, u)
			b.draw_circle(c + Vector2(-4, -0.5) * u, 1.2 * u, white)
			b.draw_circle(c + Vector2(2, -0.5) * u, 1.2 * u, white)
		"acc_none":
			b.draw_arc(c, 8 * u, 0, TAU, 20, ink, 2.5 * u, true)
			b.draw_line(c + Vector2(-5.6, 5.6) * u, c + Vector2(5.6, -5.6) * u, ink, 2.5 * u, true)
		"acc_glasses":
			for s in [-1.0, 1.0]:
				b.draw_circle(c + Vector2(s * 6, 0) * u, 5 * u, Color(0.7, 0.85, 1.0))
				b.draw_arc(c + Vector2(s * 6, 0) * u, 5 * u, 0, TAU, 18, ink, 2.2 * u, true)
			b.draw_line(c + Vector2(-1.2, -0.5) * u, c + Vector2(1.2, -0.5) * u, ink, 2.2 * u, true)
		"acc_moustache":
			# Two lobes with curled tips: ink silhouettes first, then the fills, so no seam shows.
			var brown := Color("#5C3B26")
			for pass_i in 2:
				var grow := 1.3 if pass_i == 0 else 0.0
				var col := ink if pass_i == 0 else brown
				for sx in [-1.0, 1.0]:
					b.draw_colored_polygon(_ellipse(c + Vector2(sx * 5, 1) * u, Vector2(6.2 + grow, 3.2 + grow) * u, sx * -0.3), col)
					b.draw_circle(c + Vector2(sx * 10.5, -1.5) * u, (2.2 + grow) * u, col)


static func _ellipse(centre: Vector2, r: Vector2, rot: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for k in 16:
		var a := TAU * k / 16.0
		pts.append(centre + Vector2(cos(a) * r.x, sin(a) * r.y).rotated(rot))
	return pts


static func _arc(centre: Vector2, r: float, a0: float, a1: float, n: int) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for k in n + 1:
		var a := lerpf(a0, a1, float(k) / n)
		pts.append(centre + Vector2(cos(a), sin(a)) * r)
	return pts


static func _poly(b: Button, pts: PackedVector2Array, fill: Color, ink: Color, u: float) -> void:
	b.draw_colored_polygon(pts, fill)
	var closed := pts.duplicate()
	closed.append(pts[0])
	b.draw_polyline(closed, ink, 2.2 * u, true)
