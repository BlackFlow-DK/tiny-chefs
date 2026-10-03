class_name ShopRow
extends PanelContainer
## One upgrade LINE in the shop: icon, name, level pips, the NEXT level's effect (+ running total), price chip
## and a Buy button. States: buy, poor, locked (requires), na (not on the next kitchen), max.

signal pressed(id: String)      # Buy button clicked (any state; the view decides what happens)
signal bought(id: String, level: int)

const ROW_H := 76
const ICON_PX := 56

## Wording overrides for lines whose data text is long ("{value}" = the step of the level shown).
const SHORT := {
	"gloves": "Unlocks punching: launch food, shove friends.",
	"second_plate": "Opens the second plate and bell.",
	"combo_bell": "Serve within 20 s: +{value} pay per streak step.",
	"friendly_service": "Customers wait {value} longer.",
}

var id := ""
var state := ""         # st name: buy | poor | locked | na | max
var level := 0
var cost := 0
var button: Button

var _key := ""
var _col := UITheme.MUSTARD
var _name: Label
var _pips: ShopPips
var _tag: PanelContainer
var _eff: Label
var _tot: Label
var _chip: PanelContainer
var _price: Label
var _max_badge: PanelContainer
var _style_rest: StyleBoxFlat
var _style_rec: StyleBoxFlat
var _style_max: StyleBoxFlat
var _shown_level := -1


func _init(upgrade_id: String, color: Color) -> void:
	id = upgrade_id
	_col = color
	var u := GameData.upgrade(id)
	_style_rest = UITheme.box(UITheme.CREAM, UITheme.INK, 14, 3, 4)
	_style_rec = UITheme.box(UITheme.CREAM, UITheme.MUSTARD_DARK, 14, 4, 4)
	_style_max = UITheme.box(UITheme.LETTUCE.lightened(0.78), UITheme.INK, 14, 3, 4)
	for sb in [_style_rest, _style_rec, _style_max]:
		(sb as StyleBoxFlat).set_content_margin_all(8)
	add_theme_stylebox_override("panel", _style_rest)
	custom_minimum_size = Vector2(0, ROW_H)
	size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 14)
	add_child(h)

	h.add_child(ShopIcon.new(id, color, ICON_PX))

	# Name + pips (+ the Recommended tag).
	var nv := VBoxContainer.new()
	nv.add_theme_constant_override("separation", 0)
	nv.custom_minimum_size = Vector2(250, 0)
	nv.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_name = UIKit.body(str(u.get("name", id)))
	nv.add_child(_name)
	var pr := HBoxContainer.new()
	pr.add_theme_constant_override("separation", 10)
	_pips = ShopPips.new(GameData.upgrade_max_level(id), color)
	_pips.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pr.add_child(_pips)
	_tag = PanelContainer.new()
	_tag.add_theme_stylebox_override("panel", UITheme.box(UITheme.MUSTARD, UITheme.INK, 8, 2, 2))
	(_tag.get_theme_stylebox("panel") as StyleBoxFlat).set_content_margin_all(2)
	(_tag.get_theme_stylebox("panel") as StyleBoxFlat).content_margin_left = 8
	(_tag.get_theme_stylebox("panel") as StyleBoxFlat).content_margin_right = 8
	var tl := UIKit.caption("Recommended")
	tl.add_theme_color_override("font_color", UITheme.INK)
	tl.add_theme_font_size_override("font_size", 14)
	_tag.add_child(tl)
	_tag.visible = false
	_tag.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	pr.add_child(_tag)
	nv.add_child(pr)
	h.add_child(nv)

	# Effect of the next level + total.
	var ev := VBoxContainer.new()
	ev.add_theme_constant_override("separation", 0)
	ev.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ev.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_eff = UIKit.body("")
	_eff.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_eff.custom_minimum_size = Vector2(300, 0)
	ev.add_child(_eff)
	_tot = UIKit.caption("")
	_tot.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ev.add_child(_tot)
	h.add_child(ev)

	# Price chip + button (or the MAX ribbon in the button's place).
	_chip = PanelContainer.new()
	_chip.theme_type_variation = "ChipPanel"
	_chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var ph := HBoxContainer.new()
	ph.add_theme_constant_override("separation", 6)
	ph.add_child(UIKit.dot(UITheme.MUSTARD, 20))
	_price = UIKit.number("0")
	ph.add_child(_price)
	_chip.add_child(ph)
	_chip.custom_minimum_size = Vector2(98, 0)
	h.add_child(_chip)

	var host := Control.new()
	host.custom_minimum_size = Vector2(176, 50)
	host.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	button = UIKit.button("Buy", func() -> void: pressed.emit(id), "accent", 0)
	button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	button.add_theme_font_size_override("font_size", UITheme.S_BODY)
	host.add_child(button)
	_max_badge = PanelContainer.new()
	_max_badge.add_theme_stylebox_override("panel", UITheme.box(UITheme.LETTUCE, UITheme.INK, 10, 3, 4))
	var ml := UIKit.number("MAX")
	ml.add_theme_font_size_override("font_size", UITheme.S_HEADING)
	_max_badge.add_child(ml)
	_max_badge.visible = false
	_max_badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	host.add_child(_max_badge)
	_max_badge.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)
	_max_badge.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_max_badge.grow_vertical = Control.GROW_DIRECTION_BOTH
	_max_badge.rotation = -0.06
	h.add_child(host)


## Plain-words effect of buying level `lv` (1-based): the line's desc filled with that level's own step.
static func step_text(id: String, lv: int, cumulative := false) -> String:
	var u := GameData.upgrade(id)
	var levels: Array = u.get("levels", [])
	var v := GameData.upgrade_total(id, lv) if cumulative else float(levels[clampi(lv, 1, levels.size()) - 1]["value"])
	var t := str(SHORT.get(id, u.get("desc", "")))
	return t.replace("{value}", _fmt(str(u.get("unit", "none")), v))


static func _fmt(unit: String, v: float) -> String:
	match unit:
		"pct":
			return "%d%%" % int(round(v * 100.0))
		"int":
			return str(int(round(v)))
		"num":
			return "%.2f" % v
	return ""


## "total +30%" style label of the cumulative effect at `lv`.
static func total_text(id: String, lv: int) -> String:
	if str(GameData.upgrade(id).get("unit", "none")) == "none":
		return ""
	return "+" + GameData.upgrade_value_text(id, lv)


func refresh(sm: ShiftManager, recommended: bool, animate: bool) -> void:
	var lv := sm.upgrade_level(id)
	var mx := GameData.upgrade_max_level(id)
	var price := sm.next_price(id)
	var st := "max" if price < 0 else ("buy" if sm.coins >= price else "poor")
	if st != "max" and not ShiftSystem.upgrade_available(id, sm.next_index):
		st = "na"
	elif st != "max" and not sm.requires_met(id):
		st = "locked"
	var need := maxi(price - sm.coins, 0) if st == "poor" else 0
	var key := "%s:%d:%d:%s" % [st, lv, need, str(recommended)]
	if key == _key:
		return
	_key = key
	state = st
	level = lv
	cost = price
	var unit := str(GameData.upgrade(id).get("unit", "none"))
	var shown := mini(lv + 1, mx)

	# Effect + total.
	var maxed := st == "max"
	_eff.text = step_text(id, mx, true) if maxed else step_text(id, shown)
	var tot := ""
	if unit == "none":
		tot = "Fully upgraded" if maxed else "One-time unlock"
	elif maxed:
		tot = "Total %s (max)" % total_text(id, mx)
	elif lv == 0:
		tot = "Total %s" % total_text(id, 1)
	else:
		tot = "Now %s, total %s" % [total_text(id, lv), total_text(id, shown)]
	_tot.remove_theme_color_override("font_color")
	if st == "locked":
		var req := GameData.upgrade_requires(id)
		tot = "Needs %s" % GameData.upgrade_title(str(req[0]), int(req[1]))
		_tot.add_theme_color_override("font_color", UITheme.TOMATO_DARK)
	elif st == "na":
		tot = "Not available on the next kitchen"
		_tot.add_theme_color_override("font_color", UITheme.TOMATO_DARK)
	_tot.text = tot

	# Price + button.
	_price.text = str(maxi(price, 0))
	_price.add_theme_color_override("font_color", UITheme.TOMATO_DARK if st == "poor" else UITheme.INK)
	_chip.visible = not maxed
	_chip.modulate = Color(1, 1, 1, 0.55) if (st == "na" or st == "locked") else Color.WHITE
	button.visible = not maxed
	_max_badge.visible = maxed
	match st:
		"buy":
			button.text = "Upgrade" if lv > 0 else "Buy"
			button.theme_type_variation = "AccentButton"
			button.modulate = Color.WHITE
		"poor":
			button.text = "Need %d more" % need
			button.theme_type_variation = "SecondaryButton"
			button.modulate = Color(1, 1, 1, 0.92)
		"locked":
			button.text = "Locked"
			button.theme_type_variation = "SecondaryButton"
			button.modulate = Color(1, 1, 1, 0.6)
		"na":
			button.text = "Unavailable"
			button.theme_type_variation = "SecondaryButton"
			button.modulate = Color(1, 1, 1, 0.6)
	modulate = Color(1, 1, 1, 0.7) if (st == "na" or st == "locked") else Color.WHITE

	# Frame + tag.
	_tag.visible = recommended and st == "buy"
	add_theme_stylebox_override("panel", _style_max if maxed else (_style_rec if _tag.visible else _style_rest))

	# Pips and purchase juice.
	var grew := _shown_level >= 0 and lv > _shown_level
	_pips.set_level(lv, animate and grew)
	if animate and grew:
		UIKit.punch(self, 0.04, 0.32)
		if maxed:
			UIKit.punch(_max_badge, 0.5, 0.4)
		bought.emit(id, lv)
	_shown_level = lv
