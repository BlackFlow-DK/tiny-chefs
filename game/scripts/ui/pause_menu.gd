class_name PauseMenu
extends Control
## Esc menu. The kitchen keeps running (it is a network game); your chef just stands still.

var _card: PanelContainer
var _resume: Button
var _leave_row: Control
var _quit_row: Control
var _confirm_row: Control
var _stay: Button


func _ready() -> void:
	UI.full_rect(self)
	add_child(UIKit.backdrop(0.6))
	var cv := UIKit.card(14)
	_card = cv[0]
	var v: VBoxContainer = cv[1]
	_card.custom_minimum_size = Vector2(560, 0)

	var t := UIKit.title("Paused")
	v.add_child(t)
	var sub := UIKit.body("The kitchen keeps running!")
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)

	_resume = UIKit.button("Resume", func() -> void: close(), "primary", 0)
	v.add_child(_resume)

	v.add_child(controls_strip())

	# Leave, with a confirm step.
	var leave_holder := VBoxContainer.new()
	leave_holder.add_theme_constant_override("separation", 12)
	_leave_row = UIKit.button("Leave kitchen", func() -> void: _ask_confirm(true), "danger", 0)
	leave_holder.add_child(_leave_row)
	_quit_row = UIKit.button("Quit game", func() -> void: get_tree().quit(), "secondary", 0)
	leave_holder.add_child(_quit_row)
	var cr := VBoxContainer.new()
	cr.add_theme_constant_override("separation", 12)
	var q := UIKit.body("Really leave the kitchen?")
	q.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cr.add_child(q)
	var btns := HBoxContainer.new()
	btns.add_theme_constant_override("separation", 12)
	_stay = UIKit.button("Stay", func() -> void: _ask_confirm(false), "secondary", 0)
	_stay.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var yes := UIKit.button("Leave", func() -> void:
		close()
		Net.leave(), "danger", 0)
	yes.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	btns.add_child(_stay)
	btns.add_child(yes)
	cr.add_child(btns)
	_confirm_row = cr
	_confirm_row.visible = false
	leave_holder.add_child(_confirm_row)
	v.add_child(leave_holder)
	add_child(UI.centred(_card))
	visible = false


func _ask_confirm(on: bool) -> void:
	_leave_row.visible = not on
	_quit_row.visible = not on
	_confirm_row.visible = on
	if on:
		_stay.grab_focus.call_deferred()
	else:
		_leave_row.grab_focus.call_deferred()


func open() -> void:
	visible = true
	_leave_row.visible = true
	_quit_row.visible = true
	_confirm_row.visible = false
	UIKit.pop_in(_card, 0.0, 0.16)
	_resume.grab_focus.call_deferred()
	if Net.world != null:
		Net.world.input_blocked = true


func close() -> void:
	visible = false
	if Net.world != null:
		Net.world.input_blocked = false


## The controls reference on an inset paper strip (pause menu and the title screen's "How to play").
static func controls_strip(in_game := true) -> PanelContainer:
	var strip := PanelContainer.new()
	var sb := UITheme.box(UITheme.CREAM_DIM, UITheme.PAPER_OFF_INK, 12, 3)
	sb.content_margin_left = 18
	sb.content_margin_right = 18
	sb.content_margin_top = 12
	sb.content_margin_bottom = 14
	strip.add_theme_stylebox_override("panel", sb)
	var sv := VBoxContainer.new()
	sv.add_theme_constant_override("separation", 8)
	sv.add_child(UIKit.caption("Controls"))
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 28)
	grid.add_theme_constant_override("v_separation", 10)
	for e in [["WASD", "Move"], ["Left click", "Grab / drop"], ["Right click", "Work (hold)"],
			["Space", "Punch"], ["Middle click", "Ping"], ["H", "Help"], ["Esc", "Resume" if in_game else "Pause menu"]]:
		var kh := UIKit.key_hint(e[0], e[1])
		kh.alignment = BoxContainer.ALIGNMENT_BEGIN
		kh.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(kh)
	sv.add_child(grid)
	strip.add_child(sv)
	return strip
