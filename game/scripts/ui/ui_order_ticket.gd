class_name UIOrderTicket
extends PanelContainer
## Diner order ticket: [#n] dish name, a row of ingredient swatches, patience bar.
## Build with UIKit.order_ticket(); update with set_patience(0..1). Below 20% the ticket pulses.

var patience_bar: UIProgress
var _pulse: Tween
var _dish := ""
var _colors: Array = []
var _number := ""


func setup(dish: String, ingredient_colors: Array, patience: float, number_text: String) -> void:
	_dish = dish
	_colors = ingredient_colors
	_number = number_text
	custom_minimum_size = Vector2(190, 0)
	var sb := UITheme.box(UITheme.CREAM, UITheme.INK, 12, 4, 5)
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.content_margin_top = 8
	sb.content_margin_bottom = 12
	add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	if not _number.is_empty():
		var tag := PanelContainer.new()
		var tsb := UITheme.box(UITheme.MUSTARD, UITheme.INK, 8, 3)
		tsb.content_margin_left = 8
		tsb.content_margin_right = 8
		tsb.content_margin_top = 0
		tsb.content_margin_bottom = 1
		tag.add_theme_stylebox_override("panel", tsb)
		var tl := UIKit.number(_number)
		tl.add_theme_font_size_override("font_size", UITheme.S_CAPTION)
		tag.add_child(tl)
		head.add_child(tag)
	var name_l := UIKit.heading(_dish)
	name_l.add_theme_font_size_override("font_size", UITheme.S_BODY)
	name_l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(name_l)
	v.add_child(head)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	for c in _colors:
		row.add_child(UIKit.chip_swatch(c, 26))
	v.add_child(row)
	patience_bar = UIKit.progress(patience, 100, 16, true)
	patience_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.add_child(patience_bar)
	set_patience(patience)


func set_patience(f: float) -> void:
	patience_bar.set_fraction(f)
	if f < 0.2 and f > 0.0 and _pulse == null and is_inside_tree():
		_pulse = UIKit.pulse(self, 0.04, 0.45)
	elif (f >= 0.2 or f <= 0.0) and _pulse != null:
		_pulse.kill()
		_pulse = null
		scale = Vector2.ONE
