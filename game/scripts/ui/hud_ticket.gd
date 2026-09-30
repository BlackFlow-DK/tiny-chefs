class_name HudTicket
extends Control
## One order ticket hanging from the HUD rail: pin, number tag, dish name, ingredient chips (with
## doubles badges and plate ticks), patience bar. Tilts 1-2 degrees, shakes under 25% patience.
## Positioned by HudOrderRail. Local to the HUD (the design system's UIOrderTicket has no chip state).

const W := 184.0
const PIN := Vector2(W * 0.5, 2.0)

var recipe := 0
var left := 0.0
var patience := 1.0
var tilt := 0.0        # resting rotation (radians)
var base_x := 0.0
var fx_offset := Vector2.ZERO   # entrance offset, tweened
var _card: PanelContainer
var _sb: StyleBoxFlat
var _bar: UIProgress
var _chips: Array[HudChip] = []
var _flash: Panel
var _flash_sb: StyleBoxFlat
var _urgent: Tween
var _urgent_state := false


func setup(recipe_idx: int, number_text: String, tilt_deg: float) -> void:
	recipe = recipe_idx
	tilt = deg_to_rad(tilt_deg)
	rotation = tilt
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var rec: Dictionary = GameData.RECIPES[recipe_idx]

	_card = PanelContainer.new()
	_card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_card.custom_minimum_size = Vector2(W, 0)
	_sb = UITheme.box(UITheme.CREAM, UITheme.INK, 12, 4, 5)
	_sb.content_margin_left = 12
	_sb.content_margin_right = 12
	_sb.content_margin_top = 18
	_sb.content_margin_bottom = 12
	_card.add_theme_stylebox_override("panel", _sb)
	add_child(_card)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	_card.add_child(v)

	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 6)
	var tag := PanelContainer.new()
	var tsb := UITheme.box(UITheme.MUSTARD, UITheme.INK, 8, 3)
	tsb.content_margin_left = 6
	tsb.content_margin_right = 6
	tsb.content_margin_top = 0
	tsb.content_margin_bottom = 1
	tag.add_theme_stylebox_override("panel", tsb)
	tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var tl := UIKit.number(number_text)
	tl.add_theme_font_size_override("font_size", UITheme.S_CAPTION)
	tag.add_child(tl)
	head.add_child(tag)
	var name_l := UIKit.heading(rec["name"])
	name_l.add_theme_font_size_override("font_size", UITheme.S_CAPTION)
	name_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	name_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	name_l.custom_minimum_size = Vector2(0, 40)
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(name_l)
	v.add_child(head)

	# Wraps to a second row for long recipes (Burger Meal, The Works) so the ticket keeps its width W.
	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 4)
	row.add_theme_constant_override("v_separation", 4)
	var counts := {}
	var order: Array = []
	for k in rec["items"]:
		if not counts.has(k):
			order.append(k)
		counts[k] = int(counts.get(k, 0)) + 1
	for k in order:
		var c := HudChip.new()
		c.setup(str(k), int(counts[k]))
		row.add_child(c)
		_chips.append(c)
	v.add_child(row)

	_bar = UIKit.progress(1.0, 150, 14, true)
	_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(_bar)

	_flash_sb = UITheme.box(Color(1, 1, 1, 0.8), Color(0, 0, 0, 0), 12, 0)
	_flash = Panel.new()
	_flash.add_theme_stylebox_override("panel", _flash_sb)
	_flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_flash.modulate.a = 0.0
	add_child(_flash)

	var pin := Control.new()
	pin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pin.draw.connect(func() -> void:
		pin.draw_circle(PIN + Vector2(0, 3), 10.0, UITheme.INK)
		pin.draw_circle(PIN, 9.0, UITheme.INK)
		pin.draw_circle(PIN, 6.5, UITheme.TOMATO)
		pin.draw_circle(PIN + Vector2(-2, -2), 2.2, UITheme.CREAM))
	add_child(pin)

	_card.resized.connect(_on_card_resized)
	_on_card_resized.call_deferred()


func _on_card_resized() -> void:
	size = Vector2(W, _card.size.y + 5)
	custom_minimum_size = size
	_flash.position = Vector2.ZERO
	_flash.size = _card.size
	pivot_offset = PIN


func set_progress(left_s: float, patience_s: float) -> void:
	left = left_s
	patience = patience_s
	var f := clampf(left_s / maxf(patience_s, 0.01), 0.0, 1.0)
	_bar.set_fraction(f)
	_set_urgent(f < 0.25 and f > 0.0)


func set_plate(stack: Array) -> void:
	for c in _chips:
		var n := 0
		for k in stack:
			if k == c.kind:
				n += 1
		c.set_have(n)


func flash(col: Color, hold := 0.5) -> void:
	_flash_sb.bg_color = Color(col.r, col.g, col.b, 0.8)
	_flash.modulate.a = 1.0
	var tw := create_tween()
	tw.tween_property(_flash, "modulate:a", 0.25, hold)


func stop_urgent() -> void:
	_set_urgent(false)


func _set_urgent(on: bool) -> void:
	if on == _urgent_state:
		return
	_urgent_state = on
	if _urgent != null:
		_urgent.kill()
		_urgent = null
	if on and is_inside_tree():
		_sb.border_color = UITheme.TOMATO
		# heartbeat + little shake around the pin
		_urgent = create_tween().set_loops()
		_urgent.tween_property(self, "scale", Vector2.ONE * 1.05, 0.2).set_trans(Tween.TRANS_SINE)
		_urgent.parallel().tween_property(self, "rotation", tilt + 0.035, 0.1)
		_urgent.tween_property(self, "rotation", tilt - 0.035, 0.1)
		_urgent.tween_property(self, "scale", Vector2.ONE, 0.25).set_trans(Tween.TRANS_SINE)
		_urgent.parallel().tween_property(self, "rotation", tilt, 0.25)
		_urgent.tween_interval(0.35)
	else:
		_sb.border_color = UITheme.INK
		scale = Vector2.ONE
		rotation = tilt
