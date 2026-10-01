class_name FpsCounter
extends CanvasLayer
## Tiny frame-rate chip in the top-right corner (Settings "Show FPS"; --show-fps forces it on). Updates
## twice a second; sits above every other layer and never takes the mouse.

var _chip: PanelContainer
var _label: Label
var _t := 0.0


func _ready() -> void:
	layer = 100
	_chip = PanelContainer.new()
	_chip.theme = UI.theme()   # own canvas layer: does not inherit Main's UI theme
	_chip.theme_type_variation = "DarkChipPanel"
	_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_label = UIKit.caption("-- fps", "dark")
	_chip.add_child(_label)
	add_child(_chip)
	_chip.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT, Control.PRESET_MODE_MINSIZE)
	_chip.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_chip.position += Vector2(-8, 6)
	add_to_group(QualityApply.LISTENER_GROUP)
	apply_quality()


func apply_quality() -> void:
	visible = bool(Quality.get_value("show_fps")) or Net.has_arg("show-fps")
	set_process(visible)


func _process(delta: float) -> void:
	_t += delta
	if _t < 0.5:
		return
	_t = 0.0
	_label.text = "%d fps" % roundi(Engine.get_frames_per_second())
