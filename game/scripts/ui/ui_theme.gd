class_name UITheme
extends RefCounted
## Tiny Chefs UI design tokens + the code-built Theme. ONE entry point: UITheme.build()
## (also reachable as UI.theme()). Palette, sizes and radii live here; never hardcode them elsewhere.
## Look: "order tickets on a diner rail": cream paper cards, thick ink outline, hard offset shadow.

# --- Palette ---
const CREAM := Color("#FFF6E0")        # card surface
const CREAM_HI := Color("#FFFDF3")     # inputs, raised paper
const CREAM_DIM := Color("#EADFC4")    # pressed/secondary paper, dividers on dark
const INK := Color("#2B2233")          # outlines, text on cream, dark surface
const INK_SOFT := Color("#6B5F73")     # muted text on cream
const INK_LIGHT := Color("#4A3D57")    # borders/fills on dark surface
const TOMATO := Color("#E8452C")
const TOMATO_DARK := Color("#B3311D")
const MUSTARD := Color("#FFC93C")
const MUSTARD_DARK := Color("#D9A21B")
const LETTUCE := Color("#5DBB46")
const SKY := Color("#4DA6FF")
const PAPER_OFF := Color("#D9D0BC")    # disabled fill
const PAPER_OFF_INK := Color("#9A8FA0")  # disabled text + outline
const COUNTER := Color("#C9AE86")      # reference beige counter (galleries/backdrops)
const PLAYER_COLORS: Array[Color] = [Color("#4DA6FF"), Color("#E8452C"), Color("#5DBB46"), Color("#FFC93C")]

# --- Type scale (use ONLY these) ---
const S_CAPTION := 16
const S_BODY := 20
const S_HEADING := 28
const S_TITLE := 44
const S_HERO := 72
const W_BODY := 600.0    # Fredoka wght axis is 300..700
const W_HEAVY := 700.0

# --- Geometry ---
const R_CARD := 16
const R_BTN := 14
const R_INPUT := 12
const B_CARD := 4        # outline thickness (cards)
const B_BTN := 3
const SHADOW := 6        # resting hard-shadow depth for cards
const BTN_SHADOW := 5
const GAP := 12          # default box separation (leaves room for button shadows)
const PAD := 20          # card padding

const FONT_PATH := "res://assets/fonts/Fredoka.ttf"
static var _font: Font
static var _font_heavy: Font


static func font(heavy := false) -> Font:
	if _font == null:
		var base: Font = null
		if ResourceLoader.exists(FONT_PATH):
			base = load(FONT_PATH) as Font
		if base == null:
			base = ThemeDB.fallback_font
			_font = base
			_font_heavy = base
		else:
			_font = _variation(base, W_BODY)
			_font_heavy = _variation(base, W_HEAVY)
	return _font_heavy if heavy else _font


static func _variation(base: Font, wght: float) -> FontVariation:
	var fv := FontVariation.new()
	fv.base_font = base
	var tag: int = TextServerManager.get_primary_interface().name_to_tag("wght")
	fv.variation_opentype = {tag: wght}
	return fv


## Hard-shadow box. depth = shadow offset down (0 = none); lift moves the body up (negative = sinks).
static func box(fill: Color, border: Color, radius := R_BTN, bw := B_BTN, depth := 0, lift := 0, shadow_col := INK) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = fill
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.set_corner_radius_all(radius)
	sb.anti_aliasing = true
	if depth > 0:
		sb.shadow_color = shadow_col
		sb.shadow_size = 1
		sb.shadow_offset = Vector2(0, depth)
	if lift != 0:
		sb.expand_margin_top = lift
		sb.expand_margin_bottom = -lift
	return sb


static func _btn_set(t: Theme, type: String, base: String, fill: Color, hover: Color, text: Color, border := INK) -> void:
	if type != base:
		t.set_type_variation(type, base)
	var d := BTN_SHADOW
	var pad_h := 24
	var pad_v := 9
	for sb_pair in [["normal", box(fill, border, R_BTN, B_BTN, d)],
			["hover", box(hover, border, R_BTN, B_BTN, d + 3, 3)],
			["pressed", box(fill.darkened(0.12), border, R_BTN, B_BTN, 0, -4)],
			["hover_pressed", box(fill.darkened(0.12), border, R_BTN, B_BTN, 0, -4)],
			["disabled", box(PAPER_OFF, PAPER_OFF_INK, R_BTN, B_BTN, 3, 0, PAPER_OFF_INK)]]:
		var sb: StyleBoxFlat = sb_pair[1]
		sb.content_margin_left = pad_h
		sb.content_margin_right = pad_h
		sb.content_margin_top = pad_v
		sb.content_margin_bottom = pad_v
		t.set_stylebox(sb_pair[0], type, sb)
	var focus := StyleBoxFlat.new()
	focus.draw_center = false
	focus.border_color = SKY
	focus.set_border_width_all(4)
	focus.set_corner_radius_all(R_BTN + 4)
	focus.set_expand_margin_all(6)
	focus.expand_margin_bottom = 11
	focus.anti_aliasing = true
	t.set_stylebox("focus", type, focus)
	t.set_font("font", type, font(true))
	t.set_font_size("font_size", type, S_BODY)
	t.set_color("font_color", type, text)
	t.set_color("font_hover_color", type, text)
	t.set_color("font_pressed_color", type, text)
	t.set_color("font_hover_pressed_color", type, text)
	t.set_color("font_focus_color", type, text)
	t.set_color("font_disabled_color", type, PAPER_OFF_INK)
	t.set_color("font_outline_color", type, Color(0, 0, 0, 0))
	t.set_constant("outline_size", type, 0)
	t.set_constant("h_separation", type, 8)


static func _label_var(t: Theme, type: String, size: int, color: Color, heavy: bool, outline := 0, outline_col := INK, shadow := 0) -> void:
	t.set_type_variation(type, "Label")
	t.set_font("font", type, font(heavy))
	t.set_font_size("font_size", type, size)
	t.set_color("font_color", type, color)
	t.set_color("font_outline_color", type, outline_col)
	t.set_constant("outline_size", type, outline)
	if shadow > 0:
		t.set_color("font_shadow_color", type, INK)
		t.set_constant("shadow_offset_x", type, 0)
		t.set_constant("shadow_offset_y", type, shadow)


static func build() -> Theme:
	var t := Theme.new()
	t.default_font = font()
	t.default_font_size = S_BODY

	# Panels: the cream card is the default surface.
	var card := box(CREAM, INK, R_CARD, B_CARD, SHADOW)
	card.set_content_margin_all(PAD)
	t.set_stylebox("panel", "PanelContainer", card)
	t.set_stylebox("panel", "Panel", card.duplicate())
	t.set_type_variation("DarkPanel", "PanelContainer")
	var dark := box(INK, INK_LIGHT, R_CARD, B_CARD, SHADOW, 0, Color(0, 0, 0, 0.45))
	dark.set_content_margin_all(PAD)
	t.set_stylebox("panel", "DarkPanel", dark)
	t.set_type_variation("ChipPanel", "PanelContainer")
	var chip := box(CREAM, INK, 999, B_BTN, 4)
	chip.content_margin_left = 14
	chip.content_margin_right = 14
	chip.content_margin_top = 4
	chip.content_margin_bottom = 4
	t.set_stylebox("panel", "ChipPanel", chip)
	t.set_type_variation("DarkChipPanel", "PanelContainer")
	var dchip := box(INK, INK_LIGHT, 999, B_BTN, 4, 0, Color(0, 0, 0, 0.4))
	dchip.content_margin_left = 14
	dchip.content_margin_right = 14
	dchip.content_margin_top = 4
	dchip.content_margin_bottom = 4
	t.set_stylebox("panel", "DarkChipPanel", dchip)

	# Labels by role (default Label = body text, ink on cream).
	t.set_font("font", "Label", font())
	t.set_font_size("font_size", "Label", S_BODY)
	t.set_color("font_color", "Label", INK)
	_label_var(t, "TitleLabel", S_TITLE, MUSTARD, true, 10, INK, 4)
	_label_var(t, "HeroLabel", S_HERO, MUSTARD, true, 14, INK, 6)
	_label_var(t, "HeadingLabel", S_HEADING, INK, true)
	_label_var(t, "BodyLabel", S_BODY, INK, false)
	_label_var(t, "CaptionLabel", S_CAPTION, INK_SOFT, false)
	_label_var(t, "NumberLabel", S_HEADING, INK, true)
	_label_var(t, "KeyLabel", S_CAPTION, INK, true)

	# Buttons: default = primary (tomato).
	_btn_set(t, "Button", "Button", TOMATO, TOMATO.lightened(0.12), CREAM)
	_btn_set(t, "PrimaryButton", "Button", TOMATO, TOMATO.lightened(0.12), CREAM)
	_btn_set(t, "AccentButton", "Button", MUSTARD, MUSTARD.lightened(0.15), INK)
	_btn_set(t, "SecondaryButton", "Button", CREAM, CREAM_HI, INK)
	_btn_set(t, "DangerButton", "Button", TOMATO_DARK, TOMATO_DARK.lightened(0.12), CREAM)
	_btn_set(t, "GoButton", "Button", LETTUCE, LETTUCE.lightened(0.12), INK)

	# Line edit.
	var le := box(CREAM_HI, INK, R_INPUT, B_BTN)
	le.content_margin_left = 14
	le.content_margin_right = 14
	le.content_margin_top = 9
	le.content_margin_bottom = 9
	var le_focus := le.duplicate() as StyleBoxFlat
	le_focus.border_color = SKY
	le_focus.set_border_width_all(4)
	var le_ro := le.duplicate() as StyleBoxFlat
	le_ro.bg_color = PAPER_OFF
	le_ro.border_color = PAPER_OFF_INK
	t.set_stylebox("normal", "LineEdit", le)
	t.set_stylebox("focus", "LineEdit", le_focus)
	t.set_stylebox("read_only", "LineEdit", le_ro)
	t.set_font("font", "LineEdit", font())
	t.set_font_size("font_size", "LineEdit", S_BODY)
	t.set_color("font_color", "LineEdit", INK)
	t.set_color("font_uneditable_color", "LineEdit", PAPER_OFF_INK)
	t.set_color("font_placeholder_color", "LineEdit", INK_SOFT.lightened(0.25))
	t.set_color("caret_color", "LineEdit", TOMATO)
	t.set_color("selection_color", "LineEdit", MUSTARD)
	t.set_constant("caret_width", "LineEdit", 3)

	# Progress bar (fill colour is ramped by UIKit.progress()).
	var bg := box(INK, INK, 999, 3)
	bg.bg_color = Color("#3E3349")
	bg.border_color = INK
	bg.set_border_width_all(3)
	var fill := box(LETTUCE, LETTUCE, 999, 0)
	t.set_stylebox("background", "ProgressBar", bg)
	t.set_stylebox("fill", "ProgressBar", fill)
	t.set_font("font", "ProgressBar", font(true))
	t.set_font_size("font_size", "ProgressBar", S_CAPTION)
	t.set_color("font_color", "ProgressBar", CREAM)

	# Misc.
	var line := StyleBoxLine.new()
	line.color = Color(INK.r, INK.g, INK.b, 0.25)
	line.thickness = 3
	t.set_stylebox("separator", "HSeparator", line)
	t.set_constant("separation", "VBoxContainer", GAP)
	t.set_constant("separation", "HBoxContainer", GAP)
	t.set_constant("h_separation", "GridContainer", GAP)
	t.set_constant("v_separation", "GridContainer", GAP)
	var tip := box(INK, INK_LIGHT, 10, 2)
	tip.set_content_margin_all(8)
	t.set_stylebox("panel", "TooltipPanel", tip)
	t.set_color("font_color", "TooltipLabel", CREAM)
	return t
