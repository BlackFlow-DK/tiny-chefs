class_name ChefCustomisePanel
extends VBoxContainer
## Compact look strip for the LOCAL player (lobby card): the four colour swatches, a one-line summary of the
## look and a "Wardrobe" button (hats, beards, face, outfits, back items, body shapes: WardrobeView).
## setup(peer_id): editable only when peer_id is this machine's player; picks go to Net.set_look (saved as the
## equipped look in Progress, replicated to everyone). Follows Net.looks_changed. A LobbyChefView in the same
## card with no player set is made to follow peer_id, so the card's chef shows the pick live.
## The Wardrobe button emits wardrobe_requested (the lobby opens its WardrobeView).

signal wardrobe_requested

const T = preload("res://scripts/ui/ui_theme.gd")
const SWATCH := Vector2(34, 34)

var peer_id := 0
var wide := false   ## set before adding: one row (swatches, summary, Wardrobe button) for a wide strip

var _swatches: Array[Button] = []
var _label: Label
var _warn: Label
var _wardrobe_btn: Button
var _look := {"color": 0}


func setup(id: int) -> void:
	peer_id = id
	if is_inside_tree():
		_refresh()


func _ready() -> void:
	add_theme_constant_override("separation", 6)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL if wide else Control.SIZE_SHRINK_CENTER
	if peer_id == 0:
		peer_id = Net.my_id()
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.alignment = BoxContainer.ALIGNMENT_BEGIN if wide else BoxContainer.ALIGNMENT_CENTER
	add_child(row)
	_swatches = []
	for i in GameData.PLAYER_COLORS.size():
		var b := _chip_button(SWATCH, "%s jacket" % GameData.COLOR_NAMES[i])
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		b.pressed.connect(func() -> void: _pick({"color": i}))
		b.draw.connect(_draw_swatch.bind(b, i))
		row.add_child(b)
		_swatches.append(b)
	_label = UIKit.caption("")
	_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_label.clip_text = true
	_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_wardrobe_btn = UIKit.button("Wardrobe", func() -> void: wardrobe_requested.emit(), "accent", 150)
	_wardrobe_btn.custom_minimum_size.y = 46
	_wardrobe_btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if wide:
		# The strip is narrow (two lobby cells): swatches + a wide Wardrobe button; the summary is its tooltip
		# (the player's card above shows the look anyway).
		var sp := Control.new()
		sp.custom_minimum_size = Vector2(6, 0)
		sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(sp)
		_wardrobe_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(_wardrobe_btn)
		_label.visible = false
		add_child(_label)
	else:
		_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_label.custom_minimum_size = Vector2(140, 0)
		add_child(_label)
		_wardrobe_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		add_child(_wardrobe_btn)
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


func _chip_button(sz: Vector2, tip: String) -> Button:
	var b := Button.new()
	b.custom_minimum_size = sz
	b.tooltip_text = tip
	b.focus_mode = Control.FOCUS_ALL
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	UIKit.attach_press_squash(b)
	return b


## Chip look: the colour, ink outline (thicker when picked), small hard shadow.
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
	_wardrobe_btn.visible = on
	_label.text = "%s · %s" % [GameData.COLOR_NAMES[int(_look["color"])], summary(_look)]
	_wardrobe_btn.tooltip_text = "Hats, beards, outfits and more. Wearing: %s" % _label.text
	var same := PackedStringArray()
	for id in Net.players.keys():
		if int(id) != peer_id and Net.color_index_of(int(id)) == int(_look["color"]):
			same.append(Net.name_of(int(id)))
	_warn.text = "Same colour as %s" % ", ".join(same) if not same.is_empty() else ""
	_warn.visible = not same.is_empty()


## "Cowboy hat + Glasses + Tall": the worn items that differ from the plain chef (or "Classic chef").
static func summary(l: Dictionary) -> String:
	var parts := PackedStringArray()
	for cat: String in Cosmetics.CATEGORIES:
		var id := str(l.get(cat, Cosmetics.default_id(cat)))
		if id != Cosmetics.default_id(cat) and id != str(Cosmetics.EMPTY.get(cat, "")):
			parts.append(Cosmetics.item_name(cat, id))
	return " + ".join(parts) if not parts.is_empty() else "Classic chef"


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


## A tick on the picked colour.
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
