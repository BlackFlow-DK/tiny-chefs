class_name HudChip
extends Control
## One LAYER of the mini burger stack on a HUD order ticket: a rendered thumbnail of the food model
## (ItemIcons), or the old coloured chip while the icon is still being rendered / missing. A run of the same
## kind (patty, patty) is one layer drawn as 2-3 copies with a "2x" badge. Layers overlap like a real stack
## (the one above is added later, so it draws over the one below). The marks that must never be covered
## (count badge, plate tick, "1st"/"last" tags) are drawn by the ticket's overlay through draw_marks().
## Done layers (already on the plate) get the washed-out icon variant plus a green tick.
## Local to the HUD: the design system has no ingredient chip with state.

const ICON_W := 50.0       # icon width at zoom 1
const GUTTER := 24.0       # left of the icon: the 1st / last tag
const COPY_DY := 5.0       # each extra copy of a repeated item sits this much higher
const PLATE_FONT := 13
const LABEL_FONT := 14
const SHORT := {"patty_cooked": "Patty", "bacon_cooked": "Bacon", "sausage_cooked": "Sausage", "chicken_cooked": "Chicken",
		"bun_bottom": "Bottom bun", "bun_top": "Top bun", "hotdog_bun": "Hot dog bun", "cheese_slice": "Cheese",
		"lettuce_leaf": "Lettuce", "tomato_slice": "Tomato", "onion_slice": "Onion", "pickle_slice": "Pickle",
		"fried_egg": "Egg", "soda_cup": "Soda", "fries": "Fries", "onion_rings": "Onion rings"}

var kind := ""
var need := 1
var have := 0
var step := 20.0           # vertical space this layer takes in the stack (what the next layer sits above)
var h_box := 38.0          # tallest the icon may be drawn
var tag := ""              # "1st" / "last" / ""
var zoom := 1.0
var label := ""           # name beside the icon (single-column tickets only)
var mark_x := 80.0         # where the count pill / tick starts
var _color := Color.WHITE
var _round := false
var _wfac := 1.0
var _is_top := false


## zoom scales the icon and the layer spacing; col_w is the chip width; labelled adds the name beside the icon.
func setup(item_kind: String, count: int, z := 1.0, col_w := 110.0, labelled := false) -> void:
	zoom = z
	kind = item_kind
	need = count
	var d: Dictionary = GameData.ITEMS[kind]
	_color = d["color"]
	var shape := str(d["shape"])
	_round = shape == "cyl" or shape == "sphere" or shape == "dome"
	var sz: Vector3 = d["size"]
	if sz.y <= 0.4:
		h_box = 30.0
		step = 17.0
	elif sz.y <= 1.2:
		h_box = 38.0
		step = 21.0
	else:
		h_box = 46.0
		step = 24.0
	_wfac = lerpf(0.72, 1.0, clampf(maxf(sz.x, sz.z) / 3.2, 0.0, 1.0))
	h_box *= zoom
	step = maxf(step * zoom, 19.0 if labelled else 14.0)
	var extra := COPY_DY * (mini(need, 3) - 1)
	h_box += extra
	step += extra
	mark_x = GUTTER + ICON_W * zoom - 12.0   # two-column tickets: badge and tick hang on the icon's right edge
	if labelled:
		mark_x += 18.0
		label = SHORT.get(kind, str(d["label"]))
		var f := UITheme.font(true)
		mark_x += f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_FONT).x + 8.0
	custom_minimum_size = Vector2(col_w, h_box)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	ItemIcons.ready_signal().connect(_on_icon_ready)


func _on_icon_ready(k: String) -> void:
	if k == kind:
		queue_redraw()


func set_have(n: int) -> void:
	n = mini(n, need)
	if n != have:
		var was_done := have >= need
		have = n
		queue_redraw()
		if get_parent_control() != null:
			get_parent_control().queue_redraw()
		if have >= need and not was_done and is_inside_tree():
			UIKit.punch(self, 0.25, 0.25)


func is_done() -> bool:
	return have >= need


func _draw() -> void:
	var done := is_done()
	var copies := mini(need, 3)
	var tex := ItemIcons.texture(kind, done)
	var iw := ICON_W * zoom
	var cx := GUTTER + iw * 0.5
	var bottom := size.y
	var img_h := h_box - COPY_DY * (copies - 1)
	for c in copies:
		var y_off := -COPY_DY * c
		if tex != null:
			var ts := tex.get_size()
			var sc := minf(iw * _wfac / ts.x, img_h / ts.y)
			var dsz := ts * sc
			draw_texture_rect(tex, Rect2(Vector2(cx - dsz.x * 0.5, bottom - dsz.y + y_off), dsz), false)
		else:
			var fill := _color.lerp(UITheme.CREAM, 0.55) if done else _color
			var r := Rect2(cx - 14 * zoom, bottom - 28 * zoom + y_off, 28 * zoom, 28 * zoom)
			draw_style_box(UITheme.box(fill, UITheme.INK, 14 if _round else 8, 3), r)
	if label != "":
		var vis := minf(step, h_box) if not _is_top else h_box
		var f := UITheme.font(true)
		draw_string(f, Vector2(GUTTER + iw + 6.0, bottom - vis * 0.5 + 5.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1, LABEL_FONT, UITheme.INK_SOFT if done else UITheme.INK)


## Count badge, tick and tag, drawn on the ticket's overlay (after every layer) at this layer's position.
func draw_marks(ci: CanvasItem, is_top: bool) -> void:
	_is_top = is_top
	var done := is_done()
	var f := UITheme.font(true)
	var fs := PLATE_FONT
	var vis := h_box if is_top else minf(step, h_box)
	var cy := position.y + size.y - vis * 0.5
	var x := position.x + mark_x
	if need > 1:
		var txt := ("%dx" % need) if have == 0 else ("%d/%d" % [have, need])
		var w := f.get_string_size(txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x + 10.0
		var r := Rect2(x, cy - 8.5, w, 17)
		ci.draw_style_box(UITheme.box(UITheme.LETTUCE if done else UITheme.MUSTARD, UITheme.INK, 8, 2), r)
		ci.draw_string(f, Vector2(r.position.x + 5, r.position.y + 13.0), txt, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, UITheme.INK)
		if done:
			_tick(ci, Vector2(r.end.x, r.position.y + 1.0), 7.0)
	elif done:
		_tick(ci, Vector2(x + 9.0, cy), 8.5)
	if tag == "cont":
		var cr := Rect2(position.x + GUTTER - 24.0, position.y + size.y - 17.0, 22, 15)
		ci.draw_style_box(UITheme.box(UITheme.INK, UITheme.INK, 7, 1), cr)
		var cc := cr.get_center()
		ci.draw_polyline(PackedVector2Array([cc + Vector2(-2.5, -4.5), cc + Vector2(2.5, 0), cc + Vector2(-2.5, 4.5)]), UITheme.CREAM, 2.4, true)
	elif tag != "":
		var tw := f.get_string_size(tag, HORIZONTAL_ALIGNMENT_LEFT, -1, fs - 2).x + 8.0
		var ty := position.y + size.y - 15.0 if tag == "1st" else position.y + size.y - h_box + 2.0
		var tr := Rect2(position.x + GUTTER - tw - 2.0, ty, tw, 15)
		ci.draw_style_box(UITheme.box(UITheme.INK, UITheme.INK, 7, 1), tr)
		ci.draw_string(f, Vector2(tr.position.x + 4, tr.position.y + 11.5), tag, HORIZONTAL_ALIGNMENT_LEFT, -1, fs - 2, UITheme.CREAM)


static func _tick(ci: CanvasItem, c: Vector2, r: float) -> void:
	ci.draw_circle(c, r, UITheme.INK)
	ci.draw_circle(c, r * 0.78, UITheme.LETTUCE)
	var k := r / 10.0
	var pts := PackedVector2Array([c + Vector2(-4, 0) * k, c + Vector2(-1, 3.5) * k, c + Vector2(4.5, -3.5) * k])
	ci.draw_polyline(pts, UITheme.CREAM_HI, maxf(2.0, 2.6 * k), true)
