class_name HazardSystem
extends RefCounted
## Generic hazard runner: one Hazard per id in world.map.hazards, loaded from
## res://scripts/world/hazards/<id>_hazard.gd (ids without a script, e.g. events owned elsewhere, are
## skipped with a log line). Every peer. World calls host_tick from _simulate (host, after the
## stations, only while PLAYING) and client_tick from _process (every peer).

const DIR := "res://scripts/world/hazards/"

var world: World
var hazards: Array[Hazard] = []


func _init(w: World) -> void:
	world = w
	for id in w.map.get("hazards", []):
		var path := DIR + "%s_hazard.gd" % str(id)
		if not ResourceLoader.exists(path):
			print("hazard: '%s' has no %s, skipped" % [id, path])
			continue
		var h := (load(path) as GDScript).new() as Hazard
		if h == null:
			print("hazard: '%s' is not a Hazard, skipped" % id)
			continue
		h.setup(w)
		hazards.append(h)


func host_tick(dt: float, playing: bool) -> void:
	if not playing:
		return
	for h in hazards:
		h.host_tick(dt)


func client_tick(dt: float) -> void:
	for h in hazards:
		h.client_tick(dt)
