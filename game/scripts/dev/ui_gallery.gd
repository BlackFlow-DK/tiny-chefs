extends Control
## UI style gallery: every building block in every state, on a counter-beige backdrop.
## Screenshot: tools\godot-screenshot.ps1 -Scene res://scenes/dev/ui_gallery.tscn -Resolution 1280x720
## Env UI_GALLERY_PAGE=2 shows the "in context" page (overlay card, toast, dark chips).

const T = preload("res://scripts/ui/ui_theme.gd")
var _focus_btn: Button


func _ready() -> void:
	theme = UI.theme()
	UI.full_rect(self)
	var bg := _Backdrop.new()
	UI.full_rect(bg)
	add_child(bg)
	var page := OS.get_environment("UI_GALLERY_PAGE")
	var m := MarginContainer.new()
	UI.full_rect(m)
	for s in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + s, 22)
	add_child(m)
	if page == "2":
		m.add_child(_page_context())
	else:
		m.add_child(_page_main())
	if _focus_btn != null:
		_focus_btn.grab_focus.call_deferred()


func _btn_state(text: String, kind: String, state: String) -> Button:
	var b := UIKit.button(text, Callable(), kind, 116)
	var type: String = b.theme_type_variation
	match state:
		"hover":
			b.add_theme_stylebox_override("normal", theme.get_stylebox("hover", type))
		"pressed":
			b.add_theme_stylebox_override("normal", theme.get_stylebox("pressed", type))
		"disabled":
			b.disabled = true
		"focus":
			if _focus_btn == null:
				_focus_btn = b
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE if state != "normal" else Control.MOUSE_FILTER_STOP
	return b


func _page_main() -> Control:
	var cols := HBoxContainer.new()
	cols.add_theme_constant_override("separation", 22)

	# ---- column 1: buttons + inputs
	var c1 := VBoxContainer.new()
	c1.add_theme_constant_override("separation", 20)
	c1.custom_minimum_size.x = 690
	cols.add_child(c1)
	var bc := UIKit.card(6)
	c1.add_child(bc[0])
	var bv: VBoxContainer = bc[1]
	bv.add_child(UIKit.heading("Buttons"))
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 14)
	grid.add_theme_constant_override("v_separation", 14)
	for s in ["normal", "hover", "pressed", "disabled", "focus"]:
		var cap := UIKit.caption(s)
		cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		grid.add_child(cap)
	for k in [["primary", "Play"], ["accent", "Buy"], ["secondary", "Back"], ["danger", "Quit"], ["go", "Ready"]]:
		for s in ["normal", "hover", "pressed", "disabled", "focus"]:
			grid.add_child(_btn_state(k[1], k[0], s))
	bv.add_child(grid)

	var ic := UIKit.card(10)
	c1.add_child(ic[0])
	var iv: VBoxContainer = ic[1]
	iv.add_child(UIKit.heading("Inputs, meters, hints"))
	var row := HBoxContainer.new()
	var le := LineEdit.new()
	le.text = "Sander"
	le.custom_minimum_size.x = 170
	row.add_child(le)
	var le2 := LineEdit.new()
	le2.placeholder_text = "host IP"
	le2.custom_minimum_size.x = 170
	row.add_child(le2)
	var le3 := LineEdit.new()
	le3.text = "locked"
	le3.editable = false
	le3.custom_minimum_size.x = 140
	row.add_child(le3)
	row.add_child(UIKit.coin_chip(1250))
	iv.add_child(row)
	var bars := HBoxContainer.new()
	bars.add_theme_constant_override("separation", 16)
	for f in [1.0, 0.7, 0.45, 0.25, 0.08]:
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 4)
		col.add_child(UIKit.progress(f, 100, 20))
		col.add_child(UIKit.caption("%d%%" % int(f * 100)))
		bars.add_child(col)
	iv.add_child(bars)
	var hints := HBoxContainer.new()
	hints.add_theme_constant_override("separation", 22)
	hints.add_child(UIKit.key_hint("E", "Grab"))
	hints.add_child(UIKit.key_hint("F", "Chop"))
	hints.add_child(UIKit.key_hint("Q", "Punch"))
	hints.add_child(UIKit.key_hint("Esc", "Pause"))
	iv.add_child(hints)

	# ---- column 2: type, palette, tickets, badges
	var c2 := VBoxContainer.new()
	c2.add_theme_constant_override("separation", 20)
	c2.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_child(c2)
	var tc := UIKit.card(4)
	c2.add_child(tc[0])
	var tv: VBoxContainer = tc[1]
	tv.add_child(UIKit.title("TINY CHEFS", T.S_HERO))
	tv.add_child(UIKit.title("Shift complete!"))
	tv.add_child(UIKit.heading("Heading 28: Kitchen upgrades"))
	tv.add_child(UIKit.body("Body 20: carry the patty together."))
	tv.add_child(UIKit.caption("Caption 16: 2 chefs connected"))
	var nr := HBoxContainer.new()
	nr.add_child(UIKit.number("12,480"))
	nr.add_child(UIKit.caption("number role"))
	tv.add_child(nr)
	var pal := HBoxContainer.new()
	pal.add_theme_constant_override("separation", 8)
	for c in [T.CREAM, T.INK, T.TOMATO, T.MUSTARD, T.LETTUCE, T.SKY]:
		pal.add_child(UIKit.chip_swatch(c, 34))
	tv.add_child(pal)

	var kc := UIKit.card(10)
	c2.add_child(kc[0])
	var kv: VBoxContainer = kc[1]
	kv.add_child(UIKit.heading("Orders and players"))
	var tr := HBoxContainer.new()
	tr.add_theme_constant_override("separation", 12)
	tr.add_child(UIKit.order_ticket("Burger", [Color("#D9A05B"), Color("#7A3F26"), Color("#FFC93C"), Color("#5DBB46")], 0.85, "#1"))
	tr.add_child(UIKit.order_ticket("Hot dog", [Color("#D9A05B"), Color("#C0562F")], 0.18, "#2"))
	kv.add_child(tr)
	var pr := HBoxContainer.new()
	for i in 4:
		pr.add_child(UIKit.player_badge(["Sander", "Mia", "Bo", "Ida"][i], i))
	kv.add_child(pr)
	return cols


func _page_context() -> Control:
	var root := Control.new()
	# Fake "world" text with a card behind it, then an overlay.
	var top := HBoxContainer.new()
	top.position = Vector2(0, 0)
	top.add_child(UIKit.coin_chip(320))
	top.add_child(UIKit.player_badge("Mia", 1))
	root.add_child(top)
	var world := UIKit.body("Text floating over the world (outlined)", "world")
	world.position = Vector2(0, 90)
	root.add_child(world)
	var dim := UIKit.backdrop()
	dim.anchor_right = 0
	dim.anchor_bottom = 0
	dim.position = Vector2(-22, 140)
	dim.size = Vector2(1280, 600)
	root.add_child(dim)
	var cc := UIKit.card(12)
	var p: PanelContainer = cc[0]
	var v: VBoxContainer = cc[1]
	p.custom_minimum_size.x = 420
	p.position = Vector2(400, 200)
	v.add_child(UIKit.title("PAUSED"))
	v.add_child(UIKit.button("Resume", Callable(), "primary"))
	v.add_child(UIKit.button("Settings", Callable(), "secondary"))
	v.add_child(UIKit.button("Leave kitchen", Callable(), "danger"))
	root.add_child(p)
	UIKit.toast(root, "Order served! +40", "success", 3600.0)
	return root


class _Backdrop extends Control:
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), UITheme.COUNTER)
		var s := 80.0
		var y := 0
		while y * s < size.y:
			var x := 0
			while x * s < size.x:
				if (x + y) % 2 == 0:
					draw_rect(Rect2(x * s, y * s, s, s), Color(0, 0, 0, 0.05))
				x += 1
			y += 1
