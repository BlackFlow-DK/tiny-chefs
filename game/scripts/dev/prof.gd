class_name Prof
extends Node
## CPU section timer for `--profile` (Main adds one). Off: Prof.t0() returns 0 and Prof.add() returns at
## once (one static bool check per call site). On: sections accumulate microseconds; every
## --profile-every seconds (10) and at exit it prints `profile: {json}` with each section's ms per rendered
## frame, calls per frame and worst single call, slowest first, plus the frame/process/physics totals.
## Sections: World physics tick (by system), snapshot build, World presentation, camera, indicators,
## HUD, chefs, items, bots. Usage: `var t := Prof.t0()` ... `Prof.add(&"name", t)`.

static var on := false
static var _acc: Dictionary = {}   # StringName -> PackedInt64Array [total_us, calls, max_us]

var _t := 0.0
var _every := 10.0
var _frames0 := 0
var _phys0 := 0
var _frame_us := 0
var _last_us := 0
var _frame_n := 0
var _total := {}   # whole run: same layout as _acc
var _frames_total := 0
var _phys_start := 0
var _proc_start := 0


## Runs last in both loops: closes the "all scripts" sections opened by Prof itself (which runs first).
class _End extends Node:
	var prof: Prof

	func _init() -> void:
		process_priority = 1000
		process_physics_priority = 1000

	func _process(_d: float) -> void:
		Prof.add(&"all _process scripts", prof._proc_start)

	func _physics_process(_d: float) -> void:
		Prof.add(&"all _physics_process scripts", prof._phys_start)


static func t0() -> int:
	return Time.get_ticks_usec() if on else 0


static func add(section: StringName, start: int) -> void:
	if not on:
		return
	var d := Time.get_ticks_usec() - start
	var a: PackedInt64Array = _acc.get(section, PackedInt64Array([0, 0, 0]))
	a[0] += d
	a[1] += 1
	a[2] = maxi(a[2], d)
	_acc[section] = a


func _ready() -> void:
	on = true
	process_mode = Node.PROCESS_MODE_ALWAYS
	process_priority = -1000
	process_physics_priority = -1000
	var e := _End.new()
	e.prof = self
	e.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(e)
	_every = Net.arg_float("profile-every", 10.0)
	_frames0 = Engine.get_process_frames()
	_phys0 = Engine.get_physics_frames()


func _physics_process(_delta: float) -> void:
	_phys_start = Time.get_ticks_usec()


func _process(delta: float) -> void:
	var now := Time.get_ticks_usec()
	_proc_start = now
	if _last_us > 0:
		_frame_us += now - _last_us
		_frame_n += 1
	_last_us = now
	_t += delta
	if _t >= _every:
		_t = 0.0
		_flush("window")


func _exit_tree() -> void:
	_flush("window")
	_report(_total, _frames_total, "total")
	on = false


func _flush(kind: String) -> void:
	var frames := maxi(1, Engine.get_process_frames() - _frames0)
	var phys := Engine.get_physics_frames() - _phys0
	_frames0 = Engine.get_process_frames()
	_phys0 = Engine.get_physics_frames()
	for k in _acc:
		var a: PackedInt64Array = _acc[k]
		var t: PackedInt64Array = _total.get(k, PackedInt64Array([0, 0, 0]))
		t[0] += a[0]
		t[1] += a[1]
		t[2] = maxi(t[2], a[2])
		_total[k] = t
	_frames_total += frames
	var extra := {"frame_ms": snappedf(_frame_us / 1000.0 / maxi(1, _frame_n), 0.01), "physics_ticks_per_frame": snappedf(float(phys) / frames, 0.01),
		"chefs": Net.world.chefs.size() if Net.world != null else 0, "items": Net.world.items.size() if Net.world != null else 0,
		"draw_calls": RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)}
	_report(_acc, frames, kind, extra)
	_acc = {}
	_frame_us = 0
	_frame_n = 0


static func _report(acc: Dictionary, frames: int, kind: String, extra := {}) -> void:
	if acc.is_empty():
		return
	var rows: Array = []
	for k in acc:
		var a: PackedInt64Array = acc[k]
		rows.append([str(k), a[0] / 1000.0 / frames, float(a[1]) / frames, a[2] / 1000.0])
	rows.sort_custom(func(x: Array, y: Array) -> bool: return x[1] > y[1])
	var sections: Array = []
	for r in rows:
		sections.append({"name": r[0], "ms_per_frame": snappedf(r[1], 0.001), "calls_per_frame": snappedf(r[2], 0.01), "max_ms": snappedf(r[3], 0.01)})
	var d := {"kind": kind, "frames": frames, "sections": sections}
	d.merge(extra)
	print("profile: " + JSON.stringify(d))
