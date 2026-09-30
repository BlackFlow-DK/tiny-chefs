class_name UIProgress
extends ProgressBar
## Chunky progress bar. Drive with set_fraction(0..1). ramp = colour goes green -> mustard -> tomato.
## pulse_when_low: heartbeat once the fraction drops under 0.2.

var ramp := true
var pulse_when_low := false
var fill_color := UITheme.LETTUCE
var _fill: StyleBoxFlat
var _pulse: Tween


func _init() -> void:
	min_value = 0.0
	max_value = 1.0
	step = 0.0
	show_percentage = false
	custom_minimum_size = Vector2(160, 20)
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_fill = UITheme.box(UITheme.LETTUCE, UITheme.LETTUCE, 999, 0)
	add_theme_stylebox_override("fill", _fill)


func set_fraction(f: float) -> void:
	f = clampf(f, 0.0, 1.0)
	value = f
	_fill.bg_color = UIKit.ramp_color(f) if ramp else fill_color
	if pulse_when_low:
		if f < 0.2 and f > 0.0 and _pulse == null and is_inside_tree():
			_pulse = UIKit.pulse(self, 0.06, 0.45)
		elif (f >= 0.2 or f <= 0.0) and _pulse != null:
			_pulse.kill()
			_pulse = null
			scale = Vector2.ONE

