class_name HudEventBanner
extends Control
## Shift-event banners (EventSystem, world/events/*.gd). Listens to Net.event_received for the "ev_*" sfx
## (Hud skips those in its toasts) and reads world.events for the inspector countdown, so it looks the
## same on host and clients:
##   ev_vip        gold "VIP INCOMING!" card (top right, under the timer)
##   ev_paw        orange "CAT PAW!" card
##   ev_inspector  "HEALTH INSPECTOR" card with a live countdown (EventSystem.inspector_left())
##   ev_inspected  a red "INSPECTED" stamp slammed onto the middle of the screen + the result line
##   ev_vip_paid   a big gold "VIP DELIGHTED!" celebration with "+N coins" and confetti

const TOP := 128.0
const RIGHT := 12.0

var world: World = null

var _card: PanelContainer = null
var _count: Label = null
var _big: Control = null


func _ready() -> void:
	UI.full_rect(self)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	Net.event_received.connect(_on_event)


func _on_event(text: String, sfx: String) -> void:
	if not is_visible_in_tree():
		return
	match sfx:
		"ev_vip":
			_show_card("VIP INCOMING!", "Gold ticket: triple pay, short patience.", UITheme.MUSTARD, 3.8)
		"ev_paw":
			_show_card("CAT PAW!", "Here, kitty kitty... Get out of the shadow!", Color("#F28C28"), 3.8)
		"ev_inspector":
			_show_card("HEALTH INSPECTOR", "Trash every burnt thing!", UITheme.SKY, 0.0, true)
		"ev_inspected":
			_close_card()
			var sub := text.substr(text.find(":") + 1).strip_edges() if text.contains(":") else text
			_stamp(sub, sub.contains("Clean"))
		"ev_vip_paid":
			var m := RegEx.create_from_string("\\+(\\d+)").search(text)
			_vip_party("+%s coins" % (m.get_string(1) if m != null else "?"))


func _process(_delta: float) -> void:
	if _count == null or not is_instance_valid(_count):
		return
	var left := world.events.inspector_left() if world != null and is_instance_valid(world) and world.events != null else -1.0
	if left < 0.0:
		_close_card()
		return
	var s := int(ceil(left))
	var txt := "Arriving in %d s" % s
	if _count.text != txt:
		_count.text = txt
		if s <= 5:
			UIKit.punch(_card, 0.08, 0.2)


# ================================================================ top-right card

func _show_card(title: String, sub: String, col: Color, seconds: float, countdown := false) -> void:
	_close_card()
	var p := PanelContainer.new()
	var sb := UITheme.box(UITheme.CREAM, UITheme.INK, 14, 4, 5)
	sb.border_width_left = 14
	sb.border_color = UITheme.INK
	sb.content_margin_left = 16
	sb.content_margin_right = 16
	sb.content_margin_top = 10
	sb.content_margin_bottom = 12
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.anchor_left = 1.0
	p.anchor_right = 1.0
	p.offset_left = -RIGHT
	p.offset_right = -RIGHT
	p.offset_top = TOP
	p.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	p.custom_minimum_size = Vector2(300, 0)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	p.add_child(h)
	var badge := Control.new()
	badge.custom_minimum_size = Vector2(44, 44)
	badge.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	badge.draw.connect(func() -> void:
		badge.draw_circle(Vector2(22, 24), 21.0, UITheme.INK)
		badge.draw_circle(Vector2(22, 22), 19.0, col)
		badge.draw_circle(Vector2(22, 22), 19.0, UITheme.INK, false, 3.0)
		var f := UITheme.font(true)
		badge.draw_string(f, Vector2(0, 32), "!", HORIZONTAL_ALIGNMENT_CENTER, 44, 30, UITheme.INK))
	h.add_child(badge)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	h.add_child(v)
	var t := UIKit.heading(title)
	v.add_child(t)
	if countdown:
		_count = UIKit.number("Arriving in %d s" % int(Tuning.INSPECTOR_LEAD))
		_count.add_theme_font_size_override("font_size", UITheme.S_HEADING)
		_count.add_theme_color_override("font_color", UITheme.TOMATO)
		v.add_child(_count)
	var s := UIKit.caption(sub)
	v.add_child(s)
	add_child(p)
	_card = p
	UIKit.pop_in(p, 0.0, 0.25)
	if seconds > 0.0:
		var tw := p.create_tween()
		tw.tween_interval(seconds)
		tw.tween_callback(func() -> void:
			if _card == p:
				_close_card())


func _close_card() -> void:
	if _card != null and is_instance_valid(_card):
		UIKit.pop_out(_card, true)
	_card = null
	_count = null


# ================================================================ centre moments

func _clear_big() -> void:
	if _big != null and is_instance_valid(_big):
		_big.queue_free()
	_big = null


## A rubber-stamp "INSPECTED" slammed onto the screen (green-ish check line when clean, red when fined).
func _stamp(sub: String, clean: bool) -> void:
	_clear_big()
	var col := UITheme.LETTUCE if clean else UITheme.TOMATO
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.anchor_left = 0.5
	root.anchor_right = 0.5
	root.anchor_top = 0.42
	root.anchor_bottom = 0.42
	add_child(root)
	var p := PanelContainer.new()
	var sb := UITheme.box(Color(1, 0.97, 0.9, 0.92), col, 10, 8, 0)
	sb.content_margin_left = 30
	sb.content_margin_right = 30
	sb.content_margin_top = 8
	sb.content_margin_bottom = 12
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	p.add_child(v)
	var big := UIKit.number("INSPECTED", "card", col)
	big.add_theme_font_size_override("font_size", UITheme.S_HERO)
	big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(big)
	var l := UIKit.heading(sub)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_color_override("font_color", col.darkened(0.25))
	v.add_child(l)
	root.add_child(p)
	_big = root
	# Centre on the anchor once sized, then slam down from 2.2x with a little overshoot.
	p.resized.connect(func() -> void:
		p.position = -p.size * 0.5
		p.pivot_offset = p.size * 0.5)
	p.rotation = deg_to_rad(-9.0)
	p.scale = Vector2(2.2, 2.2)
	p.modulate.a = 0.0
	var tw := p.create_tween()
	tw.tween_property(p, "modulate:a", 1.0, 0.06)
	tw.parallel().tween_property(p, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void: UIKit.shake(p, 10.0))
	tw.tween_interval(2.4)
	tw.tween_property(p, "modulate:a", 0.0, 0.35)
	tw.tween_callback(root.queue_free)


## VIP served: a big gold card with the coins and a burst of confetti.
func _vip_party(amount: String) -> void:
	_clear_big()
	var root := Control.new()
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.anchor_left = 0.5
	root.anchor_right = 0.5
	root.anchor_top = 0.42
	root.anchor_bottom = 0.42
	add_child(root)
	var p := PanelContainer.new()
	var sb := UITheme.box(Color("#FFE8A3"), UITheme.MUSTARD_DARK, 16, 7, 6)
	sb.content_margin_left = 34
	sb.content_margin_right = 34
	sb.content_margin_top = 12
	sb.content_margin_bottom = 16
	p.add_theme_stylebox_override("panel", sb)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	p.add_child(v)
	v.add_child(UIKit.title("VIP DELIGHTED!"))
	var n := UIKit.number(amount, "card", UITheme.LETTUCE)
	n.add_theme_font_size_override("font_size", UITheme.S_HERO)
	n.add_theme_color_override("font_outline_color", UITheme.INK)
	n.add_theme_constant_override("outline_size", 12)
	n.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(n)
	root.add_child(p)
	_big = root
	p.resized.connect(func() -> void:
		p.position = -p.size * 0.5
		p.pivot_offset = p.size * 0.5)
	p.scale = Vector2(0.4, 0.4)
	var tw := p.create_tween()
	tw.tween_property(p, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(2.3)
	tw.tween_property(p, "modulate:a", 0.0, 0.35)
	tw.tween_callback(root.queue_free)
	var cols := [UITheme.MUSTARD, UITheme.LETTUCE, UITheme.TOMATO, UITheme.SKY, Color("#FFE8A3")]
	var origin := get_viewport_rect().size * Vector2(0.5, 0.42)
	for i in 36:
		var c := ColorRect.new()
		c.color = cols[i % cols.size()]
		c.size = Vector2(11, 11)
		c.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(c)
		c.global_position = origin
		c.pivot_offset = Vector2(5, 5)
		var ang := randf() * TAU
		var dist := randf_range(120.0, 330.0)
		var to := origin + Vector2(cos(ang), sin(ang) * 0.6) * dist + Vector2(0, 60)
		var ct := c.create_tween().set_parallel(true)
		ct.tween_property(c, "global_position", to, 1.0).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		ct.tween_property(c, "rotation", randf_range(-8.0, 8.0), 1.0)
		ct.tween_property(c, "modulate:a", 0.0, 0.35).set_delay(0.75)
		ct.chain().tween_callback(c.queue_free)
