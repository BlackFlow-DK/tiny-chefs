class_name ObjectiveRow
extends HBoxContainer
## One campaign objective as a line: status mark (ring = in progress, green tick = met, red cross = failed),
## the objective text and its progress ("1/3"). Entry format: ObjectiveSystem ([type, recipe, n, have, state]).
## Used by the HUD objectives card, the mission intro and the results screen.

var mark: ObjectiveMark
var text_lbl: Label
var prog_lbl: Label
var _state := -1


## text_width > 0 wraps the text at that width. size: UITheme.S_CAPTION (HUD) or S_BODY.
func _init(text_width := 0.0, font_size := UITheme.S_CAPTION) -> void:
	add_theme_constant_override("separation", 8)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	mark = ObjectiveMark.new(22.0 if font_size <= UITheme.S_CAPTION else 28.0)
	mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	add_child(mark)
	text_lbl = UIKit.body("")
	text_lbl.add_theme_font_size_override("font_size", font_size)
	text_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	if text_width > 0.0:
		text_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		text_lbl.custom_minimum_size = Vector2(text_width, 0)
	add_child(text_lbl)
	prog_lbl = UIKit.number("")
	prog_lbl.add_theme_font_size_override("font_size", font_size)
	prog_lbl.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	add_child(prog_lbl)


## Returns true when the state changed since the last call (the caller may punch the row).
func set_entry(e: Array) -> bool:
	text_lbl.text = ObjectiveSystem.label(e)
	var st := int(e[4])
	prog_lbl.text = ObjectiveSystem.progress_text(e)
	var changed := st != _state
	if changed:
		_state = st
		mark.state = st
		var col := UITheme.INK
		if st == ObjectiveSystem.MET:
			col = UITheme.LETTUCE.darkened(0.3)
		elif st == ObjectiveSystem.FAILED:
			col = UITheme.TOMATO_DARK
		text_lbl.add_theme_color_override("font_color", col)
		prog_lbl.add_theme_color_override("font_color", col)
	return changed
