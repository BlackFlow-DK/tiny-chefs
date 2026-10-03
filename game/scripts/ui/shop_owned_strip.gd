class_name ShopOwnedStrip
extends HFlowContainer
## "Owned" summary: one small emblem tile per upgrade line the team owns, with its level number.
## Used by the shop header and the pause menu. `refresh(shift)` rebuilds only when the build changed.

const TILE := 38

var tile := TILE

var _key := "?"
var _empty: Label
var _dark := true


func _init(dark := true, tile_px := TILE) -> void:
	_dark = dark
	tile = tile_px
	add_theme_constant_override("h_separation", 6 if tile_px >= 34 else 0)
	add_theme_constant_override("v_separation", 6)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_empty = UIKit.caption("Nothing yet. Your upgrades show up here.", "dark" if dark else "card")
	add_child(_empty)


func has_any() -> bool:
	return _key != "?" and _key != ""


## Returns true when the strip changed (the new tile ids in `fresh` get a punch).
func refresh(sm: ShiftManager) -> bool:
	if sm == null:
		return false
	var parts: Array = []
	for u in GameData.UPGRADES:
		var lv := sm.upgrade_level(u["id"])
		if lv > 0:
			parts.append("%s:%d" % [u["id"], lv])
	var key := ",".join(parts)
	if key == _key:
		return false
	var first := _key == "?"
	var old := _key.split(",", false)
	_key = key
	for ch in get_children():
		if ch != _empty:
			ch.queue_free()
	_empty.visible = parts.is_empty()
	for pr in parts:
		var id := str(pr).get_slice(":", 0)
		var lv := int(str(pr).get_slice(":", 1))
		var t := _Tile.new(id, lv, tile)
		add_child(t)
		if not first and not (pr in old):
			UIKit.punch(t, 0.35, 0.4)
	return true


class _Tile extends Control:
	func _init(id: String, lv: int, px: int) -> void:
		custom_minimum_size = Vector2(px + 4, px + 4)
		var col: Color = ShopView.COLORS.get(str(GameData.upgrade(id).get("category", "")), UITheme.MUSTARD)
		var icon := ShopIcon.new(id, col, px, true)
		icon.position = Vector2(0, 2)
		add_child(icon)
		if GameData.upgrade_max_level(id) > 1:
			add_child(_Badge.new(lv, px))   # after the icon, so it draws on top
		tooltip_text = GameData.upgrade_title(id, lv)


class _Badge extends Control:
	var level := 1
	var r := 10.0

	func _init(lv: int, px: int) -> void:
		level = lv
		r = clampf(px * 0.27, 7.0, 10.0)
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	func _draw() -> void:
		var at := Vector2(size.x - r + 1, size.y - r)
		var fs := int(r * 1.5)
		draw_circle(at, r, UITheme.INK)
		draw_arc(at, r, 0, TAU, 20, UITheme.CREAM, 1.5, true)
		var f := UITheme.font(true)
		var txt := str(level)
		var w := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(f, at + Vector2(-w / 2.0, fs * 0.36), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UITheme.CREAM)
