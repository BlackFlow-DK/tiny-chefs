class_name CameraSystem
extends RefCounted
## Owns the follow camera: creates world.camera and eases it after the local chef every frame.
## Every peer. Reads world.my_chef(), Tuning.CAMERA_*. The HUD reads world.camera to project labels.

var world: World
var _cam_ready := false


func _init(w: World) -> void:
	world = w
	var camera := Camera3D.new()
	camera.fov = Tuning.CAMERA_FOV
	camera.far = 500.0
	w.add_child(camera)
	camera.current = true
	w.camera = camera


func update(delta: float) -> void:
	var camera := world.camera
	var target := Vector3(0, 0, 2)
	var me := world.my_chef()
	if me != null:
		target = me.global_position
		target.y = clampf(target.y, -1.0, 1.0)
	var pitch := deg_to_rad(Tuning.CAMERA_PITCH_DEG)
	var want := target + Vector3(0, sin(pitch), cos(pitch)) * Tuning.CAMERA_DISTANCE
	if not _cam_ready:
		camera.global_position = want
		_cam_ready = me != null
	else:
		camera.global_position = camera.global_position.lerp(want, 1.0 - exp(-Tuning.CAMERA_SMOOTH * delta))
	camera.rotation = Vector3(-pitch, 0, 0)
