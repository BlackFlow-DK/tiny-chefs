class_name ChefAnim
extends RefCounted
## Procedural chef animator (rig v2, no skeleton). The owner (Chef, a dev preview, a turntable) fills `state`
## every frame and calls update(dt); ChefAnim poses the chef.glb parts: the model root (hops, squash, fall
## flail), Body (hips pivot: bob, lean, sway, breathing), Head (neck: look-around, nods), Eyes (blink),
## Brows, Mouth, HandL/HandR (hand centre), FootL/FootR (ankle). Missing parts are skipped (primitive chef).
## Every input is something a puppet knows as well (observed motion, replicated flags + held item, Net
## events), so the same code animates every chef on every peer. Cheap: a few dozen trig calls, no allocations.
## Body shapes: static shape(model, id) (GameData.BODY_SHAPES) sets the rest pose the animator works from;
## call refresh_rest() after it.

signal step(side: int)  ## a foot planted while walking (0 = FootL at +X, 1 = FootR): footstep dust hook
signal skid             ## hard direction change at speed: skid puff hook
signal sweat            ## straining under food too heavy for the crew (about once a second): sweat-drop hook

enum Work { NONE, CHOP, DISPENSE, BELL, SODA }

const PARTS := ["Body", "Head", "HandL", "HandR", "FootL", "FootR", "LegL", "LegR"]
const LEG_LEN := 0.13      # ankle to hip (chef.glb), the part LegL/LegR stretch
const SLEEVE_X := 0.283    # sleeve end; hands sit just beyond it
const PUNCH_DUR := 0.32
const TOSS_DUR := 0.35
const SLAP_DUR := 0.42
const CELE_DUR := 1.2
const FAIL_DUR := 1.5
const PING_DUR := 1.0
const LAND_DUR := 0.5


## What the owner knows about the chef this frame. One-shot pulses are cleared by update().
class State:
	var vel := Vector3.ZERO        ## world horizontal velocity (observed from motion)
	var yaw := 0.0                 ## chef yaw, turns vel into chef space
	var turn_rate := 0.0           ## rad/s (observed)
	var vy := 0.0                  ## vertical speed (observed); a hard stop after a fall = landing squash
	var carrying := false
	var weight := 1                ## held food weight (Item.weight())
	var carriers := 1              ## chefs on it
	var hold := Vector3.ZERO       ## carry: hand reach offset from the hand rest (chef space; carry visuals)
	var working := false           ## work held at a station (Chef.FLAG_WORKING)
	var work_kind := Work.NONE
	var punching := false          ## Chef.FLAG_PUNCHING (rising edge starts the swing)
	var falling := false           ## Chef.FLAG_RESPAWNING
	var toss := false              ## pulse: let go of food
	var celebrate := false         ## pulse: an order was served
	var fail := false              ## pulse: something failed (expired order, burnt food, fine)
	var slap := false              ## pulse: this chef rang the bell
	var ping := false              ## pulse: this chef pinged ping_dir
	var ping_dir := Vector3(0, 0, 1)  ## chef space, horizontal


var state := State.new()
var idle_time := 0.0  ## s standing still with nothing to do (drives look-around)
var model: Node3D

var _root_rest := Transform3D.IDENTITY
var _body: Node3D
var _head: Node3D
var _eyes: Node3D
var _brows: Node3D
var _mouth: Node3D
var _hand_l: Node3D
var _hand_r: Node3D
var _foot_l: Node3D
var _foot_r: Node3D
var _body_pos := Vector3.ZERO
var _body_scale := Vector3.ONE
var _hand_rest_l := Vector3.ZERO
var _hand_rest_r := Vector3.ZERO
var _foot_rest_l := Transform3D.IDENTITY
var _foot_rest_r := Transform3D.IDENTITY
var _eyes_scale := Vector3.ONE
var _mouth_scale := Vector3.ONE
var _brows_pos := Vector3.ZERO

var _rng := RandomNumberGenerator.new()
var _t := 0.0
var _phase := 0.0
var _speed := 0.0
var _cadence := 0.0   # like _speed but not capped at PLAYER_SPEED: shoes (move_mult) step faster, feet don't slide
var _dir := Vector3(0, 0, 1)
var _lv_prev := Vector3.ZERO
var _acc := Vector3.ZERO
var _vy_prev := 0.0
var _was_punching := false
var _w_carry := 0.0
var _w_work := 0.0
var _w_fall := 0.0
var _strain := 0.0
var _lean := 0.0
var _punch := 0.0
var _toss := 0.0
var _slap := 0.0
var _cele := 0.0
var _fail := 0.0
var _ping := 0.0
var _land := 0.0
var _land_amp := 0.0
var _ping_dir := Vector3(0, 0, 1)
var _blink := 0.0
var _blink_cd := 2.0
var _look_cd := 1.0
var _look_yaw := 0.0
var _look_pitch := 0.0
var _head_rot := Vector3.ZERO
var _skid_cd := 0.0
var _sweat_cd := 0.0
var _fc_l := 0.0
var _fc_r := 0.0


## chef_model: a chef.glb instance (or the primitive chef). seed_value: per chef (peer id), so blinks and
## glances match on every peer.
func _init(chef_model: Node3D, seed_value := 0) -> void:
	model = chef_model
	_rng.seed = hash(seed_value) & 0x7fffffff
	_blink_cd = _rng.randf_range(0.5, 3.0)
	if model == null:
		return
	_root_rest = model.transform
	_body = model.find_child("Body", true, false) as Node3D
	_head = model.find_child("Head", true, false) as Node3D
	_eyes = model.find_child("Eyes", true, false) as Node3D
	_brows = model.find_child("Brows", true, false) as Node3D
	_mouth = model.find_child("Mouth", true, false) as Node3D
	_hand_l = model.find_child("HandL", true, false) as Node3D
	_hand_r = model.find_child("HandR", true, false) as Node3D
	_foot_l = model.find_child("FootL", true, false) as Node3D
	_foot_r = model.find_child("FootR", true, false) as Node3D
	if _eyes != null:
		_eyes_scale = _eyes.scale
	if _mouth != null:
		_mouth_scale = _mouth.scale
	if _brows != null:
		_brows_pos = _brows.position
	refresh_rest()


## Re-read the rest pose (after shape() changed the body shape).
func refresh_rest() -> void:
	if model == null:
		return
	var rest: Dictionary = model.get_meta("rig_rest") if model.has_meta("rig_rest") else {}
	if _body != null:
		var bt: Transform3D = rest.get("Body", _body.transform)
		_body_pos = bt.origin
		_body_scale = bt.basis.get_scale()
	if _hand_l != null:
		_hand_rest_l = (rest.get("HandL", _hand_l.transform) as Transform3D).origin
	if _hand_r != null:
		_hand_rest_r = (rest.get("HandR", _hand_r.transform) as Transform3D).origin
	if _foot_l != null:
		_foot_rest_l = rest.get("FootL", _foot_l.transform)
	if _foot_r != null:
		_foot_rest_r = rest.get("FootR", _foot_r.transform)


## Apply a GameData.BODY_SHAPES entry to a chef.glb instance: scales Body, Head, hands, feet and legs, keeps
## the soles on the ground and the head/hands attached. Stores the rest pose as meta "rig_rest" (the
## animator's base) and the untouched glb pose as "rig_base". Anchors are children of the parts, so attached
## hats/beards/back items follow. No-op on models without a Body (primitive chef).
static func shape(chef_model: Node3D, shape_id: String) -> void:
	if chef_model == null:
		return
	var base: Dictionary
	if chef_model.has_meta("rig_base"):
		base = chef_model.get_meta("rig_base")
	else:
		base = {}
		for n: String in PARTS:
			var p := chef_model.find_child(n, true, false) as Node3D
			if p != null:
				base[n] = p.transform
		chef_model.set_meta("rig_base", base)
	if not base.has("Body") or not base.has("FootL") or not base.has("FootR"):
		return
	var sh := GameData.body_shape(shape_id)
	var b: Vector3 = sh["body"]
	var h := float(sh["head"])
	var hs := float(sh["hands"])
	var fs := float(sh["feet"])
	var lg := float(sh["legs"])
	var out := float(sh["arm_out"])
	var bt: Transform3D = base["Body"]
	var ankle := (base["FootL"] as Transform3D).origin.y
	var hip := bt.origin.y
	# feet scale about the ankle: lift the ankle so the sole stays on y = 0; the body rides on the legs
	var lift := ankle * (fs - 1.0) + LEG_LEN * (fs * lg - 1.0)
	var rest := {}
	rest["Body"] = Transform3D(Basis.from_scale(b), Vector3(bt.origin.x, hip + lift, bt.origin.z))
	if base.has("Head"):
		rest["Head"] = Transform3D(Basis.from_scale(Vector3(h / b.x, h / b.y, h / b.z)), (base["Head"] as Transform3D).origin)
	for n: String in ["HandL", "HandR"]:
		if not base.has(n):
			continue
		var o: Vector3 = (base[n] as Transform3D).origin
		var sx := signf(o.x)
		var p := Vector3(sx * (SLEEVE_X * b.x + (absf(o.x) - SLEEVE_X) * hs + out), hip + lift + (o.y - hip) * b.y,
			bt.origin.z + (o.z - bt.origin.z) * b.z)
		rest[n] = Transform3D(Basis.from_scale(Vector3.ONE * hs), p)
	for n: String in ["FootL", "FootR"]:
		var o: Vector3 = (base[n] as Transform3D).origin
		rest[n] = Transform3D(Basis.from_scale(Vector3.ONE * fs), Vector3(o.x * maxf(1.0, b.x * 0.9), ankle * fs, o.z))
	for n: String in ["LegL", "LegR"]:
		if base.has(n):
			rest[n] = Transform3D(Basis.from_scale(Vector3(1.0, lg, 1.0)), (base[n] as Transform3D).origin)
	for n: String in rest:
		(chef_model.find_child(n, true, false) as Node3D).transform = rest[n]
	chef_model.set_meta("rig_rest", rest)
	chef_model.set_meta("rig_shape", shape_id)


func update(dt: float) -> void:
	if model == null or dt <= 0.0:
		return
	var s := state
	_t += dt
	# ---- motion in chef space
	var lv := s.vel.rotated(Vector3.UP, -s.yaw)
	lv.y = 0.0
	var spd := lv.length()
	var ratio := clampf(spd / Tuning.PLAYER_SPEED, 0.0, 1.6)
	_speed = lerpf(_speed, minf(ratio, 1.0), 1.0 - exp(-10.0 * dt))
	_cadence = lerpf(_cadence, ratio, 1.0 - exp(-10.0 * dt))
	_acc = _acc.lerp((lv - _lv_prev) / dt, 1.0 - exp(-8.0 * dt))
	_lv_prev = lv
	if spd > 0.3:
		_dir = _dir.lerp(lv / spd, 1.0 - exp(-12.0 * dt)).normalized()
	_skid_cd -= dt
	if spd > 2.5 and _acc.dot(lv / spd) < -25.0 and _skid_cd <= 0.0:
		_skid_cd = 0.3
		skid.emit()
	var sp := _speed
	var w_move := clampf(sp * 3.0, 0.0, 1.0)
	# ---- state weights and one-shot timers
	var heavy := 1.0
	var short := 0.0
	if s.carrying:
		heavy = 1.0 + 0.35 * float(s.weight - 1)
		short = clampf(float(s.weight - s.carriers) / 2.0, 0.0, 1.0)
	var k_w := 1.0 - exp(-10.0 * dt)
	_w_carry = lerpf(_w_carry, 1.0 if s.carrying else 0.0, k_w)
	_w_work = lerpf(_w_work, 1.0 if s.working and not s.carrying else 0.0, k_w)
	_w_fall = lerpf(_w_fall, 1.0 if s.falling else 0.0, 1.0 - exp(-8.0 * dt))
	_strain = lerpf(_strain, short if s.carrying and s.weight > s.carriers else 0.0, 1.0 - exp(-6.0 * dt))
	if s.punching and not _was_punching:
		_punch = PUNCH_DUR
	_was_punching = s.punching
	if s.toss:
		_toss = TOSS_DUR
	if s.slap:
		_slap = SLAP_DUR
	if s.celebrate:
		_cele = CELE_DUR
	if s.fail:
		_fail = FAIL_DUR
	if s.ping:
		_ping = PING_DUR
		_ping_dir = Vector3(s.ping_dir.x, 0.0, s.ping_dir.z)
		_ping_dir = _ping_dir.normalized() if _ping_dir.length_squared() > 0.0001 else Vector3(0, 0, 1)
	if _vy_prev < -2.0 and s.vy > -0.5 and s.vy < 1.5 and not s.falling:
		_land = LAND_DUR
		_land_amp = clampf(-_vy_prev / 7.0, 0.35, 1.0)
	_vy_prev = s.vy
	s.toss = false
	s.slap = false
	s.celebrate = false
	s.fail = false
	s.ping = false
	_punch = maxf(0.0, _punch - dt)
	_toss = maxf(0.0, _toss - dt)
	_slap = maxf(0.0, _slap - dt)
	_cele = maxf(0.0, _cele - dt)
	_fail = maxf(0.0, _fail - dt)
	_ping = maxf(0.0, _ping - dt)
	_land = maxf(0.0, _land - dt)
	var e_cele := _env(_cele, CELE_DUR, 0.08, 0.3)
	var e_fail := _env(_fail, FAIL_DUR, 0.25, 0.4)
	var e_ping := _env(_ping, PING_DUR, 0.12, 0.3) * (1.0 - _w_carry)
	var e_toss := _env(_toss, TOSS_DUR, 0.06, 0.2)
	var busy := s.carrying or s.working or s.falling or _punch > 0.0 or _cele > 0.0 or _fail > 0.0 or _ping > 0.0
	idle_time = idle_time + dt if sp < 0.05 and not busy else 0.0
	# ---- idle life: blink, look-around
	_blink_cd -= dt
	if _blink_cd <= 0.0:
		_blink = 0.13
		_blink_cd = _rng.randf_range(0.25, 0.4) if _rng.randf() < 0.18 else _rng.randf_range(1.8, 4.6)
	_blink = maxf(0.0, _blink - dt)
	if idle_time > 1.2:
		_look_cd -= dt
		if _look_cd <= 0.0:
			_look_cd = _rng.randf_range(1.4, 3.4)
			_look_yaw = 0.0 if _rng.randf() < 0.25 else _rng.randf_range(-0.7, 0.7)
			_look_pitch = _rng.randf_range(-0.14, 0.1)
	else:
		_look_yaw = 0.0
		_look_pitch = 0.0
	# ---- walk cycle
	_phase = fmod(_phase + dt * (4.0 + 12.0 * _cadence) / heavy, TAU)
	var sn := sin(_phase)
	var cs := cos(_phase)
	var breath := sin(_t * 2.4)
	# ---- root (whole figure): bob, hops, squash, fall flail
	var fig_y := absf(cs) * 0.06 * sp / heavy * (1.0 - 0.5 * _w_carry)
	var fig_rot := Vector3.ZERO
	var fig_scale := Vector3.ONE
	if _cele > 0.0 and not s.carrying:
		var tt := CELE_DUR - _cele
		if tt < 0.06:
			fig_scale = Vector3(1.06, 0.9, 1.06)
		elif tt < 0.48:
			var hop := sin(PI * (tt - 0.06) / 0.42)
			fig_y += 0.3 * hop
			fig_scale = Vector3(1.0 - 0.05 * hop, 1.0 + 0.08 * hop, 1.0 - 0.05 * hop)
		elif tt < 0.8:
			fig_y += 0.12 * sin(PI * (tt - 0.48) / 0.32)
		fig_rot.y = sin(tt * 9.0) * 0.18 * e_cele
	if _land > 0.0:
		var tl := LAND_DUR - _land
		var q := _land_amp * exp(-8.0 * tl) * cos(22.0 * tl)
		fig_scale *= Vector3(1.0 + 0.16 * q, 1.0 - 0.24 * q, 1.0 + 0.16 * q)
	fig_rot += Vector3(sin(_t * 7.0) * 0.35, 0.0, cos(_t * 9.0) * 0.3) * _w_fall
	model.transform = _root_rest * Transform3D(Basis.from_euler(fig_rot) * Basis.from_scale(fig_scale), Vector3(0, fig_y, 0))
	# ---- body: lean (walk + acceleration, carry weight, work), twist, sway, turn lean, strain wobble, breathing
	var carry_lean := 0.05 * sp
	if s.weight > 1:
		carry_lean = -(0.05 + 0.13 * short) * (0.5 + 0.5 * sp)
	var lean := lerpf(0.14 * sp + clampf(_acc.z / 45.0, -1.0, 1.0) * 0.14, carry_lean, _w_carry)
	var chop := pow(0.5 + 0.5 * sin(_t * 13.0), 2.0)
	var pull := 0.5 + 0.5 * sin(_t * 6.0)
	if _w_work > 0.01:
		var wl := 0.08
		match s.work_kind:
			Work.CHOP:
				wl = 0.1 + 0.05 * (1.0 - chop)
			Work.DISPENSE:
				wl = 0.04 - 0.1 * pull
			Work.SODA:
				wl = 0.02
		lean = lerpf(lean, wl, _w_work)
	var p_punch := 1.0 - _punch / PUNCH_DUR if _punch > 0.0 else 1.0
	var twist := sn * 0.08 * sp
	if _punch > 0.0:
		if p_punch < 0.3:
			twist += 0.35 * (p_punch / 0.3)
		elif p_punch < 0.55:
			twist += lerpf(0.35, -0.4, (p_punch - 0.3) / 0.25)
			lean += 0.15
		else:
			twist += lerpf(-0.4, 0.0, (p_punch - 0.55) / 0.45)
	lean += 0.28 * e_fail + 0.12 * e_toss - 0.08 * e_cele
	_lean = lerpf(_lean, lean, 1.0 - exp(-12.0 * dt))
	var roll := sn * 0.06 * sp - clampf(s.turn_rate * sp * 0.05, -0.22, 0.22) - clampf(_acc.x / 45.0, -1.0, 1.0) * 0.1
	roll += sin(_t * 23.0) * 0.04 * _strain
	var body_y := 0.012 * absf(cs) * w_move - 0.04 * e_fail
	if _body != null:
		_body.position = _body_pos + Vector3(0, body_y, 0)
		_body.rotation = Vector3(_lean, twist, roll)
		_body.scale = _body_scale * Vector3(1.0 - 0.006 * breath, 1.0 + 0.016 * breath, 1.0 - 0.006 * breath)
	# ---- head: steadies against the lean, looks into turns, looks around when idle, nods at work
	if _head != null:
		var hp := _look_pitch - 0.45 * _lean
		var hy := _look_yaw + clampf(s.turn_rate * 0.06, -0.35, 0.35)
		var hr := sin(_t * 17.0) * 0.05 * _strain + sin(_t * 15.0) * 0.12 * e_cele
		if _w_work > 0.01:
			var wp := 0.15
			match s.work_kind:
				Work.CHOP:
					wp = 0.3 + 0.05 * chop
				Work.SODA:
					wp = -0.08
			hp = lerpf(hp, wp, _w_work)
		hp += -0.25 * e_cele + 0.38 * e_fail + 0.25 * _w_fall * sin(_t * 11.0)
		if e_ping > 0.0:
			hy = lerpf(hy, clampf(atan2(_ping_dir.x, _ping_dir.z), -0.9, 0.9), e_ping)
		_head_rot = _head_rot.lerp(Vector3(hp, hy, hr), 1.0 - exp(-9.0 * dt))
		_head.rotation = _head_rot
	# ---- face: blink, squint, happy eyes, frown, gasp, brows
	if _eyes != null:
		var ey := 0.1
		if _blink <= 0.0:
			ey = lerpf(1.0, 0.65, _strain)
			ey = lerpf(ey, 0.8, e_fail)
			ey = lerpf(ey, 0.42, e_cele)
			ey = lerpf(ey, 1.25, _w_fall)
		_eyes.scale = _eyes.scale.lerp(_eyes_scale * Vector3(1.0 + 0.1 * _w_fall, ey, 1.0), 1.0 - exp(-40.0 * dt))
	if _mouth != null:
		var my := lerpf(1.0, -0.9, e_fail)        # through a flat line into a frown
		my = lerpf(my, 1.7, e_cele)
		my = lerpf(my, 2.3, _w_fall)
		my = lerpf(my, 0.35, _strain)
		var mx := 1.0 + 0.25 * e_cele - 0.4 * _w_fall + 0.15 * _strain
		_mouth.scale = _mouth.scale.lerp(_mouth_scale * Vector3(mx, my, 1.0), 1.0 - exp(-14.0 * dt))
	if _brows != null:
		var by := 0.012 * e_cele - 0.009 * e_fail - 0.006 * _strain + 0.016 * _w_fall
		_brows.position = _brows.position.lerp(_brows_pos + Vector3(0, by, 0), 1.0 - exp(-22.0 * dt))
	# ---- hands (children of the root, so carry targets stay exact; they follow the body bob and lean)
	var common := Vector3(0, body_y + 0.006 * breath, _lean * 0.26)
	var kh := 1.0 - exp(-(40.0 if _punch > 0.0 or _slap > 0.0 else 22.0) * dt)
	if _hand_l != null:
		_hand_l.position = _hand_l.position.lerp(_hand_target(0, _hand_rest_l + common, sn, w_move, chop, pull, e_toss, e_cele, e_fail, e_ping, p_punch), kh)
	if _hand_r != null:
		_hand_r.position = _hand_r.position.lerp(_hand_target(1, _hand_rest_r + common, sn, w_move, chop, pull, e_toss, e_cele, e_fail, e_ping, p_punch), kh)
	# ---- feet: step along the move direction, lift in the swing, kick when falling
	var stride := 0.1 * w_move / heavy
	if _foot_l != null:
		_foot_l.transform = _foot_pose(_foot_rest_l, 0, sn, cs, stride, w_move)
	if _foot_r != null:
		_foot_r.transform = _foot_pose(_foot_rest_r, 1, -sn, -cs, stride, w_move)
	# ---- VFX hooks
	if w_move > 0.4 and not s.falling:
		if _fc_l > 0.0 and cs <= 0.0:
			step.emit(0)
		if _fc_r > 0.0 and cs >= 0.0:
			step.emit(1)
	_fc_l = cs
	_fc_r = -cs
	if _strain > 0.3:
		_sweat_cd -= dt
		if _sweat_cd <= 0.0:
			_sweat_cd = 1.1
			sweat.emit()
	else:
		_sweat_cd = 0.4


## Target of hand i (0 = HandL at +X, 1 = HandR) in model space: the walk pose with every state blended over it.
func _hand_target(i: int, r: Vector3, sn: float, w_move: float, chop: float, pull: float,
		e_toss: float, e_cele: float, e_fail: float, e_ping: float, p_punch: float) -> Vector3:
	var s := state
	var side := 1.0 if i == 0 else -1.0
	var h := r + Vector3(side * 0.02 * w_move, 0.02 * absf(sn) * w_move, -sn * side * 0.09 * w_move)
	if _w_work > 0.01:
		var w := r + Vector3(0, 0.15 + sin(_t * 30.0 + i * PI) * 0.18, 0.3)
		match s.work_kind:
			Work.CHOP:
				w = r + (Vector3(0.1, 0.06 + 0.22 * chop, 0.3) if i == 1 else Vector3(-0.1, 0.04, 0.28))
			Work.DISPENSE:
				w = r + Vector3(-side * 0.06, 0.13 + 0.04 * pull, 0.42 - 0.13 * pull)
			Work.SODA:
				var press := pow(sin(_t * 4.0), 2.0)
				w = r + (Vector3(0.08, 0.26 - 0.07 * press, 0.4) if i == 1 else Vector3(-0.06, 0.04, 0.32))
		h = h.lerp(w, _w_work)
	if _w_carry > 0.01:
		h = h.lerp(r + s.hold + Vector3(0, sin(_t * 31.0 + i * 1.7) * 0.012 * _strain, 0), _w_carry)
	if e_ping > 0.0 and i == (0 if _ping_dir.x >= 0.0 else 1):
		h = h.lerp(Vector3(r.x * 0.7, r.y + 0.3, r.z) + _ping_dir * 0.34, e_ping)
	if _punch > 0.0:
		if i == 1:
			var wind := r + Vector3(-0.06, 0.22, -0.1)
			var hit := r + Vector3(0.2, 0.25, 0.75)
			if p_punch < 0.3:
				h = h.lerp(wind, p_punch / 0.3)
			elif p_punch < 0.55:
				h = wind.lerp(hit, (p_punch - 0.3) / 0.25)
			else:
				h = hit.lerp(h, (p_punch - 0.55) / 0.45)
		else:
			h = h.lerp(r + Vector3(-0.05, 0.14, 0.14), _env(_punch, PUNCH_DUR, 0.05, 0.12))
	if e_toss > 0.0:
		h += Vector3(0, 0.3, 0.35) * e_toss
	if _slap > 0.0 and i == 1:
		var ts := SLAP_DUR - _slap
		var up := r + Vector3(0.1, 0.42, 0.3)
		var down := r + Vector3(0.1, 0.1, 0.38)
		if ts < 0.16:
			h = h.lerp(up, ts / 0.16)
		elif ts < 0.24:
			h = up.lerp(down, (ts - 0.16) / 0.08)
		else:
			h = down.lerp(h, (ts - 0.24) / (SLAP_DUR - 0.24))
	if not s.carrying:
		if e_cele > 0.0:
			h = h.lerp(r + Vector3(side * 0.2, 0.6 + 0.05 * sin(_t * 22.0 + i * PI), -0.04), e_cele)
		if e_fail > 0.0:
			h = h.lerp(r + Vector3(-side * 0.05, -0.1, 0.06), e_fail)
	if _w_fall > 0.01:
		h = h.lerp(r + Vector3(side * 0.12, 0.42 + 0.14 * sin(_t * 19.0 + i * PI), 0.06 * cos(_t * 17.0)), _w_fall)
	return h


func _foot_pose(rest: Transform3D, i: int, fs: float, fc: float, stride: float, w_move: float) -> Transform3D:
	var off := _dir * fs * stride
	off.y = maxf(0.0, fc) * 0.07 * w_move
	var pitch := -0.35 * w_move * fs * _dir.z
	if _w_fall > 0.01:
		var k := sin(_t * 15.0 + i * PI)
		off += Vector3(0, 0.06 + 0.04 * k, 0.1 * k) * _w_fall
		pitch += 0.4 * k * _w_fall
	return Transform3D(Basis(Vector3.RIGHT, pitch) * rest.basis, rest.origin + off)


## One line for --anim-log: smoothed speed, walk phase, state weights, active one-shots, hand/foot offsets.
func debug_line() -> String:
	var hr := (_hand_r.position - _hand_rest_r) if _hand_r != null else Vector3.ZERO
	var fl := (_foot_l.position - _foot_rest_l.origin) if _foot_l != null else Vector3.ZERO
	return "speed=%.2f phase=%.2f carry=%.2f work=%.2f(%d) fall=%.2f strain=%.2f lean=%.2f punch=%.2f cele=%.2f fail=%.2f slap=%.2f ping=%.2f land=%.2f idle=%.1f handR=(%.2f,%.2f,%.2f) footL=(%.2f,%.2f,%.2f)" % [
		_speed, _phase, _w_carry, _w_work, state.work_kind, _w_fall, _strain, _lean, _punch, _cele, _fail, _slap, _ping, _land,
		idle_time, hr.x, hr.y, hr.z, fl.x, fl.y, fl.z]


## 0..1 envelope of a countdown timer: ramps in over fade_in s after it starts, out over the last fade_out s.
static func _env(left: float, dur: float, fade_in: float, fade_out: float) -> float:
	if left <= 0.0:
		return 0.0
	return clampf(minf((dur - left) / fade_in, left / fade_out), 0.0, 1.0)
