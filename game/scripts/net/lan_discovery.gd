extends Node
## LAN game discovery (query/reply). Lives as a child of the Net autoload: `Net.discovery`.
##
## Searcher (join screen): start_search() sends a small JSON query once a second from an ephemeral UDP port
## to the discovery port (game port + 1, Net.discovery_port()) at 255.255.255.255, every local IPv4
## interface's directed broadcast (/24 assumed; 169.254.x.x -> /16) and 127.0.0.1, and reads the replies on
## the same socket. A game not heard from for EXPIRE_MSEC drops off. games_changed fires (once per frame at
## most) only when the list or a field changes. Join a listed game with Net.join(g.address, name, g.port).
## Host: Net calls start_hosting() when a host starts and stop_hosting() from Net.leave(); while hosting it
## listens on the discovery port and answers each valid query with one unicast reply built from the live
## lobby (name, players, map, mode, state, version, port). If the port cannot be bound, hosting carries on
## (one warning; typing the address still works).
## Packets: UTF-8 JSON <= MAX_PACKET bytes with MAGIC + PROTO; anything else is dropped silently.
## The reply also carries "id" (random per hosting session) so one host seen at several addresses
## (loopback + LAN on the same PC, two adapters) is listed once, at its best address.
## --fake-lan-games: start_search() reports three made-up games and never opens a socket (UI screenshots).

signal games_changed(games: Array)   ## Array of Dictionary (see get_games), sorted by name

const MAGIC := "TinyChefsLAN"
const PROTO := 1
const MAX_PACKET := 512
const QUERY_MSEC := 1000
const EXPIRE_MSEC := 3000
const MAX_PACKETS_PER_FRAME := 32   # per socket; the rest wait for the next frame
const MAX_GAMES := 32                # ignore new hosts beyond this (flood guard)
const NAME_LEN := 24
const FIELD_LEN := 32

var _fake := false
var _searching := false
var _search_sock: PacketPeerUDP = null
var _next_query := 0
var _warned_search := false
var _games: Dictionary = {}   # host id -> {"game": Dictionary (API shape), "seen": msec, "rank": int}
var _published: Array = []    # last list sent with games_changed

var _host_sock: PacketPeerUDP = null
var _host_id := ""
var _answered: Dictionary = {}   # address -> true, to log the first answer per searcher only
var _version := ""


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_fake = Net.has_arg("fake-lan-games")
	_version = str(ProjectSettings.get_setting("application/config/version", ""))


func _exit_tree() -> void:
	stop_search()
	stop_hosting()


# ---------------------------------------------------------------- searcher API

func start_search() -> void:
	if _searching:
		return
	_searching = true
	_games.clear()
	if _fake:
		print("lan: search started (--fake-lan-games: three made-up games, no network)")
		_publish(_fake_games())
		return
	_next_query = 0
	print("lan: search started (queries to UDP %d at %s)" % [Net.discovery_port(), ", ".join(_targets())])
	_publish([])


func stop_search() -> void:
	if not _searching:
		return
	_searching = false
	if _search_sock != null:
		_search_sock.close()
		_search_sock = null
	_games.clear()
	print("lan: search stopped")
	_publish([])


func is_searching() -> bool:
	return _searching


## Copy of the current list: [{address, port, name, players, max_players, map, mode, state, version, compatible}],
## sorted by name.
func get_games() -> Array:
	return _published.duplicate(true)


# ---------------------------------------------------------------- host API

func start_hosting() -> void:
	stop_hosting()
	var dport := Net.discovery_port()
	var bind_ip := Net.arg_str("bind", "*")
	if bind_ip == "*":
		bind_ip = "0.0.0.0"   # IPv4 socket: broadcasts are IPv4
	var s := PacketPeerUDP.new()
	var err := s.bind(dport, bind_ip, 16384)
	if err != OK:
		push_warning("lan: cannot listen for LAN searches on UDP %d (%s); hosting continues, players can still type the address" % [dport, error_string(err)])
		return
	_host_sock = s
	_host_id = "%08x%08x" % [randi(), randi()]
	_answered.clear()
	print("lan: answering LAN searches on UDP %d (%s)" % [dport, bind_ip])


func stop_hosting() -> void:
	if _host_sock == null:
		return
	_host_sock.close()
	_host_sock = null
	print("lan: stopped answering LAN searches")


func is_hosting() -> bool:
	return _host_sock != null


# ---------------------------------------------------------------- loop

func _process(_delta: float) -> void:
	if _host_sock != null:
		_serve()
	if _searching and not _fake:
		var now := Time.get_ticks_msec()
		if now >= _next_query:
			_next_query = now + QUERY_MSEC
			_send_queries()
		var changed := _read_replies(now)
		if _expire(now) or changed:
			_publish(_sorted_games())


# ---------------------------------------------------------------- host side

func _serve() -> void:
	var n := 0
	while _host_sock != null and _host_sock.get_available_packet_count() > 0 and n < MAX_PACKETS_PER_FRAME:
		n += 1
		var pkt := _host_sock.get_packet()
		var ip := _host_sock.get_packet_ip()
		var pport := _host_sock.get_packet_port()
		var d: Variant = parse_packet(pkt)
		if d == null or not _is(d.get("type"), "query") or ip.is_empty() or pport <= 0:
			continue
		var reply := _reply_bytes()
		if reply.is_empty():
			continue
		if _host_sock.set_dest_address(ip, pport) != OK:
			continue
		_host_sock.put_packet(reply)
		if not _answered.has(ip) and _answered.size() < 64:
			_answered[ip] = true
			print("lan: answered a LAN search from %s" % ip)


## The reply, read from the live lobby every time.
func _reply_bytes() -> PackedByteArray:
	var d := {
		"magic": MAGIC, "proto": PROTO, "type": "reply", "id": _host_id,
		"name": Net.name_of(1),
		"players": Net.players.size(),
		"max_players": Tuning.MAX_PLAYERS,
		"map": World.map_id_for_session(),
		"mode": str(Net.settings.mode),
		"state": "lobby" if Net.phase <= Net.Phase.LOBBY else "playing",
		"version": _version,
		"port": Net.port(),
	}
	var b := JSON.stringify(d).to_utf8_buffer()
	return b if b.size() <= MAX_PACKET else PackedByteArray()


# ---------------------------------------------------------------- searcher side

func _send_queries() -> void:
	if _search_sock == null:
		var s := PacketPeerUDP.new()
		s.set_broadcast_enabled(true)
		var err := s.bind(0, "0.0.0.0", 65536)
		if err != OK:
			if not _warned_search:
				_warned_search = true
				push_warning("lan: cannot open a UDP socket to search the LAN (%s)" % error_string(err))
			return
		_search_sock = s
	var q := JSON.stringify({"magic": MAGIC, "proto": PROTO, "type": "query"}).to_utf8_buffer()
	var dport := Net.discovery_port()
	for t in _targets():
		if _search_sock.set_dest_address(t, dport) == OK:
			_search_sock.put_packet(q)   # an adapter that cannot broadcast just fails; ignored


## Query destinations: limited broadcast, each local IPv4 interface's directed broadcast, loopback.
func _targets() -> PackedStringArray:
	var t := PackedStringArray(["255.255.255.255"])
	for iface: Dictionary in IP.get_local_interfaces():
		for a: String in iface.get("addresses", []):
			var p := a.split(".")
			if a.contains(":") or p.size() != 4 or a.begins_with("127.") or a == "0.0.0.0":
				continue
			var b := "%s.%s.255.255" % [p[0], p[1]] if a.begins_with("169.254.") else "%s.%s.%s.255" % [p[0], p[1], p[2]]
			if not t.has(b):
				t.append(b)
	t.append("127.0.0.1")
	return t


## Reads pending replies; true when the list or a field changed.
func _read_replies(now: int) -> bool:
	var changed := false
	var n := 0
	while _search_sock != null and _search_sock.get_available_packet_count() > 0 and n < MAX_PACKETS_PER_FRAME:
		n += 1
		var pkt := _search_sock.get_packet()
		var ip := _search_sock.get_packet_ip()
		var d: Variant = parse_packet(pkt)
		if d == null or ip.is_empty() or ip.contains(":"):
			continue
		var g: Variant = game_from_reply(d, ip, _version)
		if g == null:
			continue
		var id := str(d["id"])
		var rank := _addr_rank(ip)
		if _games.has(id):
			var e: Dictionary = _games[id]
			if rank > int(e["rank"]) and now - int(e["seen"]) < EXPIRE_MSEC:
				continue   # same host at a worse address while the better one is fresh: keep the better one
			if e["game"] != g:
				changed = true
			e["game"] = g
			e["seen"] = now
			e["rank"] = rank
		elif _games.size() < MAX_GAMES:
			_games[id] = {"game": g, "seen": now, "rank": rank}
			changed = true
	return changed


func _expire(now: int) -> bool:
	var gone: Array = []
	for id in _games:
		if now - int(_games[id]["seen"]) > EXPIRE_MSEC:
			gone.append(id)
	for id in gone:
		_games.erase(id)
	return not gone.is_empty()


func _sorted_games() -> Array:
	var out: Array = []
	for e: Dictionary in _games.values():
		out.append(e["game"])
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var na := str(a["name"]).to_lower()
		var nb := str(b["name"]).to_lower()
		if na != nb:
			return na < nb
		return "%s:%d" % [a["address"], a["port"]] < "%s:%d" % [b["address"], b["port"]])
	return out


func _publish(list: Array) -> void:
	if list == _published:
		return
	_published = list
	var parts: PackedStringArray = []
	for g: Dictionary in list:
		parts.append("%s @ %s:%d %s %d/%d %s v%s%s" % [g["name"], g["address"], g["port"], g["state"],
			g["players"], g["max_players"], g["map"], g["version"], "" if g["compatible"] else " (incompatible)"])
	print("lan: games (%d): %s" % [list.size(), "; ".join(parts)])
	games_changed.emit(get_games())


## Loopback first (same PC), then home/office LANs, then the rest (often virtual adapters).
func _addr_rank(ip: String) -> int:
	if ip.begins_with("127."):
		return 0
	if ip.begins_with("192.168."):
		return 1
	if ip.begins_with("10."):
		return 2
	return 3


func _fake_games() -> Array:
	return [
		{"address": "192.168.1.23", "port": Tuning.PORT, "name": "Anna", "players": 1, "max_players": 4,
			"map": "diner", "mode": "campaign", "state": "lobby", "version": _version, "compatible": true},
		{"address": "192.168.1.41", "port": Tuning.PORT, "name": "Jonas", "players": 3, "max_players": 4,
			"map": "picnic", "mode": "endless", "state": "playing", "version": _version, "compatible": true},
		{"address": "192.168.1.57", "port": Tuning.PORT, "name": "Old Laptop", "players": 2, "max_players": 4,
			"map": "diner", "mode": "custom", "state": "lobby", "version": "0.3.0", "compatible": false},
	]


# ---------------------------------------------------------------- packet validation (static, testable)

## A Dictionary with our magic and protocol, or null. Never prints: foreign or broken traffic is just dropped.
static func parse_packet(pkt: PackedByteArray) -> Variant:
	if pkt.is_empty() or pkt.size() > MAX_PACKET or not _valid_utf8(pkt):
		return null
	var j := JSON.new()
	if j.parse(pkt.get_string_from_utf8()) != OK:
		return null
	var d: Variant = j.data
	if typeof(d) != TYPE_DICTIONARY or not _is(d.get("magic"), MAGIC) or _int_of(d.get("proto"), 0, 1 << 30) != PROTO:
		return null
	if typeof(d.get("type")) != TYPE_STRING:
		return null
	return d


## A game entry (API shape) from a parsed reply, or null when a field is missing or the wrong type.
static func game_from_reply(d: Dictionary, address: String, my_version: String) -> Variant:
	if not _is(d.get("type"), "reply"):
		return null
	var id: Variant = _str_of(d.get("id"), FIELD_LEN)
	var gname: Variant = _str_of(d.get("name"), NAME_LEN)
	var map: Variant = _str_of(d.get("map"), FIELD_LEN)
	var mode: Variant = _str_of(d.get("mode"), FIELD_LEN)
	var state: Variant = d.get("state")
	var version: Variant = _str_of(d.get("version"), FIELD_LEN)
	var max_players: Variant = _int_of(d.get("max_players"), 1, 16)
	var players: Variant = _int_of(d.get("players"), 0, 16)
	var gport: Variant = _int_of(d.get("port"), 0, 1 << 30)
	if id == null or str(id).is_empty() or gname == null or map == null or mode == null or version == null:
		return null
	if max_players == null or players == null or gport == null or int(gport) < 1 or int(gport) > 65535:
		return null
	if not _is(state, "lobby") and not _is(state, "playing"):
		return null
	if str(gname).is_empty():
		gname = "Chef"
	return {"address": address, "port": int(gport), "name": str(gname), "players": mini(int(players), int(max_players)),
		"max_players": int(max_players), "map": str(map), "mode": str(mode), "state": str(state),
		"version": str(version), "compatible": str(version) == my_version}


## v is the String s (type checked first: never compares across types).
static func _is(v: Variant, s: String) -> bool:
	return typeof(v) == TYPE_STRING and v == s


## int in lo..hi (clamped) from a JSON number that is a whole number, else null.
static func _int_of(v: Variant, lo: int, hi: int) -> Variant:
	if typeof(v) != TYPE_INT and typeof(v) != TYPE_FLOAT:
		return null
	var f := float(v)
	if is_nan(f) or is_inf(f) or f != floorf(f):
		return null
	return clampi(int(clampf(f, lo, hi)), lo, hi)


## String without control characters, trimmed and clamped to max_len, else null.
static func _str_of(v: Variant, max_len: int) -> Variant:
	if typeof(v) != TYPE_STRING:
		return null
	var s: String = v
	var out := ""
	for i in mini(s.length(), max_len * 4):
		var c := s.unicode_at(i)
		if c >= 0x20 and c != 0x7f and not (c >= 0xd800 and c <= 0xdfff):
			out += String.chr(c)
	return out.strip_edges().substr(0, max_len)


## Strict UTF-8 check (no control bytes, no overlongs, no surrogates), so decoding never logs an error.
static func _valid_utf8(b: PackedByteArray) -> bool:
	var i := 0
	var n := b.size()
	while i < n:
		var c := b[i]
		var extra := 0
		var lo := 0x80
		var hi := 0xbf
		if c < 0x80:
			if c < 0x20 or c == 0x7f:
				return false
			i += 1
			continue
		elif c >= 0xc2 and c <= 0xdf:
			extra = 1
		elif c >= 0xe0 and c <= 0xef:
			extra = 2
			if c == 0xe0:
				lo = 0xa0
			elif c == 0xed:
				hi = 0x9f
		elif c >= 0xf0 and c <= 0xf4:
			extra = 3
			if c == 0xf0:
				lo = 0x90
			elif c == 0xf4:
				hi = 0x8f
		else:
			return false
		if i + extra >= n:
			return false
		for k in extra:
			var cc := b[i + 1 + k]
			if k == 0:
				if cc < lo or cc > hi:
					return false
			elif cc < 0x80 or cc > 0xbf:
				return false
		i += 1 + extra
	return true
