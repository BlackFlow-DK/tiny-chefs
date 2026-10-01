class_name HowToPlay
extends Control
## Title-screen "How to play" card: five lines on how a shift works and the controls strip shared with
## the pause menu. Esc or Close hides it; open() shows it and puts focus on Close.

const LINES := [
	["Carry", "Left click grabs. Heavy food needs two chefs at once!"],
	["Cook", "Hold right click at the griddle. Pull food off before it burns."],
	["Chop and fry", "Hold right click at the cutting board or the fryer."],
	["Serve", "Stack the plate to match a ticket, then work the bell."],
	["Ping", "Middle click marks a spot that everyone sees."],
]

var _card: PanelContainer
var _close: Button


func _init() -> void:
	UI.full_rect(self)
	visible = false
	add_child(UIKit.backdrop(0.7))
	var cv := UIKit.card(14)
	_card = cv[0]
	var v: VBoxContainer = cv[1]
	_card.custom_minimum_size = Vector2(700, 0)
	v.add_child(UIKit.title("How to play"))
	var list := VBoxContainer.new()
	list.add_theme_constant_override("separation", 8)
	for i in LINES.size():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var num := PanelContainer.new()
		num.add_theme_stylebox_override("panel", UITheme.box(UITheme.MUSTARD, UITheme.INK, 14, 3))
		num.custom_minimum_size = Vector2(32, 32)
		num.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		var nl := UIKit.caption(str(i + 1))
		nl.add_theme_color_override("font_color", UITheme.INK)
		nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		num.add_child(nl)
		row.add_child(num)
		var t := RichTextLabel.new()
		t.bbcode_enabled = true
		t.fit_content = true
		t.scroll_active = false
		t.mouse_filter = Control.MOUSE_FILTER_IGNORE
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		t.custom_minimum_size = Vector2(1, 0)
		t.add_theme_font_override("normal_font", UITheme.font())
		t.add_theme_font_override("bold_font", UITheme.font(true))
		t.add_theme_font_size_override("normal_font_size", UITheme.S_BODY)
		t.add_theme_font_size_override("bold_font_size", UITheme.S_BODY)
		t.add_theme_color_override("default_color", UITheme.INK)
		t.text = "[b]%s[/b]  %s" % [LINES[i][0], LINES[i][1]]
		row.add_child(t)
		list.add_child(row)
	v.add_child(list)
	v.add_child(PauseMenu.controls_strip(false))
	_close = UIKit.button("Got it", close, "primary", 0)
	v.add_child(_close)
	add_child(UI.centred(_card))


func open() -> void:
	visible = true
	UIKit.pop_in(_card, 0.0, 0.16)
	_close.grab_focus.call_deferred()


func close() -> void:
	visible = false


func _unhandled_key_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		close()
		get_viewport().set_input_as_handled()
