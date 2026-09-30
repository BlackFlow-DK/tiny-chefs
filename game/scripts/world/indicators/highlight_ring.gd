class_name HighlightRing
extends MeshInstance3D
## Thin pulsing outline in the local player's colour that hugs a target footprint (item or station).
## show_at() every frame while targeted, hide_ring() otherwise.

const WIDTH := 0.13
const INK := 0.045

var _key := ""
var _ink_mat: StandardMaterial3D
var _col_mat: StandardMaterial3D
var _color := Color.WHITE


func _init() -> void:
	visible = false
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ink_mat = OutlineMesh.flat_material(UITheme.INK)
	_col_mat = OutlineMesh.flat_material(Color.WHITE)


func hide_ring() -> void:
	visible = false


## centre: world position of the footprint's base centre. hx/hz: half extents (already with margin).
func show_at(centre: Vector3, hx: float, hz: float, yaw: float, corner: float, color: Color, t: float) -> void:
	var key := "%.2f|%.2f|%.2f" % [hx, hz, corner]
	if key != _key:
		_key = key
		mesh = OutlineMesh.rounded_ring(hx, hz, corner, WIDTH, INK)
		set_surface_override_material(0, _ink_mat)
		set_surface_override_material(1, _col_mat)
	if color != _color:
		_color = color
	var pulse := 0.5 + 0.5 * sin(t * 5.0)
	_col_mat.albedo_color = _color.lerp(Color.WHITE, 0.1 + 0.3 * pulse)
	var s := 1.0 + 0.025 * pulse
	visible = true
	global_position = centre + Vector3(0, 0.05, 0)
	rotation = Vector3(0, yaw, 0)
	scale = Vector3(s, 1, s)
