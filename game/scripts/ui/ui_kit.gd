class_name UIKit
extends RefCounted
## Reusable Tiny Chefs UI building blocks + tween helpers. Needs UITheme applied on an ancestor
## (main.gd does `root.theme = UI.theme()`). All builders return an unparented node; you add it.
## `on` (text tone): "card" = ink text for cream cards, "dark" = cream text on aubergine,
## "world" = cream text with ink outline for text floating over the 3D scene.

const T = preload("res://scripts/ui/ui_theme.gd")


# ---------------------------------------------------------------- text

static func _tone(l: Label, on: String, muted := false) -> void:
	match on:
		"dark":
			l.add_theme_color_override("font_color", T.CREAM_DIM if muted else T.CREAM)
		"world":
			l.add_theme_color_override("font_color", T.CREAM_DIM if muted else T.CREAM)
			l.add_theme_color_override("font_outline_color", T.INK)
			l.add_theme_constant_override("outline_size", 6)


static func _lbl(text: String, variation: String, on: String, muted := false) -> Label:
	var l := Label.new()
	l.text = text
	l.theme_type_variation = variation
	_tone(l, on, muted)
	return l


## Mustard display text with a thick ink outline; readable on anything. size: S_TITLE or S_HERO.
static func title(text: String, size := UITheme.S_TITLE) -> Label:
	var l := _lbl(text, "HeroLabel" if size >= T.S_HERO else "TitleLabel", "card")
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l

static func heading(text: String, on := "card") -> Label:
	return _lbl(text, "HeadingLabel", on)

static func body(text: String, on := "card") -> Label:
	return _lbl(text, "BodyLabel", on)

static func caption(text: String, on := "card") -> Label:
	return _lbl(text, "CaptionLabel", on, true)

## Big heavy number (score, timer). Pass color to tint (e.g. T.MUSTARD on dark).
static func number(text: String, on := "card", color := Color(0, 0, 0, 0)) -> Label:
	var l := _lbl(text, "NumberLabel", on)
	if color.a > 0.0:
		l.add_theme_color_override("font_color", color)
	return l


# ---------------------------------------------------------------- surfaces

## Cream card (or aubergine with dark=true). Returns [PanelContainer, VBoxContainer] like UI.panel().
static func card(sep := UITheme.GAP, dark := false) -> Array:
	var p := PanelContainer.new()
	if dark:
		p.theme_type_variation = "DarkPanel"
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", sep)
	p.add_child(v)
	return [p, v]


## Full-screen aubergine dimmer for overlays (pause, results). Blocks mouse.
static func backdrop(alpha := 0.72) -> ColorRect:
	var c := ColorRect.new()
	c.color = Color(T.INK.r, T.INK.g, T.INK.b, alpha)
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_STOP
	return c


## Round colour dot with ink outline (player colour, status).
static func dot(color: Color, px := 22) -> Panel:
	var p := Panel.new()
	p.custom_minimum_size = Vector2(px, px)
	p.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	p.add_theme_stylebox_override("panel", T.box(color, T.INK, px / 2, 3))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


## Rounded-square ingredient swatch with ink outline.
static func chip_swatch(color: Color, px := 28) -> Panel:
	var p := Panel.new()
	p.custom_minimum_size = Vector2(px, px)
	p.add_theme_stylebox_override("panel", T.box(color, T.INK, 8, 3))
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p


static func player_color(index: int) -> Color:
	return T.PLAYER_COLORS[posmod(index, T.PLAYER_COLORS.size())]


## Colour dot + name in a pill. color may be a Color or a player index (int).
static func player_badge(player_name: String, color: Variant, dark := false) -> PanelContainer:
	var col: Color = color if color is Color else player_color(int(color))
	var p := PanelContainer.new()
	p.theme_type_variation = "DarkChipPanel" if dark else "ChipPanel"
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	h.add_child(dot(col, 20))
	var l := body(player_name, "dark" if dark else "card")
	h.add_child(l)
	p.add_child(h)
	return p


# ---------------------------------------------------------------- buttons

## kind: "primary" (tomato), "accent" (mustard), "secondary" (cream), "danger" (dark red), "go" (green).
static func button(text: String, cb: Callable = Callable(), kind := "primary", min_width := 0) -> Button:
	var b := Button.new()
	b.text = text
	b.theme_type_variation = {
		"primary": "PrimaryButton", "accent": "AccentButton", "secondary": "SecondaryButton",
		"danger": "DangerButton", "go": "GoButton"}.get(kind, "PrimaryButton")
	b.custom_minimum_size = Vector2(min_width, 52)
	b.focus_mode = Control.FOCUS_ALL
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if cb.is_valid():
		b.pressed.connect(cb)
	attach_press_squash(b)
	return b


## Adds the squash-on-press feel to any Control that emits button_down/button_up.
static func attach_press_squash(b: BaseButton) -> void:
	b.resized.connect(func() -> void: b.pivot_offset = b.size / 2.0)
	b.button_down.connect(func() -> void:
		if b.disabled:
			return
		var tw := b.create_tween()
		tw.tween_property(b, "scale", Vector2(1.04, 0.93), 0.05))
	b.button_up.connect(func() -> void:
		var tw := b.create_tween()
		tw.tween_property(b, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT))


## Keycap + label, e.g. key_hint("E", "Grab"). on: text tone for the label.
static func key_hint(key: String, text: String, on := "card") -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	h.alignment = BoxContainer.ALIGNMENT_CENTER
	var cap := PanelContainer.new()
	var sb := T.box(T.CREAM_HI, T.INK, 8, 3, 4)
	sb.content_margin_left = 9
	sb.content_margin_right = 9
	sb.content_margin_top = 1
	sb.content_margin_bottom = 3
	cap.add_theme_stylebox_override("panel", sb)
	cap.custom_minimum_size = Vector2(34, 32)
	cap.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var kl := Label.new()
	kl.text = key
	kl.theme_type_variation = "KeyLabel"
	kl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	kl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cap.add_child(kl)
	h.add_child(cap)
	var l := body(text, on)
	l.add_theme_font_size_override("font_size", T.S_BODY)
	h.add_child(l)
	return h


# ---------------------------------------------------------------- meters

## Coin pill: gold coin + amount. Use chip.set_amount(n) (pops on change).
static func coin_chip(amount := 0, dark := false) -> UICoinChip:
	var c := UICoinChip.new()
	c.dark = dark
	c.set_amount(amount, false)
	return c


## Progress bar, value 0..1 via bar.set_fraction(f). ramp=true: green -> mustard -> tomato as it drains.
static func progress(fraction := 1.0, width := 160, height := 20, ramp := true) -> UIProgress:
	var p := UIProgress.new()
	p.custom_minimum_size = Vector2(width, height)
	p.ramp = ramp
	p.set_fraction(fraction)
	return p


## Colour for a 0..1 "health" fraction: 1 green, ~0.5 mustard, <=0.2 tomato.
static func ramp_color(f: float) -> Color:
	if f >= 0.5:
		return T.MUSTARD.lerp(T.LETTUCE, clampf((f - 0.5) / 0.4, 0.0, 1.0))
	return T.TOMATO.lerp(T.MUSTARD, clampf((f - 0.15) / 0.35, 0.0, 1.0))


## Order ticket: header (number + dish), ingredient swatches, patience bar. Wire with set_patience(f).
static func order_ticket(dish: String, ingredient_colors: Array = [], patience := 1.0, number_text := "") -> UIOrderTicket:
	var t := UIOrderTicket.new()
	t.setup(dish, ingredient_colors, patience, number_text)
	return t


## Transient message. Adds itself to `host` (a Control covering the screen), pops in, fades, frees itself.
## kind: "info" | "success" | "warn" | "error".
static func toast(host: Control, text: String, kind := "info", seconds := 2.4) -> PanelContainer:
	var col: Color = {"info": T.SKY, "success": T.LETTUCE, "warn": T.MUSTARD, "error": T.TOMATO}.get(kind, T.SKY)
	var p := PanelContainer.new()
	p.theme_type_variation = "DarkChipPanel"
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	h.add_child(dot(col, 18))
	h.add_child(body(text, "dark"))
	p.add_child(h)
	host.add_child(p)
	p.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE)
	p.position.y = 24
	p.grow_horizontal = Control.GROW_DIRECTION_BOTH
	pop_in(p)
	var tw := p.create_tween()
	tw.tween_interval(seconds)
	tw.tween_property(p, "modulate:a", 0.0, 0.25)
	tw.tween_callback(p.queue_free)
	return p


# ---------------------------------------------------------------- motion

static func _pivot(c: Control) -> void:
	c.pivot_offset = c.size / 2.0


## Pop-in: scale 0.6 -> 1 with overshoot plus fade, ~0.15 s. Safe to call before the node is laid out.
static func pop_in(c: Control, delay := 0.0, duration := 0.15) -> void:
	c.scale = Vector2(0.6, 0.6)
	c.modulate.a = 0.0
	if not c.is_inside_tree():
		await c.tree_entered
	await c.get_tree().process_frame
	if not is_instance_valid(c):
		return
	_pivot(c)
	var tw := c.create_tween().set_parallel(true)
	tw.tween_property(c, "scale", Vector2.ONE, duration).set_delay(delay).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "modulate:a", 1.0, duration * 0.7).set_delay(delay)


## Quick shrink + fade, then hides (or frees with free_after).
static func pop_out(c: Control, free_after := false, duration := 0.12) -> void:
	_pivot(c)
	var tw := c.create_tween().set_parallel(true)
	tw.tween_property(c, "scale", Vector2(0.8, 0.8), duration).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_IN)
	tw.tween_property(c, "modulate:a", 0.0, duration)
	tw.chain().tween_callback(c.queue_free if free_after else c.hide)


## One-shot bump (score ticks, coin gain).
static func punch(c: Control, amount := 0.18, duration := 0.22) -> void:
	_pivot(c)
	var tw := c.create_tween()
	tw.tween_property(c, "scale", Vector2.ONE * (1.0 + amount), duration * 0.35).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "scale", Vector2.ONE, duration * 0.65).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)


## Looping heartbeat for urgent things (timer < 10 s, order about to expire). Returns the Tween: kill() it to stop,
## then set c.scale = Vector2.ONE.
static func pulse(c: Control, amount := 0.1, period := 0.5) -> Tween:
	_pivot(c)
	var tw := c.create_tween().set_loops()
	tw.tween_property(c, "scale", Vector2.ONE * (1.0 + amount), period * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	tw.tween_property(c, "scale", Vector2.ONE, period * 0.5).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	return tw


## Horizontal wobble for "no!" feedback (can't afford, wrong item).
static func shake(c: Control, strength := 8.0) -> void:
	var x := c.position.x
	var tw := c.create_tween()
	for i in 4:
		tw.tween_property(c, "position:x", x + strength * (1.0 if i % 2 == 0 else -1.0) * (1.0 - i * 0.2), 0.045)
	tw.tween_property(c, "position:x", x, 0.05)
