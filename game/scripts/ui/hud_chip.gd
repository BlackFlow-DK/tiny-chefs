class_name HudChip
extends Control
## Ingredient chip for a HUD order ticket: coloured swatch (round or square by food shape), a count
## badge for doubles ("2x", or "1/2" while the plate is part-way), and a green tick once the plate
## already holds enough of it. Local to the HUD: the design system has no ingredient chip with state.

const SZ := Vector2(36, 32)
const BODY := 28.0

var kind := ""
var need := 1
var have := 0
var _color := Color.WHITE
var _round := false


func setup(item_kind: String, count: int) -> void:
	kind = item_kind
	need = count
	var d: Dictionary = GameData.ITEMS[kind]
	_color = d["color"]
	var shape := str(d["shape"])
	_round = shape == "cyl" or shape == "sphere" or shape == "dome"
	custom_minimum_size = SZ
	size = SZ
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_have(n: int) -> void:
	n = mini(n, need)
	if n != have:
		var was_done := have >= need
		have = n
		queue_redraw()
		if have >= need and not was_done and is_inside_tree():
			UIKit.punch(self, 0.25, 0.25)


func is_done() -> bool:
	return have >= need


func _draw() -> void:
	var done := is_done()
	var body := Rect2(0, 0, BODY, BODY)
	var fill := _color
	if done:
		fill = _color.lerp(UITheme.CREAM, 0.55)
	draw_style_box(UITheme.box(fill, UITheme.INK, 14 if _round else 8, 3), body)
	if done:
		var pts := PackedVector2Array([Vector2(7, 15), Vector2(12, 20), Vector2(21, 8)])
		draw_polyline(pts, UITheme.INK, 8.0, true)
		draw_polyline(pts, UITheme.LETTUCE, 4.5, true)
	if need > 1:
		var f := UITheme.font(true)
		var fs := UITheme.S_CAPTION - 2
		var txt := ("%dx" % need) if have == 0 else ("%d/%d" % [have, need])
		var w := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 10.0
		var r := Rect2(SZ.x - w, SZ.y - 19, w, 19)
		draw_style_box(UITheme.box(UITheme.LETTUCE if done else UITheme.MUSTARD, UITheme.INK, 9, 2), r)
		draw_string(f, Vector2(r.position.x + 5, r.position.y + 14.5), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UITheme.INK)
