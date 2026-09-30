class_name PauseMenu
extends Control
## Esc menu. The kitchen keeps running (it is a network game); your chef just stands still.


func _ready() -> void:
	UI.full_rect(self)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.45)
	UI.full_rect(dim)
	add_child(dim)
	var pv := UI.panel(12)
	var v: VBoxContainer = pv[1]
	v.add_child(UI.label("Paused", 40, UI.YELLOW))
	v.add_child(UI.label("The kitchen keeps cooking while you are here.", 15, UI.DIM))
	v.add_child(UI.button("Resume", func() -> void: close()))
	v.add_child(UI.button("Leave to menu", func() -> void:
		close()
		Net.leave()))
	v.add_child(UI.button("Quit game", func() -> void: get_tree().quit()))
	add_child(UI.centred(pv[0]))
	visible = false


func open() -> void:
	visible = true
	if Net.world != null:
		Net.world.input_blocked = true


func close() -> void:
	visible = false
	if Net.world != null:
		Net.world.input_blocked = false
