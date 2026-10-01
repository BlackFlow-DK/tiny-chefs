class_name Hazard
extends RefCounted
## Base for a map hazard (MapDef "hazards" ids; HazardSystem loads world/hazards/<id>_hazard.gd).
## setup(world) once on every peer after the stations exist; host_tick(dt) on the host every physics
## tick while a shift is playing (gameplay: push food, send Net.event); client_tick(dt) on every peer
## (the host too) every frame (presentation: particles, toasts, sounds). Hazards talk to clients
## through Net.event (reliable, every peer) and the normal item snapshots; they add no RPCs.

var world: World


func setup(w: World) -> void:
	world = w


func host_tick(_dt: float) -> void:
	pass


func client_tick(_dt: float) -> void:
	pass
