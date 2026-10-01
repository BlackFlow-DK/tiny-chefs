class_name IndicatorLayer
extends CanvasLayer
## Screen-space projection of every in-world indicator (crisp text at any zoom): station markers that fade
## when the local chef is close, target prompt chips, cook/chop/dispense bars with DONE!/BURNT pops,
## crew pips on heavy carried food, name badges over remote chefs, "Buy <upgrade>" pills over closed
## stations, and pings (a bouncing pin + ground ring in the player's colour, from "ping" Net events).
## Sits under the HUD (layer -1) and runs with process_priority 200: after the camera driver (100), so
## the projected points use this frame's camera and do not lag or jitter.
## Reads world.camera, chefs, items, stations, grab_target, work_target, shift, local_input. Every peer.

const FADE_NEAR := 4.0           # m from the local chef to a station footprint: fully hidden inside
const FADE_FAR := 8.5           # fully visible beyond

var world: World
var _root: Control
var _cam: Camera3D
var _time := 0.0
var _stack: Dictionary = {}      # anchor key -> px already used above its point this frame

var _markers: Dictionary = {}    # Station -> Tag
var _badges: Dictionary = {}     # peer id -> {tag, name, color}
var _bars: Dictionary = {}       # item id -> {tag, bar, kind, f, pos}
var _pips: Dictionary = {}       # item id -> {tag, pips}
var _pops: Array = []            # {tag, pos, t}
var _chips: Array = []           # two slots
var _hold_tag: IndicatorParts.Tag
var _hold_bar: IndicatorParts.WorldBar
var _hold_t := 0.0
var _hold_target: Station = null
var _locks: Dictionary = {}      # Station -> Tag ("Buy Second Plate") while closed
var _pings: Dictionary = {}      # peer id -> {tag, pin, ring, pos, t}


func _init(w: World) -> void:
	world = w
	name = "Indicators"
	layer = -1
	process_priority = 200
	_root = Control.new()
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_root.theme = IndicatorParts.theme()
	add_child(_root)
	for i in 2:
		_chips.append({"tag": null, "sig": "", "pos": Vector3.ZERO, "px": 0.0})
	_hold_bar = IndicatorParts.WorldBar.new()
	_hold_tag = IndicatorParts.Tag.new(_hold_bar)
	_root.add_child(_hold_tag)
	Net.event_received.connect(_on_event)


func _process(delta: float) -> void:
	_cam = world.camera
	var me := world.my_chef()
	if _cam == null or not _cam.is_inside_tree() or Net.phase != Net.Phase.PLAYING or me == null:
		_root.visible = false
		_clear_pings()
		return
	_root.visible = true
	_time += delta
	_stack.clear()
	_update_markers(me, delta)
	_update_items(delta)
	_update_hold(me, delta)
	_update_chips(me, delta)
	_update_badges(me, delta)
	_update_pops(delta)
	_update_locks(delta)
	_update_pings(delta)


# ---------------------------------------------------------------- helpers

func _proj(p: Vector3) -> Variant:
	if _cam.is_position_behind(p):
		return null
	return _cam.unproject_position(p)


## Far (back) edge of an item's top, so indicators float above the food's rim instead of on it.
func _item_anchor(it: Item) -> Vector3:
	var b := it.global_transform.basis
	var ez := absf(b.x.z) * it.size.x * 0.5 + absf(b.z.z) * it.size.z * 0.5
	return it.global_position + Vector3(0, it.size.y, -ez)


func _station_anchor(s: Station) -> Vector3:
	var y := 0.05 if s.size.y < 1.0 else s.size.y
	if s.type == "dispenser":
		y = s.size.y + 0.6
	return s.global_position + Vector3(0, y, -s.half.y)


func _used(key: Variant, h: float, gap := 6.0) -> float:
	var used: float = _stack.get(key, 0.0)
	_stack[key] = used + h + gap
	return used


func _add(tag: IndicatorParts.Tag) -> IndicatorParts.Tag:
	_root.add_child(tag)
	return tag


# ---------------------------------------------------------------- station markers

func _update_markers(me: Chef, delta: float) -> void:
	var early: bool = world.shift.index == 0
	for s in world.stations:
		if s.type == "dispenser":
			continue
		var tag: IndicatorParts.Tag = _markers.get(s)
		if tag == null:
			tag = _add(IndicatorParts.Tag.new(IndicatorParts.station_pill(str(s.def["label"]))))
			_markers[s] = tag
		var want := 0.0
		if early:
			var d: float = s.footprint_distance(me.global_position)
			want = smoothstep(FADE_NEAR, FADE_FAR, d) * 0.96
		var sp: Variant = _proj(_station_anchor(s))
		if sp == null:
			tag.visible = false
			continue
		tag.show_at((sp as Vector2) + Vector2(0, -8), want, delta, 1.0, 3.0)


# ---------------------------------------------------------------- items: bars, pips

func _update_items(delta: float) -> void:
	var seen := {}
	for it: Item in world.items.values():
		if not is_instance_valid(it) or it.removed:
			continue
		var id := it.item_id
		var anchor := _item_anchor(it)
		var sp: Variant = _proj(anchor)
		# --- bar
		if it.bar_kind != Item.Bar.NONE:
			seen[id] = true
			var e: Dictionary = _bars.get(id, {})
			if e.is_empty():
				var nb := IndicatorParts.WorldBar.new()
				e = {"tag": _add(IndicatorParts.Tag.new(nb)), "bar": nb, "kind": it.bar_kind, "f": 0.0, "pos": anchor}
				_bars[id] = e
			var tag: IndicatorParts.Tag = e["tag"]
			var bar: IndicatorParts.WorldBar = e["bar"]
			if (e["kind"] == Item.Bar.COOK or e["kind"] == Item.Bar.FRY) and it.bar_kind == Item.Bar.BURN:
				_pop("DONE!", UITheme.LETTUCE, true, anchor, id)
			e["kind"] = it.bar_kind
			e["pos"] = anchor
			var f := clampf(it.bar, 0.0, 1.0)
			e["f"] = f
			var col := UITheme.MUSTARD
			var flash := 0.0
			match it.bar_kind:
				Item.Bar.COOK:
					col = UITheme.MUSTARD
				Item.Bar.BURN:
					# Time left before it burns: full green, draining to red.
					col = UIKit.ramp_color(1.0 - f)
					if f > 0.68:
						flash = 0.5 + 0.5 * sin(_time * (10.0 + 14.0 * (f - 0.68)))
						col = UITheme.TOMATO.lerp(UITheme.MUSTARD, flash * 0.5)
						if fmod(_time, 0.5) < delta:
							tag.bump()
					f = 1.0 - f
				Item.Bar.CHOP:
					col = UITheme.SKY
				Item.Bar.FRY:
					col = UITheme.MUSTARD.lerp(UITheme.TOMATO, 0.45)
			bar.set_state(f, col, flash)
			if sp != null:
				tag.show_at((sp as Vector2) + Vector2(0, -8 - _used(id, 19.0)), 1.0, delta, 1.0, 10.0)
			else:
				tag.visible = false
		# --- crew pips (heavy food someone is holding)
		if it.carrier_count > 0 and it.weight() > 1:
			var pe: Dictionary = _pips.get(id, {})
			if pe.is_empty():
				var pips := IndicatorParts.ChefPips.new()
				var pill := IndicatorParts._pill(UITheme.CREAM, 8, 2)
				pill.add_child(pips)
				pe = {"tag": _add(IndicatorParts.Tag.new(pill)), "pips": pips, "n": -1}
				_pips[id] = pe
			var ptag: IndicatorParts.Tag = pe["tag"]
			var pp: IndicatorParts.ChefPips = pe["pips"]
			if pe["n"] != it.carrier_count:
				if int(pe["n"]) >= 0:
					ptag.bump()
				pe["n"] = it.carrier_count
			pp.set_counts(it.weight(), it.carrier_count)
			seen[-id - 1] = true
			if sp != null:
				ptag.show_at((sp as Vector2) + Vector2(0, -8 - _used(id, 26.0)), 1.0, delta, 1.0, 10.0)
			else:
				ptag.visible = false
	# Free what is gone (a chopped tomato that reached the end pops "CHOP!").
	for id in _bars.keys():
		if not seen.has(id):
			var e2: Dictionary = _bars[id]
			var gone := not world.items.has(id)
			if e2["kind"] == Item.Bar.CHOP and float(e2["f"]) > 0.7 and gone:
				_pop("CHOP!", UITheme.SKY, true, e2["pos"], -1)
			elif e2["kind"] == Item.Bar.BURN and not gone:
				var it2: Item = world.items.get(id)
				if it2 != null and str(it2.kind).ends_with("_burnt"):
					_pop("BURNT", UITheme.TOMATO, false, e2["pos"], id)
			(e2["tag"] as Node).queue_free()
			_bars.erase(id)
	for id in _pips.keys():
		if not seen.has(-int(id) - 1):
			(_pips[id]["tag"] as Node).queue_free()
			_pips.erase(id)


func _pop(text: String, fill: Color, ink_text: bool, pos: Vector3, _id: int) -> void:
	var tag := _add(IndicatorParts.Tag.new(IndicatorParts.pop_pill(text, fill, ink_text)))
	tag.bump()
	tag.pop = 1.0
	_pops.append({"tag": tag, "pos": pos, "t": 0.0})


func _update_pops(delta: float) -> void:
	for pe in _pops.duplicate():
		pe["t"] = float(pe["t"]) + delta
		var t: float = pe["t"]
		var tag: IndicatorParts.Tag = pe["tag"]
		if t > 1.3:
			tag.queue_free()
			_pops.erase(pe)
			continue
		var sp: Variant = _proj(pe["pos"])
		if sp == null:
			tag.visible = false
			continue
		var a := 1.0 - smoothstep(0.8, 1.3, t)
		var rise := 34.0 + 22.0 * (1.0 - pow(1.0 - minf(t / 0.6, 1.0), 2.0))
		tag.place((sp as Vector2) + Vector2(0, -rise), a, 1.0 + 0.1 * sin(minf(t / 0.3, 1.0) * PI))


# ---------------------------------------------------------------- dispenser hold bar (local estimate)

func _update_hold(me: Chef, delta: float) -> void:
	var tgt: Station = world.work_target
	var ok: bool = tgt is Dispenser and world.local_input.work and me.held_id < 0 and not world.input_blocked
	if not ok:
		_hold_t = 0.0
		_hold_target = null
		_hold_tag.visible = false
		return
	if tgt != _hold_target:
		_hold_target = tgt
		_hold_t = 0.0
	_hold_t += delta
	var f := _hold_t / (tgt as Dispenser).hold_time()
	var sp: Variant = _proj(_station_anchor(tgt))
	if f >= 1.05 or sp == null:
		_hold_tag.visible = false
		return
	_hold_bar.set_state(minf(f, 1.0), UITheme.SKY)
	_hold_tag.place((sp as Vector2) + Vector2(0, -8 - _used(tgt, 19.0)), 1.0)


# ---------------------------------------------------------------- target prompt chips

func _update_chips(me: Chef, delta: float) -> void:
	var g: Item = world.grab_target
	var w: Station = world.work_target
	var want: Array = [null, null]     # [signature, pairs, world pos, stack key, crew]
	var grab_pair := ["LMB", "Grab"]
	var work_pair: Array = []
	if w != null:
		match w.type:
			"board":
				work_pair = ["RMB", "Chop"]
			"bell":
				work_pair = ["RMB", "Serve"]
			"dispenser":
				work_pair = ["RMB", "Hold"]
			"soda":
				work_pair = ["RMB", "Pour"]
	if g != null and not work_pair.is_empty() and w.contains_xz(g.global_position):
		want[0] = {"pairs": [grab_pair, work_pair], "pos": _item_anchor(g), "key": g.item_id, "crew": g.weight()}
	else:
		if g != null:
			want[0] = {"pairs": [grab_pair], "pos": _item_anchor(g), "key": g.item_id, "crew": g.weight()}
		if not work_pair.is_empty():
			var key: Variant = w
			var pos := _station_anchor(w)
			if w is CuttingBoard and (w as CuttingBoard).has_tomato:
				for it: Item in world.items.values():
					if is_instance_valid(it) and not it.removed and it.def.has("chops_to") and w.contains_xz(it.global_position):
						pos = _item_anchor(it)
						key = it.item_id   # same stack as its chop bar
						break
			want[1] = {"pairs": [work_pair], "pos": pos, "key": key, "crew": 0}
	for i in 2:
		var slot: Dictionary = _chips[i]
		var d: Variant = want[i]
		if d != null:
			var sig := str(d["pairs"]) + str(d["crew"])
			if slot["tag"] == null or slot["sig"] != sig:
				if slot["tag"] != null:
					(slot["tag"] as Node).queue_free()
				var tag := _add(IndicatorParts.Tag.new(IndicatorParts.key_chip(d["pairs"], int(d["crew"]))))
				tag.bump()
				slot["tag"] = tag
				slot["sig"] = sig
			slot["pos"] = d["pos"]
			slot["px"] = _used(d["key"], 24.0) + 12.0
		var t: IndicatorParts.Tag = slot["tag"]
		if t == null:
			continue
		var sp: Variant = _proj(slot["pos"])
		if sp == null:
			t.visible = false
			continue
		t.show_at((sp as Vector2) + Vector2(0, -float(slot["px"]) - 2.0), 1.0 if d != null else 0.0, delta, 1.0, 9.0)


# ---------------------------------------------------------------- remote name badges

func _update_badges(me: Chef, delta: float) -> void:
	for id in _badges.keys():
		if not world.chefs.has(id):
			(_badges[id]["tag"] as Node).queue_free()
			_badges.erase(id)
	for c: Chef in world.chefs.values():
		if c == me or c.peer_id == world.my_id:
			continue
		var color: Color = c.color
		var e: Dictionary = _badges.get(c.peer_id, {})
		if e.is_empty() or e["name"] != c.player_name or e["color"] != color:
			if not e.is_empty():
				(e["tag"] as Node).queue_free()
			e = {"tag": _add(IndicatorParts.Tag.new(IndicatorParts.name_badge(c.player_name, color))), "name": c.player_name, "color": color}
			_badges[c.peer_id] = e
		var tag: IndicatorParts.Tag = e["tag"]
		var foot: Variant = _proj(c.global_position)
		var head: Variant = _proj(c.global_position + Vector3(0, 1.7, 0))
		if foot == null or head == null or (c.flags & Chef.FLAG_RESPAWNING) != 0:
			tag.show_at(Vector2.ZERO, 0.0, delta)
			continue
		var chef_px: float = absf((foot as Vector2).y - (head as Vector2).y)
		var s := clampf(chef_px * 0.5 / 28.0, 0.6, 1.0)
		var at := (head as Vector2) + Vector2(0, -4)
		var target := 1.0
		# Fade when the food this chef carries would sit under the badge.
		var it := c._held_item()
		if it != null:
			var ip: Variant = _proj(it.global_position + Vector3(0, it.size.y * 0.5, 0))
			var ir: Variant = _proj(it.global_position + Vector3(0, it.size.y * 0.5, 0) + _cam.global_basis.x * it.radius())
			if ip != null and ir != null:
				var rad := ((ir as Vector2) - (ip as Vector2)).length()
				var box := Rect2(at - Vector2(50 * s, 28 * s), Vector2(100 * s, 28 * s))
				var nearest := Vector2(clampf((ip as Vector2).x, box.position.x, box.end.x), clampf((ip as Vector2).y, box.position.y, box.end.y))
				if nearest.distance_to(ip) < rad:
					target = 0.15
		tag.show_at(at, target, delta, s, 5.0)


# ---------------------------------------------------------------- closed stations

## Locked plates (and a locked bell whose plate is open) carry a "Buy <upgrade>" pill.
func _update_locks(delta: float) -> void:
	for s in world.stations:
		var st := s as Station
		var show: bool = st.is_locked() and (st is Plate or (st is Bell and ((st as Bell).plate == null or not (st as Bell).plate.is_locked())))
		var tag: IndicatorParts.Tag = _locks.get(st)
		if not show:
			if tag != null:
				tag.visible = false
			continue
		if tag == null:
			tag = _add(IndicatorParts.Tag.new(IndicatorParts.pop_pill("Buy %s" % st.unlock_name(), UITheme.MUSTARD, true)))
			_locks[st] = tag
		var sp: Variant = _proj(st.global_position + Vector3(0, 3.2 if st is Plate else 2.6, 0))
		if sp == null:
			tag.visible = false
			continue
		tag.show_at((sp as Vector2) + Vector2(0, -_used(st, 30.0)), 1.0, delta, 1.0, 6.0)


# ---------------------------------------------------------------- pings

## "ping" events carry "<peer>:<x>:<z>" (World.host_ping). One live ping per player: a new one replaces it.
func _on_event(text: String, sfx: String) -> void:
	if sfx != "ping":
		return
	var f := text.split(":")
	if f.size() != 3:
		return
	var id := int(f[0])
	var pos := Vector3(float(f[1]), 0.0, float(f[2]))
	var c: Chef = world.chefs.get(id)
	var color: Color = GameData.PLAYER_COLORS[(c.slot if c != null else 0) % GameData.PLAYER_COLORS.size()]
	var picked: Variant = c.get("color") if c != null else null   # lobby-picked colour when chefs have one
	if picked is Color:
		color = picked
	_remove_ping(id)
	var pin := IndicatorParts.PingPin.new(color)
	var tag := _add(IndicatorParts.Tag.new(pin))
	tag.bump()
	var ring := MeshInstance3D.new()
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ring.mesh = OutlineMesh.player_ring(1.0, 0.16, 0.05, false)
	ring.set_surface_override_material(0, OutlineMesh.flat_material(UITheme.INK))
	ring.set_surface_override_material(1, OutlineMesh.flat_material(color.lightened(0.15)))
	world.add_child(ring)
	ring.global_position = pos + Vector3(0, 0.07, 0)
	ring.scale = Vector3(0.01, 1, 0.01)
	_pings[id] = {"tag": tag, "pin": pin, "ring": ring, "pos": pos, "t": 0.0}
	if Net.has_arg("input-log"):
		print("ping: %s sees peer %d ping at %s" % ["host" if world.is_host else "client", id, pos.snapped(Vector3.ONE * 0.01)])


func _update_pings(delta: float) -> void:
	for id in _pings.keys():
		var e: Dictionary = _pings[id]
		var t: float = float(e["t"]) + delta
		e["t"] = t
		if t >= Tuning.PING_TIME:
			_remove_ping(id)
			continue
		var fade := 1.0 - smoothstep(Tuning.PING_TIME - 0.35, Tuning.PING_TIME, t)
		var grow := minf(t / 0.18, 1.0)
		var ring: MeshInstance3D = e["ring"]
		var r := 1.3 * grow * fade * (1.0 + 0.08 * sin(t * 9.0))
		ring.scale = Vector3(maxf(r, 0.01), 1, maxf(r, 0.01))
		var pin: IndicatorParts.PingPin = e["pin"]
		pin.set_lift(absf(sin(t * 5.5)) * 16.0 * (0.55 + 0.45 * fade))
		var tag: IndicatorParts.Tag = e["tag"]
		var sp: Variant = _proj(e["pos"])
		if sp == null:
			tag.visible = false
			continue
		tag.place((sp as Vector2) + Vector2(0, 6), fade, 1.0)


func _remove_ping(id: int) -> void:
	var e: Dictionary = _pings.get(id, {})
	if e.is_empty():
		return
	(e["tag"] as Node).queue_free()
	(e["ring"] as Node).queue_free()
	_pings.erase(id)


func _clear_pings() -> void:
	for id in _pings.keys():
		_remove_ping(id)
