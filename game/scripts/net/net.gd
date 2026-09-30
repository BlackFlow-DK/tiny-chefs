extends Node
## Autoload "Net": the ENet session, player registry, game phase, command-line args and test hooks.
## Host-authoritative: clients send inputs, the host simulates and broadcasts snapshots.
## All RPCs live here (the autoload exists at the same path on every peer), and are forwarded
## to the World when one exists, so a packet can never target a node that is not there yet.
##
## User args (after "--"): --host --join=<ip> --name=<x> --autostart --players=<n> --bot
##   --bind=<ip> --shift-seconds=<s> --test-report=<json path> --quit-after=<s> --quit-after-shift

signal players_changed
signal phase_changed(phase: int)
signal session_ended(reason: String)
signal event_received(text: String, sfx: String)

enum Phase { MENU, LOBBY, PLAYING, RESULTS, SHOP }

var phase: int = Phase.MENU
var phase_info: Dictionary = {}
var players: Dictionary = {}  # peer id -> {"name": String, "slot": int}
var local_name := "Chef"
var is_host := false
var join_ip := ""
var args: Dictionary = {}
var metrics: Dictionary = {}
var world: Node = null  # the World sets itself here while it exists

var _ready_peers: Dictionary = {}
var _test_report := ""
var _finished := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_parse_args()
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


# ---------------------------------------------------------------- session

func host(pname: String) -> Error:
	leave(false)
	var peer := ENetMultiplayerPeer.new()
	if has_arg("bind"):
		peer.set_bind_ip(arg_str("bind", "*"))
	var err := peer.create_server(Tuning.PORT, Tuning.MAX_PLAYERS - 1)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	is_host = true
	local_name = clean_name(pname)
	players = {1: {"name": local_name, "slot": 0}}
	metrics["role"] = "host"
	metrics["connected"] = true
	print("net: hosting on UDP %d" % Tuning.PORT)
	set_phase(Phase.LOBBY, {})
	players_changed.emit()
	return OK


func join(ip: String, pname: String) -> Error:
	leave(false)
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(ip, Tuning.PORT)
	if err != OK:
		return err
	multiplayer.multiplayer_peer = peer
	is_host = false
	join_ip = ip
	local_name = clean_name(pname)
	metrics["role"] = "client"
	print("net: connecting to %s:%d" % [ip, Tuning.PORT])
	return OK


## Close the session and go back to the menu.
func leave(emit := true) -> void:
	if multiplayer.multiplayer_peer != null and not (multiplayer.multiplayer_peer is OfflineMultiplayerPeer):
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = OfflineMultiplayerPeer.new()
	players.clear()
	_ready_peers.clear()
	is_host = false
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
	metrics["connected"] = true
	print("net: connected to host, my id %d" % my_id())
	_register.rpc_id(1, local_name)


func _on_connection_failed() -> void:
	leave(false)
	_apply_phase(Phase.MENU, {})
	session_ended.emit("Could not connect to %s (port %d UDP)." % [join_ip, Tuning.PORT])
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
func _register(pname: String) -> void:
	if not is_host:
		return
	var id := multiplayer.get_remote_sender_id()
	if players.size() >= Tuning.MAX_PLAYERS:
		_rejected.rpc_id(id, "That kitchen is full (4 chefs).")
		get_tree().create_timer(0.5).timeout.connect(func() -> void:
			if multiplayer.multiplayer_peer is ENetMultiplayerPeer:
				multiplayer.multiplayer_peer.disconnect_peer(id))
		return
	players[id] = {"name": clean_name(pname), "slot": _free_slot()}
	print("net: %s joined as peer %d" % [players[id]["name"], id])
	_sync_players.rpc(players)
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


# ---------------------------------------------------------------- phases

## Host only: change the phase everywhere.
func set_phase(ph: int, info: Dictionary) -> void:
	if not is_host:
		return
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
		_rpc_input.rpc_id(1, inp.move, inp.work, inp.grab_seq, inp.punch_seq, inp.work_seq)


@rpc("any_peer", "call_remote", "unreliable_ordered", 2)
func _rpc_input(move: Vector2, work: bool, grab_seq: int, punch_seq: int, work_seq: int) -> void:
	if is_host and world != null:
		world.receive_input(multiplayer.get_remote_sender_id(), move, work, grab_seq, punch_seq, work_seq)


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


func buy(upgrade_id: String) -> void:
	if is_host:
		if world != null:
			world.try_buy(upgrade_id)
	else:
		_buy.rpc_id(1, upgrade_id)


@rpc("any_peer", "call_remote", "reliable")
func _buy(upgrade_id: String) -> void:
	if is_host and world != null:
		world.try_buy(upgrade_id)


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
