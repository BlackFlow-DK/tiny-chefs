class_name InspectorEvent
extends ShiftEvent
## "inspector": "Health inspector arriving in 15 s!" with a countdown (HUD reads EventSystem.inspector_left()),
## then every burnt item over any counter surface, loose or carried, costs Tuning.INSPECTOR_FINE (a red toast
## each) and an "INSPECTED" stamp banner follows; a clean kitchen earns Tuning.INSPECTOR_BONUS.


func _init(w: World) -> void:
	super(w)
	id = "inspector"
	period = Tuning.INSPECTOR_PERIOD
	lead = Tuning.INSPECTOR_LEAD


func telegraph() -> void:
	Net.event("Health inspector arriving in %d s!" % int(lead), "ev_inspector")


func hit() -> void:
	var burnt: Array[Item] = []
	for it: Item in world.items.values():
		if it.removed or not it.kind.ends_with("_burnt"):
			continue
		var p := it.global_position
		if p.y > -1.0 and world.on_counter(Vector2(p.x, p.z)):
			burnt.append(it)
	var shift := world.shift
	for it in burnt:
		shift.add_coins(-Tuning.INSPECTOR_FINE)
		Net.event("Inspector: %s! -%d" % [it.label_text(), Tuning.INSPECTOR_FINE], "fail")
		world.events.note_fine(it.kind, Tuning.INSPECTOR_FINE)
	world.events.note_inspection(burnt.size())
	if burnt.is_empty():
		shift.add_coins(Tuning.INSPECTOR_BONUS)
		Net.event("INSPECTED: Clean kitchen! +%d" % Tuning.INSPECTOR_BONUS, "ev_inspected")
	else:
		Net.event("INSPECTED: %d burnt, -%d" % [burnt.size(), burnt.size() * Tuning.INSPECTOR_FINE], "ev_inspected")
	print("events: inspection, %d burnt item(s) fined" % burnt.size())
