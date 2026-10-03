class_name UITokenChip
extends PanelContainer
## Pill with the blue hexagon token and an amount (the player's wardrobe wallet). set_amount(n) counts the
## number to n and pops the chip; set_amount(n, false) jumps there. Optional caption above the number.

var dark := false
var amount := 0
var caption := ""
var big := false        ## title-size number (wardrobe wallet)
var _label: Label
var _shown := 0.0
var _tween: Tween


func _init() -> void:
	theme_type_variation = "ChipPanel"


func _ready() -> void:
	if dark:
		theme_type_variation = "DarkChipPanel"
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10 if big else 8)
	h.add_child(TokenIcon.new(40 if big else 26))
	var on := "dark" if dark else "card"
	_label = UIKit.number(str(amount), on, UITheme.SKY if dark else Color(0, 0, 0, 0))
	_label.add_theme_font_size_override("font_size", UITheme.S_TITLE if big else UITheme.S_BODY + 4)
	_label.custom_minimum_size = Vector2(56 if big else 0, 0)
	if caption.is_empty():
		h.add_child(_label)
	else:
		var v := VBoxContainer.new()
		v.add_theme_constant_override("separation", -6)
		v.alignment = BoxContainer.ALIGNMENT_CENTER
		v.add_child(UIKit.caption(caption, on))
		v.add_child(_label)
		h.add_child(v)
	add_child(h)
	_shown = amount


func set_amount(n: int, animate := true) -> void:
	var changed := n != amount
	amount = n
	if _label == null:
		_shown = n
		return
	if _tween != null:
		_tween.kill()
	if not changed or not animate:
		_shown = n
		_label.text = str(n)
		return
	_tween = create_tween()
	_tween.tween_method(func(v: float) -> void:
		_shown = v
		_label.text = str(roundi(v)), _shown, float(n), clampf(absf(n - _shown) / 40.0, 0.25, 0.8))
	UIKit.punch(self)
