class_name EventSystem
extends RefCounted
## Timed shift events (docs/design/overnight-1.md section 7): vip, inspector, cat_paw (world/events/*.gd).
## Enabled per shift by ShiftDef "events" (campaign missions; endless from shift 2; custom GameSettings.events),
## cat_paw only on maps whose "hazards" include "cat_paw". Host: --events=a,b forces that list in endless and
## custom; --event-fast lets the first one fire EVENT_FAST_START s into the shift (testing).
## Schedule (host): each enabled event has its own cadence (period +-15%); one event at a time; a telegraph
## (banner + sound, Net.event with an "ev_*" sfx) runs `lead` s before the effect; the next telegraph waits
## EVENT_GAP s after the last effect; nothing starts before EVENT_QUIET_START s and every effect is over
## EVENT_QUIET_END s before the shift ends.
## Replication: state() rides in the snapshot meta ("e": [event index or -1, t, params...]); clients run
## the same visuals(t) from it (the paw, the inspector countdown via inspector_left()).
## Stats: signals below + `counters` (run totals, mirrored to Net.metrics["events"]).

signal vip_served(pay: int)
signal vip_expired
signal inspector_fined(kind: String, coins: int)
signal inspected(burnt_count: int)
signal paw_hit(target: Node3D)    # an Item launched or a Chef shoved

var world: World
var events: Array[ShiftEvent] = []           # one per GameSettings.EVENT_IDS, same order
var enabled: Array[ShiftEvent] = []          # host: this shift's, in fire order for --event-fast
var current: ShiftEvent = null
var t := 0.0                                  # s since current's telegraph
var counters := {"vip_served": 0, "vip_expired": 0, "vip_coins": 0, "inspections": 0, "inspector_fines": 0,
	"inspector_fine_coins": 0, "paw_sweeps": 0, "paw_hits": 0, "fired": {}}

var _hit_done := false
var _due: Dictionary = {}                     # host: event id -> shift-elapsed s when it may fire next
var _last_end := -INF
var _rng := RandomNumberGenerator.new()


func _init(w: World) -> void:
	world = w
	_rng.randomize()
	for eid in GameSettings.EVENT_IDS:
		match eid:
			"vip":
				events.append(VipEvent.new(w))
			"inspector":
				events.append(InspectorEvent.new(w))
			"cat_paw":
				events.append(CatPawEvent.new(w))
	Net.metrics["events"] = counters


func by_id(eid: String) -> ShiftEvent:
	for e in events:
		if e.id == eid:
			return e
	return null


## The ids that fire this shift: def "events" (or the host's --events outside campaign), known ids only,
## cat_paw only when the map has that hazard.
static func enabled_ids(def: Dictionary, map: Dictionary) -> Array:
	var ids: Array = def.get("events", [])
	if Net.has_arg("events") and str(def.get("mode", "")) != "campaign":
		ids = Array(Net.arg_str("events", "").split(",", false))
	var out: Array = []
	for e in ids:
		var s := str(e).strip_edges()
		if not GameSettings.EVENT_IDS.has(s) or out.has(s):
			continue
		if s == "cat_paw" and not (map.get("hazards", []) as Array).has("cat_paw"):
			continue
		out.append(s)
	return out


# ================================================================ host

func start_shift() -> void:
	_cancel()
	enabled.clear()
	_due.clear()
	_last_end = -INF
	var fast := Net.has_arg("event-fast")
	var ids := enabled_ids(world.shift.def, world.map)
	for i in ids.size():
		var e := by_id(str(ids[i]))
		enabled.append(e)
		if fast:
			_due[e.id] = Tuning.EVENT_FAST_START + 0.001 * i
		else:
			_due[e.id] = Tuning.EVENT_QUIET_START + _rng.randf_range(0.0, e.period * 0.5)
	print("events: shift %d enabled [%s]%s" % [world.shift.index + 1, ",".join(ids), " (fast)" if fast else ""])


## Every host tick (after the stations, before falls are removed).
func tick(dt: float, playing: bool) -> void:
	var shift := world.shift
	if current != null:
		if not playing or not shift.running:
			_cancel()
			return
		t += dt
		if not _hit_done and t >= current.lead:
			_hit_done = true
			current.hit()
		current.host_tick(dt, t)
		if t >= current.lead + current.active_time():
			_last_end = _elapsed()
			_cancel()
		return
	if not playing or not shift.running or enabled.is_empty():
		return
	var now := _elapsed()
	var start := Tuning.EVENT_FAST_START if Net.has_arg("event-fast") else Tuning.EVENT_QUIET_START
	if now < start or now < _last_end + Tuning.EVENT_GAP:
		return
	var pick: ShiftEvent = null
	for e in enabled:
		if float(_due[e.id]) > now or shift.time_left < e.lead + e.active_time() + Tuning.EVENT_QUIET_END:
			continue
		if not e.available():
			continue
		if pick == null or float(_due[e.id]) < float(_due[pick.id]):
			pick = e
	if pick != null:
		_start(pick, now)


func _start(e: ShiftEvent, now: float) -> void:
	current = e
	t = 0.0
	_hit_done = false
	_due[e.id] = now + e.period * _rng.randf_range(0.85, 1.15)
	var fired: Dictionary = counters["fired"]
	fired[e.id] = int(fired.get(e.id, 0)) + 1
	if e.id == "cat_paw":
		counters["paw_sweeps"] = int(counters["paw_sweeps"]) + 1
	print("events: %s at %.1f s of the shift (effect in %.0f s; %.1f s after launch)" % [e.id, now, e.lead, Time.get_ticks_msec() / 1000.0])
	e.telegraph()


func _cancel() -> void:
	if current != null:
		current.finish()
	current = null
	t = 0.0
	_hit_done = false


func _elapsed() -> float:
	return float(world.shift.def.get("duration", 0.0)) - world.shift.time_left


# ================================================================ hooks (host)

func on_order_served(o: Dictionary, pay: int) -> void:
	if not bool(o.get("vip", false)):
		return
	counters["vip_served"] = int(counters["vip_served"]) + 1
	counters["vip_coins"] = int(counters["vip_coins"]) + pay
	vip_served.emit(pay)
	Net.event("VIP delighted! +%d coins" % pay, "ev_vip_paid")


func on_order_expired(o: Dictionary) -> void:
	if bool(o.get("vip", false)):
		counters["vip_expired"] = int(counters["vip_expired"]) + 1
		vip_expired.emit()


func note_fine(kind: String, coins: int) -> void:
	counters["inspector_fines"] = int(counters["inspector_fines"]) + 1
	counters["inspector_fine_coins"] = int(counters["inspector_fine_coins"]) + coins
	inspector_fined.emit(kind, coins)


func note_inspection(burnt_count: int) -> void:
	counters["inspections"] = int(counters["inspections"]) + 1
	inspected.emit(burnt_count)


func note_paw_hit(target: Node3D) -> void:
	counters["paw_hits"] = int(counters["paw_hits"]) + 1
	paw_hit.emit(target)


# ================================================================ every peer

## s until the health inspector arrives, or -1 when none is on the way (HUD countdown).
func inspector_left() -> float:
	if current != null and current.id == "inspector" and t < current.lead:
		return current.lead - t
	return -1.0


## Every frame: clients extrapolate t between snapshots; everyone draws the current event.
func process(delta: float) -> void:
	if current == null:
		return
	if not world.is_host:
		t += delta
	current.visuals(t)


func state() -> Array:
	if current == null:
		return [-1]
	var a: Array = [events.find(current), t]
	a.append_array(current.params())
	return a


func apply_state(a: Array) -> void:
	var idx := int(a[0]) if a.size() > 0 else -1
	if idx < 0 or idx >= events.size() or a.size() < 2:
		_cancel()
		return
	var e := events[idx]
	var ht := float(a[1])
	if e != current:
		_cancel()
		current = e
		t = ht
	elif ht < t - 1.0 or absf(ht - t) > 0.2:
		t = ht   # resync (a restarted event of the same kind jumps back)
	e.apply_params(a.slice(2))
