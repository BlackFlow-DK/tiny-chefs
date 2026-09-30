class_name UICoinChip
extends PanelContainer
## Pill with a gold coin and an amount. set_amount(n) pops the chip when the value changes.

var dark := false
var amount := 0
var _label: Label


func _init() -> void:
	theme_type_variation = "ChipPanel"


func _ready() -> void:
	if dark:
		theme_type_variation = "DarkChipPanel"
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	var coin := Panel.new()
	coin.custom_minimum_size = Vector2(26, 26)
	coin.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	coin.add_theme_stylebox_override("panel", UITheme.box(UITheme.MUSTARD, UITheme.INK, 13, 3))
	var inner := Panel.new()
	inner.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT, Control.PRESET_MODE_MINSIZE, 6)
	inner.add_theme_stylebox_override("panel", UITheme.box(UITheme.MUSTARD_DARK, UITheme.MUSTARD_DARK, 7, 0))
	inner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	coin.add_child(inner)
	h.add_child(coin)
	_label = UIKit.number(str(amount), "dark" if dark else "card")
	_label.add_theme_font_size_override("font_size", UITheme.S_BODY + 4)
	h.add_child(_label)
	add_child(h)


func set_amount(n: int, animate := true) -> void:
	var changed := n != amount
	amount = n
	if _label != null:
		_label.text = str(n)
		if changed and animate:
			UIKit.punch(self)
