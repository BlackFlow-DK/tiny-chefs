class_name MenuScreen
extends Control
## Title screen: name, Host, Join (IP), Quit.

var name_edit: LineEdit
var ip_edit: LineEdit
var status: Label
var _buttons: Array = []


func _ready() -> void:
	UI.full_rect(self)
	var bg := ColorRect.new()
	bg.color = Color(0.2, 0.28, 0.4)
	UI.full_rect(bg)
	add_child(bg)
	var pv := UI.panel(12)
	var p: PanelContainer = pv[0]
	var v: VBoxContainer = pv[1]
	p.custom_minimum_size = Vector2(520, 0)
	add_child(UI.centred(p))
	var title := UI.label("TINY CHEFS", 64, UI.YELLOW)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title)
	var sub := UI.label("Co-op kitchen chaos on a giant counter. Food is bigger than you: carry it together!", 16, UI.DIM)
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(sub)
	var nh := HBoxContainer.new()
	nh.add_child(UI.label("Your name"))
	name_edit = LineEdit.new()
	name_edit.text = _default_name()
	name_edit.max_length = 16
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	nh.add_child(name_edit)
	v.add_child(nh)
	var hb := UI.button("Host a kitchen (solo or LAN)", _on_host)
	v.add_child(hb)
	var jh := HBoxContainer.new()
	ip_edit = LineEdit.new()
	ip_edit.text = "127.0.0.1"
	ip_edit.placeholder_text = "host IP, e.g. 192.168.1.20"
	ip_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	jh.add_child(ip_edit)
	var jb := UI.button("Join", _on_join, 120)
	jh.add_child(jb)
	v.add_child(jh)
	var qb := UI.button("Quit", func() -> void: get_tree().quit())
	v.add_child(qb)
	_buttons = [hb, jb]
	status = UI.label("", 16, UI.YELLOW)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status.custom_minimum_size = Vector2(480, 0)
	v.add_child(status)
	var help := UI.label(UI.controls_text(), 13, UI.DIM)
	v.add_child(help)


func _default_name() -> String:
	var n := OS.get_environment("USERNAME")
	return n.substr(0, 16) if not n.is_empty() else "Chef"


func set_status(msg: String) -> void:
	status.text = msg
	for b in _buttons:
		b.disabled = false


func _on_host() -> void:
	var err := Net.host(name_edit.text)
	if err != OK:
		set_status("Could not host on UDP port %d (%s). Is another game already hosting on this PC?" % [Tuning.PORT, error_string(err)])


func _on_join() -> void:
	var ip := ip_edit.text.strip_edges()
	if ip.is_empty():
		ip = "127.0.0.1"
	var err := Net.join(ip, name_edit.text)
	if err != OK:
		set_status("Could not start connecting (%s)." % error_string(err))
		return
	status.text = "Connecting to %s ..." % ip
	for b in _buttons:
		b.disabled = true
