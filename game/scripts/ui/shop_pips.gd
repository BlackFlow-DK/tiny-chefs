class_name ShopPips
extends Control
## Level pips for one upgrade line: a filled dot per owned level, an empty dot per level still to buy.
## `set_level(n, true)` pops the newest pip when a level was just bought.

const R := 8.0
const STEP := 22.0

var _max := 1
var _level := 0
var _color := UITheme.MUSTARD
var _pop := 0.0          # 0..1 while the newest pip pops
var _tween: Tween


func _init(max_level := 1, color := UITheme.MUSTARD) -> void:
	_max = max_level
	_color = color
	custom_minimum_size = Vector2(STEP * max_level + 4.0, R * 2.0 + 8.0)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func set_level(level: int, animate := false) -> void:
	var grew := level > _level
	_level = level
	if _tween != null:
		_tween.kill()
	_pop = 0.0
	if animate and grew:
		_tween = create_tween()
		_tween.tween_method(func(x: float) -> void:
			_pop = x
			queue_redraw(), 0.0, 1.0, 0.45)
	queue_redraw()


func _draw() -> void:
	var cy := size.y / 2.0
	for i in _max:
		var at := Vector2(R + 2.0 + i * STEP, cy)
		var on := i < _level
		var r := R
		if on and i == _level - 1 and _pop > 0.0 and _pop < 1.0:
			r = R * (1.0 + 0.7 * sin(_pop * PI))
		if on:
			draw_circle(at, r, _color)
			draw_arc(at, r, 0, TAU, 20, UITheme.INK, 3.0, true)
			draw_circle(at + Vector2(-r * 0.3, -r * 0.3), r * 0.28, _color.lightened(0.6))
		else:
			draw_circle(at, r, UITheme.CREAM_DIM)
			draw_arc(at, r, 0, TAU, 20, UITheme.PAPER_OFF_INK, 2.5, true)
