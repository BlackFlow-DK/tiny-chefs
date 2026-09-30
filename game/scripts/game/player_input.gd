class_name PlayerInput
extends RefCounted
## One player's input as the host sees it. Button presses are counters (not bools) so a
## press survives a dropped unreliable packet: the host acts whenever a counter changes.

var move := Vector2.ZERO   # x = right, y = towards the camera (+Z)
var work := false          # held
var grab_seq := 0
var punch_seq := 0
var work_seq := 0


func copy_from(o: PlayerInput) -> void:
	move = o.move
	work = o.work
	grab_seq = o.grab_seq
	punch_seq = o.punch_seq
	work_seq = o.work_seq


func move3() -> Vector3:
	return Vector3(move.x, 0.0, move.y).limit_length(1.0)
