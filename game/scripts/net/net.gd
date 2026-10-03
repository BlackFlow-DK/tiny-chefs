extends Node
## Autoload "Net": the ENet session, player registry, game phase, command-line args and test hooks.
## Host-authoritative: clients send inputs, the host simulates and broadcasts snapshots.
## All RPCs live here (the autoload exists at the same path on every peer), and are forwarded
## to the World when one exists, so a packet can never target a node that is not there yet.
##
## User args (after "--"): --host --join=<ip> --name=<x> --autostart --players=<n> --bot
##   --bind=<ip> --port=<n> --shift-seconds=<s> --test-report=<json path> --quit-after=<s> --quit-after-shift
##   Game settings (host): --mode=campaign|endless|custom --map=<id> --difficulty=easy|normal|hard|chaos
##   --modifiers=a,b --mission=<n>
##
## Game settings: `settings` (GameSettings) is owned by the host and mirrored read-only on clients.
## Change it with change_setting(key, value) or set_settings(s) (host or offline menu only, MENU/LOBBY
## phase only; clients are ignored). Every change goes to all clients via the _sync_settings RPC, late
## joiners get it on join, and settings_changed fires on every peer.
##
## Chef looks: every players entry also holds "color" (index into GameData.PLAYER_COLORS, default = slot),
## "hat" (GameData.HATS id), "acc" (GameData.ACCESSORIES id), "beard" (BEARDS), "outfit" (OUTFITS), "back"
## (BACKS) and "body" (BODY_SHAPES id); unknown ids fall back to each table's first entry. Each player sets only its own look with
## set_look({...}) (any phase): the host stores it and re-sends the roster via _sync_players; a client
## sends it with _register on join and _request_look afterwards. Read with look_of(id) / color_of(id).
## The local pick (local_look) is the Wardrobe's equipped look, saved in Progress (user://progress.cfg
## [equipped]); args --look=hat:beanie,acc:glasses,body:stout,... and --color= --hat= --acc= ... override.
## Ids are the Cosmetics catalogue (GameData tables = Cosmetics lists).

signal players_changed
signal looks_changed  ## some player's look may have changed (also fires with every roster sync)
signal phase_changed(phase: int)
signal session_ended(reason: String)
signal event_received(text: String, sfx: String)
signal settings_changed

enum Phase { MENU, LOBBY, PLAYING, RESULTS, SHOP }

var phase: int = Phase.MENU
var phase_info: Dictionary = {}
var players: Dictionary = {}  # peer id -> {"name": String, "slot": int, "color": int, "hat", "acc", "beard", "outfit", "back", "body": String}
var local_name := "Chef"
var local_look := {"color": -1, "hat": "toque", "acc": "none", "beard": "moustache", "outfit": "classic", "back": "none", "body": "standard"}  # my pick; color -1 = my slot's colour
## Look keys besides "color" -> the GameData table that validates them (first entry = default).
const LOOK_TABLES := {"hat": GameData.HATS, "acc": GameData.ACCESSORIES, "beard": GameData.BEARDS,
	"outfit": GameData.OUTFITS, "back": GameData.BACKS, "body": GameData.BODY_SHAPES}
var is_host := false
var join_ip := ""
var args: Dictionary = {}
var metrics: Dictionary = {}
var world: Node = null  # the World sets itself here while it exists
var settings := GameSettings.new()  # host-owned game settings; a read-only copy on clients

const JOIN_ATTEMPT_SECONDS := 4.0   # with a retry window open: an attempt still connecting after this restarts
const AUTO_JOIN_RETRY_SECONDS := 60.0   # --join runs keep retrying this long (join_retry_for)

var _ready_peers: Dictionary = {}
var _test_report := ""
var _finished := false
var _join_retry_until := 0   # Time.get_ticks_msec(): failed / unanswered connects retry until then
var _join_attempt := 0


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_parse_args()
	settings = _settings_from_args()
	_load_look()
	Controls.setup()
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	_test_report = arg_str("test-report", "")
	metrics = {"role": "none", "connected": false, "max_chefs_seen": 0, "orders_served": 0,
		"served_recipes": [], "coins_start": -1, "coins_max": 0, "coins_final": 0,
		"patty_solo_speed": 0.0, "patty_duo_speed": 0.0, "patty_duo_seconds": 0.0,
		"shifts_finished": 0, "snapshots": 0}
	if has_arg("quit-after"):
		get_tree().create_timer(arg_float("quit-after", 60.0), true, false, true).timeout.connect(
			func() -> void:
				print("net: --quit-after reached")
				finish_test())


# ---------------------------------------------------------------- args

func _parse_args() -> void:
	for a in OS.get_cmdline_user_args():
		if not a.begins_with("--"):
			continue
		var s := a.substr(2)
		var eq := s.find("=")
		if eq >= 0:
			args[s.substr(0, eq)] = s.substr(eq + 1)
		else:
			args[s] = "true"


func has_arg(key: String) -> bool:
	return args.has(key)


func arg_str(key: String, default: String) -> String:
	return str(args.get(key, default))


func arg_float(key: String, default: float) -> float:
	return float(args[key]) if args.has(key) else default


func arg_int(key: String, default: int) -> int:
	return int(args[key]) if args.has(key) else default


## UDP port: --port=<n> if given, else Tuning.PORT (7777).
func port() -> int:
	return arg_int("port", Tuning.PORT)


## Defaults overridden by --mode= --map= --difficulty= --modifiers=a,b --mission=<n>, validated.
func _settings_from_args() -> GameSettings:
	var s := GameSettings.new()
	s.mode = arg_str("mode", s.mode)
	s.map = arg_str("map", s.map)
	s.difficulty = arg_str("difficulty", s.difficulty)
	if has_arg("modifiers"):
		s.modifiers.assign(Array(arg_str("modifiers", "").split(",", false)))
	s.mission = arg_int("mission", s.mission)
	for f in s.validate():
		print("net: settings arg fixed: %s" % f)
	return s


# ---------------------------------------------------------------- session

func host(pname: String) -> Error:
	leave(false)
	var peer := ENetMultiplayerPeer.new()
	if has_arg("bind"):
		peer.set_bind_ip(arg_str("bind", "*"))
	var err := peer.create_server(port(), Tuning.MAX_PLAYERS - 1)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	is_host = true
	local_name = clean_name(pname)
	players = {1: {"name": local_name, "slot": 0}}
	players[1].merge(resolve_look(local_look, 0), true)
	metrics["role"] = "host"
	metrics["connected"] = true
	print("net: hosting on UDP %d" % port())
	print("net: settings %s" % settings.describe())
	set_phase(Phase.LOBBY, {})
	players_changed.emit()
	return OK


func join(ip: String, pname: String) -> Error:
	leave(false)
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(ip, port())
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	is_host = false
	join_ip = ip
	local_name = clean_name(pname)
	metrics["role"] = "client"
	print("net: connecting to %s:%d" % [ip, port()])
	_join_attempt += 1
	if join_retry_left() > 0.0:
		var a := _join_attempt
		get_tree().create_timer(JOIN_ATTEMPT_SECONDS).timeout.connect(func() -> void:
			if a == _join_attempt and _connecting():
				_retry_join())
	return OK


## --join runs (bots, tests, LAN shortcuts): keep retrying a connect that fails or gets no answer for this
## long. A client started before its host listens (busy machine, many test processes) used to give up after
## one ENet attempt / the menu's 9 s timeout and sit in the menu (balance runs: "never connected").
func join_retry_for(seconds: float) -> void:
	_join_retry_until = Time.get_ticks_msec() + int(seconds * 1000.0)


func join_retry_left() -> float:
	return maxf(0.0, float(_join_retry_until - Time.get_ticks_msec()) / 1000.0)


func _connecting() -> bool:
	var p := multiplayer.multiplayer_peer
	return p is ENetMultiplayerPeer and not is_host and \
		p.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTING


## The player cancelled a join that is still connecting: close the peer and stop any retry (--join window,
## pending attempt timer).
func cancel_join() -> void:
	_join_retry_until = 0
	_join_attempt += 1
	print("net: join to %s:%d cancelled" % [join_ip, port()])
	leave(false)


## A new attempt while the retry window is open (true), else false.
func _retry_join() -> bool:
	if join_retry_left() <= 0.0:
		return false
	print("net: no answer from %s:%d yet, retrying (%.0f s left)" % [join_ip, port(), join_retry_left()])
	join(join_ip, local_name)
	return true


## Close the session and go back to the menu.
func leave(emit := true) -> void:
	var was_client := not is_host and multiplayer.multiplayer_peer is ENetMultiplayerPeer
	if multiplayer.multiplayer_peer != null and not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer):
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	players.clear()
	_ready_peers.clear()
	is_host = false
	if was_client:
		# Drop the last host's settings; our own (args/defaults) apply if we host next.
		settings = _settings_from_args()
		settings_changed.emit()
	if emit:
		_apply_phase(Phase.MENU, {})
		players_changed.emit()


func my_id() -> int:
	return multiplayer.get_unique_id()


func clean_name(n: String) -> String:
	n = n.strip_edges().replace("\n", " ")
	if n.is_empty():
		n = "Chef"
	return n.substr(0, 16)


func lan_addresses() -> PackedStringArray:
	var out := PackedStringArray()
	for a in IP.get_local_addresses():
		if a.contains(":") or a.begins_with("127.") or a.begins_with("169.254.") or a == "0.0.0.0":
			continue
		if not out.has(a):
			out.append(a)
	# Home/office LANs first; 172.x is often a virtual adapter (WSL, Hyper-V, VPN).
	var ranked := Array(out)
	ranked.sort_custom(func(x: String, y: String) -> bool: return _ip_rank(x) < _ip_rank(y))
	return PackedStringArray(ranked)


func _ip_rank(ip: String) -> int:
	if ip.begins_with("192.168."):
		return 0
	if ip.begins_with("10."):
		return 1
	return 2


func _free_slot() -> int:
	var used: Array = []
	for p in players.values():
		used.append(int(p["slot"]))
	for s in Tuning.MAX_PLAYERS:
		if not used.has(s):
			return s
	return 0


func slot_of(id: int) -> int:
	return int(players[id]["slot"]) if players.has(id) else 0


func name_of(id: int) -> String:
	return str(players[id]["name"]) if players.has(id) else "Chef"


func _on_peer_connected(id: int) -> void:
	if is_host:
		print("net: peer %d connected, waiting for registration" % id)


func _on_peer_disconnected(id: int) -> void:
	if not is_host:
		return
	print("net: peer %d left" % id)
	players.erase(id)
	_ready_peers.erase(id)
	_sync_players.rpc(players)
	players_changed.emit()


func _on_connected_to_server() -> void:
	_join_retry_until = 0
	metrics["connected"] = true
	print("net: connected to host, my id %d" % my_id())
	_register.rpc_id(1, local_name, local_look)


func _on_connection_failed() -> void:
	if _retry_join():
		return
	leave(false)
	_apply_phase(Phase.MENU, {})
	session_ended.emit("Could not connect to %s (port %d UDP)." % [join_ip, port()])
	if not _test_report.is_empty():
		finish_test()


func _on_server_disconnected() -> void:
	print("net: host closed the session")
	leave(false)
	_apply_phase(Phase.MENU, {})
	players_changed.emit()
	session_ended.emit("The host left the game.")
	if not _test_report.is_empty():
		finish_test()


@rpc("any_peer", "call_remote", "reliable")
func _register(pname: String, look: Dictionary) -> void:
	if not is_host:
		return
	var id := multiplayer.get_remote_sender_id()
	if players.size() >= Tuning.MAX_PLAYERS:
		_rejected.rpc_id(id, "That kitchen is full (4 chefs).")
		get_tree().create_timer(0.5).timeout.connect(func() -> void:
			if multiplayer.multiplayer_peer is ENetMultiplayerPeer:
				multiplayer.multiplayer_peer.disconnect_peer(id))
		return
	var slot := _free_slot()
	players[id] = {"name": clean_name(pname), "slot": slot}
	players[id].merge(resolve_look(look, slot), true)
	print("net: %s joined as peer %d" % [players[id]["name"], id])
	_sync_players.rpc(players)
	_sync_settings.rpc_id(id, settings.to_dict())  # before the phase, so a World built on join sees them
	_sync_phase.rpc_id(id, phase, phase_info)
	players_changed.emit()

@rpc("authority", "call_remote", "reliable")
func _rejected(msg: String) -> void:
	leave(false)
	_apply_phase(Phase.MENU, {})
	session_ended.emit(msg)


@rpc("authority", "call_remote", "reliable")
func _sync_players(p: Dictionary) -> void:
	players = p
	players_changed.emit()
	looks_changed.emit()


# ---------------------------------------------------------------- chef looks

## A valid look for a player in slot: color 0..3 (out of range / -1 = the slot's colour), every LOOK_TABLES key
## a known id of its table (else the table's first entry).
func resolve_look(look: Dictionary, slot: int) -> Dictionary:
	var n := GameData.PLAYER_COLORS.size()
	var c := int(look.get("color", -1))
	if c < 0 or c >= n:
		c = posmod(slot, n)
	var out := {"color": c}
	var fixed := look
	for key: String in Cosmetics.RETIRED:   # retired ids (acc "moustache" -> beard "handlebar")
		var parts := key.split(":")
		if str(look.get(parts[0], "")) == parts[1]:
			fixed = look.duplicate()
			fixed.merge(Cosmetics.RETIRED[key], true)
	for k: String in LOOK_TABLES:
		var table: Array = LOOK_TABLES[k]
		var id := str(fixed.get(k, ""))
		out[k] = id if GameData.has_look_id(table, id) else str(table[0]["id"])
	return out


## {color: int, hat, acc, beard, outfit, back, body: String} of a player. Offline (no roster) the local pick, as slot 0.
func look_of(id: int) -> Dictionary:
	if players.has(id):
		return resolve_look(players[id], int(players[id]["slot"]))
	return resolve_look(local_look, 0)


func color_index_of(id: int) -> int:
	return int(look_of(id)["color"])


func color_of(id: int) -> Color:
	return GameData.PLAYER_COLORS[color_index_of(id)]


## My own look: merge a partial pick ({"color": 2} / {"hat": "beanie"} / {"body": "tall"} ...), remember
## it in menu.cfg and share it (host: roster sync; client: _request_look). Works offline and in any phase.
func set_look(pick: Dictionary) -> void:
	for k in local_look.keys():
		if pick.has(k):
			local_look[k] = pick[k]
	_save_look()
	if is_host:
		_store_look(1, local_look)
	elif multiplayer.multiplayer_peer is ENetMultiplayerPeer and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		_request_look.rpc_id(1, local_look)  # after _register on the same reliable channel
		if players.has(my_id()):  # show it at once; the host's roster sync confirms
			players[my_id()].merge(resolve_look(local_look, slot_of(my_id())), true)
			looks_changed.emit()
	else:
		looks_changed.emit()


@rpc("any_peer", "call_remote", "reliable")
func _request_look(look: Dictionary) -> void:
	if is_host:
		_store_look(multiplayer.get_remote_sender_id(), look)


## Host: validate and store a player's look, then re-send the roster.
## Trust model (friends game): ownership and tokens are local to each player (Progress), so the host does
## NOT check that a player owns what it wears; it accepts any catalogue id and only maps unknown ids to the
## default. A modded client can wear anything; nothing about gameplay depends on the look.
func _store_look(id: int, look: Dictionary) -> void:
	if not players.has(id):
		return
	var r := resolve_look(look, int(players[id]["slot"]))
	var cur: Dictionary = players[id]
	var same := true
	for k: String in r:
		if cur.get(k) != r[k]:
			same = false
	if same:
		return
	cur.merge(r, true)
	print("net: peer %d look %s" % [id, r])
	_sync_players.rpc(players)
	players_changed.emit()
	looks_changed.emit()


## The equipped look lives in Progress [equipped] (it migrates the old menu.cfg [chef] keys once). Scripted
## runs (--host / --join / --bot) start from the defaults and never save it. --look=hat:beanie,acc:glasses,...
## then --color= --hat= --acc= --beard= --outfit= --back= --body= override (not saved).
func _look_cfg_enabled() -> bool:
	return not (has_arg("host") or has_arg("join") or has_arg("bot"))


func _load_look() -> void:
	if _look_cfg_enabled():
		local_look.merge(Progress.equipped(), true)
	for pair in arg_str("look", "").split(",", false):
		var kv := pair.split(":")
		if kv.size() == 2 and local_look.has(kv[0]):
			local_look[kv[0]] = int(kv[1]) if kv[0] == "color" else kv[1]
	if has_arg("color"):
		local_look["color"] = arg_int("color", -1)
	for k: String in LOOK_TABLES:   # --hat= --acc= --beard= --outfit= --back= --body=
		if has_arg(k):
			local_look[k] = arg_str(k, str(local_look[k]))
	local_look.merge(_fix_retired(local_look), true)


## Retired ids in my own pick (acc "moustache" -> beard "handlebar"); the categories only, not the colour.
func _fix_retired(look: Dictionary) -> Dictionary:
	var r := resolve_look(look, 0)
	r.erase("color")
	return r


func _save_look() -> void:
	if _look_cfg_enabled():
		Progress.set_equipped(local_look)


# ---------------------------------------------------------------- phases

## Host only: change the phase everywhere.
func set_phase(ph: int, info: Dictionary) -> void:
	if not is_host:
		return
	info = info.duplicate()
	info["map"] = World.map_id_for_session()   # every peer builds its World from this map id
	_apply_phase(ph, info)
	_sync_phase.rpc(ph, info)


@rpc("authority", "call_remote", "reliable")
func _sync_phase(ph: int, info: Dictionary) -> void:
	_apply_phase(ph, info)


func _apply_phase(ph: int, info: Dictionary) -> void:
	phase = ph
	phase_info = info
	if ph <= Phase.LOBBY:
		_ready_peers.clear()
	phase_changed.emit(ph)


# ---------------------------------------------------------------- game settings

## True on the host, and offline in the menu (before hosting). False on a client.
func can_edit_settings() -> bool:
	return is_host or not (multiplayer.multiplayer_peer is ENetMultiplayerPeer)


## Host: replace the settings (a validated copy of s) and send them to every client.
## Ignored on clients and once a run has started (phase past LOBBY).
func set_settings(s: GameSettings) -> void:
	if not can_edit_settings() or s == null:
		return
	if phase > Phase.LOBBY:
		print("net: settings change ignored during a run")
		return
	var n := s.copy()
	for f in n.validate():
		print("net: settings fixed: %s" % f)
	if n.equals(settings):
		return
	settings = n
	print("net: settings %s" % settings.describe())
	if is_host:
		_sync_settings.rpc(settings.to_dict())
	settings_changed.emit()


## Host: change one field, e.g. change_setting("difficulty", "hard"), change_setting("modifiers", ["slippery"]).
## key is a GameSettings.to_dict() key; unknown keys are ignored.
func change_setting(key: String, value: Variant) -> void:
	var d := settings.to_dict()
	if not d.has(key):
		print("net: unknown setting %s" % key)
		return
	d[key] = value
	set_settings(GameSettings.from_dict(d))


@rpc("authority", "call_remote", "reliable")
func _sync_settings(d: Dictionary) -> void:
	if is_host:
		return
	var s := GameSettings.from_dict(d)
	s.validate()
	settings = s
	print("net: settings from host %s" % settings.describe())
	settings_changed.emit()


## Client: my World exists, start sending me snapshots.
func world_ready() -> void:
	if not is_host and multiplayer.multiplayer_peer is ENetMultiplayerPeer:
		_client_world_ready.rpc_id(1)


@rpc("any_peer", "call_remote", "reliable")
func _client_world_ready() -> void:
	if is_host:
		_ready_peers[multiplayer.get_remote_sender_id()] = true


# ---------------------------------------------------------------- game traffic

func send_snapshot(d: Dictionary) -> void:
	for pid in _ready_peers.keys():
		if players.has(pid):
			_snapshot.rpc_id(pid, d)


@rpc("authority", "call_remote", "unreliable_ordered", 1)
func _snapshot(d: Dictionary) -> void:
	metrics["snapshots"] = int(metrics["snapshots"]) + 1
	if world != null:
		world.apply_snapshot(d)


func send_input(inp: PlayerInput) -> void:
	if multiplayer.multiplayer_peer is ENetMultiplayerPeer and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED:
		_rpc_input.rpc_id(1, inp.move, inp.work, inp.grab_seq, inp.punch_seq, inp.work_seq, inp.aim_point, inp.has_aim)


@rpc("any_peer", "call_remote", "unreliable_ordered", 2)
func _rpc_input(move: Vector2, work: bool, grab_seq: int, punch_seq: int, work_seq: int, aim_point: Vector2, has_aim: bool) -> void:
	if is_host and world != null:
		world.receive_input(multiplayer.get_remote_sender_id(), move, work, grab_seq, punch_seq, work_seq, aim_point, has_aim)


## Host: toast + sound for everyone (to_peer 0) or one player.
func event(text: String, sfx: String, to_peer := 0) -> void:
	if not is_host:
		return
	if to_peer == 0 or to_peer == 1:
		event_received.emit(text, sfx)
	if to_peer == 0:
		_event.rpc(text, sfx)
	elif to_peer != 1 and players.has(to_peer):
		_event.rpc_id(to_peer, text, sfx)


@rpc("authority", "call_remote", "reliable")
func _event(text: String, sfx: String) -> void:
	event_received.emit(text, sfx)


## Every peer: ping world point xz (see World.host_ping); clients ask the host.
func ping(xz: Vector2) -> void:
	if is_host:
		if world != null:
			world.host_ping(1, xz)
	elif multiplayer.multiplayer_peer is ENetMultiplayerPeer:
		_rpc_ping.rpc_id(1, xz)


@rpc("any_peer", "call_remote", "reliable")
func _rpc_ping(xz: Vector2) -> void:
	if is_host and world != null:
		world.host_ping(multiplayer.get_remote_sender_id(), xz)


## level = the level this click buys (owned + 1 as the buyer saw it); the host refuses any other, so two
## quick clicks (or two players) cannot buy two levels with one look at the card.
func buy(upgrade_id: String, level: int) -> void:
	if is_host:
		if world != null:
			world.try_buy(upgrade_id, level)
	elif multiplayer.multiplayer_peer is ENetMultiplayerPeer:   # not after the host has gone
		_buy.rpc_id(1, upgrade_id, level)


@rpc("any_peer", "call_remote", "reliable")
func _buy(upgrade_id: String, level: int) -> void:
	if is_host and world != null:
		world.try_buy(upgrade_id, level)


# ---------------------------------------------------------------- test hooks

func metric_max(key: String, v: float) -> void:
	metrics[key] = maxf(float(metrics.get(key, 0.0)), v)


## Writes --test-report (if given) and quits with exit code 0.
func finish_test() -> void:
	if _finished:
		return
	_finished = true
	if not _test_report.is_empty():
		DirAccess.make_dir_recursive_absolute(_test_report.get_base_dir())
		var f := FileAccess.open(_test_report, FileAccess.WRITE)
		if f != null:
			f.store_string(JSON.stringify(metrics, "  "))
			f.close()
			print("net: test report written to %s" % _test_report)
	leave(false)
	get_tree().quit(0)
