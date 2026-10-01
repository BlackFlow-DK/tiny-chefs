class_name Training
extends RefCounted
## Mission 0 step prompts: a scripted list, advanced from the replicated world state on every peer
## (team-wide: whoever does the step moves everyone on). Serving an order before the last step ends it.

const STEPS := [
	{"key": "LMB", "text": "Grab a bun bottom"},
	{"key": "LMB", "text": "Drop it on the plate"},
	{"key": "", "text": "Cook a patty on the griddle"},
	{"key": "RMB", "text": "Ring the bell to serve"},
]

var step := 0


## True while the shift is the campaign training mission.
static func active(w: World) -> bool:
	return w != null and w.shift.running and str(w.shift.def.get("mode", "")) == "campaign" \
		and int(w.shift.def.get("mission_id", -1)) == 0


## Advances past every step already done and returns the current step (STEPS.size() = finished).
func update(w: World) -> int:
	if w.shift.served > 0:
		step = STEPS.size()
		return step
	var plate: Array = w.plate.stack if w.plate != null else []
	var at := 0
	if _carried(w, "bun_bottom") or plate.has("bun_bottom"):
		at = 1
	if plate.has("bun_bottom"):
		at = 2
	if at == 2 and (_exists(w, "patty_cooked") or plate.has("patty_cooked")):
		at = 3
	step = maxi(step, at)
	return step


static func _carried(w: World, kind: String) -> bool:
	for it in w.items.values():
		if str(it.kind) == kind and it.carrier_count > 0:
			return true
	return false


static func _exists(w: World, kind: String) -> bool:
	for it in w.items.values():
		if str(it.kind) == kind:
			return true
	return false
