class_name ChefAnim
extends RefCounted
## Procedural chef animator (rig v2 + arms, no skeleton). The owner (Chef, a dev preview, a turntable) fills
## `state` every frame and calls update(dt); ChefAnim poses the chef.glb parts: the model root (bob, step
## squash, hops, spins, fall flail), Body (hips pivot: lean, twist, sway, breathing), Head (neck: aim lead,
## look-around, nods), Eyes (blink), Brows, Mouth, HandL/HandR (hand centre), FootL/FootR (ankle) with LegL/LegR
## aimed at the hips, ArmL/ArmR (shoulder: UpperArm, Forearm, Cuff aimed shoulder -> elbow -> wrist with a
## two-bone bend, stretching past full reach), Toque + HatAnchor (hat pops off in a fall). Missing parts are
## skipped (primitive chef, older glb).
## Readable at game distance: big bob with squash and stretch per step, long strides with visible foot lift,
## spring-driven lean and turn roll (overshoot, then settle), distinct heavy (leaning back, short quick steps,
## straining elbows, waddle) and light (chest up, springy) carries, overhead chop, wind-up punch, double-hop
## celebration (a spin for a VIP), comedic fall, idle fidgets (foot tap, brow wipe, look around).
## Every input is something a puppet knows as well (observed motion, replicated flags + held item, Net
## events), so the same code animates every chef on every peer; look_yaw is optional (only owners that know
## the aim fill it). Cheap: trig and a few Basis builds per frame, no allocations.
## Body shapes: static shape(model, id) (GameData.BODY_SHAPES) sets the rest pose the animator works from;
## call refresh_rest() after it.

signal step(side: int)  ## a foot planted while walking (0 = FootL at +X, 1 = FootR): footstep dust hook
signal skid             ## hard direction change at speed: skid puff hook
signal sweat            ## straining under food too heavy for the crew (about once a second): sweat-drop hook

enum Work { NONE, CHOP, DISPENSE, BELL, SODA }
enum Fidget { NONE, TAP, WIPE, LOOK }

const PARTS := ["Body", "Head", "HandL", "HandR", "FootL", "FootR", "LegL", "LegR"]
const LEG_LEN := 0.13      # ankle to hip (chef.glb), the part LegL/LegR stretch
const SLEEVE_X := 0.283    # old sleeve end; hand rest x is measured from it (body shapes)
const SHOULDER := Vector3(0.19, 0.41, 0.0)  # Body-local arm root (x sign per side) = characters.py PIV_SHOULDER
const HIP := Vector3(0.13, 0.0, 0.005)      # Body-local top of the legs (x sign per side)
const ARM_SEG := 0.08      # authored UpperArm / Forearm length (characters.py ARM_SEG)
const WRIST_OFF := 0.075   # cuff centre to hand centre at hand scale 1 (characters.py WRIST_OFF)
const ARM_SLACK := 1.1     # segment length = ARM_SLACK x half the rest shoulder-wrist reach: a slight elbow at rest
const PUNCH_DUR := 0.42
const TOSS_DUR := 0.35
const SLAP_DUR := 0.42
const CELE_DUR := 1.4
const FAIL_DUR := 1.5
const PING_DUR := 1.0
const LAND_DUR := 0.5
const FIDGET_AFTER := 3.0  # s idle before fidgets start
const FIDGET_DUR := [0.0, 1.7, 1.6, 2.2]

# amplitudes (game camera ~17 m away; v1 values in brackets)
const BOB := 0.11          # m, root bob per step at full walk [0.06]
const SQUASH := 0.07       # y scale squash at foot contact / stretch at the passing pose [0]
const STRIDE := 0.16       # m, foot travel either side [0.10]
const LIFT := 0.12         # m, swing foot lift [0.07]
const WALK_LEAN := 0.2     # rad forward lean at full speed [0.14]
const ACC_LEAN := 0.3      # rad lean into acceleration / braking, spring overshoot [0.14, no spring]
const TURN_ROLL := 0.35    # rad roll into turns (cap) [0.22]
const SWAY := 0.1          # rad side sway per step [0.06]
const TWIST := 0.16        # rad hip twist per step [0.08]
const HAND_SWING := 0.16   # m hand swing fore/aft [0.09]


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
	var has_look := false          ## look_yaw is known (the owner knows this chef's aim: host sim, local player)
	var look_yaw := 0.0            ## where the chef is about to face, relative to its yaw (rad): the head leads
	var toss := false              ## pulse: let go of food
	var celebrate := false         ## pulse: an order was served
	var vip := false               ## pulse: a VIP order was paid (celebration with a spin)
	var fail := false              ## pulse: something failed (expired order, burnt food, fine)
	var slap := false              ## pulse: this chef rang the bell
	var ping := false              ## pulse: this chef pinged ping_dir
	var ping_dir := Vector3(0, 0, 1)  ## chef space, horizontal


var state := State.new()
var idle_time := 0.0  ## s standing still with nothing to do (drives look-around and fidgets)
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
var _leg_l: Node3D
var _leg_r: Node3D
var _arm_l: Node3D
var _arm_r: Node3D
var _up_l: Node3D
var _up_r: Node3D
var _fo_l: Node3D
var _fo_r: Node3D
var _cu_l: Node3D
var _cu_r: Node3D
var _toque: Node3D
var _hat_anchor: Node3D
var _toque_pos := Vector3.ZERO
var _hat_pos := Vector3.ZERO
var _body_pos := Vector3.ZERO
var _body_scale := Vector3.ONE
var _hand_rest_l := Vector3.ZERO
var _hand_rest_r := Vector3.ZERO
var _foot_rest_l := Transform3D.IDENTITY
var _foot_rest_r := Transform3D.IDENTITY
var _eyes_scale := Vector3.ONE
var _mouth_scale := Vector3.ONE
var _brows_pos := Vector3.ZERO
var _arm_seg_l := ARM_SEG
var _arm_seg_r := ARM_SEG
var _arm_th := Vector3.ONE     # upper thickness, forearm thickness, hand scale (meta rig_arm)
var _leg_scale := 1.0

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
var _w_heavy := 0.0
var _w_work := 0.0
var _w_fall := 0.0
var _strain := 0.0
var _lean := 0.0      # spring part of the body lean (locomotion, carry, slump)
var _lean_v := 0.0
var _roll := 0.0      # spring part of the body roll (turns, sideways acceleration)
var _roll_v := 0.0
var _lean_total := 0.0
var _punch := 0.0
var _toss := 0.0
var _slap := 0.0
var _cele := 0.0
var _spin := false
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
var _fid := 0.0
var _fid_kind := 0  # Fidget
var _fid_cd := 0.0
var _hat_y := 0.0
var _hat_v := 0.0
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
	_fid_cd = _rng.randf_range(0.0, 2.0)
	if model == null:
		return
	_root_rest = model.transform
	_body = _find("Body")
	_head = _find("Head")
	_eyes = _find("Eyes")
	_brows = _find("Brows")
	_mouth = _find("Mouth")
	_hand_l = _find("HandL")
	_hand_r = _find("HandR")
	_foot_l = _find("FootL")
	_foot_r = _find("FootR")
	_leg_l = _find("LegL")
	_leg_r = _find("LegR")
	_arm_l = _find("ArmL")
	_arm_r = _find("ArmR")
	_up_l = _find("UpperArmL")
	_up_r = _find("UpperArmR")
	_fo_l = _find("ForearmL")
	_fo_r = _find("ForearmR")
	_cu_l = _find("CuffL")
	_cu_r = _find("CuffR")
	_toque = _find("Toque")
	_hat_anchor = _find("HatAnchor")
	if _toque != null:
		_toque_pos = _toque.position
	if _hat_anchor != null:
		_hat_pos = _hat_anchor.position
	if _eyes != null:
		_eyes_scale = _eyes.scale
	if _mouth != null:
		_mouth_scale = _mouth.scale
	if _brows != null:
		_brows_pos = _brows.position
	refresh_rest()


func _find(n: String) -> Node3D:
	return model.find_child(n, true, false) as Node3D


## Re-read the rest pose (after shape() changed the body shape).
func refresh_rest() -> void:
	if model == null:
		return
	var rest: Dictionary = model.get_meta("rig_rest") if model.has_meta("rig_rest") else {}
	var bt := Transform3D.IDENTITY
	if _body != null:
		bt = rest.get("Body", _body.transform)
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
	if _leg_l != null:
		_leg_scale = (rest.get("LegL", _leg_l.transform) as Transform3D).basis.get_scale().y
	_arm_th = model.get_meta("rig_arm") if model.has_meta("rig_arm") else Vector3.ONE
	_arm_seg_l = _arm_seg(bt * Vector3(SHOULDER.x, SHOULDER.y, SHOULDER.z), _hand_rest_l, _arm_th.z)
	_arm_seg_r = _arm_seg(bt * Vector3(-SHOULDER.x, SHOULDER.y, SHOULDER.z), _hand_rest_r, _arm_th.z)


## Apply a GameData.BODY_SHAPES entry to a chef.glb instance: scales Body, Head, hands, feet and legs, keeps
## the soles on the ground and the head/hands attached, sets the arm thickness (meta "rig_arm") and poses the
## arms at rest. Stores the rest pose as meta "rig_rest" (the animator's base) and the untouched glb pose as
## "rig_base". Anchors are children of the parts, so attached hats/beards/back items follow. No-op on models
## without a Body (primitive chef).
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
	# arm thickness: the upper arm follows the build, the forearm the hands (big_arms = Popeye forearms)
	var th := Vector3(pow(b.x, 0.6) * pow(hs, 0.45), pow(b.x, 0.4) * pow(hs, 0.9), hs)
	chef_model.set_meta("rig_arm", th)
	var body_rest: Transform3D = rest["Body"]
	for i in 2:
		var sfx := "L" if i == 0 else "R"
		var side := 1.0 if i == 0 else -1.0
		var arm := chef_model.find_child("Arm" + sfx, true, false) as Node3D
		if arm == null or not rest.has("Hand" + sfx):
			continue
		var s := body_rest * Vector3(side * SHOULDER.x, SHOULDER.y, SHOULDER.z)
		var hp: Vector3 = (rest["Hand" + sfx] as Transform3D).origin
		pose_arm(arm, chef_model.find_child("UpperArm" + sfx, true, false) as Node3D,
			chef_model.find_child("Forearm" + sfx, true, false) as Node3D,
			chef_model.find_child("Cuff" + sfx, true, false) as Node3D,
			s, hp, Vector3(side * 0.75, -0.25, -0.6), _arm_seg(s, hp, hs), th)


## Segment length (UpperArm = Forearm) for a shoulder s and hand rest h: a slight elbow at rest.
static func _arm_seg(s: Vector3, h: Vector3, hs: float) -> float:
	var w := h - (h - s).normalized() * WRIST_OFF * hs
	return maxf(0.03, s.distance_to(w) * 0.5 * ARM_SLACK)


## Pose one arm (model space): shoulder s, hand centre h, elbow pushed towards pole (chef space), segment
## length seg (both), th = (upper thickness, forearm thickness, hand scale). Out of reach: both segments
## stretch (and thin a little) instead of the hand leaving the cuff.
static func pose_arm(arm: Node3D, up: Node3D, fo: Node3D, cu: Node3D, s: Vector3, h: Vector3, pole: Vector3,
		seg: float, th: Vector3) -> void:
	if arm == null:
		return
	var hd := h - s
	var hl := hd.length()
	var dir := hd / hl if hl > 0.0001 else Vector3.DOWN
	var w := h - dir * WRIST_OFF * th.z
	var v := w - s
	var d := v.length()
	if d < 0.0001:
		v = Vector3.DOWN * 0.01
		d = 0.01
	var vd := v / d
	var perp := pole - vd * pole.dot(vd)
	if perp.length_squared() < 0.0001:
		perp = Vector3(0, 0, -1) - vd * vd.z
	perp = perp.normalized()
	var e: Vector3
	var len := seg
	var thin := 1.0
	if d < 2.0 * seg:
		var x := d * 0.5
		e = s + vd * x + perp * sqrt(maxf(seg * seg - x * x, 0.0))
	else:
		len = d * 0.5
		thin = clampf(1.0 / sqrt(len / seg), 0.72, 1.0)
		e = s + vd * len + perp * 0.008
	arm.transform = Transform3D(Basis.IDENTITY, s)
	if up != null:
		up.transform = Transform3D(_seg_basis((e - s).normalized(), len / ARM_SEG, th.x * thin), Vector3.ZERO)
	var fd := (w - e).normalized()
	if fo != null:
		fo.transform = Transform3D(_seg_basis(fd, len / ARM_SEG, th.y * thin), e - s)
	if cu != null:
		cu.transform = Transform3D(_seg_basis(fd, 1.0, th.y), w - s)


## Basis whose -Y runs along dir (unit), Y scaled by len_scale, X/Z by thick. Segments are round: any spin is fine.
static func _seg_basis(dir: Vector3, len_scale: float, thick: float) -> Basis:
	var y := -dir
	var ref := Vector3(0, 0, 1) if absf(y.z) < 0.9 else Vector3(1, 0, 0)
	var x := ref.cross(y).normalized()
	var z := x.cross(y)
	return Basis(x * thick, y * len_scale, z * thick)


func update(dt: float) -> void:
	if model == null or dt <= 0.0:
		return
	var s := state
	_t += dt
	var ds := minf(dt, 0.04)  # spring step (stable at low frame rates)
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
	var hv := 0.0     # heavy food (weight 2+): leaning back, short quick steps
	var short := 0.0  # under-staffed: strain
	if s.carrying:
		hv = clampf(float(s.weight - 1) / 2.0, 0.0, 1.0)
		short = clampf(float(s.weight - s.carriers) / 2.0, 0.0, 1.0)
	var k_w := 1.0 - exp(-10.0 * dt)
	_w_carry = lerpf(_w_carry, 1.0 if s.carrying else 0.0, k_w)
	_w_heavy = lerpf(_w_heavy, hv, k_w)
	var w_light := maxf(0.0, _w_carry - _w_heavy)
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
	if s.celebrate or s.vip:
		if _cele <= 0.0 or CELE_DUR - _cele > 0.5:
			_cele = CELE_DUR
			_spin = s.vip
		elif s.vip:
			_spin = true
	if s.fail:
		_fail = FAIL_DUR
	if s.ping:
		_ping = PING_DUR
		_ping_dir = Vector3(s.ping_dir.x, 0.0, s.ping_dir.z)
		_ping_dir = _ping_dir.normalized() if _ping_dir.length_squared() > 0.0001 else Vector3(0, 0, 1)
	if _vy_prev < -2.0 and s.vy > -0.5 and s.vy < 1.5 and not s.falling:
		_land = LAND_DUR
		_land_amp = clampf(-_vy_prev / 7.0, 0.35, 1.0)
		_hat_v += 1.4 * _land_amp   # the hat pops on the landing and settles back
	_vy_prev = s.vy
	s.toss = false
	s.slap = false
	s.celebrate = false
	s.vip = false
	s.fail = false
	s.ping = false
	_punch = maxf(0.0, _punch - dt)
	_toss = maxf(0.0, _toss - dt)
	_slap = maxf(0.0, _slap - dt)
	_cele = maxf(0.0, _cele - dt)
	_fail = maxf(0.0, _fail - dt)
	_ping = maxf(0.0, _ping - dt)
	_land = maxf(0.0, _land - dt)
	var e_cele := _env(_cele, CELE_DUR, 0.08, 0.3) * (1.0 - _w_carry)
	var e_fail := _env(_fail, FAIL_DUR, 0.25, 0.4)
	var e_ping := _env(_ping, PING_DUR, 0.12, 0.3) * (1.0 - _w_carry)
	var e_toss := _env(_toss, TOSS_DUR, 0.06, 0.2)
	var busy := s.carrying or s.working or s.falling or _punch > 0.0 or _cele > 0.0 or _fail > 0.0 or _ping > 0.0
	idle_time = idle_time + dt if sp < 0.05 and not busy else 0.0
	# ---- idle life: blink, look-around, fidgets
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
	if idle_time > FIDGET_AFTER:
		_fid_cd -= dt
		if _fid_cd <= 0.0 and _fid <= 0.0:
			_fid_kind = _rng.randi_range(Fidget.TAP, Fidget.LOOK)
			_fid = FIDGET_DUR[_fid_kind]
			_fid_cd = _fid + _rng.randf_range(2.0, 4.5)
	elif idle_time <= 0.0:
		_fid = 0.0
		_fid_cd = minf(_fid_cd, 1.0)
	_fid = maxf(0.0, _fid - dt)
	var fid_dur: float = FIDGET_DUR[_fid_kind]
	var e_fid := _env(_fid, fid_dur, 0.25, 0.3) if _fid > 0.0 else 0.0
	var fid_t := fid_dur - _fid
	var e_tap := e_fid if _fid_kind == Fidget.TAP else 0.0
	var e_wipe := e_fid if _fid_kind == Fidget.WIPE else 0.0
	var e_look := e_fid if _fid_kind == Fidget.LOOK else 0.0
	# ---- walk cycle: heavy food = short quick steps
	_phase = fmod(_phase + dt * (4.0 + 12.0 * _cadence) * (1.0 + 0.7 * _w_heavy), TAU)
	var sn := sin(_phase)
	var cs := cos(_phase)
	var q := (1.0 - 2.0 * absf(cs)) * w_move   # +1 at foot contact (squash), -1 passing (stretch)
	var breath := sin(_t * 2.4)
	# ---- chop rhythm (2 Hz): slow raise overhead, fast strike, hold
	var ct := fmod(_t * 2.0, 1.0)
	var chop := 0.0   # hand height 0..1
	var imp := 0.0    # impact pulse
	if ct < 0.42:
		chop = smoothstep(0.0, 1.0, ct / 0.42)
	elif ct < 0.56:
		chop = 1.0 + 0.06 * sin(PI * (ct - 0.42) / 0.14)   # hang at the top (anticipation)
	elif ct < 0.66:
		var k := (ct - 0.56) / 0.1
		chop = 1.0 - k * k
	else:
		imp = clampf(1.0 - (ct - 0.66) / 0.2, 0.0, 1.0)
	var w_chop := _w_work if s.work_kind == Work.CHOP else 0.0
	var pull := 0.5 + 0.5 * sin(_t * 6.0)
	var p_punch := 1.0 - _punch / PUNCH_DUR if _punch > 0.0 else 1.0
	# ---- root (whole figure): bob + step squash, hops, spins, punch lunge, fall flail
	var bob_amp := BOB * lerpf(sp, w_move, 0.5) * lerpf(1.0, 0.4, _w_heavy) * (1.0 + 0.35 * w_light)
	var fig_y := absf(cs) * bob_amp
	var sq := SQUASH * q * lerpf(1.0, 0.6, _w_heavy)
	var fig_rot := Vector3.ZERO
	var fig_scale := Vector3(1.0 + 0.5 * sq, 1.0 - sq, 1.0 + 0.5 * sq)
	var lunge := 0.0
	if _cele > 0.0 and not s.carrying:
		var tt := CELE_DUR - _cele
		if tt < 0.07:
			fig_scale = Vector3(1.08, 0.86, 1.08)
		elif tt < 0.47:
			var hop := sin(PI * (tt - 0.07) / 0.4)
			fig_y += 0.34 * hop
			fig_scale = Vector3(1.0 - 0.06 * hop, 1.0 + 0.1 * hop, 1.0 - 0.06 * hop)
		elif tt < 0.55:
			var l1 := sin(PI * (tt - 0.47) / 0.08)
			fig_scale = Vector3(1.0 + 0.07 * l1, 1.0 - 0.12 * l1, 1.0 + 0.07 * l1)
		elif tt < 0.87:
			var hop2 := sin(PI * (tt - 0.55) / 0.32)
			fig_y += 0.22 * hop2
			fig_scale = Vector3(1.0 - 0.05 * hop2, 1.0 + 0.08 * hop2, 1.0 - 0.05 * hop2)
		elif tt < 0.97:
			var l2 := sin(PI * (tt - 0.87) / 0.1)
			fig_scale = Vector3(1.0 + 0.06 * l2, 1.0 - 0.1 * l2, 1.0 + 0.06 * l2)
		if _spin:
			fig_rot.y = TAU * smoothstep(0.07, 0.87, tt)
		else:
			fig_rot.y = sin(tt * 9.0) * 0.2 * e_cele
	if _land > 0.0:
		var tl := LAND_DUR - _land
		var lq := _land_amp * exp(-8.0 * tl) * cos(22.0 * tl)
		fig_scale *= Vector3(1.0 + 0.18 * lq, 1.0 - 0.28 * lq, 1.0 + 0.18 * lq)
	if _punch > 0.0:
		if p_punch < 0.32:
			fig_scale *= Vector3.ONE.lerp(Vector3(1.03, 0.94, 1.03), p_punch / 0.32)
		elif p_punch < 0.62:
			lunge = 0.07 * sin(PI * clampf((p_punch - 0.32) / 0.3, 0.0, 1.0))
			fig_scale *= Vector3(0.98, 1.05, 0.98)
	fig_scale.y *= 1.0 - 0.05 * imp * w_chop
	fig_rot += Vector3(sin(_t * 7.0) * 0.5, 0.0, cos(_t * 9.0) * 0.42) * _w_fall
	model.transform = _root_rest * Transform3D(Basis.from_euler(fig_rot) * Basis.from_scale(fig_scale), Vector3(0, fig_y, lunge))
	# ---- body lean: a spring (overshoot, then settle) for locomotion, carry posture, slump; direct for rhythms
	var lean := WALK_LEAN * sp + clampf(_acc.z / 45.0, -1.0, 1.0) * ACC_LEAN
	var carry_lean := lerpf(-0.06 + 0.04 * sp, -(0.24 + 0.12 * short) - 0.06 * sp, _w_heavy / maxf(_w_carry, 0.001))
	lean = lerpf(lean, carry_lean, _w_carry)
	if _w_work > 0.01:
		var wl := 0.1
		match s.work_kind:
			Work.CHOP:
				wl = 0.12
			Work.DISPENSE:
				wl = 0.06
			Work.SODA:
				wl = 0.02
		lean = lerpf(lean, wl, _w_work)
	lean += 0.36 * e_fail + 0.08 * e_wipe
	_lean_v += ((lean - _lean) * 170.0 - _lean_v * 14.0) * ds
	_lean += _lean_v * ds
	var lean_fx := 0.0   # direct (fast) lean
	var twist := sn * TWIST * sp
	lean_fx += (0.14 - 0.34 * chop) * w_chop
	twist += -0.14 * chop * w_chop
	if _w_work > 0.01 and s.work_kind == Work.DISPENSE:
		lean_fx += -0.12 * pull * _w_work
	if _punch > 0.0:
		if p_punch < 0.32:
			var kw := smoothstep(0.0, 1.0, p_punch / 0.32)
			twist += -0.6 * kw
			lean_fx += -0.12 * kw
		elif p_punch < 0.48:
			var ks := (p_punch - 0.32) / 0.16
			twist += lerpf(-0.6, 0.5, ks)
			lean_fx += lerpf(-0.12, 0.28, ks)
		elif p_punch < 0.62:
			twist += 0.5
			lean_fx += 0.28
		else:
			var kr := smoothstep(0.0, 1.0, (p_punch - 0.62) / 0.38)
			twist += lerpf(0.5, 0.0, kr)
			lean_fx += lerpf(0.28, 0.0, kr)
	lean_fx += 0.16 * e_toss - 0.12 * e_cele
	twist += sin(fid_t * 2.6) * 0.18 * e_look
	_lean_total = _lean + lean_fx
	var roll_t := -clampf(s.turn_rate * sp * 0.07, -TURN_ROLL, TURN_ROLL) - clampf(_acc.x / 45.0, -1.0, 1.0) * 0.16
	_roll_v += ((roll_t - _roll) * 150.0 - _roll_v * 13.0) * ds
	_roll += _roll_v * ds
	var roll := _roll + sn * SWAY * sp + sn * 0.12 * _w_heavy * w_move   # heavy: waddle
	roll += sin(_t * 23.0) * 0.045 * _strain
	var body_y := 0.02 * absf(cs) * w_move - 0.045 * e_fail - 0.04 * _w_heavy - 0.03 * imp * w_chop
	if _punch > 0.0 and p_punch < 0.4:
		body_y -= 0.03 * sin(PI * p_punch / 0.4)
	if _body != null:
		_body.position = _body_pos + Vector3(0, body_y, 0)
		_body.rotation = Vector3(_lean_total, twist, roll)
		_body.scale = _body_scale * Vector3(1.0 - 0.006 * breath, 1.0 + 0.016 * breath, 1.0 - 0.006 * breath)
	# ---- head: steadies against the lean, leads the aim / turns, looks around when idle, nods per step
	if _head != null:
		var hp := _look_pitch - 0.45 * _lean_total + 0.07 * q + 0.22 * _w_heavy - 0.1 * w_light
		var lead := clampf(s.turn_rate * 0.08, -0.5, 0.5)
		if s.has_look and not s.carrying:
			lead += clampf(s.look_yaw, -1.2, 1.2) * 0.75
		var hy := clampf(_look_yaw + lead, -1.0, 1.0)
		var hr := sin(_t * 17.0) * 0.05 * _strain + sin(_t * 15.0) * 0.14 * e_cele
		if _w_work > 0.01:
			var wp := 0.15
			match s.work_kind:
				Work.CHOP:
					wp = 0.34 - 0.18 * chop
				Work.SODA:
					wp = -0.08
			hp = lerpf(hp, wp, _w_work)
		hp += -0.3 * e_cele + 0.42 * e_fail + 0.3 * _w_fall * sin(_t * 11.0) - 0.18 * e_wipe + 0.12 * e_tap
		hy = lerpf(hy, sin(fid_t * 2.6) * 0.85, e_look)
		hr += 0.12 * e_tap * sin(fid_t * 3.0)
		if e_ping > 0.0:
			hy = lerpf(hy, clampf(atan2(_ping_dir.x, _ping_dir.z), -0.9, 0.9), e_ping)
		_head_rot = _head_rot.lerp(Vector3(hp, hy, hr), 1.0 - exp(-14.0 * dt))
		_head.rotation = _head_rot
	# ---- hat: pops up in a fall, lands back with a bounce
	_hat_v += ((0.14 * _w_fall - _hat_y) * 140.0 - _hat_v * 9.0) * ds
	_hat_y = maxf(-0.015, _hat_y + _hat_v * ds)
	var hat_off := Vector3(0, _hat_y, 0)
	if _toque != null:
		_toque.position = _toque_pos + hat_off
	if _hat_anchor != null:
		_hat_anchor.position = _hat_pos + hat_off
	# ---- face: blink, squint, happy eyes, frown, gasp, brows
	if _eyes != null:
		var ey := 0.1
		if _blink <= 0.0:
			ey = lerpf(1.0, 0.65, _strain)
			ey = lerpf(ey, 0.8, e_fail)
			ey = lerpf(ey, 0.42, e_cele)
			ey = lerpf(ey, 0.5, e_wipe)
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
	var common := Vector3(0, body_y + 0.006 * breath, _lean_total * 0.26 * (1.0 - _w_carry))
	var fast := _punch > 0.0 or _slap > 0.0 or w_chop > 0.5
	var kh := 1.0 - exp(-(40.0 if fast else 22.0) * dt)
	var carry_comp := Vector3(0, -fig_y * _w_carry, 0)
	if _hand_l != null:
		_hand_l.position = _hand_l.position.lerp(_hand_target(0, _hand_rest_l + common, sn, q, w_move, chop, pull, e_toss, e_cele,
			e_fail, e_ping, e_tap, e_wipe, fid_t, p_punch) + carry_comp, kh)
	if _hand_r != null:
		_hand_r.position = _hand_r.position.lerp(_hand_target(1, _hand_rest_r + common, sn, q, w_move, chop, pull, e_toss, e_cele,
			e_fail, e_ping, e_tap, e_wipe, fid_t, p_punch) + carry_comp, kh)
	# ---- arms: shoulder (on the posed Body) -> elbow -> wrist at the hand
	if _body != null:
		var bx := _body.transform
		var pole_out := 0.75 + 0.55 * _w_heavy + 0.3 * _w_fall
		if _arm_l != null and _hand_l != null:
			pose_arm(_arm_l, _up_l, _fo_l, _cu_l, bx * Vector3(SHOULDER.x, SHOULDER.y, SHOULDER.z), _hand_l.position,
				Vector3(pole_out, -0.25, -0.6), _arm_seg_l, _arm_th)
		if _arm_r != null and _hand_r != null:
			pose_arm(_arm_r, _up_r, _fo_r, _cu_r, bx * Vector3(-SHOULDER.x, SHOULDER.y, SHOULDER.z), _hand_r.position,
				Vector3(-pole_out, -0.25, -0.6), _arm_seg_r, _arm_th)
	# ---- feet: step along the move direction, lift in the swing, kick when falling, tap when bored
	var stride := STRIDE * w_move * lerpf(1.0, 0.45, _w_heavy)
	var lift := LIFT * w_move * lerpf(1.0, 0.55, _w_heavy)
	if _foot_l != null:
		_foot_l.transform = _foot_pose(_foot_rest_l, 0, sn, cs, stride, lift, w_move, 0.0, fid_t)
	if _foot_r != null:
		_foot_r.transform = _foot_pose(_foot_rest_r, 1, -sn, -cs, stride, lift, w_move, e_tap, fid_t)
	# legs: from the ankle up to the hips (they tilt and stretch with the stride instead of sliding)
	if _body != null:
		var bx2 := _body.transform
		if _leg_l != null and _foot_l != null:
			_leg_l.transform = _leg_pose(_foot_l.transform, bx2 * Vector3(HIP.x, HIP.y + 0.02, HIP.z))
		if _leg_r != null and _foot_r != null:
			_leg_r.transform = _leg_pose(_foot_r.transform, bx2 * Vector3(-HIP.x, HIP.y + 0.02, HIP.z))
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
func _hand_target(i: int, r: Vector3, sn: float, q: float, w_move: float, chop: float, pull: float,
		e_toss: float, e_cele: float, e_fail: float, e_ping: float, e_tap: float, e_wipe: float, fid_t: float,
		p_punch: float) -> Vector3:
	var s := state
	var side := 1.0 if i == 0 else -1.0
	var h := r + Vector3(side * 0.03 * w_move, 0.05 * absf(sn) * w_move - 0.015 * q, -sn * side * HAND_SWING * w_move)
	if e_tap > 0.0:   # hands on the hips, impatient
		h = h.lerp(r + Vector3(-side * 0.02, -0.06, -0.07), e_tap)
	if e_wipe > 0.0 and i == 1 and _head != null:
		# right hand to the forehead, a sweep across, then down
		var fh: Vector3 = _body.transform * _head.position + Vector3(0.0, 0.16, 0.27) if _body != null else r + Vector3(0.3, 0.45, 0.2)
		fh.x += lerpf(-0.14, 0.12, smoothstep(0.35, 1.2, fid_t))
		h = h.lerp(fh, e_wipe)
	if _w_work > 0.01:
		var w := r + Vector3(0, 0.15 + sin(_t * 30.0 + i * PI) * 0.18, 0.3)
		match s.work_kind:
			Work.CHOP:
				# knife hand: from the board up over the head (out to the side, clear of the face) and down
				w = r + (Vector3(0.06 - 0.16 * chop, 0.04 + 0.9 * chop, 0.32 - 0.1 * chop) if i == 1 else Vector3(-0.1, 0.04, 0.28))
			Work.DISPENSE:
				w = r + Vector3(-side * 0.06, 0.15 + 0.06 * pull, 0.46 - 0.18 * pull)
			Work.SODA:
				var press := pow(sin(_t * 4.0), 2.0)
				w = r + (Vector3(0.08, 0.3 - 0.1 * press, 0.4) if i == 1 else Vector3(-0.06, 0.04, 0.32))
		h = h.lerp(w, _w_work)
	if _w_carry > 0.01:
		var shake := sin(_t * 31.0 + i * 1.7) * (0.014 * _strain + 0.006 * _w_heavy)
		var bounce := -0.012 * q * maxf(0.0, _w_carry - _w_heavy)  # light carry: springy hands
		h = h.lerp(r + s.hold + Vector3(0, shake + bounce, 0), _w_carry)
	if e_ping > 0.0 and i == (0 if _ping_dir.x >= 0.0 else 1):
		h = h.lerp(Vector3(r.x * 0.7, r.y + 0.34, r.z) + _ping_dir * 0.45, e_ping)
	if _punch > 0.0:
		if i == 1:
			var wind := r + Vector3(-0.1, 0.16, -0.32)
			var hit := r + Vector3(0.16, 0.22, 0.82)
			if p_punch < 0.32:
				h = h.lerp(wind, smoothstep(0.0, 1.0, p_punch / 0.32))
			elif p_punch < 0.48:
				h = wind.lerp(hit, (p_punch - 0.32) / 0.16)
			elif p_punch < 0.62:
				h = hit
			else:
				h = hit.lerp(h, smoothstep(0.0, 1.0, (p_punch - 0.62) / 0.38))
		else:  # guard up
			h = h.lerp(r + Vector3(-0.07, 0.2, 0.2), _env(_punch, PUNCH_DUR, 0.06, 0.15))
	if e_toss > 0.0:
		h += Vector3(0, 0.38, 0.42) * e_toss
	if _slap > 0.0 and i == 1:
		var ts := SLAP_DUR - _slap
		var up := r + Vector3(0.1, 0.5, 0.3)
		var down := r + Vector3(0.1, 0.1, 0.4)
		if ts < 0.16:
			h = h.lerp(up, ts / 0.16)
		elif ts < 0.24:
			h = up.lerp(down, (ts - 0.16) / 0.08)
		else:
			h = down.lerp(h, (ts - 0.24) / (SLAP_DUR - 0.24))
	if not s.carrying:
		if e_cele > 0.0:
			h = h.lerp(r + Vector3(side * 0.24, 0.72 + 0.07 * sin(_t * 22.0 + i * PI), -0.02), e_cele)
		if e_fail > 0.0:
			h = h.lerp(r + Vector3(-side * 0.05, -0.12, 0.08), e_fail)
	if _w_fall > 0.01:
		h = h.lerp(r + Vector3(side * 0.36, 0.34 + 0.16 * sin(_t * 19.0 + i * PI), 0.08 * cos(_t * 17.0)), _w_fall)
	return h


func _foot_pose(rest: Transform3D, i: int, fs: float, fc: float, stride: float, lift: float, w_move: float,
		e_tap: float, fid_t: float) -> Transform3D:
	var off := _dir * fs * stride
	off.y = maxf(0.0, fc) * lift
	var pitch := -0.45 * w_move * fs * _dir.z
	if e_tap > 0.0:   # toe taps (heel down)
		var tap := maxf(0.0, sin(fid_t * 14.0))
		pitch -= 0.5 * tap * e_tap
		off.z += 0.04 * e_tap
	if _w_fall > 0.01:
		var k := sin(_t * 15.0 + i * PI)
		off += Vector3((0.1 if i == 0 else -0.1), 0.08 + 0.05 * k, 0.12 * k) * _w_fall
		pitch += 0.5 * k * _w_fall
	return Transform3D(Basis(Vector3.RIGHT, pitch) * rest.basis, rest.origin + off)


## LegL/LegR (child of the foot, origin at the ankle, mesh along +Y, LEG_LEN long) aimed at the hip point
## (model space) and stretched to reach it.
func _leg_pose(foot: Transform3D, hip: Vector3) -> Transform3D:
	var v := foot.affine_inverse() * hip
	var l := v.length()
	if l < 0.001:
		return Transform3D(Basis.from_scale(Vector3(1.0, _leg_scale, 1.0)), Vector3.ZERO)
	var y := v / l
	var x := (Vector3(1, 0, 0) - y * y.x).normalized()
	var z := x.cross(y)
	return Transform3D(Basis(x, y * (l / LEG_LEN), z), Vector3.ZERO)


## One line for --anim-log: smoothed speed, walk phase, state weights, active one-shots, hand/foot offsets.
func debug_line() -> String:
	var hr := (_hand_r.position - _hand_rest_r) if _hand_r != null else Vector3.ZERO
	var fl := (_foot_l.position - _foot_rest_l.origin) if _foot_l != null else Vector3.ZERO
	var el := (_fo_r.position.length()) if _fo_r != null else 0.0
	return "speed=%.2f phase=%.2f carry=%.2f heavy=%.2f work=%.2f(%d) fall=%.2f strain=%.2f lean=%.2f punch=%.2f cele=%.2f%s fail=%.2f slap=%.2f ping=%.2f land=%.2f idle=%.1f fidget=%d handR=(%.2f,%.2f,%.2f) footL=(%.2f,%.2f,%.2f) upperR=%.2f hat=%.2f" % [
		_speed, _phase, _w_carry, _w_heavy, _w_work, state.work_kind, _w_fall, _strain, _lean_total, _punch, _cele,
		"(spin)" if _spin and _cele > 0.0 else "", _fail, _slap, _ping, _land, idle_time, _fid_kind if _fid > 0.0 else 0,
		hr.x, hr.y, hr.z, fl.x, fl.y, fl.z, el, _hat_y]


## 0..1 envelope of a countdown timer: ramps in over fade_in s after it starts, out over the last fade_out s.
static func _env(left: float, dur: float, fade_in: float, fade_out: float) -> float:
	if left <= 0.0:
		return 0.0
	return clampf(minf((dur - left) / fade_in, left / fade_out), 0.0, 1.0)
