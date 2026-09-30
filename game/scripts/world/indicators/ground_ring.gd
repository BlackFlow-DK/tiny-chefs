class_name GroundRing
extends MeshInstance3D
## Thin player-colour ring on the counter under a chef with a chevron on the +Z (facing) side.
## Add as a child of the Chef: the chef's yaw turns the chevron. The local chef's ring is brighter.


func setup(color: Color, own: bool) -> void:
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	position = Vector3(0, 0.06, 0)
	mesh = OutlineMesh.player_ring(0.78, 0.1 if own else 0.075, 0.035)
	var col := color.lightened(0.3) if own else color.darkened(0.05)
	set_surface_override_material(0, OutlineMesh.flat_material(UITheme.INK))
	set_surface_override_material(1, OutlineMesh.flat_material(col))
