class_name PlayerInput
extends RefCounted
## One player's input as the host sees it. Button presses are counters (not bools) so a
## press survives a dropped unreliable packet: the host acts whenever a counter changes.
##
## Aim (wire format, sent every tick with the rest):
##   aim_point  world XZ point the player points at (x = world X, y = world Z), on the counter
##              top plane (y = 0). Mouse: the point under the cursor. Pad: a few metres from the
##              chef along the right stick. Only meaningful while has_aim is true.
##   has_aim    true while the mouse is the active device (it moved or clicked last), or the pad's
##              right stick is deflected. False for bots and for pad play without the right stick.
## Host: read a player's aim with world.input_of(peer_id).aim_point / .has_aim. Local peer:
## world.local_input. A chef that is not carrying turns to face aim_point when has_aim.

var move := Vector2.ZERO   # x = right, y = towards the camera (+Z)
var work := false          # held
var grab_seq := 0
var punch_seq := 0
var work_seq := 0
var aim_point := Vector2.ZERO
var has_aim := false


func copy_from(o: PlayerInput) -> void:
	move = o.move
	work = o.work
	grab_seq = o.grab_seq
	punch_seq = o.punch_seq
	work_seq = o.work_seq
	aim_point = o.aim_point
	has_aim = o.has_aim


func move3() -> Vector3:
	return Vector3(move.x, 0.0, move.y).limit_length(1.0)


## aim_point as a world position on the counter top (y = 0).
func aim3() -> Vector3:
	return Vector3(aim_point.x, 0.0, aim_point.y)
