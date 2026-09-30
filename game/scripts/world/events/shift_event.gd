class_name ShiftEvent
extends RefCounted
## Base for one timed shift event (world/events/*.gd, one file per event). EventSystem owns the schedule
## and runs at most one event at a time: telegraph() at t = 0 (host), hit() at t = lead (host), host_tick
## until t = lead + active_time(), then finish(). visuals(t) runs every frame on every peer from the
## replicated (t, params()), so clients animate the same thing without extra RPCs.

var id := ""
var world: World       # a Node; the EventSystem is world.events (no back-reference: no RefCounted cycle)
var period := 60.0      # s between two firings (EventSystem jitters it +-15%)
var lead := 4.0         # s of telegraph before the effect


func _init(w: World) -> void:
	world = w


## s the effect lasts after the lead (0 = instant).
func active_time() -> float:
	return 0.0


## Host: may it start now? (e.g. only one open VIP at a time)
func available() -> bool:
	return true


## Host, t = 0: pick parameters, announce (banner + sound through Net.event).
func telegraph() -> void:
	pass


## Host, t = lead: the effect.
func hit() -> void:
	pass


## Host, every tick while the event runs (t = s since telegraph).
func host_tick(_dt: float, _t: float) -> void:
	pass


## Every peer, every frame while the event runs (t = s since telegraph; clients extrapolate it).
func visuals(_t: float) -> void:
	pass


## Every peer: the event ended or was cancelled; hide anything it shows.
func finish() -> void:
	pass


## Replicated parameters (floats) chosen in telegraph(); apply_params on clients.
func params() -> Array:
	return []


func apply_params(_p: Array) -> void:
	pass
